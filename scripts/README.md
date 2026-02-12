# 🔧 Scripts Automation

Script per automatizzare operazioni comuni su Kafka Lab e Vault.

---

## 📁 Struttura

```
scripts/
├── vault/      # Vault secret management
├── kafka/      # Kafka operations (future)
└── utils/      # Utility generici (future)
```

---

## 🔐 Vault Scripts

### vault-init-secrets.sh

**Scopo:** Inizializza tutti i secret in Vault

**Prerequisiti:**
- Vault deployato e unsealed
- `vault` CLI installato
- Variabili ambiente impostate:
  ```bash
  export VAULT_ADDR='http://127.0.0.1:8200'
  export VAULT_TOKEN='root'
  ```

**Utilizzo:**

```bash
cd scripts/vault
./vault-init-secrets.sh
```

**Modalità:**
1. **Automatica** - Genera password casuali sicure (consigliato LAB)
2. **Interattiva** - Inserisci password manualmente (consigliato PROD)

**Output:**
- Secret creati in Vault:
  - `secret/kafka/users/admin`
  - `secret/kafka/users/producer-user`
  - `secret/kafka/users/consumer-user`
  - `secret/kafka/monitoring/grafana`
  - `secret/kafka/jenkins/admin`
- Opzionalmente: file `vault-passwords-YYYYMMDD-HHMMSS.txt`

**Esempio:**

```bash
$ ./vault-init-secrets.sh

============================================
  Vault Secret Initialization for Kafka Lab
============================================

Verifico prerequisiti...
Testo connessione a Vault (http://127.0.0.1:8200)... ✓
Verifico KV secrets engine... ✓ Già abilitato

Scegli modalità:
1) Automatica - genera password casuali (consigliato per lab)
2) Interattiva - inserisci password manualmente (consigliato per prod)
Scelta [1/2]: 1

Modalità Automatica - Generazione password casuali

Caricamento secret in Vault...
Creo secret: users/admin... ✓
Creo secret: users/producer-user... ✓
Creo secret: users/consumer-user... ✓
Creo secret: monitoring/grafana... ✓
Creo secret: jenkins/admin... ✓

✓ Inizializzazione completata!
```

---

### vault-configure-k8s-auth.sh

**Scopo:** Configura Kubernetes authentication in Vault

**Prerequisiti:**
- Vault deployato in Kubernetes
- `kubectl` configurato
- ServiceAccount `vault-auth` creato (o verrà creato dallo script)

**Utilizzo:**

```bash
cd scripts/vault
./vault-configure-k8s-auth.sh
```

**Operazioni:**
1. Verifica Vault pod e ServiceAccount
2. Crea ServiceAccount se non esiste
3. Estrae JWT token e CA certificate
4. Configura Kubernetes auth in Vault
5. Crea policy per kafka-lab namespace
6. Crea role per autenticazione

**Output:**
- Kubernetes auth abilitato in Vault
- Policy `kafka-lab` creata
- Role `kafka-lab` creato
- ServiceAccount `vault-auth` configurato

**Esempio:**

```bash
$ ./vault-configure-k8s-auth.sh

============================================
  Vault Kubernetes Auth Configuration
============================================

Verifico prerequisiti...
Verifico Vault pod... ✓
Verifico ServiceAccount vault-auth... ✓

Raccolta informazioni Kubernetes...
Kubernetes API server... https://10.0.0.1:6443
Estraggo JWT token... ✓
Estraggo CA certificate... ✓

Configurazione Vault...
Eseguo configurazione in Vault pod...
→ Abilito Kubernetes auth method...
  ✓ Kubernetes auth abilitato
→ Configuro Kubernetes auth...
  ✓ Kubernetes auth configurato
→ Carico policy...
  ✓ Policy 'kafka-lab' creata
→ Creo role per namespace kafka-lab...
  ✓ Role 'kafka-lab' creato

✓ Configurazione completata!
```

