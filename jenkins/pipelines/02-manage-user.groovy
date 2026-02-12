// ============================================================================
// PIPELINE: GESTIONE KAFKA USERS CON ACL
// ============================================================================
// Crea/elimina KafkaUser con autenticazione SCRAM-SHA-512 e ACL granulari
// La password viene gestita da Vault tramite External Secrets
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
            name: 'USERNAME',
            defaultValue: '',
            description: 'Nome utente Kafka (es: app-pagamenti, service-ordini)'
        )
        choice(
            name: 'ROLE',
            choices: ['producer', 'consumer', 'producer-consumer', 'admin'],
            description: 'Ruolo predefinito (determina le ACL automaticamente)'
        )
        string(
            name: 'TOPIC_PATTERN',
            defaultValue: '*',
            description: 'Pattern topic accessibili (es: ordini-*, * per tutti)'
        )
        string(
            name: 'CONSUMER_GROUP',
            defaultValue: '*',
            description: 'Consumer group permesso (solo per ruolo consumer)'
        )
        string(
            name: 'CONFIRM_DELETE',
            defaultValue: '',
            description: '⚠️  Solo per DELETE: riscrivi username per confermare'
        )
    }

    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        KAFKA_CLUSTER   = 'kafka-cluster'
    }

    stages {

        stage('Validazione') {
            steps {
                script {
                    if (!params.USERNAME?.trim()) {
                        error "❌ USERNAME è obbligatorio!"
                    }
                    if (params.USERNAME ==~ /[^a-z0-9\-]/) {
                        error "❌ Username deve contenere solo lettere minuscole, numeri e trattini"
                    }
                    def protectedUsers = ['admin', 'kafka-connect', 'producer-user', 'consumer-user']
                    if (params.USERNAME in protectedUsers) {
                        error "❌ Utente di sistema protetto: ${params.USERNAME}"
                    }
                    if (params.ACTION == 'DELETE' && params.USERNAME != params.CONFIRM_DELETE) {
                        error "❌ Conferma non valida! Hai scritto '${params.CONFIRM_DELETE}' invece di '${params.USERNAME}'"
                    }
                    echo "✅ Validazione OK: ${params.ACTION} user '${params.USERNAME}' con ruolo '${params.ROLE}'"
                }
            }
        }

        stage('Crea Utente') {
            when { expression { params.ACTION == 'CREATE' } }
            steps {
                container('kubectl') {
                    script {
                        // Costruisci ACL in base al ruolo scelto
                        def acls = ""

                        if (params.ROLE in ['producer', 'producer-consumer']) {
                            acls += """
      - resource:
          type: topic
          name: "${params.TOPIC_PATTERN}"
          patternType: ${params.TOPIC_PATTERN.endsWith('*') ? 'prefix' : 'literal'}
        operations: ["Write", "Describe", "Create"]"""
                        }

                        if (params.ROLE in ['consumer', 'producer-consumer']) {
                            acls += """
      - resource:
          type: topic
          name: "${params.TOPIC_PATTERN}"
          patternType: ${params.TOPIC_PATTERN.endsWith('*') ? 'prefix' : 'literal'}
        operations: ["Read", "Describe"]
      - resource:
          type: group
          name: "${params.CONSUMER_GROUP}"
          patternType: ${params.CONSUMER_GROUP == '*' ? 'literal' : 'literal'}
        operations: ["Read"]"""
                        }

                        if (params.ROLE == 'admin') {
                            acls += """
      - resource:
          type: topic
          name: "*"
          patternType: literal
        operations: ["All"]
      - resource:
          type: group
          name: "*"
          patternType: literal
        operations: ["All"]
      - resource:
          type: cluster
        operations: ["All"]"""
                        }

                        sh """
cat <<YAML | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${params.USERNAME}
  namespace: ${env.KAFKA_NAMESPACE}
  labels:
    strimzi.io/cluster: ${env.KAFKA_CLUSTER}
    managed-by: jenkins
    role: ${params.ROLE}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
${acls}
YAML
"""
                        // Attendi che Strimzi crei l'utente
                        sh "kubectl wait kafkauser/${params.USERNAME} -n ${env.KAFKA_NAMESPACE} --for=condition=Ready --timeout=60s"

                        // Mostra il secret creato da Strimzi (contiene username/password)
                        echo "✅ Utente '${params.USERNAME}' creato con ruolo '${params.ROLE}'!"
                        echo "📋 Secret K8s creato: ${params.USERNAME}"
                        echo "   Recupera password: kubectl get secret ${params.USERNAME} -n ${env.KAFKA_NAMESPACE} -o jsonpath='{.data.password}' | base64 -d"
                    }
                }
            }
        }

        stage('Elimina Utente') {
            when { expression { params.ACTION == 'DELETE' } }
            steps {
                container('kubectl') {
                    script {
                        sh "kubectl delete kafkauser ${params.USERNAME} -n ${env.KAFKA_NAMESPACE} --ignore-not-found"
                        echo "✅ Utente '${params.USERNAME}' eliminato!"
                    }
                }
            }
        }

        stage('Verifica Finale') {
            steps {
                container('kubectl') {
                    script {
                        echo "📋 Utenti nel cluster:"
                        sh "kubectl get kafkauser -n ${env.KAFKA_NAMESPACE} --no-headers | sort"
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
