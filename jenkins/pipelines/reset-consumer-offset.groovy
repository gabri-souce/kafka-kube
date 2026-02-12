// ============================================================================
// PIPELINE: RESET CONSUMER GROUP OFFSET
// ============================================================================
// Resetta l'offset di un consumer group
// 
// ⚠️ ATTENZIONE: Il consumer group deve essere FERMO (nessun consumer attivo)
// ============================================================================

pipeline {
    agent { label 'kafka-agent' }
    
    environment {
        KAFKA_NAMESPACE = 'kafka-lab'
        KAFKA_CLUSTER = 'kafka-cluster'
    }
    
    parameters {
        string(
            name: 'CONSUMER_GROUP',
            defaultValue: '',
            description: 'Nome del consumer group'
        )
        string(
            name: 'TOPIC',
            defaultValue: '',
            description: 'Topic (lascia vuoto per tutti i topic del gruppo)'
        )
        choice(
            name: 'RESET_TO',
            choices: ['earliest', 'latest', 'datetime', 'offset'],
            description: 'Dove resettare gli offset'
        )
        string(
            name: 'DATETIME_OR_OFFSET',
            defaultValue: '',
            description: 'Data (2024-01-15T10:00:00.000) o offset numerico'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: true,
            description: 'Dry run (mostra cosa farebbe senza eseguire)'
        )
        booleanParam(
            name: 'CONFIRM',
            defaultValue: false,
            description: '⚠️ Conferma esecuzione (richiesto se DRY_RUN=false)'
        )
    }
    
    stages {
        stage('Validate') {
            steps {
                script {
                    if (!params.CONSUMER_GROUP?.trim()) {
                        error "CONSUMER_GROUP è obbligatorio!"
                    }
                    
                    if (!params.DRY_RUN && !params.CONFIRM) {
                        error "Devi confermare l'operazione (CONFIRM=true) per eseguire!"
                    }
                    
                    if (params.RESET_TO in ['datetime', 'offset'] && !params.DATETIME_OR_OFFSET?.trim()) {
                        error "Per ${params.RESET_TO} devi specificare DATETIME_OR_OFFSET!"
                    }
                }
            }
        }
        
        stage('Setup Admin Config') {
            steps {
                container('kubectl') {
                    sh """
                        kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                            bash -c 'cat > /tmp/admin.properties << EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF'
                    """
                }
            }
        }
        
        stage('Show Current State') {
            steps {
                container('kubectl') {
                    sh """
                        echo "=== STATO ATTUALE DEL CONSUMER GROUP ==="
                        kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                            /opt/kafka/bin/kafka-consumer-groups.sh \
                            --bootstrap-server localhost:9092 \
                            --command-config /tmp/admin.properties \
                            --describe \
                            --group ${params.CONSUMER_GROUP} || echo "Gruppo non trovato o vuoto"
                    """
                }
            }
        }
        
        stage('Reset Offset') {
            steps {
                container('kubectl') {
                    script {
                        def topicOption = params.TOPIC?.trim() ? "--topic ${params.TOPIC}" : "--all-topics"
                        def resetOption = ""
                        
                        switch(params.RESET_TO) {
                            case 'earliest':
                                resetOption = "--to-earliest"
                                break
                            case 'latest':
                                resetOption = "--to-latest"
                                break
                            case 'datetime':
                                resetOption = "--to-datetime ${params.DATETIME_OR_OFFSET}"
                                break
                            case 'offset':
                                resetOption = "--to-offset ${params.DATETIME_OR_OFFSET}"
                                break
                        }
                        
                        def executeOption = params.DRY_RUN ? "--dry-run" : "--execute"
                        
                        sh """
                            echo "=== ${params.DRY_RUN ? 'DRY RUN' : 'ESECUZIONE'} RESET ==="
                            echo "Consumer Group: ${params.CONSUMER_GROUP}"
                            echo "Reset to: ${params.RESET_TO}"
                            echo ""
                            
                            kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                                /opt/kafka/bin/kafka-consumer-groups.sh \
                                --bootstrap-server localhost:9092 \
                                --command-config /tmp/admin.properties \
                                --group ${params.CONSUMER_GROUP} \
                                ${topicOption} \
                                --reset-offsets \
                                ${resetOption} \
                                ${executeOption}
                        """
                    }
                }
            }
        }
        
        stage('Verify') {
            when {
                expression { !params.DRY_RUN }
            }
            steps {
                container('kubectl') {
                    sh """
                        echo "=== STATO DOPO IL RESET ==="
                        kubectl exec ${env.KAFKA_CLUSTER}-kafka-0 -n ${env.KAFKA_NAMESPACE} -- \
                            /opt/kafka/bin/kafka-consumer-groups.sh \
                            --bootstrap-server localhost:9092 \
                            --command-config /tmp/admin.properties \
                            --describe \
                            --group ${params.CONSUMER_GROUP}
                    """
                }
            }
        }
    }
    
    post {
        success {
            script {
                if (params.DRY_RUN) {
                    echo "✅ Dry run completato. Deseleziona DRY_RUN e seleziona CONFIRM per eseguire."
                } else {
                    echo "✅ Offset resettato con successo!"
                }
            }
        }
        failure {
            echo "❌ Errore durante il reset degli offset"
        }
    }
}
