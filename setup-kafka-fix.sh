#!/bin/bash
# ============================================================================
# KAFKA-FIX SETUP SCRIPT
# ============================================================================
# Prepara e deploya kafka-fix su Mac M4 con Docker Desktop Kubernetes
# ============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variabili
NAMESPACE="kafka-lab"
HELM_RELEASE="kafka-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         KAFKA-FIX AUTOMATED SETUP                             ║"
echo "║         Mac M4 + Docker Desktop Kubernetes                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# FASE 0: PREREQUISITI
# ============================================================================
echo -e "${YELLOW}[FASE 0] Verifica prerequisiti...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker non trovato!${NC}"
    echo "Installa Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon non running!${NC}"
    echo "Avvia Docker Desktop e riprova."
    exit 1
fi
echo -e "${GREEN}✅ Docker: OK${NC}"

# Check Kubernetes
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl non trovato!${NC}"
    echo "Installa: brew install kubectl"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Kubernetes cluster non raggiungibile!${NC}"
    echo "Abilita Kubernetes in Docker Desktop:"
    echo "  Settings → Kubernetes → Enable Kubernetes"
    exit 1
fi
echo -e "${GREEN}✅ Kubernetes: OK${NC}"

# Check Helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm non trovato!${NC}"
    echo "Installa: brew install helm"
    exit 1
fi
echo -e "${GREEN}✅ Helm: OK${NC}"

# Check risorse Docker Desktop
DOCKER_MEM=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
echo -e "${BLUE}ℹ️  Docker Memory: ${DOCKER_MEM}${NC}"
echo -e "${YELLOW}⚠️  Raccomandato: 8GB+${NC}"
echo -e "${YELLOW}⚠️  Se deployment fallisce, aumenta RAM in Docker Desktop Settings${NC}"

echo ""
read -p "Prerequisiti OK. Continuare? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# ============================================================================
# FASE 1: CLEANUP (OPZIONALE)
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 1] Cleanup installazione precedente (opzionale)${NC}"
read -p "Vuoi pulire installazione precedente? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rimozione installazione precedente..."
    
    # Uninstall Helm releases
    helm uninstall $HELM_RELEASE -n $NAMESPACE 2>/dev/null || true
    helm uninstall strimzi-operator -n $NAMESPACE 2>/dev/null || true
    
    # Delete PVC (dati Kafka)
    kubectl delete pvc --all -n $NAMESPACE 2>/dev/null || true
    
    # Delete namespace
    kubectl delete namespace $NAMESPACE 2>/dev/null || true
    
    echo "Aspetto cleanup completo (30 secondi)..."
    sleep 30
    
    echo -e "${GREEN}✅ Cleanup completato${NC}"
fi

# ============================================================================
# FASE 2: CREA NAMESPACE
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 2] Creazione namespace...${NC}"

if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${BLUE}ℹ️  Namespace $NAMESPACE già esistente${NC}"
else
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✅ Namespace $NAMESPACE creato${NC}"
fi

# ============================================================================
# FASE 3: INSTALLA STRIMZI OPERATOR
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 3] Installazione Strimzi Operator...${NC}"

# Aggiungi Helm repo
helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
helm repo update

# Installa Strimzi
echo "Installazione Strimzi 0.50.0..."
helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
  -n $NAMESPACE \
  --version 0.50.0 \
  --set watchNamespaces="{$NAMESPACE}" \
  --wait \
  --timeout 5m

echo "Attendo Strimzi Operator ready..."
kubectl wait --for=condition=Ready pod \
  -l name=strimzi-cluster-operator \
  -n $NAMESPACE \
  --timeout=300s

echo -e "${GREEN}✅ Strimzi Operator installato${NC}"

# ============================================================================
# FASE 4: PREPARA HELM CHART
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 4] Preparazione Helm chart...${NC}"

cd "$SCRIPT_DIR/helm"

# Aggiungi repo AWX
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/ 2>/dev/null || true
helm repo update

# Update dependencies
echo "Download dependencies..."
helm dependency update

echo -e "${GREEN}✅ Helm chart preparato${NC}"

# ============================================================================
# FASE 5: CONFIGURAZIONE OPZIONALE
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 5] Configurazione deployment...${NC}"

