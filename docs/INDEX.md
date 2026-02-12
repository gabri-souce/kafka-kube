# 📚 Indice Documentazione

Benvenuto nella documentazione di Kafka Lab! Questa pagina ti aiuta a trovare rapidamente ciò che cerchi.

---

## 🚀 Punto di Partenza

**→ [00-START-HERE.md](00-START-HERE.md)** - Inizia qui se sei nuovo

---

## 📖 Guide Complete (Step-by-Step)

### Infrastructure

| Guida | Livello | Tempo | Descrizione |
|-------|---------|-------|-------------|
| [KAFKA_DEPLOYMENT.md](guides/KAFKA_DEPLOYMENT.md) | Intermedio | 30 min | Deploy Kafka cluster con Strimzi |
| [VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md) | Avanzato | 45 min | Configurazione completa Vault |

### Automation

| Guida | Livello | Tempo | Descrizione |
|-------|---------|-------|-------------|
| [JENKINS_GUIDE.md](guides/JENKINS_GUIDE.md) | Intermedio | 20 min | CI/CD per operazioni Kafka |
| [AWX_SETUP.md](guides/AWX_SETUP.md) | Avanzato | 30 min | Orchestrazione Ansible |

---

## 📋 Quick Reference

### Decision Guides

- **[JENKINS_VS_AWX.md](reference/JENKINS_VS_AWX.md)** - Quando usare Jenkins vs AWX

### Cheatsheets

(In preparazione - contribuisci!)

---

## 🏗️ Architecture & Design

| Documento | Descrizione |
|-----------|-------------|
| [STRUCTURE_ANALYSIS.md](architecture/STRUCTURE_ANALYSIS.md) | Analisi struttura progetto |

---

## 📝 Changelog & History

| File | Descrizione |
|------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Modifiche Vault integration |

---

## 🎯 Per Caso d'Uso

### Voglio imparare Kafka
1. [00-START-HERE.md](00-START-HERE.md) → Percorso Learning
2. [../esercizi/](../esercizi/) → 60+ esercizi

### Voglio deployare in LAB
1. [00-START-HERE.md](00-START-HERE.md) → Quick Start
2. [guides/KAFKA_DEPLOYMENT.md](guides/KAFKA_DEPLOYMENT.md)

### Voglio gestire secret con Vault
1. [guides/VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md)
2. [../examples/vault/](../examples/vault/) → Esempi

### Voglio automatizzare operazioni
1. [reference/JENKINS_VS_AWX.md](reference/JENKINS_VS_AWX.md) → Scegli tool
2. [guides/JENKINS_GUIDE.md](guides/JENKINS_GUIDE.md) o [guides/AWX_SETUP.md](guides/AWX_SETUP.md)

### Voglio andare in produzione
1. [guides/VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md) → Best Practices
2. [00-START-HERE.md](00-START-HERE.md) → Checklist produzione

---

## 🔍 Ricerca Rapida

### Per Argomento

**Vault & Secret Management**
- Setup: [guides/VAULT_SETUP_GUIDE.md](guides/VAULT_SETUP_GUIDE.md)
- Esempi: [../examples/vault/](../examples/vault/)
- Troubleshooting: [guides/VAULT_SETUP_GUIDE.md#troubleshooting](guides/VAULT_SETUP_GUIDE.md#troubleshooting)

**Kafka**
- Deployment: [guides/KAFKA_DEPLOYMENT.md](guides/KAFKA_DEPLOYMENT.md)
- Esercizi: [../esercizi/](../esercizi/)

**Automation**
- Jenkins: [guides/JENKINS_GUIDE.md](guides/JENKINS_GUIDE.md)
- AWX: [guides/AWX_SETUP.md](guides/AWX_SETUP.md)
- Script: [../scripts/](../scripts/)

**Monitoring**
- (Guide in preparazione)

---

## 📂 Struttura Directory

```
docs/
├── 00-START-HERE.md           # ← Entry point
├── INDEX.md                    # ← Sei qui
│
├── guides/                     # Guide complete
│   ├── KAFKA_DEPLOYMENT.md
│   ├── VAULT_SETUP_GUIDE.md
│   ├── JENKINS_GUIDE.md
│   └── AWX_SETUP.md
│
├── reference/                  # Quick reference
│   ├── JENKINS_VS_AWX.md
│   └── README_ORIGINAL.md
│
├── architecture/               # Design & structure
│   └── STRUCTURE_ANALYSIS.md
│
└── CHANGELOG.md               # Project changes
```

---

## 🆘 Troubleshooting

**External Secrets non funzionano?**
→ [guides/VAULT_SETUP_GUIDE.md#troubleshooting](guides/VAULT_SETUP_GUIDE.md#troubleshooting)

**Kafka User non si crea?**
→ [guides/KAFKA_DEPLOYMENT.md](guides/KAFKA_DEPLOYMENT.md)

**Jenkins non si avvia?**
→ [guides/JENKINS_GUIDE.md](guides/JENKINS_GUIDE.md)

---

## 💡 Contribuire alla Documentazione

Vuoi migliorare questa documentazione?

1. Identifica gap o errori
2. Scrivi/aggiorna file markdown
3. Invia pull request

**Guide mancanti:**
- Monitoring setup (Prometheus/Grafana)
- Networking & LoadBalancer
- Backup & Disaster Recovery
- Performance tuning

---

**Pronto?** → [00-START-HERE.md](00-START-HERE.md)
