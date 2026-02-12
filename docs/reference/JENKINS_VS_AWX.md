# ⚡ QUICK REFERENCE: Jenkins vs AWX

## 🎯 REGOLA D'ORO

```
┌─────────────────────────────────────────────────────────┐
│  "È un'operazione che farò spesso?"                     │
│                                                          │
│  SÌ, almeno 1 volta/settimana  → JENKINS ✅             │
│  NO, meno di 1 volta/settimana → AWX ✅                 │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 DECISION FLOWCHART

```
START: Ho bisogno di...
│
├─ Serve APPROVAZIONE?
│  ├─ SÌ → AWX ✅
│  └─ NO → continua ↓
│
├─ È COMPLESSO? (>10 step Ansible)
│  ├─ SÌ → AWX ✅
│  └─ NO → continua ↓
│
├─ DEVELOPERS self-service?
│  ├─ SÌ → JENKINS ✅
│  └─ NO → continua ↓
│
├─ Operazione CRITICA production?
│  ├─ SÌ → AWX (audit trail) ✅
│  └─ NO → JENKINS ✅
│
└─ Default → JENKINS ✅
```

---

## 🔵 JENKINS - Quick Guide

### Quando Usarlo
- ✅ Create topic (quotidiano)
- ✅ Create user (quotidiano)
- ✅ Deploy connector (settimanale)
- ✅ Health check (automatico)
- ✅ Consumer lag (automatico)

### Accesso
```bash
URL: http://localhost:32000
User: admin
Pass: admin123
```

### Jobs Principali
```
kafka-operations/
├── deploy-topic       → 2 min
├── deploy-user        → 2 min
├── deploy-connector   → 3 min
├── health-check       → 30 sec (scheduled ogni 30 min)
└── consumer-lag       → 20 sec (scheduled ogni 5 min)
```

### Esempio Uso
```
1. Apri http://localhost:32000
2. Click "kafka-operations" → "deploy-topic"
3. "Build with Parameters"
4. Compila form
5. "Build"
6. Aspetta 2 minuti → Done! ✅
```

---

## 🟢 AWX - Quick Guide

### Quando Usarlo
- ✅ Full cluster test (settimanale)
- ✅ Security audit (settimanale)
- ✅ Backup config (notturno automatico)
- ✅ Scale cluster (mensile, con approval)
- ✅ Disaster recovery (emergenza)

### Accesso
```bash
URL: http://localhost:30043
User: admin
Pass: [da kubectl get secret]

# Recupera password:
kubectl get secret awx-admin-password -n kafka-lab \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Templates Principali
```
Job Templates/
├── Full Kafka Test        → 5-10 min
├── Security Audit         → 3 min
├── Backup Configuration   → 10 min (scheduled nightly)
├── Scale Cluster          → 30-60 min (approval needed)
└── Disaster Recovery      → 1-3 hours (approval needed)
```

### Esempio Uso
```
1. Apri http://localhost:30043
2. Login con password da kubectl
3. "Templates" → "Full Kafka Test"
4. Click rocket icon (Launch)
5. Aspetta 5-10 min → Report completo! ✅
```

---

## 📋 USE CASES COMUNI

### Create Kafka Topic
```
Tool: JENKINS ✅
Perché: Quotidiano, semplice, self-service
Tempo: 2 minuti
```

### Create Kafka User + ACL
```
Tool: JENKINS ✅
Perché: Quotidiano, template standard
Tempo: 2 minuti
```

### Deploy Kafka Connector (CDC)
```
Tool: JENKINS ✅
Perché: Settimanale, data engineers self-service
Tempo: 3 minuti
```

### Health Check Automatico
```
Tool: JENKINS ✅
Perché: Ogni 30 min, veloce, alert automatici
Tempo: 30 secondi
```

### Full Cluster Test
```
Tool: AWX ✅
Perché: Settimanale, complesso (20+ task), report
Tempo: 5-10 minuti
```

### Security Audit
```
Tool: AWX ✅
Perché: Compliance, report dettagliato, scheduled
Tempo: 3 minuti
```

### Backup Configurazioni
```
Tool: AWX ✅
Perché: Notturno, upload S3, verify integrity
Tempo: 10 minuti
```

