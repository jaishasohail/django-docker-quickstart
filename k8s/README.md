# Kubernetes Deployment Manifests

This directory contains Kubernetes manifests for deploying the Django application to a Kubernetes cluster (EKS or Minikube).

## Prerequisites

- Kubernetes cluster (EKS, Minikube, or similar)
- kubectl configured to access your cluster
- Docker images built and pushed to a registry

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       Ingress                            │
│              (nginx-ingress-controller)                  │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   Backend Service                        │
│              (Django Application - 2+ pods)              │
└─────────────────────────────────────────────────────────┘
            │                              │
            ▼                              ▼
┌──────────────────────┐      ┌──────────────────────────┐
│  PostgreSQL Service  │      │     Redis Service        │
│   (StatefulSet)      │      │    (Deployment)          │
└──────────────────────┘      └──────────────────────────┘
            │                              │
            ▼                              ▼
   ┌─────────────────┐          ┌─────────────────────┐
   │   PVC (10Gi)    │          │  Celery Workers     │
   │  (Database)     │          │  (2+ pods)          │
   └─────────────────┘          └─────────────────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │  Celery Beat    │
                                │   (1 pod)       │
                                └─────────────────┘
```

## Manifest Files

- **namespace.yaml**: Namespace definitions for dev, prod, and monitoring
- **configmap.yaml**: Application configuration (non-sensitive)
- **secret.yaml**: Sensitive configuration (credentials)
- **postgres-deployment.yaml**: PostgreSQL StatefulSet with persistent storage
- **redis-deployment.yaml**: Redis deployment for caching and message queue
- **backend-deployment.yaml**: Django application deployment with HPA
- **celery-deployment.yaml**: Celery worker and beat deployments
- **ingress.yaml**: Ingress configuration for external access
- **jobs.yaml**: Database migrations, static files collection, and backups

## Quick Start

### 1. Local Development (Minikube)

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Deploy application
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/redis-deployment.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n django-app-dev --timeout=300s

# Run migrations
kubectl apply -f k8s/jobs.yaml

# Deploy application
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/celery-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Get Minikube IP
minikube ip

# Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
echo "$(minikube ip) django-app.local" | sudo tee -a /etc/hosts

# Access application
open http://django-app.local
```

### 2. AWS EKS Deployment

```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name django-app-dev

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Configure secrets (use AWS Secrets Manager or External Secrets Operator)
# Update secret.yaml with actual credentials
kubectl apply -f k8s/secret.yaml

# Deploy configuration
kubectl apply -f k8s/configmap.yaml

# Deploy infrastructure services
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/redis-deployment.yaml

# Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n django-app-dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n django-app-dev --timeout=300s

# Run database migrations
kubectl apply -f k8s/jobs.yaml

# Wait for migration job to complete
kubectl wait --for=condition=complete job/django-migrations -n django-app-dev --timeout=300s

# Deploy application
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/celery-deployment.yaml

# Install ingress controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Get Load Balancer URL
kubectl get ingress -n django-app-dev
```

## Verification

### Check Deployment Status

```bash
# View all resources
kubectl get all -n django-app-dev

# Check pods
kubectl get pods -n django-app-dev

# Check services
kubectl get svc -n django-app-dev

# Check ingress
kubectl get ingress -n django-app-dev
```

### View Logs

```bash
# Backend logs
kubectl logs -f deployment/backend -n django-app-dev

# Celery worker logs
kubectl logs -f deployment/celery-worker -n django-app-dev

# Celery beat logs
kubectl logs -f deployment/celery-beat -n django-app-dev

# Database logs
kubectl logs -f statefulset/postgres -n django-app-dev
```

### Exec into Pods

```bash
# Backend pod
kubectl exec -it deployment/backend -n django-app-dev -- /bin/bash

# Run Django management commands
kubectl exec -it deployment/backend -n django-app-dev -- python manage.py shell

# Database pod
kubectl exec -it statefulset/postgres -n django-app-dev -- psql -U postgres -d django_app_db
```

## Configuration

### Update Application Configuration

Edit `configmap.yaml` and apply:

```bash
kubectl apply -f k8s/configmap.yaml

# Restart deployments to pick up changes
kubectl rollout restart deployment/backend -n django-app-dev
kubectl rollout restart deployment/celery-worker -n django-app-dev
```

### Update Secrets

For production, use AWS Secrets Manager or External Secrets Operator:

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n kube-system

