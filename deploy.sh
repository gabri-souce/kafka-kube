#!/bin/bash
# ============================================================================
# KAFKA LAB - DEPLOY AUTOMATICO COMPLETO
# ============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAULT_NODEPORT=30372
KAFKA_NAMESPACE="kafka-lab"
VAULT_NAMESPACE="vault-system"
ESO_NAMESPACE="external-secrets-system"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 KAFKA LAB - AUTO DEPLOY                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo

# ============================================================================
# CHIEDI PASSWORD UNA VOLTA SOLA
# ============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Inserisci la password che verrà usata per TUTTI i servizi:${NC}"
echo -e "${YELLOW}  (Grafana, Jenkins, Kafka Admin, Producer, Consumer, AWX)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

while true; do
    read -rsp "  Password (min 12 caratteri): " APP_PASSWORD
    echo
    if [ ${#APP_PASSWORD} -lt 12 ]; then
        echo -e "${RED}  ❌ Password troppo corta! Minimo 12 caratteri.${NC}"
    else
        read -rsp "  Conferma password: " APP_PASSWORD2
        echo
        if [ "$APP_PASSWORD" == "$APP_PASSWORD2" ]; then
            echo -e "${GREEN}  ✓ Password accettata${NC}"
            break
        else
            echo -e "${RED}  ❌ Le password non corrispondono!${NC}"
        fi
    fi
done

echo

# ============================================================================
# STEP 1: PREREQUISITI
# ============================================================================
echo -e "${BLUE}[1/7] Verifica prerequisiti...${NC}"

for cmd in kubectl helm docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ $cmd non trovato${NC}"
        exit 1
    fi
done

if ! command -v vault &> /dev/null; then
    echo -e "${YELLOW}⚠️  vault CLI non trovato, installo...${NC}"
    brew install vault
fi

echo -e "${GREEN}✓ Prerequisiti OK${NC}"
echo

# ============================================================================
# BUILD IMMAGINI DOCKER (se non esistono su Docker Hub)
# ============================================================================
echo -e "${BLUE}[1b/7] Verifica immagini Docker...${NC}"

DOCKER_USER="gabrisource"
JENKINS_IMAGE="${DOCKER_USER}/jenkins-kafka:1.0.0"
AWX_EE_IMAGE="${DOCKER_USER}/kafka-ee:1.0.0"

build_and_push_image() {
    local IMAGE=$1
    local CONTEXT=$2
    local NAME=$3

    echo -n "  Verifico ${NAME} (${IMAGE})... "

    # Controlla se esiste già su Docker Hub
    if docker manifest inspect "${IMAGE}" &>/dev/null; then
        echo -e "${GREEN}✓ Già presente su Docker Hub${NC}"
        return 0
    fi

    # Non esiste - controlla se esiste localmente
    if docker image inspect "${IMAGE}" &>/dev/null; then
        echo -e "${YELLOW}↑ Presente solo in locale, push in corso...${NC}"
        docker push "${IMAGE}" > /dev/null
        echo -e "${GREEN}✓ Push completato${NC}"
        return 0
    fi

    # Non esiste da nessuna parte - build + push
    echo -e "${YELLOW}⚙️  Non trovata, build in corso...${NC}"
    echo -e "  ${CYAN}(Prima esecuzione: può richiedere 5-10 minuti)${NC}"

    if docker build -t "${IMAGE}" "${CONTEXT}" ; then
        echo -n "  Push su Docker Hub... "
        docker push "${IMAGE}" > /dev/null
        echo -e "${GREEN}✓ Build e push completati${NC}"
    else
        echo -e "${RED}❌ Build fallita per ${NAME}${NC}"
        exit 1
    fi
}

# Verifica login Docker Hub
echo -n "  Verifico login Docker Hub... "
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo -e "${YELLOW}⚠️  Non loggato, eseguo login...${NC}"
    docker login
fi
echo -e "${GREEN}✓${NC}"

# Build Jenkins con plugin
build_and_push_image "${JENKINS_IMAGE}" "./jenkins" "Jenkins+plugin"

# Build AWX Execution Environment
build_and_push_image "${AWX_EE_IMAGE}" "./awx-ee" "AWX Execution Environment"

echo -e "${GREEN}✓ Immagini Docker pronte${NC}"
echo

# ============================================================================
# STEP 2: INSTALLA VAULT
# ============================================================================
echo -e "${BLUE}[2/7] Installazione HashiCorp Vault (NodePort: ${VAULT_NODEPORT})...${NC}"

helm repo add hashicorp https://helm.releases.hashicorp.com &> /dev/null || true
helm repo update &> /dev/null

kubectl create namespace $VAULT_NAMESPACE 2>/dev/null || true

# Crea values file con NodePort fisso
cat > /tmp/vault-values.yaml << EOF
server:
  dev:
    enabled: true
    devRootToken: "root"
ui:
  enabled: true
  serviceType: NodePort
  serviceNodePort: ${VAULT_NODEPORT}
injector:
  enabled: false
EOF

helm install vault hashicorp/vault -n $VAULT_NAMESPACE -f /tmp/vault-values.yaml --wait --timeout 5m

echo -n "  Attendo Vault ready... "
kubectl -n $VAULT_NAMESPACE wait --for=condition=ready pod -l app.kubernetes.io/name=vault --timeout=120s > /dev/null
echo -e "${GREEN}✓${NC}"

export VAULT_ADDR="http://localhost:${VAULT_NODEPORT}"
export VAULT_TOKEN="root"

echo -e "${GREEN}✓ Vault installato → http://localhost:${VAULT_NODEPORT} (token: root)${NC}"
echo

# ============================================================================
# STEP 3: INIZIALIZZA SECRET IN VAULT
# ============================================================================
echo -e "${BLUE}[3/7] Inizializzazione secret in Vault...${NC}"

# Abilita KV engine
vault secrets enable -version=2 -path=secret kv 2>/dev/null || true

# Carica tutti i secret con la password inserita
echo -n "  Carico secrets in Vault... "
vault kv put secret/kafka/users/admin        password="${APP_PASSWORD}" > /dev/null
vault kv put secret/kafka/users/producer-user password="${APP_PASSWORD}" > /dev/null
vault kv put secret/kafka/users/consumer-user password="${APP_PASSWORD}" > /dev/null
vault kv put secret/kafka/monitoring/grafana  password="${APP_PASSWORD}" > /dev/null
vault kv put secret/kafka/jenkins/admin       password="${APP_PASSWORD}" > /dev/null
echo -e "${GREEN}✓${NC}"

# Salva le password in file
PWD_FILE="scripts/vault/vault-passwords-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p scripts/vault
cat > "$PWD_FILE" << EOF
# ============================================
# KAFKA LAB - CREDENZIALI
# Generato: $(date)
# ============================================

# ATTENZIONE: Non committare questo file su Git!

Kafka Admin:      admin / ${APP_PASSWORD}
Kafka Producer:   producer-user / ${APP_PASSWORD}
Kafka Consumer:   consumer-user / ${APP_PASSWORD}
Grafana:          admin / ${APP_PASSWORD}
Jenkins:          admin / ${APP_PASSWORD}
Vault:            http://localhost:${VAULT_NODEPORT} (token: root)
EOF

echo -e "${GREEN}✓ Secret inizializzati${NC}"
echo -e "  Credenziali salvate in: ${CYAN}${PWD_FILE}${NC}"
echo

# ============================================================================
# STEP 4: CONFIGURA KUBERNETES AUTH IN VAULT
# ============================================================================
echo -e "${BLUE}[4/7] Configurazione Kubernetes Auth in Vault...${NC}"

kubectl create namespace $KAFKA_NAMESPACE 2>/dev/null || true

# Configura Vault K8s auth direttamente nel pod
echo -n "  Configuro Kubernetes auth... "
kubectl -n $VAULT_NAMESPACE exec vault-0 -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Abilita Kubernetes auth
vault auth enable kubernetes 2>/dev/null || true

# Configura con credenziali del pod
vault write auth/kubernetes/config \
    kubernetes_host='https://kubernetes.default.svc:443' \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Crea policy
vault policy write kafka-lab - <<POLICY
path \"secret/data/kafka/*\" {
  capabilities = [\"read\", \"list\"]
}
path \"secret/metadata/kafka/*\" {
  capabilities = [\"list\"]
}
POLICY

# Crea role
vault write auth/kubernetes/role/kafka-lab \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=${KAFKA_NAMESPACE} \
    policies=kafka-lab \
    ttl=24h
" > /dev/null

echo -e "${GREEN}✓${NC}"

# Crea token secret per ServiceAccount (dopo che Helm crea il SA)
# Lo creiamo subito con apply così Helm lo adotterà
echo -e "${GREEN}✓ Kubernetes Auth configurato${NC}"
echo

# ============================================================================
# STEP 5: INSTALLA EXTERNAL SECRETS OPERATOR
# ============================================================================
echo -e "${BLUE}[5/7] Installazione External Secrets Operator...${NC}"

helm repo add external-secrets https://charts.external-secrets.io &> /dev/null || true
helm repo update &> /dev/null

helm install external-secrets external-secrets/external-secrets \
    -n $ESO_NAMESPACE --create-namespace \
    --set installCRDs=true \
    --wait --timeout 5m

echo -n "  Attendo ESO ready... "
kubectl -n $ESO_NAMESPACE wait --for=condition=ready pod \
    -l app.kubernetes.io/name=external-secrets --timeout=120s > /dev/null
echo -e "${GREEN}✓${NC}"

echo -e "${GREEN}✓ External Secrets Operator installato${NC}"
echo

# ============================================================================
# STEP 6: INSTALLA STRIMZI OPERATOR
# ============================================================================
echo -e "${BLUE}[6/7] Installazione Strimzi Kafka Operator...${NC}"

helm repo add strimzi https://strimzi.io/charts/ &> /dev/null || true
helm repo update &> /dev/null

helm install strimzi-operator strimzi/strimzi-kafka-operator \
    --namespace $KAFKA_NAMESPACE \
    --wait --timeout 5m

echo -n "  Attendo Strimzi ready... "
kubectl -n $KAFKA_NAMESPACE wait --for=condition=ready pod \
    -l name=strimzi-cluster-operator --timeout=120s > /dev/null
echo -e "${GREEN}✓${NC}"

echo -e "${GREEN}✓ Strimzi Operator installato${NC}"
echo

# ============================================================================
# STEP 7: INSTALLA KAFKA LAB
# ============================================================================
echo -e "${BLUE}[7/7] Installazione Kafka Lab (può richiedere 10-15 minuti)...${NC}"

helm install kafka-lab ./helm -n $KAFKA_NAMESPACE --timeout 15m

echo -e "${GREEN}✓ Helm chart applicato${NC}"
echo

# ============================================================================
# ATTENDI CHE EXTERNAL SECRETS SINCRONIZZI
# ============================================================================
echo -e "${BLUE}Attendo sincronizzazione External Secrets...${NC}"
echo -e "${YELLOW}(Questo può richiedere 2-5 minuti)${NC}"
echo

# Aspetta che vault-auth secret sia creato da Helm
echo -n "  Attendo ServiceAccount vault-auth... "
for i in {1..60}; do
    if kubectl -n $KAFKA_NAMESPACE get sa vault-auth &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    sleep 2
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗ Timeout${NC}"
    fi
done

# Crea token secret per vault-auth
echo -n "  Creo token per vault-auth... "
kubectl -n $KAFKA_NAMESPACE apply -f - > /dev/null << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: ${KAFKA_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
EOF
sleep 3
echo -e "${GREEN}✓${NC}"

# Aggiorna Vault con il nuovo token del SA
echo -n "  Aggiorno Vault con token ServiceAccount... "
kubectl -n $VAULT_NAMESPACE exec vault-0 -- sh -c "
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
vault write auth/kubernetes/config \
    kubernetes_host='https://kubernetes.default.svc:443' \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
" > /dev/null
echo -e "${GREEN}✓${NC}"

# Forza sync degli ExternalSecrets
echo -n "  Forzo sync External Secrets... "
sleep 5
for es in admin-password producer-user-password consumer-user-password grafana-admin-secret jenkins-admin-secret; do
    kubectl -n $KAFKA_NAMESPACE annotate externalsecret $es \
        force-sync=$(date +%s) --overwrite &>/dev/null || true
done
echo -e "${GREEN}✓${NC}"

# Aspetta che tutti gli ExternalSecrets siano sincronizzati
echo -n "  Attendo SecretSynced... "
SYNCED=0
for attempt in {1..30}; do
    READY=$(kubectl -n $KAFKA_NAMESPACE get externalsecrets -o jsonpath='{.items[*].status.conditions[0].status}' 2>/dev/null | tr ' ' '\n' | grep -c "True" || true)
    TOTAL=$(kubectl -n $KAFKA_NAMESPACE get externalsecrets --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        SYNCED=1
        echo -e "${GREEN}✓ ($TOTAL/$TOTAL sincronizzati)${NC}"
        break
    fi
    sleep 5
done

if [ $SYNCED -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Non tutti i secret sono sincronizzati, continuo comunque...${NC}"
fi

# ============================================================================
# ATTENDI POD RUNNING
# ============================================================================
echo
echo -e "${BLUE}Attendo che tutti i pod siano Running...${NC}"
echo -e "${YELLOW}(Kafka e AWX richiedono qualche minuto)${NC}"

echo -n "  Attendo Grafana... "
kubectl -n $KAFKA_NAMESPACE wait --for=condition=ready pod \
    -l app=grafana --timeout=300s > /dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠️  Ancora in avvio${NC}"

echo -n "  Attendo Jenkins... "
kubectl -n $KAFKA_NAMESPACE wait --for=condition=ready pod \
    -l app=jenkins --timeout=300s > /dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠️  Ancora in avvio${NC}"

echo -n "  Attendo Kafka brokers... "
kubectl -n $KAFKA_NAMESPACE wait --for=condition=ready pod \
    -l strimzi.io/kind=Kafka --timeout=300s > /dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠️  Ancora in avvio${NC}"

# ============================================================================
# RIEPILOGO FINALE
# ============================================================================
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                   DEPLOYMENT STATUS                        ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
kubectl -n $KAFKA_NAMESPACE get pods --no-headers | awk '{
    if ($3 == "Running" || $3 == "Completed")
        printf "\033[0;32m✓\033[0m %-45s %s\n", $1, $3
    else
        printf "\033[0;31m✗\033[0m %-45s %s\n", $1, $3
}'

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                   ACCESSO AI SERVIZI                       ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${GREEN}  🔐 Vault:${NC}       http://localhost:${VAULT_NODEPORT}  (token: root)"
echo -e "${GREEN}  📊 Kafka UI:${NC}    http://localhost:30080"
echo -e "${GREEN}  📈 Grafana:${NC}     http://localhost:30030  (admin / ${APP_PASSWORD})"
echo -e "${GREEN}  🔧 Jenkins:${NC}     http://localhost:32000  (admin / ${APP_PASSWORD})"
echo -e "${GREEN}  🔭 Prometheus:${NC}  http://localhost:30090"
echo -e "${GREEN}  ⚙️  AWX:${NC}         http://localhost:30043"
echo
AWX_PASS=$(kubectl get secret awx-admin-password -n ${KAFKA_NAMESPACE} -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "recupera con: kubectl get secret awx-admin-password -n kafka-lab -o jsonpath='{.data.password}' | base64 -d")
echo -e "${YELLOW}  AWX Password:${NC} ${AWX_PASS}"
echo
echo -e "${YELLOW}  📄 Credenziali salvate in: ${CYAN}${PWD_FILE}${NC}"
echo
echo -e "${CYAN}  ℹ️  AWX Execution Environment già pushato: gabrisource/kafka-ee:1.0.0${NC}"
echo -e "${CYAN}     Configura in AWX: Administration → Execution Environments → Add${NC}"
echo -e "${CYAN}     Poi segui: docs/AWX_SETUP.md${NC}"
echo
echo -e "${YELLOW}  📄 Credenziali salvate in: ${CYAN}${PWD_FILE}${NC}"
echo
echo -e "${GREEN}🎉 Deploy completato!${NC}"
