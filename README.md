#!/bin/bash

# ===========================
# VARIÁVEIS DE AMBIENTE
# ===========================
AWS_ACCOUNT_ID="528188785087"
CLUSTER_NAME="minelsos-cluster"
REGION="us-east-2"
NODEGROUP_NAME="cheap-ng-spot"
NODE_ROLE_NAME="EKSNodeRole"
VPC_ID="vpc-00ac24c38a169f38f"

# Se quiser, você pode adicionar subnets específicas:
SUBNETS=("subnet-0c520415f6ef42760" "subnet-04d3aa791f1837e30" "subnet-0399f8ad6ff995394")

# ===========================
# 1️⃣ Baixar IAM Policy oficial
# ===========================
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# ===========================
# 2️⃣ Criar a policy na AWS
# ===========================
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# ===========================
# 3️⃣ Anexar a policy à Node Role
# ===========================
aws iam attach-role-policy \
  --role-name EKSNodeRole \
  --policy-arn arn:aws:iam::528188785087:policy/AWSLoadBalancerControllerIAMPolicy

# ===========================
# 4️⃣ Adicionar repositório Helm e atualizar
# ===========================
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# ===========================
# 5️⃣ Instalar o AWS Load Balancer Controller via Helm
# ===========================
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=minelsos-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-2 \
  --set vpcId=vpc-00ac24c38a169f38f \
  --set replicaCount=1 \
  --set resources.limits.cpu=150m \
  --set resources.limits.memory=300Mi \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=128Mi \
  --set enableCertManager=false \
  --wait


# ===========================
# 6️⃣ Verificar se os pods estão rodando
# ===========================
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

###############################################################
# IDs das subnets do cluster
SUBNETS=("subnet-0c520415f6ef42760" "subnet-04d3aa791f1837e30" "subnet-0399f8ad6ff995394")

for SUBNET in "${SUBNETS[@]}"; do
  echo "Ajustando tags da subnet $SUBNET..."
  
  # Adiciona/atualiza tags corretas
  aws ec2 create-tags --resources $SUBNET \
    --tags Key=kubernetes.io/cluster/minelsos-cluster,Value=shared \
           Key=kubernetes.io/role/internal-elb,Value=1
  echo "Tags ajustadas"
done


# Criar Subnet Pública
 aws ec2 create-subnet \
  --vpc-id vpc-00ac24c38a169f38f \
  --cidr-block 172.31.100.0/24 \
  --availability-zone us-east-2a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=eks-public-1}]'

# Habilitar IP público automático
aws ec2 modify-subnet-attribute \
  --subnet-id subnet-0f6ce91cacddd47cd \
  --map-public-ip-on-launch

# Criar route table publica
aws ec2 create-route-table \
  --vpc-id vpc-00ac24c38a169f38f

# Criar rota
aws ec2 create-route \
  --route-table-id rtb-01f53867ac7467e46 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-05b87df018a08e4bc

# associar
aws ec2 associate-route-table \
  --subnet-id subnet-0f6ce91cacddd47cd \
  --route-table-id rtb-01f53867ac7467e46

# Criar a tag na sub pub
 aws ec2 create-tags \
  --resources subnet-0f6ce91cacddd47cd \
  --tags Key=kubernetes.io/cluster/minelsos-cluster,Value=shared \
         Key=kubernetes.io/role/elb,Value=1

