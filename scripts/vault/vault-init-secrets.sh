#!/bin/bash
# ============================================================================
# Script per inizializzare Vault con i secret del progetto Kafka
# ============================================================================
# Utilizzo:
#   ./scripts/vault-init-secrets.sh
#
# Prerequisiti:
#   - Vault deve essere già deployato e unsealed
#   - vault CLI deve essere installato
#   - VAULT_ADDR e VAULT_TOKEN devono essere impostati
# ============================================================================

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
VAULT_KV_PATH="secret/kafka"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Vault Secret Initialization for Kafka Lab${NC}"
echo -e "${BLUE}============================================${NC}"
echo

# Verifica prerequisiti
echo -e "${YELLOW}Verifico prerequisiti...${NC}"

if ! command -v vault &> /dev/null; then
    echo -e "${RED}❌ vault CLI non trovato. Installalo: https://www.vaultproject.io/downloads${NC}"
    exit 1
fi

if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}❌ VAULT_ADDR non impostato${NC}"
    echo "Esempio: export VAULT_ADDR='http://127.0.0.1:8200'"
    exit 1
fi

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}❌ VAULT_TOKEN non impostato${NC}"
    echo "Esempio: export VAULT_TOKEN='root'"
    exit 1
fi

# Verifica connessione a Vault
echo -n "Testo connessione a Vault ($VAULT_ADDR)... "
if vault status &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}❌ Impossibile connettersi a Vault${NC}"
    exit 1
fi

# Verifica se KV engine è abilitato
echo -n "Verifico KV secrets engine... "
if vault secrets list | grep -q "^secret/"; then
    echo -e "${GREEN}✓ Già abilitato${NC}"
else
    echo -e "${YELLOW}Non trovato, abilito...${NC}"
    vault secrets enable -version=2 -path=secret kv
    echo -e "${GREEN}✓ KV engine abilitato${NC}"
fi

echo

