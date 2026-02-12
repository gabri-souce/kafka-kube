# 🚀 KAFKA LAB - INSTALLAZIONE COMPLETA

## ⚠️ PREREQUISITI

```bash
# 1. Cluster Kubernetes funzionante
kubectl cluster-info

# 2. Helm 3 installato
helm version

# 3. Vault CLI installato
vault version
```

---

## 📦 INSTALLAZIONE PASSO-PASSO

### STEP 1: Installa HashiCorp Vault

```bash
# Aggiungi repo Helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Crea namespace
kubectl create namespace vault-system

# Installa Vault in dev mode
helm install vault hashicorp/vault -n vault-system \
  --set server.dev.enabled=true \
  --set server.dev.devRootToken=root \
  --set ui.enabled=true \
  --set ui.serviceType=NodePort \
  --set injector.enabled=false

# Verifica
kubectl -n vault-system get pods
kubectl -n vault-system get svc
```

**Vault UI:** http://localhost:NODEPORT (trova porta con `kubectl -n vault-system get svc vault-ui`)

---

### STEP 2: Inizializza Secret in Vault

```bash
cd scripts/vault

# Configura accesso Vault
export VAULT_ADDR='http://localhost:NODEPORT'  # Usa NodePort di vault-ui
export VAULT_TOKEN='root'

# Esegui script inizializzazione
./vault-init-secrets.sh

# Scegli:
# - Opzione 1: Password casuali (per lab/test)
# - Opzione 2: Password manuali (per prod)

# Le password vengono salvate in: vault-passwords-TIMESTAMP.txt
# ⚠️ CONSERVA QUESTO FILE! Serve per accedere a Grafana/Jenkins
```

---

### STEP 3: Configura Kubernetes Auth in Vault

```bash
# Ancora in scripts/vault/
./vault-configure-k8s-auth.sh

# Lo script:
# 1. Crea ServiceAccount vault-auth
# 2. Configura Vault per autenticare Kubernetes
# 3. Crea policy e role kafka-lab
```

---

### STEP 4: Installa External Secrets Operator

```bash
# Aggiungi repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Installa ESO
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true

# Verifica
kubectl -n external-secrets-system get pods
```

---

### STEP 5: Installa Strimzi Operator

```bash
# Aggiungi repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Crea namespace
kubectl create namespace kafka-lab

# Installa Strimzi
helm install strimzi-operator strimzi/strimzi-kafka-operator \
  --namespace kafka-lab

# Verifica
kubectl -n kafka-lab get pods
```

---

### STEP 6: Installa Kafka Lab

```bash
# Dalla root del progetto
cd kafka-lab-fixed

# Installa Helm chart
helm install kafka-lab ./helm -n kafka-lab --timeout 15m

# Monitora deployment
watch kubectl -n kafka-lab get pods
```

**Attendi che TUTTI i pod siano Running (può richiedere 5-10 minuti)**

---

## ✅ VERIFICA INSTALLAZIONE

```bash
# 1. Verifica External Secrets
kubectl -n kafka-lab get externalsecrets
# Devono essere STATUS: SecretSynced, READY: True

# 2. Verifica Kafka Users
kubectl -n kafka-lab get kafkauser
# Devono essere tutti READY: True

# 3. Verifica tutti i pod
kubectl -n kafka-lab get pods
# Tutti devono essere Running o Completed

# 4. Verifica servizi
kubectl -n kafka-lab get svc
```

---

## 🌐 ACCESSO ALLE UI

### Kafka UI
```bash
kubectl -n kafka-lab get svc kafka-ui
# http://localhost:NODEPORT
```

### Grafana
```bash
kubectl -n kafka-lab get svc grafana
# http://localhost:NODEPORT
# User: admin
# Password: vedi file vault-passwords-*.txt
```

### Jenkins
```bash
kubectl -n kafka-lab get svc jenkins
# http://localhost:NODEPORT
# User: admin
# Password: vedi file vault-passwords-*.txt
```

### AWX
```bash
kubectl -n kafka-lab get svc awx-service
# http://localhost:NODEPORT
# User: admin
# Password: vedi file vault-passwords-*.txt
```

### Prometheus
```bash
kubectl -n kafka-lab get svc prometheus
# http://localhost:NODEPORT
```

---

## 🧪 TEST FUNZIONALITÀ

### Test 1: Crea Topic
```bash
kubectl -n kafka-lab apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  namespace: kafka-lab
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
    segment.bytes: 1073741824
EOF

# Verifica
kubectl -n kafka-lab get kafkatopic test-topic
```

### Test 2: Producer
```bash
kubectl -n kafka-lab run kafka-producer -ti \
  --image=quay.io/strimzi/kafka:0.44.0-kafka-4.0.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic
  
# Scrivi messaggi, premi CTRL+C per uscire
```

### Test 3: Consumer
```bash
kubectl -n kafka-lab run kafka-consumer -ti \
  --image=quay.io/strimzi/kafka:0.44.0-kafka-4.0.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

---

## 🔧 TROUBLESHOOTING

### External Secrets in errore
```bash
# Vedi errore
kubectl -n kafka-lab describe externalsecret admin-password

# Fix comune: Ricrea ServiceAccount
kubectl -n kafka-lab delete sa vault-auth
kubectl -n kafka-lab delete secret vault-auth-token
kubectl -n kafka-lab create sa vault-auth
kubectl -n kafka-lab apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: kafka-lab
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
EOF

# Riavvia ESO
kubectl -n external-secrets-system rollout restart deployment external-secrets
```

### Pod in CreateContainerConfigError
```bash
# Verifica secret esistano
kubectl -n kafka-lab get secrets

# Se mancano, forza sync External Secrets
kubectl -n kafka-lab annotate externalsecret admin-password force-sync=$(date +%s) --overwrite
```

### Kafka broker non partono
```bash
# Vedi log
kubectl -n kafka-lab logs kafka-cluster-kafka-nodes-0

# Verifica storage
kubectl -n kafka-lab get pvc

# Ricrea PVC se corrotti
kubectl -n kafka-lab delete pvc data-kafka-cluster-kafka-nodes-0
```

---

## 🗑️ DISINSTALLAZIONE COMPLETA

```bash
# 1. Rimuovi Kafka Lab
helm uninstall kafka-lab -n kafka-lab

# 2. Rimuovi Strimzi
helm uninstall strimzi-operator -n kafka-lab

# 3. Rimuovi External Secrets
helm uninstall external-secrets -n external-secrets-system

# 4. Rimuovi Vault
helm uninstall vault -n vault-system

# 5. Elimina namespace
kubectl delete namespace kafka-lab
kubectl delete namespace external-secrets-system
kubectl delete namespace vault-system

# 6. Pulisci PVC orfani
kubectl get pvc --all-namespaces | grep kafka
kubectl delete pvc -n kafka-lab --all
```

---

## 📚 DOCUMENTAZIONE

- **Strimzi:** https://strimzi.io/docs/operators/latest/overview.html
- **Vault:** https://www.vaultproject.io/docs
- **External Secrets:** https://external-secrets.io/latest/
- **Kafka:** https://kafka.apache.org/documentation/

---

## 🆘 SUPPORTO

In caso di problemi:
1. Controlla i log: `kubectl -n kafka-lab logs <pod-name>`
2. Verifica eventi: `kubectl -n kafka-lab get events --sort-by='.lastTimestamp'`
3. Stato risorse: `kubectl -n kafka-lab get all`
