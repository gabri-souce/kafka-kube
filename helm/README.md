# Kafka Lab Helm Chart

## Prerequisites

- Kubernetes 1.25+
- Strimzi Operator 0.50.0

## Install

```bash
# 1. Install Strimzi Operator first
helm repo add strimzi https://strimzi.io/charts/
helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
  -n kafka-lab \
  --version 0.50.0 \
  --set watchNamespaces="{kafka-lab}"

# 2. Install this chart
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm dependency update
helm install kafka-lab . -n kafka-lab
```

## Values

See `values.yaml` for configuration options.
