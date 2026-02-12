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

    options {
        timeout(time: 10, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        choice(name: 'ACTION', choices: ['CREATE', 'DELETE'], description: 'Operazione')
        string(name: 'USERNAME', defaultValue: '', description: 'Nome utente')
        choice(name: 'ROLE', choices: ['producer', 'consumer', 'producer-consumer', 'admin'], description: 'Ruolo')
        string(name: 'TOPIC_PATTERN', defaultValue: '*', description: 'Pattern Topic (es. ordini-*)')
        string(name: 'CONSUMER_GROUP', defaultValue: '*', description: 'Consumer Group')
        string(name: 'CONFIRM_DELETE', defaultValue: '', description: '⚠️ Solo per DELETE: riscrivi username')
    }

    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        KAFKA_CLUSTER   = 'kafka-cluster'
    }

    stages {
        stage('Validazione') {
            steps {
                script {
                    if (!params.USERNAME?.trim()) error "❌ USERNAME obbligatorio!"
                    if (params.ACTION == 'DELETE' && params.USERNAME != params.CONFIRM_DELETE) error "❌ Conferma fallita!"
                }
            }
        }

        stage('Esecuzione') {
            steps {
                container('kubectl') {
                    script {
                        if (params.ACTION == 'CREATE') {
                            def acls = ""
                            def patternType = params.TOPIC_PATTERN.endsWith('*') ? 'prefix' : 'literal'
                            def cleanPattern = params.TOPIC_PATTERN.replace('*', '')

                            if (params.ROLE in ['producer', 'producer-consumer']) {
                                acls += """
      - resource:
          type: topic
          name: "${cleanPattern}"
          patternType: ${patternType}
        operations: ["Write", "Describe", "Create"]"""
                            }
                            if (params.ROLE in ['consumer', 'producer-consumer']) {
                                acls += """
      - resource:
          type: topic
          name: "${cleanPattern}"
          patternType: ${patternType}
        operations: ["Read", "Describe"]
      - resource:
          type: group
          name: "${params.CONSUMER_GROUP}"
          patternType: literal
        operations: ["Read"]"""
                            }
                            if (params.ROLE == 'admin') {
                                acls += """
      - resource: { type: topic, name: "*", patternType: literal }
        operations: ["All"]
      - resource: { type: group, name: "*", patternType: literal }
        operations: ["All"]
      - resource: { type: cluster }
        operations: ["All"]"""
                            }

                            sh """
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: ${params.USERNAME}
  namespace: ${env.KAFKA_NAMESPACE}
  labels:
    strimzi.io/cluster: ${env.KAFKA_CLUSTER}
    managed-by: jenkins
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
${acls}
EOF
"""
                            echo "⏳ Attesa riconciliazione utente (max 2 min)..."
                            sleep 5
                            // Se fallisce il wait, stampiamo il motivo prima di uscire
                            try {
                                sh "kubectl wait kafkauser/${params.USERNAME} -n ${env.KAFKA_NAMESPACE} --for=condition=Ready --timeout=120s"
                            } catch (Exception e) {
                                sh "kubectl get kafkauser ${params.USERNAME} -n ${env.KAFKA_NAMESPACE} -o yaml"
                                error "❌ L'utente non è diventato Ready. Controlla lo stato sopra."
                            }
                            echo "✅ Utente '${params.USERNAME}' pronto!"
                        } else {
                            sh "kubectl delete kafkauser ${params.USERNAME} -n ${env.KAFKA_NAMESPACE} --ignore-not-found"
                            echo "✅ Utente eliminato!"
                        }
                    }
                }
            }
        }
    }
}
