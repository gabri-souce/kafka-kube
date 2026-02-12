// ============================================================================
// PIPELINE: DEPLOY KAFKA CONNECTOR (Fixed Version)
// ============================================================================

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: kafka-agent
spec:
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["/bin/sh", "-c"]
    args: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
"""
        }
    }
    
    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        KAFKA_CONNECT_CLUSTER = 'kafka-connect'
        // Assicurati che su Jenkins esista una credenziale "Secret Text" con questo ID
        K8S_CREDENTIAL_ID = 'k8s-token' 
    }
    
    parameters {
        string(name: 'CONNECTOR_NAME', defaultValue: '', description: 'Nome del connector')
        choice(name: 'CONNECTOR_TYPE', choices: ['FileStreamSource', 'FileStreamSink', 'Custom'], description: 'Tipo')
        string(name: 'TOPIC', defaultValue: 'connector-topic', description: 'Topic Kafka')
        string(name: 'FILE_PATH', defaultValue: '/tmp/test.txt', description: 'Path del file')
        text(name: 'CUSTOM_CONFIG', defaultValue: '', description: 'Configurazione custom (YAML)')
    }
    
    stages {
        stage('Validate') {
            steps {
                script {
                    if (!params.CONNECTOR_NAME?.trim()) {
                        error "ERRORE: Il nome del connettore è obbligatorio!"
                    }
                }
            }
        }
        
        stage('Generate & Deploy') {
            steps {
                container('kubectl') {
                    script {
                        def connectorClass = ""
                        def config = ""
                        
                        switch(params.CONNECTOR_TYPE) {
                            case 'FileStreamSource':
                                connectorClass = "org.apache.kafka.connect.file.FileStreamSourceConnector"
                                config = "    file: \"${params.FILE_PATH}\"\n    topic: \"${params.TOPIC}\""
                                break
                            case 'FileStreamSink':
                                connectorClass = "org.apache.kafka.connect.file.FileStreamSinkConnector"
                                config = "    file: \"${params.FILE_PATH}\"\n    topics: \"${params.TOPIC}\""
                                break
                        }
                        
                        def yamlContent = (params.CONNECTOR_TYPE == 'Custom') ? params.CUSTOM_CONFIG : """
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: ${params.CONNECTOR_NAME}
  namespace: ${env.KAFKA_NAMESPACE}
  labels:
    strimzi.io/cluster: ${env.KAFKA_CONNECT_CLUSTER}
spec:
  class: ${connectorClass}
  tasksMax: 1
  config:
${config}
"""
                        writeFile file: 'connector.yaml', text: yamlContent
                        
                        // Esecuzione del comando kubectl
                        withCredentials([string(credentialsId: env.K8S_CREDENTIAL_ID, variable: 'K8S_TOKEN')]) {
                            sh """
                                kubectl apply -f connector.yaml \
                                --token=${K8S_TOKEN} \
                                --server=https://kubernetes.default.svc \
                                --insecure-skip-tls-verify
                            """
                        }
                    }
                }
            }
        }
    }
}
