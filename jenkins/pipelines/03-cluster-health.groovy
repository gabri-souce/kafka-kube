// ============================================================================
// PIPELINE: MONITORAGGIO CLUSTER KAFKA
// ============================================================================
// Verifica stato completo del cluster Kafka in stile production
// Controlla broker, topic, utenti, consumer groups e lag
// ============================================================================

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-admin
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["/bin/sh", "-c", "cat"]
    tty: true
    securityContext:
      runAsUser: 0
  - name: kafka-tools
    image: quay.io/strimzi/kafka:0.44.0-kafka-3.8.0
    command: ["/bin/sh", "-c", "cat"]
    tty: true
    securityContext:
      runAsUser: 0
"""
        }
    }

    parameters {
        choice(
            name: 'CHECK_LEVEL',
            choices: ['BASIC', 'FULL', 'TOPICS_DETAIL', 'CONSUMER_LAG'],
            description: 'Livello di dettaglio del check'
        )
        string(
            name: 'TOPIC_FILTER',
            defaultValue: '',
            description: 'Filtra per nome topic (solo per TOPICS_DETAIL, lascia vuoto per tutti)'
        )
    }

    environment {
        KAFKA_NAMESPACE   = 'kafka-lab'
        KAFKA_CLUSTER     = 'kafka-cluster'
        KAFKA_BOOTSTRAP   = 'kafka-cluster-kafka-bootstrap:9092'
    }

    stages {

        stage('Status Cluster Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "  KAFKA LAB - CLUSTER HEALTH CHECK"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo ""
                        echo "📦 POD STATUS:"
                        sh "kubectl get pods -n ${env.KAFKA_NAMESPACE} --no-headers | awk '{printf \"  %-50s %s\\n\", \$1, \$3}'"
                        echo ""
                        echo "🔌 KAFKA CLUSTER STATUS:"
                        sh "kubectl get kafka ${env.KAFKA_CLUSTER} -n ${env.KAFKA_NAMESPACE} -o jsonpath='{.status.conditions[0].type}: {.status.conditions[0].status}' && echo ''"
                        sh "kubectl get kafka ${env.KAFKA_CLUSTER} -n ${env.KAFKA_NAMESPACE} -o jsonpath='Kafka version: {.spec.kafka.version}' && echo ''"
                        sh "kubectl get kafka ${env.KAFKA_CLUSTER} -n ${env.KAFKA_NAMESPACE} -o jsonpath='Listeners: {.status.listeners[*].name}' && echo ''"
                    }
                }
            }
        }

        stage('Topics Status') {
            steps {
                container('kubectl') {
                    script {
                        echo ""
                        echo "📋 KAFKA TOPICS:"
                        sh """
kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} --no-headers | \
  awk '{printf "  %-40s partitions=%-5s replicas=%-5s ready=%s\\n", \$1, \$3, \$4, \$5}' | sort
"""
                        def topicCount = sh(
                            script: "kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} --no-headers | grep -v '^connect-' | wc -l | tr -d ' '",
                            returnStdout: true
                        ).trim()
                        echo "  → Totale topic utente: ${topicCount}"
                    }
                }
            }
        }

        stage('Users Status') {
            steps {
                container('kubectl') {
                    script {
                        echo ""
                        echo "👥 KAFKA USERS:"
                        sh """
kubectl get kafkauser -n ${env.KAFKA_NAMESPACE} --no-headers | \
  awk '{printf "  %-30s auth=%-20s ready=%s\\n", \$1, \$3, \$5}' | sort
"""
                    }
                }
            }
        }

        stage('External Secrets Status') {
            steps {
                container('kubectl') {
                    script {
                        echo ""
                        echo "🔐 EXTERNAL SECRETS (Vault sync):"
                        sh """
kubectl get externalsecrets -n ${env.KAFKA_NAMESPACE} --no-headers | \
  awk '{printf "  %-35s status=%s ready=%s\\n", \$1, \$5, \$6}' | sort
"""
                    }
                }
            }
        }

        stage('PVC Status') {
            steps {
                container('kubectl') {
                    script {
                        echo ""
                        echo "💾 PERSISTENT VOLUMES:"
                        sh """
kubectl get pvc -n ${env.KAFKA_NAMESPACE} --no-headers | \
  awk '{printf "  %-40s status=%-10s size=%s\\n", \$1, \$2, \$4}' | sort
"""
                    }
                }
            }
        }

        stage('Cluster Metrics FULL') {
            when { expression { params.CHECK_LEVEL in ['FULL', 'TOPICS_DETAIL', 'CONSUMER_LAG'] } }
            steps {
                container('kafka-tools') {
                    script {
                        echo ""
                        echo "📊 TOPIC LIST (da broker):"
                        sh """
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server ${env.KAFKA_BOOTSTRAP} \
  --list 2>/dev/null | grep -v '^__' | sort | sed 's/^/  /'
"""
                    }
                }
            }
        }

        stage('Topic Detail') {
            when { expression { params.CHECK_LEVEL == 'TOPICS_DETAIL' } }
            steps {
                container('kafka-tools') {
                    script {
                        echo ""
                        echo "🔍 TOPIC DETAIL:"
                        def filter = params.TOPIC_FILTER?.trim() ? "--topic ${params.TOPIC_FILTER}" : ""
                        sh """
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server ${env.KAFKA_BOOTSTRAP} \
  --describe ${filter} 2>/dev/null | grep -v '^__' | head -100
"""
                    }
                }
            }
        }

        stage('Consumer Lag') {
            when { expression { params.CHECK_LEVEL == 'CONSUMER_LAG' } }
            steps {
                container('kafka-tools') {
                    script {
                        echo ""
                        echo "📉 CONSUMER GROUP LAG:"
                        sh """
/opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server ${env.KAFKA_BOOTSTRAP} \
  --list 2>/dev/null | while read group; do
    echo "  Group: \$group"
    /opt/kafka/bin/kafka-consumer-groups.sh \
      --bootstrap-server ${env.KAFKA_BOOTSTRAP} \
      --describe --group "\$group" 2>/dev/null | grep -v '^GROUP' | \
      awk '{printf "    topic=%-30s partition=%-5s lag=%s\\n", \$2, \$3, \$6}' || true
done
"""
                    }
                }
            }
        }

        stage('Riepilogo Salute') {
            steps {
                container('kubectl') {
                    script {
                        echo ""
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        echo "  RIEPILOGO SALUTE CLUSTER"
                        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                        def issues = 0

                        // Controlla pod non running
                        def badPods = sh(
                            script: "kubectl get pods -n ${env.KAFKA_NAMESPACE} --no-headers | grep -v 'Running\\|Completed' | wc -l | tr -d ' '",
                            returnStdout: true
                        ).trim().toInteger()
                        if (badPods > 0) {
                            echo "  ⚠️  ${badPods} pod non in stato Running!"
                            issues++
                        } else {
                            echo "  ✅ Tutti i pod Running"
                        }

                        // Contr
