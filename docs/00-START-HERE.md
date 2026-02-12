# 🚀 START HERE - Guida Introduttiva

**Benvenuto in Kafka Lab!** Questo progetto ti permette di imparare Kafka con gestione enterprise dei secret tramite Vault.

---

## 👋 Prima di Iniziare

### Cosa troverai qui

Questo progetto è un **ambiente completo** per:

1. **Imparare Kafka** - 60+ esercizi pratici
2. **Gestire secret professionalmente** - HashiCorp Vault integration
3. **Automatizzare operazioni** - Jenkins e Ansible
4. **Monitorare cluster** - Prometheus e Grafana

### Prerequisiti

- **Kubernetes cluster** (Minikube, KIND, o cloud)
- **Helm 3.0+**
- **kubectl** configurato
- **30 minuti** per il setup iniziale

---

## 🎯 Scegli il Tuo Percorso

### 🆕 Sono Nuovo - Voglio Solo Provare

**Obiettivo:** Avere Kafka funzionante in 15 minuti

**Percorso rapido:**

1. Leggi: [Quick Start nel README](../README.md#quick-start-5-comandi)
2. Esegui i 5 comandi
3. Verifica: `kubectl -n kafka-lab get pods`
4. Accedi Kafka UI: http://localhost:30080

**Prossimi step:**
- Prova alcuni [esercizi base](../esercizi/)
- Familiarizza con Kafka UI

---

### 📚 Voglio Imparare Kafka

**Obiettivo:** Padroneggiare Kafka da zero

**Percorso learning:**

1. **Setup ambiente** (15 min)
   - Segui [Quick Start](../README.md#quick-start-5-comandi)
   
2. **Apprendi basi Kafka** (2-3 ore)
   - [Esercizi Modulo 1](../esercizi/CORSO_KAFKA_SYSADMIN_MOD1.md)
   - Teoria: topic, partition, replication
   
3. **Pratica operazioni** (3-4 ore)
   - [60 esercizi completi](../esercizi/CORSO_COMPLETO_KAFKA_SYSADMIN_60_ESERCIZI.md)
   - Creazione topic, utenti, ACL
   - Consumer groups, offset management
   
4. **Kafka Connect** (2 ore)
   - [Guida Kafka Connect](../esercizi/KAFKA_CONNECT_GUIDE.md)
   - Connettori source/sink
   - Change Data Capture (CDC)

**Timeline totale:** ~1 settimana part-time

---

### 🔐 Voglio Capire Vault Integration

**Obiettivo:** Gestione professionale secret

**Percorso Vault:**

1. **Comprendi il problema** (10 min)
   ```
   PRIMA: password: "admin123"  # ❌ Hardcoded in Git
   DOPO:  vaultPath: users/admin # ✅ Recuperata da Vault
   ```

2. **Setup Vault** (30 min)
   - [Guida completa Vault](guides/VAULT_SETUP_GUIDE.md)
   - Deploy Vault server
   - Inizializza secret
   - Configura Kubernetes auth

3. **Testa funzionamento** (15 min)
   - Verifica External Secrets
   - Cambia password in Vault
   - Osserva auto-refresh

4. **Scenari avanzati** (1-2 ore)
   - [Configurazioni multi-env](../examples/vault/configuration-scenarios.yaml)
   - Vault HA, TLS, Policy
   - Secret rotation

**Timeline totale:** 3-4 ore

---

### 🏢 Deploy in Produzione

**Obiettivo:** Setup production-ready

**Checklist produzione:**

1. **Vault Setup** ✓
   - [ ] Vault HA (3+ replica)
   - [ ] TLS abilitato
   - [ ] Backup configurato
   - [ ] Audit logging attivo

2. **Kafka Setup** ✓
   - [ ] Persistent storage
   - [ ] Replication factor ≥ 3
   - [ ] Min ISR = 2
   - [ ] Resource limits appropriati

3. **Security** ✓
   - [ ] Network policies
   - [ ] Pod security policies
   - [ ] TLS per Kafka listeners
   - [ ] ACL configurate

4. **Monitoring** ✓
   - [ ] Prometheus scraping
   - [ ] Grafana dashboards
   - [ ] Alert rules
   - [ ] Log aggregation

5. **Disaster Recovery** ✓
   - [ ] Backup Vault
   - [ ] Backup Kafka config
   - [ ] Runbook recovery
   - [ ] Tested restoration

**Guide di riferimento:**
- [Vault Production](guides/VAULT_SETUP_GUIDE.md#best-practices-produzione)
- [Kafka Deployment](guides/KAFKA_DEPLOYMENT.md)

---

## 🗺️ Mappa della Documentazione

### Guide Complete (Step-by-Step)

| File | Descrizione | Quando leggerla |
|------|-------------|-----------------|
| [KAFKA_DEPLOYMENT.md](guides/KAFKA_DEPLOYMENT.md) | Setup Kafka completo | Prima del deploy |
| [VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md) | Vault end-to-end | Per gestire secret |
| [JENKINS_GUIDE.md](guides/JENKINS_GUIDE.md) | CI/CD automation | Per automatizzare ops |
| [AWX_SETUP.md](guides/AWX_SETUP.md) | Ansible orchestration | Alternative a Jenkins |

### Reference Veloci

| File | Descrizione | Quando consultarla |
|------|-------------|-------------------|
| [JENKINS_VS_AWX.md](reference/JENKINS_VS_AWX.md) | Decision guide | Scegliere tool |
| [CHANGELOG.md](CHANGELOG.md) | Modifiche progetto | Tracking changes |

### Esempi Pratici

| Cartella | Contenuto |
|----------|-----------|
| [examples/vault/](../examples/vault/) | Configurazioni Vault per vari scenari |
| [esercizi/](../esercizi/) | 60+ esercizi guidati Kafka |

---

## 🎓 FAQ - Domande Frequenti

### Q: Devo usare Vault anche per LAB?

**A:** Puoi scegliere:
- **Con Vault** (consigliato): Impari gestione secret professionale
- **Senza Vault**: Disabilita in `values.yaml` (`vault.enabled: false`)

### Q: Quanto spazio disco serve?

**A:** Minimo **20GB** per:
- Kubernetes (5GB)
- Kafka cluster (10GB per persistent volumes)
- Monitoring (3GB)
- Vault (2GB)

### Q: Posso usare Docker invece di Kubernetes?

**A:** No, questo progetto richiede Kubernetes. Per Docker, vedi altri progetti nella collection.

### Q: Come accedo alle UI?

```bash
# Kafka UI
kubectl port-forward -n kafka-lab svc/kafka-ui 8080:8080
# → http://localhost:8080

# Grafana
kubectl port-forward -n kafka-lab svc/grafana 3000:3000
# → http://localhost:3000

# Jenkins
kubectl -n kafka-lab get svc jenkins
# → http://<node-ip>:<nodeport>

# Vault UI
kubectl -n vault-system get svc vault-ui
# → http://<node-ip>:<nodeport>
```

### Q: Dove trovo le password?

**Con Vault abilitato:**
```bash
# Password Grafana
kubectl -n kafka-lab get secret grafana-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Password Jenkins
kubectl -n kafka-lab get secret jenkins-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Password Kafka users
kubectl -n vault-system exec -it vault-0 -- \
  vault kv get secret/kafka/users/admin
```

### Q: Come faccio troubleshooting?

Vedi sezione troubleshooting in:
- [README](../README.md#troubleshooting)
- [VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md#troubleshooting)

---

## ⚡ Comandi Utili

### Verifica Status

```bash
# Vault
kubectl -n vault-system get pods
vault status

# External Secrets
kubectl -n kafka-lab get externalsecrets
kubectl -n kafka-lab get secretstore

# Kafka
kubectl -n kafka-lab get kafka
kubectl -n kafka-lab get kafkauser
kubectl -n kafka-lab get kafkatopic

# Monitoring
kubectl -n kafka-lab get pods -l app=prometheus
kubectl -n kafka-lab get pods -l app=grafana
```

### Logs

```bash
# External Secrets Operator
kubectl -n external-secrets-system logs -l app.kubernetes.io/name=external-secrets

# Strimzi Operator
kubectl -n kafka-lab logs -l name=strimzi-cluster-operator

# Kafka broker
kubectl -n kafka-lab logs kafka-cluster-kafka-0

# Jenkins
kubectl -n kafka-lab logs -l app=jenkins
```

### Cleanup

```bash
# Rimuovi tutto
helm uninstall kafka-lab -n kafka-lab
helm uninstall external-secrets -n external-secrets-system
helm uninstall vault -n vault-system

# Elimina namespaces
kubectl delete namespace kafka-lab
kubectl delete namespace external-secrets-system
kubectl delete namespace vault-system
```

---

## 🚦 Prossimi Step

Hai letto questa guida? Ottimo! Ora:

### Opzione 1: Deploy Rapido
→ [README - Quick Start](../README.md#quick-start-5-comandi)

### Opzione 2: Approfondisci Vault
→ [VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md)

### Opzione 3: Inizia Esercizi Kafka
→ [Esercizi Modulo 1](../esercizi/CORSO_KAFKA_SYSADMIN_MOD1.md)

---

## 💡 Suggerimenti

1. **Inizia semplice**: Deploy LAB con dev mode
2. **Sperimenta**: Cambia config, rompi cose, impara
3. **Leggi codice**: Esplora `helm/templates/` per capire
4. **Usa script**: In `scripts/vault/` per operazioni comuni
5. **Consulta esempi**: In `examples/` per scenari reali

---

## 🤝 Bisogno di Aiuto?

1. **Leggi FAQ** (sopra)
2. **Controlla troubleshooting** nelle guide
3. **Consulta esempi** in `examples/`
4. **Verifica logs** dei componenti

---

**Buon apprendimento! 🚀**

Qualsiasi percorso tu scelga, questo progetto ti darà solide basi su Kafka e secret management enterprise-grade.
