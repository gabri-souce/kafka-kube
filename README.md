# 🚀 Kafka Lab - Production-Ready Environment

**Ambiente completo Kafka con Vault, External Secrets, Monitoring, e CI/CD**

## 🎯 Caratteristiche

✅ **Kafka Cluster** - 3 broker in KRaft mode (no ZooKeeper)  
✅ **HashiCorp Vault** - Gestione centralizzata secret  
✅ **External Secrets Operator** - Sync automatico Vault → Kubernetes  
✅ **Strimzi Operator** - Gestione Kafka-as-Code  
✅ **Monitoring Stack** - Prometheus + Grafana  
✅ **CI/CD** - Jenkins con pipelines preconfigurate  
✅ **Automation** - AWX (Ansible Tower open-source)  
✅ **Kafka UI** - Interfaccia web per management  
✅ **Kafka Connect** - Integrazione dati  
✅ **Cruise Control** - Rebalancing automatico  

---

## 🚀 Quick Start

### Deploy Automatico (Consigliato)

```bash
# 1. Pulisci eventuali installazioni precedenti
./cleanup.sh

# 2. Deploy completo
./deploy.sh
```

**Tempo stimato:** 10-15 minuti

---

## 📊 Accesso alle UI

Dopo l'installazione:

| Servizio | URL | Credenziali |
|----------|-----|-------------|
| **Kafka UI** | http://localhost:30080 | Nessuna |
| **Grafana** | http://localhost:30030 | admin / (vedi password file) |
| **Jenkins** | http://localhost:32000 | admin / (vedi password file) |
| **Prometheus** | http://localhost:30090 | Nessuna |

**File password:** `scripts/vault/vault-passwords-TIMESTAMP.txt`

---

## 📚 Documentazione

- **[INSTALL.md](INSTALL.md)** - Installazione manuale passo-passo
- **[docs/](docs/)** - Documentazione completa
- **[examples/](examples/)** - Esempi configurazione

---

## 🧪 Test Rapido

```bash
# Crea topic
kubectl -n kafka-lab apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: 3
  replicas: 3
EOF

# Producer
kubectl -n kafka-lab run kafka-producer -ti \
  --image=quay.io/strimzi/kafka:0.44.0-kafka-4.0.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic

# Consumer (in un altro terminale)
kubectl -n kafka-lab run kafka-consumer -ti \
  --image=quay.io/strimzi/kafka:0.44.0-kafka-4.0.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

---

## 🔧 Comandi Utili

```bash
# Status pods
kubectl -n kafka-lab get pods

# Kafka topics
kubectl -n kafka-lab get kafkatopic

# Kafka users
kubectl -n kafka-lab get kafkauser

# External secrets
kubectl -n kafka-lab get externalsecrets

# Logs Kafka broker
kubectl -n kafka-lab logs kafka-cluster-kafka-nodes-0
```

---

## 🗑️ Pulizia

```bash
./cleanup.sh
```

---

## 🛠️ Troubleshooting

Vedi **[INSTALL.md#troubleshooting](INSTALL.md#troubleshooting)**

---

## ✅ Cosa è stato FIXATO

Rispetto alla versione precedente:

1. ✅ **Vault path corretto** - `secret` invece di `secret/data/kafka`
2. ✅ **Kubernetes auth** - Usa credenziali del pod Vault
3. ✅ **Script automatizzati** - Deploy e cleanup in un comando
4. ✅ **Documentazione completa** - Guide passo-passo
5. ✅ **Testing incluso** - Esempi pronti all'uso

---

**Pronto per il deploy!** 🎉

---

## ⚠️ Dopo un Restart di Docker Desktop / Mac Sleep

Vault gira in **dev mode** (dati in memoria) — si svuota ad ogni restart del pod.
Quando ESO mostra `SecretSyncedError` o Kafka UI non si connette, esegui:

```bash
./scripts/vault/vault-reinit.sh
```

Lo script ripristina tutto in ~30 secondi:
- Ricarica i secret in Vault
- Riconfigura il Kubernetes auth
- Forza la risincronizzazione di ESO
- Riavvia Kafka UI

