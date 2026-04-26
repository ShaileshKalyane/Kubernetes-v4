# EKS Terraform + Kubernetes Deployment

Deploy an AWS EKS cluster with Terraform and run Kubernetes workloads using multiple deployment strategies.

## Architecture

- **VPC**: Custom VPC (`10.0.0.0/16`) with 2 public + 2 private subnets across 2 AZs
- **EKS Cluster**: Managed Kubernetes (v1.31) with worker nodes in private subnets
- **NAT Gateway**: Single NAT for private subnet internet access
- **Node Group**: `t3.medium` instances, auto-scaling (1-4 nodes, desired 2)

## Project Structure

```
terraform-eks/
├── terraform/                            # Infrastructure as Code
│   ├── provider.tf                       # AWS + Kubernetes providers
│   ├── variables.tf                      # Input variables
│   ├── terraform.tfvars                  # Variable values (edit this)
│   ├── vpc.tf                            # VPC, subnets, NAT, IGW, route tables
│   ├── eks.tf                            # EKS module invocation
│   ├── outputs.tf                        # Cluster endpoint, kubectl command
│   └── modules/eks/                      # EKS module
│       ├── main.tf                       # Cluster, node group, IAM roles
│       ├── variables.tf                  # Module inputs
│       └── outputs.tf                    # Module outputs
│
├── k8s-manifests/                        # Kubernetes manifests (numbered for apply order)
│   ├── 01-namespace.yaml                 # knote-app namespace
│   ├── 02-configmap.yaml                 # Application config
│   ├── 03-secret.yaml                    # Sensitive data (base64-encoded)
│   ├── 04-deployment-rolling-update.yaml # Zero-downtime rolling update
│   ├── 05-deployment-recreate.yaml       # Kill-all-then-create strategy
│   ├── 06-deployment-blue-green.yaml     # Blue/Green with service switch
│   ├── 07-deployment-canary.yaml         # Gradual traffic shifting
│   ├── 08-statefulset.yaml               # StatefulSet with PVCs
│   ├── 09-services.yaml                  # ClusterIP, NodePort, LoadBalancer
│   └── 10-network-policy.yaml            # Ingress/Egress rules
│
├── OPERATIONS-GUIDE.md                   # Detailed operations reference
└── README.md                             # This file
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with a named profile
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

### 1. Configure Variables

Edit `terraform/terraform.tfvars` to set your desired values:

```hcl
aws_region         = "ap-south-1"      # AWS region
cluster_name       = "knote-eks-cluster"
cluster_version    = "1.31"
vpc_cidr           = "10.0.0.0/16"
node_instance_type = "t3.medium"
node_desired_count = 2
node_min_count     = 1
node_max_count     = 4
```

Update the AWS profile in `terraform/provider.tf` if needed (currently set to `profile-name`).

### 2. Provision the EKS Cluster

```bash
cd terraform
terraform init
terraform plan
terraform apply    # Takes ~15-20 minutes
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig \
  --name knote-eks-cluster \
  --region ap-south-1 \
  --profile profile-name
```

### 4. Deploy Kubernetes Resources

```bash
kubectl apply -f k8s-manifests/
```

Or apply in order for more control:

```bash
kubectl apply -f k8s-manifests/01-namespace.yaml
kubectl apply -f k8s-manifests/02-configmap.yaml
kubectl apply -f k8s-manifests/03-secret.yaml
kubectl apply -f k8s-manifests/04-deployment-rolling-update.yaml
kubectl apply -f k8s-manifests/09-services.yaml
```

### 5. Access the Application

```bash
# Get the LoadBalancer URL
kubectl get service knote-loadbalancer -n knote-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Deployment Strategies

| Strategy | File | Use Case |
|----------|------|----------|
| **Rolling Update** | `04-deployment-rolling-update.yaml` | Zero-downtime updates (default) |
| **Recreate** | `05-deployment-recreate.yaml` | When you can tolerate downtime |
| **Blue/Green** | `06-deployment-blue-green.yaml` | Instant switchover via service selector |
| **Canary** | `07-deployment-canary.yaml` | Gradual traffic shifting to new version |

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s-manifests/

# Destroy infrastructure
cd terraform
terraform destroy
```

## Further Reading

See [OPERATIONS-GUIDE.md](OPERATIONS-GUIDE.md) for detailed commands covering ConfigMaps, Secrets, scaling, rollbacks, blue/green switching, canary promotion, StatefulSets, network policies, and debugging.