# Funzione per generare password sicura
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Funzione per creare secret in Vault
create_secret() {
    local path=$1
    local password=$2
    
    echo -n "Creo secret: ${path}... "
    if vault kv put "${VAULT_KV_PATH}/${path}" password="${password}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Modalità interattiva o automatica
echo -e "${YELLOW}Scegli modalità:${NC}"
echo "1) Automatica - genera password casuali (consigliato per lab)"
echo "2) Interattiva - inserisci password manualmente (consigliato per prod)"
echo -n "Scelta [1/2]: "
read -r MODE

echo

if [ "$MODE" == "2" ]; then
    # ========================================
    # MODALITÀ INTERATTIVA
    # ========================================
    echo -e "${BLUE}Modalità Interattiva${NC}"
    echo -e "${YELLOW}Inserisci le password (min 12 caratteri):${NC}"
    echo
    
    # Kafka Admin
    echo -n "Password per Kafka Admin User: "
    read -s ADMIN_PASSWORD
    echo
    if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
        echo -e "${RED}❌ Password troppo corta (min 12 caratteri)${NC}"
        exit 1
    fi
    
    # Producer User
    echo -n "Password per Kafka Producer User: "
    read -s PRODUCER_PASSWORD
    echo
    if [ ${#PRODUCER_PASSWORD} -lt 12 ]; then
        echo -e "${RED}❌ Password troppo corta (min 12 caratteri)${NC}"
        exit 1
    fi
    
    # Consumer User
    echo -n "Password per Kafka Consumer User: "
    read -s CONSUMER_PASSWORD
    echo
    if [ ${#CONSUMER_PASSWORD} -lt 12 ]; then
        echo -e "${RED}❌ Password troppo corta (min 12 caratteri)${NC}"
        exit 1
    fi
    
    # Grafana Admin
    echo -n "Password per Grafana Admin: "
    read -s GRAFANA_PASSWORD
    echo
    if [ ${#GRAFANA_PASSWORD} -lt 12 ]; then
        echo -e "${RED}❌ Password troppo corta (min 12 caratteri)${NC}"
        exit 1
    fi
    
    # Jenkins Admin
    echo -n "Password per Jenkins Admin: "
    read -s JENKINS_PASSWORD
    echo
    if [ ${#JENKINS_PASSWORD} -lt 12 ]; then
        echo -e "${RED}❌ Password troppo corta (min 12 caratteri)${NC}"
        exit 1
    fi
    
    echo
    
else
    # ========================================
    # MODALITÀ AUTOMATICA
    # ========================================
    echo -e "${BLUE}Modalità Automatica - Generazione password casuali${NC}"
    echo
    
    ADMIN_PASSWORD=$(generate_password)
    PRODUCER_PASSWORD=$(generate_password)
    CONSUMER_PASSWORD=$(generate_password)
    GRAFANA_PASSWORD=$(generate_password)
    JENKINS_PASSWORD=$(generate_password)
fi

# ========================================
# CREAZIONE SECRET IN VAULT
# ========================================
echo -e "${BLUE}Caricamento secret in Vault...${NC}"
echo

# Kafka Users
create_secret "users/admin" "$ADMIN_PASSWORD"
create_secret "users/producer-user" "$PRODUCER_PASSWORD"
create_secret "users/consumer-user" "$CONSUMER_PASSWORD"

# Monitoring
create_secret "monitoring/grafana" "$GRAFANA_PASSWORD"

# Jenkins
create_secret "jenkins/admin" "$JENKINS_PASSWORD"

echo

# ========================================
# VERIFICA SECRET
# ========================================
echo -e "${BLUE}Verifica secret creati...${NC}"
echo

echo "Lista secret in Vault:"
vault kv list "${VAULT_KV_PATH}/users" | sed 's/^/  /'
vault kv list "${VAULT_KV_PATH}/monitoring" | sed 's/^/  /'
vault kv list "${VAULT_KV_PATH}/jenkins" | sed 's/^/  /'

echo

# ========================================
# SALVATAGGIO PASSWORD (OPZIONALE)
# ========================================
echo -e "${YELLOW}Vuoi salvare le password in un file locale? [s/N]:${NC} "
read -r SAVE_PASSWORDS

if [ "$SAVE_PASSWORDS" == "s" ] || [ "$SAVE_PASSWORDS" == "S" ]; then
    OUTPUT_FILE="vault-passwords-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$OUTPUT_FILE" <<EOF
# ============================================================================
# KAFKA LAB - VAULT PASSWORDS
# Generato: $(date)
# ============================================================================
# ⚠️  ATTENZIONE: Questo file contiene password in chiaro!
# ⚠️  NON committare in Git
# ⚠️  Conserva in modo sicuro (1Password, Bitwarden, etc.)
# ⚠️  Elimina dopo aver memorizzato le password
# ============================================================================

KAFKA USERS:
-----------
Admin User:
  Username: admin
  Password: ${ADMIN_PASSWORD}
  
Producer User:
  Username: producer-user
  Password: ${PRODUCER_PASSWORD}
  
Consumer User:
  Username: consumer-user
  Password: ${CONSUMER_PASSWORD}

MONITORING:
----------
Grafana Admin:
  Username: admin
  Password: ${GRAFANA_PASSWORD}
  URL: http://<node-ip>:30030

JENKINS:
-------
Jenkins Admin:
  Username: admin
  Password: ${JENKINS_PASSWORD}
  URL: http://<node-ip>:32000

# ============================================================================
# VAULT ACCESS:
# vault kv get secret/kafka/users/admin
# vault kv get secret/kafka/monitoring/grafana
# ============================================================================
EOF
    
    chmod 600 "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Password salvate in: ${OUTPUT_FILE}${NC}"
    echo -e "${RED}⚠️  Ricorda di eliminare questo file dopo aver memorizzato le password!${NC}"
else
    echo -e "${YELLOW}Password non salvate. Puoi recuperarle da Vault con:${NC}"
    echo "  vault kv get ${VAULT_KV_PATH}/users/admin"
fi

echo
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✓ Inizializzazione completata!${NC}"
echo -e "${GREEN}============================================${NC}"
echo
echo -e "${YELLOW}Prossimi step:${NC}"
echo "1. Configura Kubernetes Auth in Vault"
echo "2. Crea Policy e Role"
echo "3. Deploy External Secrets Operator"
echo "4. Deploy Kafka Lab con Helm"
echo
echo "Vedi: docs/VAULT_SETUP_GUIDE.md per istruzioni complete"
