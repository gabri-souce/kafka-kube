// ============================================================================
// PIPELINE: GESTIONE KAFKA TOPICS (CREATE / DELETE)
// ============================================================================
// Crea o elimina KafkaTopic tramite Strimzi CRD
// Autenticazione: jenkins-user (SCRAM-SHA-512, solo permessi necessari)
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
"""
        }
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['CREATE', 'DELETE'],
            description: 'Operazione da eseguire'
        )
        string(
            name: 'TOPIC_NAME',
            defaultValue: '',
            description: 'Nome del topic (es: ordini-prod, pagamenti-events)'
        )
        string(
            name: 'PARTITIONS',
            defaultValue: '3',
            description: 'Numero di partizioni (default: 3)'
        )
        string(
            name: 'REPLICAS',
            defaultValue: '3',
            description: 'Numero di repliche (default: 3, max: numero broker)'
        )
        string(
            name: 'RETENTION_HOURS',
            defaultValue: '168',
            description: 'Retention in ore (default: 168 = 7 giorni)'
        )
        string(
            name: 'CONFIRM_DELETE',
            defaultValue: '',
            description: '⚠️  Solo per DELETE: riscrivi il nome del topic per confermare'
        )
    }

    environment {
        KAFKA_NAMESPACE  = 'kafka-lab'
        KAFKA_CLUSTER    = 'kafka-cluster'
    }

    stages {

        stage('Validazione') {
            steps {
                script {
                    if (!params.TOPIC_NAME?.trim()) {
                        error "❌ TOPIC_NAME è obbligatorio!"
                    }
                    if (params.ACTION == 'DELETE' && params.TOPIC_NAME != params.CONFIRM_DELETE) {
                        error "❌ Conferma non valida! Hai scritto '${params.CONFIRM_DELETE}' invece di '${params.TOPIC_NAME}'"
                    }
                    def protectedTopics = ['__consumer_offsets', '__transaction_state',
                                           'connect-cluster-configs', 'connect-cluster-offsets',
                                           'connect-cluster-status']
                    if (params.TOPIC_NAME in protectedTopics) {
                        error "❌ Topic di sistema protetto: ${params.TOPIC_NAME}"
                    }
                    echo "✅ Validazione OK: ${params.ACTION} topic '${params.TOPIC_NAME}'"
                }
            }
        }

        stage('Verifica Cluster') {
            steps {
                container('kubectl') {
                    script {
                        def clusterStatus = sh(
                            script: "kubectl get kafka ${env.KAFKA_CLUSTER} -n ${env.KAFKA_NAMESPACE} -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo 'NotFound'",
                            returnStdout: true
                        ).trim()
                        if (clusterStatus != 'Ready') {
                            error "❌ Kafka cluster non è Ready (stato: ${clusterStatus})"
                        }
                        echo "✅ Kafka cluster Ready"
                    }
                }
            }
        }

        stage('Crea Topic') {
            when { expression { params.ACTION == 'CREATE' } }
            steps {
                container('kubectl') {
                    script {
                        def retentionMs = params.RETENTION_HOURS.toInteger() * 3600000
                        sh """
cat <<YAML | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: ${params.TOPIC_NAME}
  namespace: ${env.KAFKA_NAMESPACE}
  labels:
    strimzi.io/cluster: ${env.KAFKA_CLUSTER}
    managed-by: jenkins
spec:
  partitions: ${params.PARTITIONS}
  replicas: ${params.REPLICAS}
  config:
    retention.ms: "${retentionMs}"
    segment.bytes: "1073741824"
    min.insync.replicas: "2"
YAML
"""
                        // Attendi che Strimzi crei il topic
                        sh "kubectl wait kafkatopic/${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE} --for=condition=Ready --timeout=60s"
                        echo "✅ Topic '${params.TOPIC_NAME}' creato con successo!"
                    }
                }
            }
        }

        stage('Elimina Topic') {
            when { expression { params.ACTION == 'DELETE' } }
            steps {
                container('kubectl') {
                    script {
                        def exists = sh(
                            script: "kubectl get kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE} 2>/dev/null && echo 'exists' || echo 'notfound'",
                            returnStdout: true
                        ).trim()
                        if (exists == 'notfound') {
                            echo "⚠️  Topic '${params.TOPIC_NAME}' non esiste, nulla da fare."
                        } else {
                            sh "kubectl delete kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE}"
                            echo "✅ Topic '${params.TOPIC_NAME}' eliminato!"
                        }
                    }
                }
            }
        }

        stage('Verifica Finale') {
            steps {
                container('kubectl') {
                    script {
                        echo "📋 Topic nel cluster:"
                        sh "kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} --no-headers | sort"
                    }
                }
            }
        }
    }

    post {
        success { echo "🎉 Pipeline completata con successo!" }
        failure { echo "❌ Pipeline fallita. Controlla i log sopra." }
    }
}
