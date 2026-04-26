# EKS Terraform + Kubernetes Operations Guide

Image used: `andalike/node8080`

---

## PART 1: TERRAFORM - Provision EKS Cluster

```bash
cd terraform-eks/terraform

# Initialize Terraform (downloads providers)
terraform init

# Preview what will be created
terraform plan

# Create the EKS cluster (~15-20 minutes)
terraform apply

# After creation, configure kubectl
aws eks update-kubeconfig --name knote-eks-cluster --region us-east-1 --profile profile-name

# Verify connection
kubectl get nodes
```

### Terraform Operations
```bash
# Show current state
terraform show

# Show specific resource
terraform state show aws_eks_cluster.main

# Destroy everything (WARNING: deletes the cluster)
terraform destroy

# Format terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

---

## PART 2: KUBERNETES OPERATIONS

### 2.1 Namespace
```bash
# Create namespace
kubectl apply -f k8s-manifests/01-namespace.yaml

# List namespaces
kubectl get namespaces

# Set default namespace for all commands
kubectl config set-context --current --namespace=knote-app
```

---

### 2.2 ConfigMap Operations
```bash
# Create ConfigMap
kubectl apply -f k8s-manifests/02-configmap.yaml

# List ConfigMaps
kubectl get configmap -n knote-app

# Describe (see all key-value pairs)
kubectl describe configmap knote-config -n knote-app

# Get ConfigMap as YAML
kubectl get configmap knote-config -n knote-app -o yaml

# Edit ConfigMap live (opens editor)
kubectl edit configmap knote-config -n knote-app

# Create ConfigMap from command line
kubectl create configmap my-config \
  --from-literal=KEY1=value1 \
  --from-literal=KEY2=value2 \
  -n knote-app

# Create ConfigMap from file
kubectl create configmap my-file-config \
  --from-file=config.properties \
  -n knote-app

# Delete ConfigMap
kubectl delete configmap knote-config -n knote-app
```

---

### 2.3 Secret Operations
```bash
# Create Secrets
kubectl apply -f k8s-manifests/03-secret.yaml

# List Secrets
kubectl get secrets -n knote-app

# Describe Secret (shows keys, not values)
kubectl describe secret knote-secret -n knote-app

# Decode a secret value
kubectl get secret knote-secret -n knote-app -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode

# Create Secret from command line
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n knote-app

# Create Docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_USER \
  --docker-password=YOUR_PASS \
  -n knote-app

# Create TLS secret
kubectl create secret tls my-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n knote-app

# Delete Secret
kubectl delete secret knote-secret -n knote-app
```

---

### 2.4 Deployment Operations

#### Apply Deployments
```bash
# Rolling Update deployment (zero-downtime, default)
kubectl apply -f k8s-manifests/04-deployment-rolling-update.yaml

# Recreate deployment (kills all, then creates)
kubectl apply -f k8s-manifests/05-deployment-recreate.yaml

# Blue/Green deployment
kubectl apply -f k8s-manifests/06-deployment-blue-green.yaml

# Canary deployment
kubectl apply -f k8s-manifests/07-deployment-canary.yaml
```

#### Monitor Deployments
```bash
# List all deployments
kubectl get deployments -n knote-app

# Watch deployment status live
kubectl get deployments -n knote-app --watch

# Detailed deployment info
kubectl describe deployment knote-rolling -n knote-app

# Check rollout status
kubectl rollout status deployment/knote-rolling -n knote-app

# View rollout history
kubectl rollout history deployment/knote-rolling -n knote-app
```

#### Scaling
```bash
# Scale manually
kubectl scale deployment knote-rolling --replicas=5 -n knote-app

# Scale to zero (stop all pods)
kubectl scale deployment knote-rolling --replicas=0 -n knote-app

# Autoscale (requires metrics-server)
kubectl autoscale deployment knote-rolling \
  --min=2 --max=10 --cpu-percent=80 -n knote-app

# Check HPA status
kubectl get hpa -n knote-app
```

#### Update Image (triggers deployment strategy)
```bash
# Update image (triggers rolling update / recreate based on strategy)
kubectl set image deployment/knote-rolling \
  knote=andalike/node8080:v2 -n knote-app

# Watch the rollout happen
kubectl rollout status deployment/knote-rolling -n knote-app
```

#### Rollback
```bash
# Rollback to previous version
kubectl rollout undo deployment/knote-rolling -n knote-app