# Chiedi quali componenti installare
echo "Quali componenti vuoi installare?"
echo ""
echo "1) Tutto (Kafka + Jenkins + AWX + Monitoring) [RACCOMANDATO]"
echo "2) Kafka + Jenkins + Monitoring (no AWX)"
echo "3) Kafka + AWX + Monitoring (no Jenkins)"
echo "4) Solo Kafka + Monitoring (minimal)"
echo ""
read -p "Scelta (1-4): " DEPLOY_CHOICE

case $DEPLOY_CHOICE in
    2)
        echo "Disabilito AWX..."
        # Modifica temporanea values.yaml
        sed -i.bak 's/awx:/awx_disabled:/g' values.yaml || \
        sed -i '' 's/awx:/awx_disabled:/g' values.yaml
        ;;
    3)
        echo "Disabilito Jenkins..."
        sed -i.bak 's/jenkins:/jenkins_disabled:/g' values.yaml || \
        sed -i '' 's/jenkins:/jenkins_disabled:/g' values.yaml
        ;;
    4)
        echo "Disabilito Jenkins e AWX..."
        sed -i.bak -e 's/jenkins:/jenkins_disabled:/g' -e 's/awx:/awx_disabled:/g' values.yaml || \
        sed -i '' -e 's/jenkins:/jenkins_disabled:/g' -e 's/awx:/awx_disabled:/g' values.yaml
        ;;
    *)
        echo "Deploy completo (tutto abilitato)"
        ;;
esac

# ============================================================================
# FASE 6: DEPLOY KAFKA-FIX
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 6] Deploy kafka-fix...${NC}"

echo "Installazione in corso (può richiedere 5-10 minuti)..."
echo "Puoi monitorare in un altro terminale con:"
echo "  watch -n 2 'kubectl get pods -n $NAMESPACE'"
echo ""

helm upgrade --install $HELM_RELEASE . \
  -n $NAMESPACE \
  --timeout 15m \
  --wait

echo -e "${GREEN}✅ Helm chart installato${NC}"

# ============================================================================
# FASE 7: ATTESA POD READY
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 7] Attesa pod ready...${NC}"

echo "Attendo Kafka cluster ready (max 10 min)..."
kubectl wait --for=condition=Ready kafka/kafka-cluster \
  -n $NAMESPACE \
  --timeout=600s || echo "⚠️  Timeout Kafka (potrebbe essere ancora in avvio)"

echo ""
echo "Status pods:"
kubectl get pods -n $NAMESPACE

# ============================================================================
# FASE 8: VERIFICA DEPLOYMENT
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 8] Verifica deployment...${NC}"

# Conta pod Running
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l | tr -d ' ')
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | grep -c Running || echo "0")

echo "Pods: $RUNNING_PODS/$TOTAL_PODS Running"