### Scale Cluster 3→5 Nodi
```
Tool: AWX ✅
Perché: Critico, approval needed, 30+ step
Tempo: 30-60 minuti
```

### Disaster Recovery
```
Tool: AWX ✅
Perché: Emergenza, approval senior, audit essenziale
Tempo: 1-3 ore
```

---

## 🚦 TRAFFIC LIGHT SYSTEM

### 🟢 Usa JENKINS se vedi:
- Parola: "daily", "quick", "self-service", "developer"
- Frequenza: > 1 volta/settimana
- Complessità: 1-5 step
- Approval: Non necessaria
- Tempo: < 5 minuti

### 🟡 Può essere ENTRAMBI:
- Operazione settimanale
- Complessità media
- Team misto (dev + ops)
→ Jenkins per dev, AWX per audit/report

### 🔴 Usa AWX se vedi:
- Parola: "critical", "production", "approval", "audit"
- Frequenza: < 1 volta/settimana
- Complessità: > 10 step
- Approval: Necessaria
- Tempo: > 30 minuti

---

## 💡 PRO TIPS

### Tip 1: Pipeline Jenkins per dev, AWX per ops
```
Stesso risultato, diverso workflow:

Developer path (Jenkins):
- Form parametri semplice
- Build immediato
- Notification su Slack
- History builds

SRE path (AWX):
- Survey form completo
- Approval workflow
- Compliance checks
- PDF report generato
```

### Tip 2: Use AWX scheduled jobs per maintenance
```
AWX excels at:
- Nightly backups
- Weekly security audits
- Monthly compliance reports
- Quarterly upgrades
```

### Tip 3: Use Jenkins webhooks per CI/CD
```
Git push → Jenkins webhook triggered
→ Build app
→ Run tests
→ Create Kafka topic (auto)
→ Deploy app
→ Verify connectivity
```

### Tip 4: Combine both per complex workflows
```
Jenkins: Deploy new microservice
  ↓
  Trigger AWX via API: Full integration test
  ↓
  AWX: Generate compliance report
  ↓
  Notification: "Deployment complete + compliant"
```

---

## 📞 QUICK COMMANDS

### Check Jenkins Status
```bash
kubectl get pods -n kafka-lab -l app=jenkins
curl -s http://localhost:32000 > /dev/null && echo "✅ OK" || echo "❌ DOWN"
```

### Check AWX Status
```bash
kubectl get pods -n kafka-lab -l app.kubernetes.io/name=awx
curl -s http://localhost:30043 > /dev/null && echo "✅ OK" || echo "❌ DOWN"
```

### View Jenkins Logs
```bash
kubectl logs -n kafka-lab -l app=jenkins --tail=100 -f
```

### View AWX Logs
```bash
kubectl logs -n kafka-lab -l app.kubernetes.io/name=awx --tail=100 -f
```

### Restart Jenkins
```bash
kubectl rollout restart deployment jenkins -n kafka-lab
```

### Restart AWX
```bash
kubectl delete pod -l app.kubernetes.io/name=awx -n kafka-lab
```

---

## 🎯 FINAL ANSWER

```
┌─────────────────────────────────────────────────────────┐
│  "Devo usare Jenkins o AWX?"                            │
│                                                          │
│  RISPOSTA SEMPLICE:                                     │
│                                                          │
│  - Inizi sempre con JENKINS                             │
│  - Se l'operazione è troppo complessa/critica           │
│    → Sposti su AWX                                      │
│                                                          │
│  RATIO:                                                  │
│  - 80% operazioni → Jenkins                             │
│  - 20% operazioni → AWX                                 │
│                                                          │
│  ENTRAMBI sono utili, si complementano!                 │
└─────────────────────────────────────────────────────────┘
```

---

## 📚 Resources

- Guida completa: GUIDA_DEPLOYMENT_KAFKA_FIX.md
- Jenkins pipelines: jenkins/pipelines/*.groovy
- AWX playbooks: ansible/playbooks/*.yml
- Esercizi: esercizi/CORSO_COMPLETO_KAFKA_SYSADMIN_60_ESERCIZI.md