# Create SecretStore for AWS Secrets Manager
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: django-app-dev
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
EOF
```

### Scaling

#### Manual Scaling

```bash
# Scale backend
kubectl scale deployment/backend --replicas=5 -n django-app-dev

# Scale celery workers
kubectl scale deployment/celery-worker --replicas=4 -n django-app-dev
```

#### Auto-scaling (HPA)

HPA is already configured in deployment manifests:

```bash
# View HPA status
kubectl get hpa -n django-app-dev

# Describe HPA
kubectl describe hpa backend-hpa -n django-app-dev
```

## Maintenance

### Database Migrations

```bash
# Run migrations manually
kubectl exec -it deployment/backend -n django-app-dev -- python manage.py migrate

# Or apply migration job
kubectl delete job django-migrations -n django-app-dev  # Delete old job
kubectl apply -f k8s/jobs.yaml
```

### Collect Static Files

```bash
kubectl exec -it deployment/backend -n django-app-dev -- python manage.py collectstatic --noinput
```

### Database Backup

Backups run automatically via CronJob (daily at 2 AM):

```bash
# View backup cronjob
kubectl get cronjob -n django-app-dev

# Trigger manual backup
kubectl create job --from=cronjob/django-db-backup manual-backup-$(date +%Y%m%d) -n django-app-dev

# View backup jobs
kubectl get jobs -n django-app-dev
```

### Rolling Updates

```bash
# Update image
kubectl set image deployment/backend backend=your-registry/django-app:v2.0.0 -n django-app-dev

# Monitor rollout
kubectl rollout status deployment/backend -n django-app-dev

# Rollback if needed
kubectl rollout undo deployment/backend -n django-app-dev

# View rollout history
kubectl rollout history deployment/backend -n django-app-dev
```

## Storage

### Storage Classes

- **gp2**: AWS EBS (default for single-pod volumes)
- **efs-sc**: AWS EFS (required for multi-pod shared volumes like media files)

### EFS Setup (for Media Files)

```bash
# Install EFS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# Create EFS filesystem in AWS
aws efs create-file-system \
  --region us-east-1 \
  --performance-mode generalPurpose \
  --encrypted \
  --tags Key=Name,Value=django-app-efs

# Create storage class
kubectl apply -f - <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx  # Your EFS ID
  directoryPerms: "700"
EOF
```

## Monitoring

### Resource Usage

```bash
# Top pods
kubectl top pods -n django-app-dev

# Top nodes
kubectl top nodes

# Describe pod resources
kubectl describe pod <pod-name> -n django-app-dev
```

### Events

```bash
# View events
kubectl get events -n django-app-dev --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n django-app-dev --watch
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n django-app-dev

# View logs
kubectl logs <pod-name> -n django-app-dev --previous

# Check events
kubectl get events -n django-app-dev --field-selector involvedObject.name=<pod-name>
```

### Database Connection Issues

```bash
# Test database connectivity
kubectl run -it --rm debug --image=postgres:15.2-alpine --restart=Never -n django-app-dev -- psql -h postgres-service -U postgres -d django_app_db

# Check service endpoints
kubectl get endpoints postgres-service -n django-app-dev
```

### Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress django-ingress -n django-app-dev

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify DNS/hosts file
nslookup django-app.example.com
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n django-app-dev

# Describe PVC
kubectl describe pvc <pvc-name> -n django-app-dev

# Check storage classes
kubectl get storageclass
```

## Clean Up

### Delete Application

```bash
# Delete all resources in namespace
kubectl delete all --all -n django-app-dev

# Delete PVCs
kubectl delete pvc --all -n django-app-dev

# Delete namespace
kubectl delete namespace django-app-dev
```

### Delete Minikube Cluster

```bash
minikube delete
```

## Best Practices

1. **Resource Limits**: Always set resource requests and limits
2. **Health Checks**: Configure liveness and readiness probes
3. **Secrets Management**: Use external secret stores in production
4. **Persistent Storage**: Use appropriate storage classes
5. **Auto-scaling**: Configure HPA for production workloads
6. **Monitoring**: Enable Prometheus and Grafana
7. **Logging**: Configure centralized logging (ELK, Loki)
8. **Backups**: Automate database backups
9. **High Availability**: Run multiple replicas
10. **Security**: Use Network Policies, Pod Security Policies

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Django on Kubernetes](https://kubernetes.io/blog/2021/06/21/django-on-kubernetes/)
