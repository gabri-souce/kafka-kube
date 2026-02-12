pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-admin  # <--- IL SEGRETO È QUI: usa l'identità che abbiamo creato
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

    parameters {
        string(name: 'RESOURCE_NAME', defaultValue: 'test-topic', description: 'Nome del file YAML in esercizi/ (es. test-topic o utente-prod)')
    }

    stages {
        stage('GitOps Apply') {
            steps {
                container('kubectl') {
                    script {
                        // Niente più token o server specificati a mano! 
                        // Kubectl usa automaticamente il ServiceAccount del Pod.
                        sh "kubectl apply -f esercizi/${params.RESOURCE_NAME}.yaml"
                    }
                }
            }
        }
        
        stage('Verify Status') {
            steps {
                container('kubectl') {
                    script {
                        echo "Verifica creazione risorsa..."
                        // Un piccolo check per vedere se Strimzi ha preso in carico la richiesta
                        sh "kubectl get kafka.strimzi.io -n kafka-lab | grep ${params.RESOURCE_NAME} || true"
                    }
                }
            }
        }
    }
}