#!/bin/bash

echo "🔹 Reduzindo deployments do kube-system para 1 réplica cada..."

# Lista todos os deployments no namespace kube-system
DEPLOYMENTS=$(kubectl get deployments -n kube-system -o jsonpath='{.items[*].metadata.name}')

for dep in $DEPLOYMENTS; do
  echo "Reduzindo $dep para 1 réplica..."
  kubectl scale deployment $dep -n kube-system --replicas=1
done

echo "🔹 Reduzindo daemonsets que rodam múltiplos pods por node..."

# Lista daemonsets no namespace kube-system (não precisa reduzir se só tem 1 node, mas vamos garantir)
DAEMONSETS=$(kubectl get daemonsets -n kube-system -o jsonpath='{.items[*].metadata.name}')

for ds in $DAEMONSETS; do
  echo "Verificando $ds (DaemonSet)..."
  # Apenas informar, DaemonSets já rodam 1 pod por node
  kubectl get ds $ds -n kube-system
done

echo "✅ Todos os deployments ajustados. Agora o cluster está com minimal pods."
kubectl get pods -n kube-system
