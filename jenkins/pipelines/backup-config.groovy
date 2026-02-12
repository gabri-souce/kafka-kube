// ============================================================================
// PIPELINE: BACKUP KAFKA CONFIGURATION
// ============================================================================
// Esegue backup di tutti i KafkaTopic, KafkaUser, KafkaConnector
// 
// I file di backup sono salvati come artifact del job
// ============================================================================

pipeline {
    agent { label 'kafka-agent' }
    
    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        BACKUP_DIR = 'kafka-backup'
    }
    
    parameters {
        booleanParam(
            name: 'BACKUP_TOPICS',
            defaultValue: true,
            description: 'Backup KafkaTopic'
        )
        booleanParam(
            name: 'BACKUP_USERS',
            defaultValue: true,
            description: 'Backup KafkaUser'
        )
        booleanParam(
            name: 'BACKUP_CONNECTORS',
            defaultValue: true,
            description: 'Backup KafkaConnector'
        )
        booleanParam(
            name: 'BACKUP_CONNECT',
            defaultValue: true,
            description: 'Backup KafkaConnect cluster config'
        )
    }
    
    stages {
        stage('Prepare') {
            steps {
                container('kubectl') {
                    sh """
                        mkdir -p ${env.BACKUP_DIR}
                        echo "📁 Directory backup: ${env.BACKUP_DIR}"
                        echo "📅 Data backup: \$(date '+%Y-%m-%d %H:%M:%S')"
                    """
                }
            }
        }
        
        stage('Backup Topics') {
            when {
                expression { params.BACKUP_TOPICS }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 📋 BACKUP KAFKA TOPICS ==="
                        kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} -o yaml > ${env.BACKUP_DIR}/kafkatopics.yaml
                        
                        echo "Topics salvati:"
                        kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} --no-headers | wc -l
                    """
                }
            }
        }
        
        stage('Backup Users') {
            when {
                expression { params.BACKUP_USERS }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 👥 BACKUP KAFKA USERS ==="
                        kubectl get kafkauser -n ${env.KAFKA_NAMESPACE} -o yaml > ${env.BACKUP_DIR}/kafkausers.yaml
                        
                        echo "Users salvati:"
                        kubectl get kafkauser -n ${env.KAFKA_NAMESPACE} --no-headers | wc -l
                        
                        echo ""
                        echo "⚠️ NOTA: I secret delle password NON sono inclusi nel backup."
                        echo "Strimzi li rigenerà automaticamente al restore."
                    """
                }
            }
        }
        
        stage('Backup Connectors') {
            when {
                expression { params.BACKUP_CONNECTORS }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 🔌 BACKUP KAFKA CONNECTORS ==="
                        kubectl get kafkaconnector -n ${env.KAFKA_NAMESPACE} -o yaml > ${env.BACKUP_DIR}/kafkaconnectors.yaml 2>/dev/null || echo "Nessun connector trovato"
                        
                        if [ -f ${env.BACKUP_DIR}/kafkaconnectors.yaml ]; then
                            echo "Connectors salvati:"
                            kubectl get kafkaconnector -n ${env.KAFKA_NAMESPACE} --no-headers 2>/dev/null | wc -l
                        fi
                    """
                }
            }
        }
        
        stage('Backup Connect Cluster') {
            when {
                expression { params.BACKUP_CONNECT }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 🔧 BACKUP KAFKA CONNECT CONFIG ==="
                        kubectl get kafkaconnect -n ${env.KAFKA_NAMESPACE} -o yaml > ${env.BACKUP_DIR}/kafkaconnect.yaml 2>/dev/null || echo "Nessun KafkaConnect trovato"
                    """
                }
            }
        }
        
        stage('Create Summary') {
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 📊 SUMMARY BACKUP ===" > ${env.BACKUP_DIR}/SUMMARY.txt
                        echo "Data: \$(date '+%Y-%m-%d %H:%M:%S')" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        echo "Namespace: ${env.KAFKA_NAMESPACE}" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        echo "" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        
                        echo "File creati:" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        ls -la ${env.BACKUP_DIR}/*.yaml 2>/dev/null >> ${env.BACKUP_DIR}/SUMMARY.txt || echo "Nessun file" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        
                        echo "" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        echo "=== TOPIC LIST ===" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE} --no-headers 2>/dev/null >> ${env.BACKUP_DIR}/SUMMARY.txt || echo "Nessuno" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        
                        echo "" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        echo "=== USER LIST ===" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        kubectl get kafkauser -n ${env.KAFKA_NAMESPACE} --no-headers 2>/dev/null >> ${env.BACKUP_DIR}/SUMMARY.txt || echo "Nessuno" >> ${env.BACKUP_DIR}/SUMMARY.txt
                        
                        cat ${env.BACKUP_DIR}/SUMMARY.txt
                    """
                }
            }
        }
        
        stage('Archive') {
            steps {
                // Archivia i file come artifact Jenkins
                archiveArtifacts artifacts: "${env.BACKUP_DIR}/**/*", fingerprint: true
                
                echo """
                ✅ Backup completato!
                
                📥 Per scaricare il backup:
                1. Vai su questo build
                2. Click su 'Build Artifacts'
                3. Scarica i file
                
                📤 Per ripristinare:
                kubectl apply -f kafkatopics.yaml
                kubectl apply -f kafkausers.yaml
                kubectl apply -f kafkaconnectors.yaml
                """
            }
        }
    }
    
    post {
        success {
            echo "✅ Backup completato con successo!"
        }
        failure {
            echo "❌ Errore durante il backup"
        }
        cleanup {
            // Pulisci i file temporanei
            sh "rm -rf ${env.BACKUP_DIR} || true"
        }
    }
}
