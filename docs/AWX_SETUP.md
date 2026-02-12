# 🤖 AWX Setup - Kafka Lab

## ⚠️ PROBLEMA COMUNE: Python `kubernetes` Library Mancante

```
Failed to import the required Python library (kubernetes)
```

AWX usa un container (**Execution Environment**) che di default NON ha
la libreria Python `kubernetes`. Bisogna buildare un EE custom.

---

## STEP 1: Build e Push Execution Environment

```bash
cd awx-ee/
docker build -t gabrisource/kafka-ee:1.0.0 .
docker push gabrisource/kafka-ee:1.0.0
```

## STEP 2: Aggiungi EE in AWX

1. **Administration → Execution Environments → Add**
2. **Name:** `Kafka-EE`
3. **Image:** `gabrisource/kafka-ee:1.0.0`
4. **Pull:** `Always`
5. **Save**

---

## STEP 3: Configura Project

1. **Projects → Add**
2. **Name:** `Kafka-Kube-Project`
3. **Source Control Type:** `Git`
4. **Source Control URL:** `https://github.com/gabri-souce/kafka-kube.git`
5. **Branch:** `main`
6. **Update Revision on Launch:** ✅
7. **Save** (AWX scarica automaticamente il codice)

---

## STEP 4: Crea Inventory

1. **Inventories → Add → Inventory**
2. **Name:** `Local-K8s`
3. **Save**
4. Vai su **Hosts → Add**
5. **Name:** `localhost`
6. **Variables:**
   ```yaml
   ansible_connection: local
   ansible_python_interpreter: /usr/bin/python3
   ```
7. **Save**

---

## STEP 5: Crea Credential Kubernetes

```bash
# Recupera token ServiceAccount jenkins-admin
kubectl -n kafka-lab create token jenkins-admin --duration=8760h
```

1. **Credentials → Add**
2. **Name:** `Kafka-K8s-Token`
3. **Credential Type:** `OpenShift or Kubernetes API Bearer Token`
4. **Kubernetes API Endpoint:** `https://kubernetes.docker.internal:6443`
5. **API Authentication Bearer Token:** (token dal comando sopra)
6. **Verify SSL:** ❌ Off
7. **Save**

---

## STEP 6: Crea Job Templates

### 🔍 Health Check
| Campo | Valore |
|-------|--------|
| Name | `03-Kafka-Health-Check` |
| Inventory | `Local-K8s` |
| Project | `Kafka-Kube-Project` |
| Execution Environment | `Kafka-EE` |
| Playbook | `ansible/playbooks/kafka_health.yml` |
| Credentials | `Kafka-K8s-Token` |

### 📋 Create Topic
| Campo | Valore |
|-------|--------|
| Name | `01-Kafka-Create-Topic` |
| Inventory | `Local-K8s` |
| Project | `Kafka-Kube-Project` |
| Execution Environment | `Kafka-EE` |
| Playbook | `ansible/playbooks/kafka_create_topic.yml` |
| Credentials | `Kafka-K8s-Token` |
| Prompt on Launch | ✅ |

### 👥 Manage Users
| Campo | Valore |
|-------|--------|
| Name | `02-Kafka-Manage-Users` |
| Inventory | `Local-K8s` |
| Project | `Kafka-Kube-Project` |
| Execution Environment | `Kafka-EE` |
| Playbook | `ansible/playbooks/kafka_manage_users.yml` |
| Credentials | `Kafka-K8s-Token` |
| Prompt on Launch | ✅ |

---

## STEP 7: Schedule Health Check (come in Prod)

1. Apri Job Template `03-Kafka-Health-Check`
2. **Schedules → Add**
3. **Name:** `Every-30-Minutes`
4. **Frequency:** Every 30 minutes
5. **Save**

---

## 🔑 Password Admin AWX

```bash
kubectl get secret awx-admin-password -n kafka-lab \
  -o jsonpath="{.data.password}" | base64 -d && echo ""
```

**URL:** http://localhost:30043
