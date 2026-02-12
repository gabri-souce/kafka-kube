#!/bin/bash
# ============================================================================
# Script per configurare Kubernetes Auth in Vault
# ============================================================================
# Utilizzo:
#   ./scripts/vault-configure-k8s-auth.sh
#
# Prerequisiti:
#   - Vault deployato in Kubernetes
#   - kubectl configurato
#   - ServiceAccount vault-auth creato nel namespace kafka-lab
# ============================================================================

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurazione
VAULT_NAMESPACE="vault-system"
VAULT_POD="vault-0"
KAFKA_NAMESPACE="kafka-lab"
SA_NAME="vault-auth"
VAULT_ROLE="kafka-lab"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Vault Kubernetes Auth Configuration${NC}"
echo -e "${BLUE}============================================${NC}"
echo

# Verifica prerequisiti
echo -e "${YELLOW}Verifico prerequisiti...${NC}"

# Verifica kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl non trovato${NC}"
    exit 1
fi

# Verifica Vault pod
echo -n "Verifico Vault pod... "
if kubectl -n "$VAULT_NAMESPACE" get pod "$VAULT_POD" &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Pod Vault non trovato: ${VAULT_NAMESPACE}/${VAULT_POD}${NC}"
    exit 1
fi

# Verifica ServiceAccount
echo -n "Verifico ServiceAccount ${SA_NAME}... "
if kubectl -n "$KAFKA_NAMESPACE" get sa "$SA_NAME" &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}✗ Non trovato, lo creo...${NC}"
    kubectl -n "$KAFKA_NAMESPACE" create serviceaccount "$SA_NAME"
    echo -e "${GREEN}✓ ServiceAccount creato${NC}"
fi

echo

# ========================================
# OTTIENI INFORMAZIONI K8S
# ========================================
echo -e "${BLUE}Raccolta informazioni Kubernetes...${NC}"

# Ottieni Kubernetes API server
echo -n "Kubernetes API server... "
K8S_HOST=$(kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[0].cluster.server}')
echo -e "${GREEN}${K8S_HOST}${NC}"