---

## 🚀 Workflow Completo

### Setup da Zero

```bash
# 1. Deploy Vault
helm install vault hashicorp/vault -n vault-system --create-namespace

# 2. Accedi a Vault e unseala (se necessario)
kubectl -n vault-system exec -it vault-0 -- /bin/sh
vault operator unseal  # Ripeti 3 volte

# 3. Inizializza secret
cd scripts/vault
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
./vault-init-secrets.sh

# 4. Configura K8s auth
./vault-configure-k8s-auth.sh

# 5. Deploy External Secrets + Kafka
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace
helm install kafka-lab ../../helm -n kafka-lab
```

---

## 🔍 Troubleshooting

### Script vault-init-secrets.sh

**Errore: "vault CLI not found"**
```bash
# Installa vault CLI
# macOS
brew install vault

# Linux
wget https://releases.hashicorp.com/vault/1.15.4/vault_1.15.4_linux_amd64.zip
unzip vault_1.15.4_linux_amd64.zip
sudo mv vault /usr/local/bin/
```

**Errore: "VAULT_ADDR not set"**
```bash
export VAULT_ADDR='http://127.0.0.1:8200'
# O se Vault è in K8s
kubectl -n vault-system port-forward svc/vault 8200:8200 &
```

**Errore: "VAULT_TOKEN not set"**
```bash
# Per dev mode
export VAULT_TOKEN='root'

# Per produzione
vault login
export VAULT_TOKEN=$(cat ~/.vault-token)
```

### Script vault-configure-k8s-auth.sh

**Errore: "Vault pod not found"**
```bash
# Verifica deployment Vault
kubectl -n vault-system get pods

# Se non esiste, deploya Vault
helm install vault hashicorp/vault -n vault-system --create-namespace
```

**Errore: "ServiceAccount has no secret"**
```bash
# Kubernetes 1.24+ non crea automaticamente secret
# Lo script li crea automaticamente, ma puoi verificare:
kubectl -n kafka-lab get secret | grep vault-auth
```

**Errore: "Permission denied"**
```bash
# Rendi script eseguibili
chmod +x vault-init-secrets.sh
chmod +x vault-configure-k8s-auth.sh
```

---

## 📋 Checklist Deployment

Prima di eseguire gli script:

- [ ] Vault deployato
- [ ] Vault unsealed (se produzione)
- [ ] kubectl funzionante
- [ ] vault CLI installato
- [ ] Namespace kafka-lab esistente
- [ ] VAULT_ADDR impostato
- [ ] VAULT_TOKEN impostato

Dopo gli script:

- [ ] Secret in Vault verificati: `vault kv list secret/kafka/users`
- [ ] K8s auth configurato: `vault read auth/kubernetes/config`
- [ ] Policy creata: `vault policy read kafka-lab`
- [ ] Role creato: `vault read auth/kubernetes/role/kafka-lab`

---

## 💡 Pro Tips

1. **Salva password generate** - Se usi modalità automatica, salva il file password generato
2. **Testa connectivity** - Verifica Vault raggiungibile prima di eseguire script
3. **Usa port-forward** - Se Vault è in K8s, usa port-forward per accesso locale
4. **Log output** - Redirigi output per debugging: `./script.sh 2>&1 | tee log.txt`

---

## 🔗 Link Utili

- **Guida completa Vault:** [../../docs/guides/VAULT_SETUP_GUIDE.md](../../docs/guides/VAULT_SETUP_GUIDE.md)
- **Esempi configurazione:** [../../examples/vault/](../../examples/vault/)
- **Troubleshooting:** [../../docs/guides/VAULT_SETUP_GUIDE.md#troubleshooting](../../docs/guides/VAULT_SETUP_GUIDE.md#troubleshooting)

---

**Problemi?** → Consulta la [guida completa](../../docs/guides/VAULT_SETUP_GUIDE.md)
