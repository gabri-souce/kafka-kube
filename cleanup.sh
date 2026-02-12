#!/bin/bash
# ============================================================================
# KAFKA LAB - CLEANUP COMPLETO
# ============================================================================
# Rimuove completamente l'installazione di Kafka Lab
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              KAFKA LAB - CLEANUP COMPLETO                 ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo

echo -e "${YELLOW}⚠️  ATTENZIONE: Questa operazione rimuoverà:${NC}"
echo "   - Kafka Lab (topics, users, data)"
echo "   - Strimzi Operator"
echo "   - External Secrets Operator"
echo "   - HashiCorp Vault"
echo "   - Tutti i PVC e dati persistenti"
echo

read -p "Sei sicuro di voler continuare? (yes/NO): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}✓ Operazione annullata${NC}"
    exit 0
fi

echo

# ============================================================================
# RIMOZIONE KAFKA LAB
# ============================================================================
echo -e "${BLUE}[1/7] Rimozione Kafka Lab...${NC}"

if helm list -n kafka-lab | grep -q kafka-lab; then
    helm uninstall kafka-lab -n kafka-lab --wait --timeout 5m
    echo -e "${GREEN}✓ Kafka Lab rimosso${NC}"
else
    echo -e "${YELLOW}⊘ Kafka Lab non installato${NC}"
fi

# ============================================================================
# RIMOZIONE STRIMZI OPERATOR
# ============================================================================
echo -e "${BLUE}[2/7] Rimozione Strimzi Operator...${NC}"

if helm list -n kafka-lab | grep -q strimzi-operator; then
    helm uninstall strimzi-operator -n kafka-lab --wait --timeout 5m
    echo -e "${GREEN}✓ Strimzi Operator rimosso${NC}"
else
    echo -e "${YELLOW}⊘ Strimzi Operator non installato${NC}"
fi

# ============================================================================
# RIMOZIONE EXTERNAL SECRETS
# ============================================================================
echo -e "${BLUE}[3/7] Rimozione External Secrets Operator...${NC}"

if helm list -n external-secrets-system | grep -q external-secrets; then
    helm uninstall external-secrets -n external-secrets-system --wait --timeout 5m
    echo -e "${GREEN}✓ External Secrets rimosso${NC}"
else
    echo -e "${YELLOW}⊘ External Secrets non installato${NC}"
fi

# ============================================================================
# RIMOZIONE VAULT
# ============================================================================
echo -e "${BLUE}[4/7] Rimozione HashiCorp Vault...${NC}"

if helm list -n vault-system | grep -q vault; then
    helm uninstall vault -n vault-system --wait --timeout 5m
    echo -e "${GREEN}✓ Vault rimosso${NC}"
else
    echo -e "${YELLOW}⊘ Vault non installato${NC}"
fi

# ============================================================================
# ELIMINAZIONE NAMESPACE
# ============================================================================
echo -e "${BLUE}[5/7] Eliminazione namespace...${NC}"

for ns in kafka-lab external-secrets-system vault-system; do
    if kubectl get namespace $ns &> /dev/null; then
        echo -n "  Elimino namespace $ns... "
        kubectl delete namespace $ns --timeout=120s
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "  ${YELLOW}⊘ Namespace $ns non esiste${NC}"
    fi
done

# ============================================================================
# PULIZIA PVC ORFANI
# ============================================================================
echo -e "${BLUE}[6/7] Pulizia PVC orfani...${NC}"

ORPHAN_PVCS=$(kubectl get pvc --all-namespaces 2>/dev/null | grep -E "kafka|vault|external-secrets" | awk '{print $1"/"$2}' || true)

if [ -n "$ORPHAN_PVCS" ]; then
    echo "$ORPHAN_PVCS" | while read PVC; do
        NS=$(echo $PVC | cut -d/ -f1)
        NAME=$(echo $PVC | cut -d/ -f2)
        echo -n "  Elimino PVC $NS/$NAME... "
        kubectl -n $NS delete pvc $NAME --timeout=60s
        echo -e "${GREEN}✓${NC}"
    done
else
    echo -e "  ${YELLOW}⊘ Nessun PVC orfano trovato${NC}"
fi

# ============================================================================
# PULIZIA CRD
# ============================================================================
echo -e "${BLUE}[7/7] Pulizia CRD (Custom Resource Definitions)...${NC}"

# CRD Strimzi
for CRD in $(kubectl get crd | grep strimzi.io | awk '{print $1}'); do
    echo -n "  Elimino CRD $CRD... "
    kubectl delete crd $CRD --timeout=60s &> /dev/null || true
    echo -e "${GREEN}✓${NC}"
done

# CRD External Secrets
for CRD in $(kubectl get crd | grep external-secrets.io | awk '{print $1}'); do
    echo -n "  Elimino CRD $CRD... "
    kubectl delete crd $CRD --timeout=60s &> /dev/null || true
    echo -e "${GREEN}✓${NC}"
done

# ============================================================================
# VERIFICA FINALE
# ============================================================================
echo
echo -e "${BLUE}Verifica pulizia...${NC}"
echo

echo -e "${YELLOW}Namespace rimasti:${NC}"
kubectl get ns | grep -E "kafka|vault|external-secrets" || echo -e "  ${GREEN}✓ Nessun namespace trovato${NC}"

echo
echo -e "${YELLOW}PVC rimasti:${NC}"
kubectl get pvc --all-namespaces | grep -E "kafka|vault|external-secrets" || echo -e "  ${GREEN}✓ Nessun PVC trovato${NC}"

echo
echo -e "${YELLOW}CRD rimasti:${NC}"
kubectl get crd | grep -E "strimzi|external-secrets" || echo -e "  ${GREEN}✓ Nessun CRD trovato${NC}"

# ============================================================================
# RIEPILOGO
# ============================================================================
echo
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   CLEANUP COMPLETATO                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}✓ Kafka Lab rimosso${NC}"
echo -e "${GREEN}✓ Tutti i componenti eliminati${NC}"
echo -e "${GREEN}✓ Cluster pulito${NC}"
echo
echo -e "${YELLOW}Nota:${NC} I file di password (vault-passwords-*.txt) non sono stati eliminati."
echo "      Puoi eliminarli manualmente se necessario."
echo