# Verifica Kafka
if kubectl get kafka kafka-cluster -n $NAMESPACE &> /dev/null; then
    KAFKA_READY=$(kubectl get kafka kafka-cluster -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$KAFKA_READY" == "True" ]; then
        echo -e "${GREEN}✅ Kafka Cluster: Ready${NC}"
    else
        echo -e "${YELLOW}⚠️  Kafka Cluster: Not Ready (potrebbe essere in bootstrap)${NC}"
    fi
fi

# ============================================================================
# FASE 9: RECUPERA CREDENZIALI
# ============================================================================
echo ""
echo -e "${YELLOW}[FASE 9] Credenziali e URLs...${NC}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ACCESSO SERVIZI                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Kafka UI
if kubectl get svc kafka-ui -n $NAMESPACE &> /dev/null; then
    KAFKA_UI_PORT=$(kubectl get svc kafka-ui -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}📊 Kafka UI:${NC}"
    echo "   http://localhost:$KAFKA_UI_PORT"
    echo ""
fi

# Jenkins
if kubectl get svc jenkins -n $NAMESPACE &> /dev/null; then
    JENKINS_PORT=$(kubectl get svc jenkins -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}🔧 Jenkins:${NC}"
    echo "   http://localhost:$JENKINS_PORT"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
fi

# AWX
if kubectl get svc awx-service -n $NAMESPACE &> /dev/null; then
    AWX_PORT=$(kubectl get svc awx-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}🤖 AWX:${NC}"
    echo "   http://localhost:$AWX_PORT"
    echo "   Username: admin"
    echo -n "   Password: "
    kubectl get secret awx-admin-password -n $NAMESPACE \
      -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || echo "[recupera con: kubectl get secret awx-admin-password -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d]"
    echo ""
fi

# Grafana
if kubectl get svc grafana -n $NAMESPACE &> /dev/null; then
    GRAFANA_PORT=$(kubectl get svc grafana -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}📈 Grafana:${NC}"
    echo "   http://localhost:$GRAFANA_PORT"
    echo "   Username: admin"
    echo "   Password: admin"
    echo ""
fi

# Prometheus
if kubectl get svc prometheus -n $NAMESPACE &> /dev/null; then
    PROMETHEUS_PORT=$(kubectl get svc prometheus -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}📉 Prometheus:${NC}"
    echo "   http://localhost:$PROMETHEUS_PORT"
    echo ""
fi

# ============================================================================
# FASE 10: KAFKA USERS
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    KAFKA USERS                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Username: admin"
echo "Password: admin-secret"
echo "Role: SuperUser (tutti i permessi)"
echo ""
echo "Username: producer-user"
echo "Password: producer-secret"
echo "Role: Producer (Write su tutti i topic)"
echo ""
echo "Username: consumer-user"
echo "Password: consumer-secret"
echo "Role: Consumer (Read da tutti i topic)"
echo ""

# ============================================================================
# FASE 11: QUICK TEST
# ============================================================================
echo ""
echo -e "${YELLOW}Vuoi eseguire un quick test del cluster Kafka? (y/n)${NC}"
read -p "> " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Test Kafka cluster..."
    
    # Aspetta che almeno un pod kafka sia ready
    kubectl wait --for=condition=Ready pod \
      -l strimzi.io/cluster=kafka-cluster \
      -n $NAMESPACE \
      --timeout=60s 2>/dev/null || true
    
    KAFKA_POD=$(kubectl get pods -n $NAMESPACE -l strimzi.io/cluster=kafka-cluster -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$KAFKA_POD" ]; then
        echo "Creazione file admin.properties..."
        kubectl exec -it $KAFKA_POD -n $NAMESPACE -- bash -c "
cat > /tmp/admin.properties << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username=\"admin\" password=\"admin-secret\";
EOF
" 2>/dev/null || true

        echo "Lista broker attivi:"
        kubectl exec -it $KAFKA_POD -n $NAMESPACE -- \
          /opt/kafka/bin/kafka-broker-api-versions.sh \
            --bootstrap-server localhost:9092 \
            --command-config /tmp/admin.properties 2>/dev/null | grep "id:" || echo "⚠️  Kafka still starting..."
        
        echo ""
        echo "Creazione topic di test..."
        kubectl exec -it $KAFKA_POD -n $NAMESPACE -- \
          /opt/kafka/bin/kafka-topics.sh \
            --bootstrap-server localhost:9092 \
            --create \
            --topic test-deployment \
            --partitions 3 \
            --replication-factor 3 \
            --command-config /tmp/admin.properties 2>/dev/null || echo "Topic già esistente o cluster non ancora ready"
        
        echo -e "${GREEN}✅ Test completato${NC}"
    else
        echo -e "${YELLOW}⚠️  Nessun pod Kafka trovato (ancora in avvio)${NC}"
    fi
fi

# ============================================================================
# FINALE
# ============================================================================
echo ""
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 DEPLOYMENT COMPLETATO! 🎉                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Prossimi passi:"
echo "1. Apri Kafka UI: http://localhost:${KAFKA_UI_PORT:-30080}"
echo "2. Apri Jenkins: http://localhost:${JENKINS_PORT:-32000}"
echo "3. Leggi la guida: GUIDA_DEPLOYMENT_KAFKA_FIX.md"
echo ""
echo "Comandi utili:"
echo "  # Vedi tutti i pod"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "  # Vedi log Kafka"
echo "  kubectl logs -n $NAMESPACE kafka-cluster-kafka-0 -f"
echo ""
echo "  # Entra nel pod Kafka"
echo "  kubectl exec -it kafka-cluster-kafka-0 -n $NAMESPACE -- bash"
echo ""
echo "  # Rimuovi tutto"
echo "  helm uninstall $HELM_RELEASE -n $NAMESPACE"
echo "  helm uninstall strimzi-operator -n $NAMESPACE"
echo "  kubectl delete pvc --all -n $NAMESPACE"
echo "  kubectl delete namespace $NAMESPACE"
echo ""
echo -e "${GREEN}Buon lavoro! 🚀${NC}"