# Rollback to specific revision
kubectl rollout history deployment/knote-rolling -n knote-app
kubectl rollout undo deployment/knote-rolling --to-revision=2 -n knote-app
```

#### Blue/Green Switch
```bash
# Switch traffic from Blue to Green
kubectl patch service knote-bluegreen-svc -n knote-app \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Switch back to Blue (rollback)
kubectl patch service knote-bluegreen-svc -n knote-app \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# After green is verified, delete blue
kubectl delete deployment knote-blue -n knote-app
```

#### Canary Promotion
```bash
# Scale up canary (increase traffic %)
kubectl scale deployment knote-canary --replicas=5 -n knote-app
kubectl scale deployment knote-stable --replicas=5 -n knote-app
# Now 50/50 traffic split

# Full promotion: scale stable to 0, canary to desired count
kubectl scale deployment knote-stable --replicas=0 -n knote-app
kubectl scale deployment knote-canary --replicas=10 -n knote-app

# Rollback: scale canary to 0
kubectl scale deployment knote-canary --replicas=0 -n knote-app
kubectl scale deployment knote-stable --replicas=10 -n knote-app
```

---

### 2.5 StatefulSet Operations
```bash
# Create StatefulSet
kubectl apply -f k8s-manifests/08-statefulset.yaml

# List StatefulSets
kubectl get statefulset -n knote-app

# Watch pods come up in ORDER (0, then 1, then 2)
kubectl get pods -n knote-app -l app=knote-db --watch

# Check individual pod DNS names
# Format: <pod-name>.<headless-service>.<namespace>.svc.cluster.local
# knote-db-0.knote-db-headless.knote-app.svc.cluster.local
# knote-db-1.knote-db-headless.knote-app.svc.cluster.local
# knote-db-2.knote-db-headless.knote-app.svc.cluster.local

# Scale StatefulSet (pods added/removed in order)
kubectl scale statefulset knote-db --replicas=5 -n knote-app

# Check PersistentVolumeClaims (each pod gets its own PVC)
kubectl get pvc -n knote-app

# Describe PVC
kubectl describe pvc data-knote-db-0 -n knote-app

# Delete StatefulSet (PVCs are NOT deleted automatically)
kubectl delete statefulset knote-db -n knote-app

# Manually delete PVCs after StatefulSet deletion
kubectl delete pvc -l app=knote-db -n knote-app
```

---

### 2.6 Service Operations
```bash
# Create all services
kubectl apply -f k8s-manifests/09-services.yaml

# List all services
kubectl get services -n knote-app

# Wide output (shows endpoints)
kubectl get services -n knote-app -o wide

# Describe service (shows endpoints, selectors)
kubectl describe service knote-loadbalancer -n knote-app

# Get the LoadBalancer external URL
kubectl get service knote-loadbalancer -n knote-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get NodePort value
kubectl get service knote-nodeport -n knote-app \
  -o jsonpath='{.spec.ports[0].nodePort}'

# Check endpoints (which pods are backing the service)
kubectl get endpoints knote-clusterip -n knote-app

# Test ClusterIP from within cluster
kubectl run test-pod --rm -it --image=busybox -n knote-app -- \
  wget -qO- http://knote-clusterip.knote-app.svc.cluster.local

# Port forward (access service locally)
kubectl port-forward service/knote-clusterip 8080:80 -n knote-app
# Now accessible at http://localhost:8080

# Delete service
kubectl delete service knote-loadbalancer -n knote-app
```

---

### 2.7 Network Policy Operations
```bash
# Apply network policies (requires CNI plugin like Calico)
kubectl apply -f k8s-manifests/10-network-policy.yaml

# List network policies
kubectl get networkpolicy -n knote-app

# Describe network policy
kubectl describe networkpolicy allow-knote-to-db -n knote-app

# Test connectivity (from knote pod to db pod - should work)
kubectl exec -it <knote-pod-name> -n knote-app -- \
  wget -qO- --timeout=3 http://knote-db-headless:8080

# Test connectivity (from random pod to db - should be BLOCKED)
kubectl run test-pod --rm -it --image=busybox -n knote-app -- \
  wget -qO- --timeout=3 http://knote-db-headless:8080

# Delete a network policy
kubectl delete networkpolicy default-deny-ingress -n knote-app

# Install Calico CNI (if not present, NetworkPolicies won't be enforced)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

---

## PART 3: COMMON OPERATIONS & DEBUGGING

