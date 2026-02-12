# 🔧 AWX Setup

## 1. Login

```bash
# Get password
kubectl get secret awx-admin-password -n kafka-lab -o jsonpath="{.data.password}" | base64 -d; echo
```

- URL: http://localhost:30043
- User: admin
- Pass: (output above)

## 2. Create Kubernetes Credential

```bash
# Create ServiceAccount
kubectl create serviceaccount awx-sa -n kafka-lab
kubectl create clusterrolebinding awx-admin --clusterrole=cluster-admin --serviceaccount=kafka-lab:awx-sa

# Get token (copy this!)
kubectl create token awx-sa -n kafka-lab --duration=8760h
```

In AWX:
1. **Resources → Credentials → Add**
2. Type: `OpenShift or Kubernetes API Bearer Token`
3. API Endpoint: `https://kubernetes.default.svc`
4. Paste token

## 3. Create Project

| Field | Value |
|-------|-------|
| Name | Kafka Lab |
| SCM Type | Git |
| URL | https://github.com/YOUR-USER/kafka-lab.git |
| Branch | main |

## 4. Create Inventory

- Name: Kafka Cluster
- Host: localhost
- Variables: `ansible_connection: local`

## 5. Job Templates

| Template | Playbook |
|----------|----------|
| Health Check | `ansible/playbooks/kafka_health.yml` |
| Create Topic | `ansible/playbooks/kafka_create_topic.yml` |
| Manage Users | `ansible/playbooks/kafka_manage_users.yml` |
| Full Test | `ansible/playbooks/kafka_full_test.yml` |

Add Kubernetes credential to all templates.
