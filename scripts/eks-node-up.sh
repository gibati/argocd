#!/bin/bash

CLUSTER_NAME="minelsos-cluster"
NODEGROUP_NAME="cheap-ng-spot"
NODEGROUP_MIN="0"
NODEGROUP_MAX="2"
NODEGROUP_DESIRED="2"

echo "Ligando Node Group $NODEGROUP_NAME no cluster $CLUSTER_NAME..."
aws eks update-nodegroup-config \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODEGROUP_NAME \
  --scaling-config minSize=$NODEGROUP_MIN,maxSize=$NODEGROUP_MAX,desiredSize=$NODEGROUP_DESIRED

echo "Feito! Node Group escalado para $NODEGROUP_MAX. Verifique status com 'kubectl get nodes'."
