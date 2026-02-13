# Kafka Lab — Production-Ready Environment

Ambiente Kafka enterprise-grade su Kubernetes con secret management, CI/CD, monitoring e automazione.

## Stack

| Componente | Tecnologia | URL |
|---|---|---|
| Kafka Cluster | Apache Kafka 4.0 · KRaft · 3 broker | interno |
| Secret Management | HashiCorp Vault + External Secrets Operator | http://localhost:30372 |
| Kafka UI | Kafka UI | http://localhost:30080 |
| Monitoring | Prometheus + Grafana + Kafka Exporter | :30090 / :30030 |
| CI/CD | Jenkins | http://localhost:32000 |
| Automation | AWX (Ansible Tower OSS) | http://localhost:30043 |
| Data Integration | Kafka Connect + Cruise Control | interno |

---

## Quick Start

```bash
./deploy.sh      # installa tutto (~10-15 minuti)
./cleanup.sh     # rimuove tutto
```

Lo script chiede una password unica usata per tutti i servizi.
Le credenziali vengono salvate in `scripts/vault/vault-passwords-TIMESTAMP.txt`.

---

## Accesso alle UI

| Servizio | URL | Credenziali |
|---|---|---|
| Kafka UI | http://localhost:30080 | — |
| Grafana | http://localhost:30030 | admin / file passwords |
| Jenkins | http://localhost:32000 | admin / file passwords |
| Prometheus | http://localhost:30090 | — |
| Vault | http://localhost:30372 | token: `root` |
| AWX | http://localhost:30043 | vedi sotto |

```bash
# Password AWX
kubectl get secret awx-admin-password -n kafka-lab -o jsonpath="{.data.password}" | base64 -d
```

> **Grafana:** importa dashboard ID `7589` per monitoring Kafka completo.
> **AWX:** configurazione manuale una tantum → [docs/AWX_SETUP.md](docs/AWX_SETUP.md)

---

## ⚠️ Dopo un Restart di Docker Desktop

Vault gira in dev mode — i dati sono in RAM e si perdono ad ogni restart del pod.
Quando `kubectl get externalsecret -n kafka-lab` mostra `SecretSyncedError`:

```bash
./scripts/vault/vault-reinit.sh
```

Ripristina tutto in ~30 secondi.

---

## Test Rapido

```bash
# Entra nel broker
kubectl exec -it kafka-cluster-kafka-nodes-0 -n kafka-lab -- bash

# Crea file autenticazione (va ricreato ad ogni accesso al pod)
cat > /tmp/admin.properties << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="admin" \
  password="LA-TUA-PASSWORD";
EOF

# Crea topic
bin/kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --command-config /tmp/admin.properties \
  --create --topic test --partitions 3 --replication-factor 3

# Lista topic
bin/kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --command-config /tmp/admin.properties --list
```

---

## Comandi Utili

```bash
kubectl get pods -n kafka-lab                           # status cluster
kubectl get externalsecret -n kafka-lab                 # ESO sincronizzato?
kubectl get kafkatopic -n kafka-lab                     # topic esistenti
kubectl get kafkauser -n kafka-lab                      # utenti Kafka
kubectl logs kafka-cluster-kafka-nodes-0 -n kafka-lab   # log broker
```

---

## Documentazione

| File | Contenuto |
|---|---|
| [INSTALL.md](INSTALL.md) | Installazione manuale step-by-step |
| [docs/AWX_SETUP.md](docs/AWX_SETUP.md) | Configurazione AWX (una tantum) |
| [docs/JENKINS_GUIDE.md](docs/JENKINS_GUIDE.md) | Uso pipeline Jenkins |
| [docs/VAULT_SETUP_GUIDE.md](docs/VAULT_SETUP_GUIDE.md) | Architettura Vault + ESO |
| [docs/guides/KAFKA_DEPLOYMENT.md](docs/guides/KAFKA_DEPLOYMENT.md) | Deployment Kafka dettagliato |
| [esercizi/](esercizi/) | Esercizi pratici Kafka |
