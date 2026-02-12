// ============================================================================
// PIPELINE: DELETE KAFKA TOPIC (SAFE)
// ============================================================================
// Elimina un KafkaTopic con controlli di sicurezza
// 
// ⚠️ ATTENZIONE: Operazione irreversibile!
// ============================================================================

pipeline {
    agent { label 'kafka-agent' }
    
    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        KAFKA_CLUSTER = 'kafka-cluster'
    }
    
    parameters {
        string(
            name: 'TOPIC_NAME',
            defaultValue: '',
            description: 'Nome del topic da eliminare'
        )
        booleanParam(
            name: 'CHECK_CONSUMERS',
            defaultValue: true,
            description: 'Verifica se ci sono consumer attivi'
        )
        booleanParam(
            name: 'CHECK_MESSAGES',
            defaultValue: true,
            description: 'Verifica se ci sono messaggi non consumati'
        )
        string(
            name: 'CONFIRM_NAME',
            defaultValue: '',
            description: '⚠️ Riscrivi il nome del topic per confermare'
        )
    }
    
    stages {
        stage('Validate') {
            steps {
                script {
                    if (!params.TOPIC_NAME?.trim()) {
                        error "TOPIC_NAME è obbligatorio!"
                    }
                    
                    if (params.TOPIC_NAME != params.CONFIRM_NAME) {
                        error """
                        ❌ CONFERMA NON VALIDA!
                        
                        Per eliminare il topic '${params.TOPIC_NAME}', 
                        devi riscrivere esattamente lo stesso nome nel campo CONFIRM_NAME.
                        
                        Hai scritto: '${params.CONFIRM_NAME}'
                        """
                    }
                    
                    // Protezione topic di sistema
                    def protectedTopics = ['__consumer_offsets', '__transaction_state', 'connect-cluster-configs', 'connect-cluster-offsets', 'connect-cluster-status']
                    if (params.TOPIC_NAME in protectedTopics || params.TOPIC_NAME.startsWith('__')) {
                        error "❌ Non puoi eliminare topic di sistema: ${params.TOPIC_NAME}"
                    }
                }
            }
        }
        
        stage('Check Topic Exists') {
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 🔍 VERIFICA ESISTENZA TOPIC ==="
                        if kubectl get kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE} > /dev/null 2>&1; then
                            echo "✅ Topic '${params.TOPIC_NAME}' trovato"
                            kubectl get kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE}
                        else
                            echo "❌ Topic '${params.TOPIC_NAME}' NON ESISTE!"
                            exit 1
                        fi
                    """
                }
            }
        }
        
        stage('Check Active Consumers') {
            when {
                expression { params.CHECK_CONSUMERS }
            }
            steps {
                container('kubectl') {
                    script {
                        def result = sh(
                            script: """
                                kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                                    bash -c '
                                    cat > /tmp/admin.properties << EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF
                                    /opt/kafka/bin/kafka-consumer-groups.sh \
                                        --bootstrap-server localhost:9092 \
                                        --command-config /tmp/admin.properties \
                                        --list
                                    ' 2>/dev/null | while read group; do
                                        /opt/kafka/bin/kafka-consumer-groups.sh \
                                            --bootstrap-server localhost:9092 \
                                            --command-config /tmp/admin.properties \
                                            --describe \
                                            --group "\$group" 2>/dev/null | grep "${params.TOPIC_NAME}" || true
                                    done
                            """,
                            returnStdout: true
                        ).trim()
                        
                        if (result) {
                            echo """
                            ⚠️ ATTENZIONE: Ci sono consumer attivi su questo topic!
                            
                            ${result}
                            
                            Continuando comunque...
                            """
                        } else {
                            echo "✅ Nessun consumer attivo trovato"
                        }
                    }
                }
            }
        }
        
        stage('Check Messages') {
            when {
                expression { params.CHECK_MESSAGES }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== 📊 VERIFICA MESSAGGI ==="
                        
                        kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                            bash -c '
                            cat > /tmp/admin.properties << EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF
                            /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
                                --broker-list localhost:9092 \
                                --topic ${params.TOPIC_NAME} \
                                --time -1 \
                                --command-config /tmp/admin.properties
                            ' 2>/dev/null || echo "Impossibile verificare i messaggi"
                    """
                }
            }
        }
        
        stage('Final Confirmation') {
            steps {
                script {
                    echo """
                    ════════════════════════════════════════════════
                    ⚠️  STAI PER ELIMINARE IL TOPIC: ${params.TOPIC_NAME}
                    ════════════════════════════════════════════════
                    
                    Questa operazione è IRREVERSIBILE!
                    Tutti i messaggi nel topic verranno persi.
                    
                    Procedo con l'eliminazione...
                    """
                }
            }
        }
        
        stage('Delete Topic') {
            steps {
                container('kubectl') {
                    sh """
                        echo "🗑️ Eliminazione topic ${params.TOPIC_NAME}..."
                        kubectl delete kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE}
                        
                        echo "⏳ Attendo propagazione..."
                        sleep 10
                    """
                }
            }
        }
        
        stage('Verify Deletion') {
            steps {
                container('kubectl') {
                    sh """
                        echo "=== ✅ VERIFICA ELIMINAZIONE ==="
                        if kubectl get kafkatopic ${params.TOPIC_NAME} -n ${env.KAFKA_NAMESPACE} > /dev/null 2>&1; then
                            echo "⚠️ Il topic esiste ancora (potrebbe essere in fase di eliminazione)"
                        else
                            echo "✅ Topic '${params.TOPIC_NAME}' eliminato con successo!"
                        fi
                        
                        echo ""
                        echo "=== TOPIC RIMANENTI ==="
                        kubectl get kafkatopic -n ${env.KAFKA_NAMESPACE}
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Topic ${params.TOPIC_NAME} eliminato!"
        }
        failure {
            echo "❌ Errore durante l'eliminazione del topic"
        }
    }
}