# Aspetta che il ServiceAccount abbia un token secret
echo -n "Attendo creazione secret per ServiceAccount... "
for i in {1..30}; do
    SA_SECRET=$(kubectl -n "$KAFKA_NAMESPACE" get sa "$SA_NAME" \
      -o jsonpath='{.secrets[0].name}' 2>/dev/null || echo "")
    
    if [ -n "$SA_SECRET" ]; then
        echo -e "${GREEN}✓${NC}"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗${NC}"
        echo -e "${YELLOW}Il ServiceAccount non ha secret associati.${NC}"
        echo -e "${YELLOW}Kubernetes 1.24+ non crea automaticamente secret per SA.${NC}"
        echo -e "${YELLOW}Creo manualmente il token...${NC}"
        
        kubectl -n "$KAFKA_NAMESPACE" apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SA_NAME}-token
  namespace: ${KAFKA_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF
        sleep 2
        SA_SECRET="${SA_NAME}-token"
        break
    fi
    
    sleep 1
done

# Ottieni JWT token
echo -n "Estraggo JWT token... "
SA_JWT_TOKEN=$(kubectl -n "$KAFKA_NAMESPACE" get secret "$SA_SECRET" \
  -o jsonpath='{.data.token}' | base64 --decode)

if [ -z "$SA_JWT_TOKEN" ]; then
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Impossibile ottenere JWT token${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC}"

# Ottieni CA certificate
echo -n "Estraggo CA certificate... "
SA_CA_CRT=$(kubectl -n "$KAFKA_NAMESPACE" get secret "$SA_SECRET" \
  -o jsonpath='{.data.ca\.crt}' | base64 --decode)

if [ -z "$SA_CA_CRT" ]; then
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Impossibile ottenere CA certificate${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC}"

echo

# ========================================
# CONFIGURAZIONE VAULT
# ========================================
echo -e "${BLUE}Configurazione Vault...${NC}"

# Crea file temporaneo per policy
POLICY_FILE="/tmp/kafka-lab-policy-$$.hcl"
cat > "$POLICY_FILE" <<'EOF'
# Policy per kafka-lab namespace

# Lettura secret Kafka users
path "secret/data/kafka/users/*" {
  capabilities = ["read", "list"]
}

# Lettura secret monitoring
path "secret/data/kafka/monitoring/*" {
  capabilities = ["read", "list"]
}

# Lettura secret Jenkins
path "secret/data/kafka/jenkins/*" {
  capabilities = ["read", "list"]
}

# Metadati (per list operations)
path "secret/metadata/kafka/*" {
  capabilities = ["list"]
}

# Deny esplicito per altri path
path "secret/data/*" {
  capabilities = ["deny"]
}
EOF

echo "Policy creata in: $POLICY_FILE"
echo

# Esegui comandi in Vault
echo -e "${YELLOW}Eseguo configurazione in Vault pod...${NC}"

kubectl -n "$VAULT_NAMESPACE" exec -i "$VAULT_POD" -- sh <<EOF
set -e

export VAULT_ADDR='http://127.0.0.1:8200'

# Login con root token (se disponibile) o usa VAULT_TOKEN dal pod
if [ -f /root/.vault-token ]; then
    VAULT_TOKEN=\$(cat /root/.vault-token)
    export VAULT_TOKEN
fi

echo "→ Abilito Kubernetes auth method..."
if vault auth list | grep -q "kubernetes/"; then
    echo "  ✓ Già abilitato"
else
    vault auth enable kubernetes
    echo "  ✓ Kubernetes auth abilitato"
fi

echo "→ Configuro Kubernetes auth..."
vault write auth/kubernetes/config \\
    kubernetes_host="https://kubernetes.default.svc:443" \\
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \\
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
echo "  ✓ Kubernetes auth configurato"

echo "→ Carico policy..."
vault policy write $VAULT_ROLE - <<POLICY
$(cat "$POLICY_FILE")
POLICY
echo "  ✓ Policy '$VAULT_ROLE' creata"

echo "→ Creo role per namespace $KAFKA_NAMESPACE..."
vault write auth/kubernetes/role/$VAULT_ROLE \\
    bound_service_account_names=$SA_NAME \\
    bound_service_account_namespaces=$KAFKA_NAMESPACE \\
    policies=$VAULT_ROLE \\
    ttl=24h
echo "  ✓ Role '$VAULT_ROLE' creato"

echo
echo "Verifica configurazione:"
echo "→ Auth methods:"
vault auth list | grep kubernetes

echo
echo "→ Policy:"
vault policy read $VAULT_ROLE | head -10

echo
echo "→ Role:"
vault read auth/kubernetes/role/$VAULT_ROLE
EOF

VAULT_EXIT_CODE=$?

# Pulizia
rm -f "$POLICY_FILE"

echo

if [ $VAULT_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  ✓ Configurazione completata!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo
    echo -e "${YELLOW}Informazioni configurazione:${NC}"
    echo "  Namespace: $KAFKA_NAMESPACE"
    echo "  ServiceAccount: $SA_NAME"
    echo "  Vault Role: $VAULT_ROLE"
    echo "  Policy: $VAULT_ROLE"
    echo
    echo -e "${YELLOW}Prossimi step:${NC}"
    echo "1. Verifica External Secrets Operator sia installato"
    echo "2. Deploy Kafka Lab Helm chart"
    echo "3. Verifica creazione External Secrets"
    echo
    echo "Test configurazione:"
    echo "  kubectl -n $KAFKA_NAMESPACE get externalsecrets"
    echo "  kubectl -n $KAFKA_NAMESPACE get secrets"
else
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  ✗ Errore durante configurazione${NC}"
    echo -e "${RED}============================================${NC}"
    exit 1
fi
