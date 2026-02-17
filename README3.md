# EKS Minimal Lab – Low Cost + Spot + Pod Identity

---

## 1️⃣ Ajustar Tags das Subnets

Substitua pelos IDs reais das suas subnets:

```bash
CLUSTER_NAME="minelsos-cluster"

SUBNETS=("subnet-AAAA" "subnet-BBBB")

for SUBNET in "${SUBNETS[@]}"; do
  aws ec2 create-tags --resources $SUBNET \
    --tags Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared \
           Key=kubernetes.io/role/elb,Value=1
done
```

Para ALB interno:

```
kubernetes.io/role/internal-elb = 1
```

---

## 2️⃣ Instalar EKS Pod Identity Agent

```bash
aws eks create-addon \
  --cluster-name minelsos-cluster \
  --addon-name eks-pod-identity-agent
```

Validar:

```bash
kubectl get pods -n kube-system | grep pod-identity
```

---

## 3️⃣ Criar IAM Role do AWS Load Balancer Controller

### Criar trust.json

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

Criar role:

```bash
aws iam create-role \
  --role-name AWSLoadBalancerControllerRole \
  --assume-role-policy-document file://trust.json
```

---

## 4️⃣ Criar Policy Oficial do Controller

```bash
curl -o iam_policy.json \
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

Criar policy:

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Anexar à role:

```bash
aws iam attach-role-policy \
  --role-name AWSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::SEU_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

⚠️ Não anexar à NodeRole.

---

## 5️⃣ Criar ServiceAccount dedicada

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
```

---

## 6️⃣ Criar Pod Identity Association

```bash
aws eks create-pod-identity-association \
  --cluster-name minelsos-cluster \
  --namespace kube-system \
  --service-account aws-load-balancer-controller \
  --role-arn arn:aws:iam::SEU_ACCOUNT_ID:role/AWSLoadBalancerControllerRole
```

Validar:

```bash
aws eks list-pod-identity-associations \
  --cluster-name minelsos-cluster
```

---

## 7️⃣ Instalar AWS Load Balancer Controller (modo econômico)

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

```bash
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
```

---

## 8️⃣ Validar Pod Identity

```bash
kubectl exec -n kube-system -it deploy/aws-load-balancer-controller -- \
aws sts get-caller-identity
```

Se retornar ARN da role → Pod Identity funcionando corretamente.

---

## 9️⃣ Criar Service + Ingress

O Service deve ser:

```yaml
type: ClusterIP
```

O Ingress criará o ALB automaticamente.

---