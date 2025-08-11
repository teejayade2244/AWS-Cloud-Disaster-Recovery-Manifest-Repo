# Update kubeconfig for both clusters
aws eks update-kubeconfig --region us-east-1 --name your-primary-cluster-name
aws eks update-kubeconfig --region us-west-2 --name aura-flow-dev-eu-west-2

# Add the EKS charts repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update
VPC_ID=$(aws eks describe-cluster --name aura-flow-dev-eu-west-2 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
# Deploy to primary cluster
kubectl config use-context arn:aws:eks:us-east-1:ACCOUNT-ID:cluster/your-primary-cluster-name
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=aura-flow-dev-eu-west-2 \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=$(aws eks describe-cluster --name aura-flow-dev-eu-west-2 --query 'cluster.resourcesVpcConfig.vpcId' --output text) \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::899411341244:role/aura-flow-dev-eu-west-2-alb-ingress-controller-role

# Deploy to secondary cluster  
kubectl config use-context arn:aws:eks:us-west-2:ACCOUNT-ID:cluster/your-secondary-cluster-name
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=your-secondary-cluster-name \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT-ID:role/your-secondary-cluster-name-alb-ingress-controller-role