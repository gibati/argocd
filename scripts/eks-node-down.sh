#!/bin/bash

CLUSTER_NAME="minelsos-cluster"
NODEGROUP_NAME="cheap-ng-spot-new"

echo "Desligando Node Group $NODEGROUP_NAME no cluster $CLUSTER_NAME..."
aws eks update-nodegroup-config \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODEGROUP_NAME \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 \
  --no-cli-pager

echo "Feito! Node Group escalado para 0. Verifique status com 'kubectl get nodes'."