### Pod Operations
```bash
# List all pods
kubectl get pods -n knote-app

# List pods with more details
kubectl get pods -n knote-app -o wide

# Watch pods in real-time
kubectl get pods -n knote-app --watch

# Get pod YAML
kubectl get pod <pod-name> -n knote-app -o yaml

# Describe pod (events, conditions, volumes)
kubectl describe pod <pod-name> -n knote-app

# Get pod logs
kubectl logs <pod-name> -n knote-app

# Get logs from specific container in multi-container pod
kubectl logs <pod-name> -c <container-name> -n knote-app

# Follow logs (tail -f)
kubectl logs -f <pod-name> -n knote-app

# Get previous container logs (if crashed)
kubectl logs <pod-name> --previous -n knote-app

# Exec into a pod (interactive shell)
kubectl exec -it <pod-name> -n knote-app -- /bin/sh

# Copy files to/from pod
kubectl cp local-file.txt knote-app/<pod-name>:/tmp/file.txt
kubectl cp knote-app/<pod-name>:/tmp/file.txt local-file.txt

# Delete a pod (will be recreated by deployment)
kubectl delete pod <pod-name> -n knote-app

# Force delete a stuck pod
kubectl delete pod <pod-name> -n knote-app --grace-period=0 --force
```

### Cluster Operations
```bash
# Get all resources in namespace
kubectl get all -n knote-app

# Get nodes
kubectl get nodes

# Describe node
kubectl describe node <node-name>

# Get node resource usage (requires metrics-server)
kubectl top nodes

# Get pod resource usage
kubectl top pods -n knote-app

# Get cluster info
kubectl cluster-info

# Get all namespaces
kubectl get namespaces

# Get events (sorted by time)
kubectl get events -n knote-app --sort-by='.lastTimestamp'
```

### Apply & Delete
```bash
# Apply ALL manifests at once (in order)
kubectl apply -f k8s-manifests/

# Apply with dry-run (preview changes)
kubectl apply -f k8s-manifests/ --dry-run=client

# Delete ALL resources from manifests
kubectl delete -f k8s-manifests/

# Delete everything in a namespace
kubectl delete all --all -n knote-app

# Delete namespace (deletes everything inside)
kubectl delete namespace knote-app
```

### Labels & Selectors
```bash
# List pods with labels
kubectl get pods --show-labels -n knote-app

# Filter by label
kubectl get pods -l app=knote -n knote-app
kubectl get pods -l strategy=rolling-update -n knote-app
kubectl get pods -l "track in (stable,canary)" -n knote-app

# Add label to pod
kubectl label pod <pod-name> environment=production -n knote-app

# Remove label
kubectl label pod <pod-name> environment- -n knote-app
```

---

## PART 4: COMPLETE DEPLOYMENT ORDER

```bash
# Step 1: Provision EKS with Terraform
cd terraform-eks/terraform
terraform init && terraform apply

# Step 2: Configure kubectl
aws eks update-kubeconfig --name knote-eks-cluster --region us-east-1

# Step 3: Deploy Kubernetes resources (in order)
cd ../k8s-manifests
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secret.yaml
kubectl apply -f 04-deployment-rolling-update.yaml
kubectl apply -f 08-statefulset.yaml
kubectl apply -f 09-services.yaml
kubectl apply -f 10-network-policy.yaml

# Step 4: Verify
kubectl get all -n knote-app

# Step 5: Get LoadBalancer URL
kubectl get service knote-loadbalancer -n knote-app

# Step 6: Cleanup
kubectl delete -f k8s-manifests/
cd ../terraform
terraform destroy
```

---

## QUICK REFERENCE: File Structure

```
terraform-eks/
├── terraform/                          # Infrastructure as Code
│   ├── provider.tf                     # AWS + Kubernetes providers
│   ├── variables.tf                    # Input variables
│   ├── terraform.tfvars                # Variable values
│   ├── vpc.tf                          # VPC, subnets, NAT, IGW
│   ├── eks.tf                          # EKS cluster definition
│   ├── outputs.tf                      # Output values
│   └── modules/eks/                    # EKS module
│       ├── main.tf                     # Cluster + Node Group + IAM
│       ├── variables.tf                # Module variables
│       └── outputs.tf                  # Module outputs
│
├── k8s-manifests/                      # Kubernetes Resources
│   ├── 01-namespace.yaml               # Namespace isolation
│   ├── 02-configmap.yaml               # Non-sensitive config data
│   ├── 03-secret.yaml                  # Sensitive data (base64)
│   ├── 04-deployment-rolling-update.yaml  # Zero-downtime deploy
│   ├── 05-deployment-recreate.yaml     # Kill-all-then-create deploy
│   ├── 06-deployment-blue-green.yaml   # Blue/Green with service switch
│   ├── 07-deployment-canary.yaml       # Gradual traffic shifting
│   ├── 08-statefulset.yaml             # Stateful app + PVC + headless svc
│   ├── 09-services.yaml                # ClusterIP, NodePort, LoadBalancer, ExternalName
│   └── 10-network-policy.yaml          # Ingress/Egress traffic rules
│
└── OPERATIONS-GUIDE.md                 # This file
```
