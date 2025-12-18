# Step-by-Step Deployment Guide

This guide provides detailed, step-by-step instructions for deploying the Django application to production on AWS EKS.

## Table of Contents

1. [Prerequisites Setup](#1-prerequisites-setup)
2. [AWS Account Configuration](#2-aws-account-configuration)
3. [Infrastructure Provisioning](#3-infrastructure-provisioning)
4. [Container Registry Setup](#4-container-registry-setup)
5. [Build and Push Docker Images](#5-build-and-push-docker-images)
6. [Kubernetes Deployment](#6-kubernetes-deployment)
7. [Monitoring Setup](#7-monitoring-setup)
8. [CI/CD Pipeline Configuration](#8-cicd-pipeline-configuration)
9. [DNS and SSL Configuration](#9-dns-and-ssl-configuration)
10. [Verification and Testing](#10-verification-and-testing)
11. [Post-Deployment Tasks](#11-post-deployment-tasks)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites Setup

### Install Required Tools

#### 1.1 AWS CLI

**Linux/macOS:**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

**Windows (PowerShell):**

```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
aws --version
```

#### 1.2 Terraform

**Linux:**

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version
```

**macOS:**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

**Windows:**

```powershell
choco install terraform
terraform version
```

#### 1.3 kubectl

**Linux:**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

**macOS:**

```bash
brew install kubectl
kubectl version --client
```

**Windows (PowerShell - Run as Administrator):**

Option 1 - Using Chocolatey (Recommended):

```powershell
choco install kubernetes-cli
kubectl version --client
```

Option 2 - Manual Download:

```powershell
# Download kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Move to a directory in your PATH (e.g., C:\Program Files\kubectl\)
New-Item -Path "C:\Program Files\kubectl" -ItemType Directory -Force
Move-Item -Path .\kubectl.exe -Destination "C:\Program Files\kubectl\kubectl.exe" -Force

# Add to PATH (permanent)
$oldPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$newPath = $oldPath + ";C:\Program Files\kubectl"
[Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')

# Refresh current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify installation
kubectl version --client
```

Option 3 - Using winget:

```powershell
winget install -e --id Kubernetes.kubectl
kubectl version --client
```

#### 1.4 Ansible

```bash
pip install ansible boto3 botocore kubernetes openshift
ansible --version
```

#### 1.5 Docker

Follow official Docker installation guide for your OS:

- [Docker for Linux](https://docs.docker.com/engine/install/)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)

---

## 2. AWS Account Configuration

### 2.1 Create AWS Account

If you don't have an AWS account:

1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. Complete billing information
5. Verify your identity

### 2.2 Create IAM User

1. Log into AWS Console
2. Go to IAM → Users → Add User
3. User name: `terraform-user`
4. Access type: Programmatic access
5. Attach policies:
   - AdministratorAccess (for initial setup)
   - Or create custom policy with required permissions
6. Save access key ID and secret access key

### 2.3 Configure AWS CLI

```bash
aws configure

# Enter when prompted:
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region: us-east-1
# Default output format: json
```

Verify configuration:

```bash
aws sts get-caller-identity
```

### 2.4 Create EC2 Key Pair

```bash
aws ec2 create-key-pair \
  --key-name django-app-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/django-app-key.pem

chmod 400 ~/.ssh/django-app-key.pem
```

---

## 3. Infrastructure Provisioning

### 3.1 Prepare Terraform Configuration

```bash
cd infra

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit variables (use your favorite editor)
vim terraform.tfvars
```

Update these values in `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
project_name = "django-app"
environment = "dev"

# Database
db_username = "dbadmin"
db_password = "CHANGE-ME-SECURE-PASSWORD"  # Use strong password!

# EKS
eks_desired_size = 2
eks_min_size = 1
eks_max_size = 4
```

### 3.2 Configure Terraform Backend (Optional but Recommended)

Create S3 bucket for state:

```bash
aws s3api create-bucket \
  --bucket my-terraform-state-django-app \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket my-terraform-state-django-app \
  --versioning-configuration Status=Enabled
```

Create DynamoDB table for state locking:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

Update `provider.tf`:

```hcl
backend "s3" {
  bucket         = "my-terraform-state-django-app"
  key            = "django-app/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### 3.3 Initialize Terraform

```bash
terraform init
```

Expected output:

```
Terraform has been successfully initialized!
```

### 3.4 Validate Configuration

```bash
terraform validate
```

### 3.5 Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see resources to be created:

- VPC and subnets
- EKS cluster
- RDS instance
- ElastiCache cluster
- S3 buckets
- Security groups
- IAM roles

### 3.6 Apply Infrastructure

```bash
terraform apply tfplan
```

This will take 15-20 minutes. Output will show:

```
Apply complete! Resources: 50+ added, 0 changed, 0 destroyed.
```

### 3.7 Save Terraform Outputs

```bash
terraform output > ../outputs.txt
terraform output -json > ../outputs.json
```

---

## 4. Container Registry Setup

### 4.1 Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name django-app \
  --region us-east-1
```

### 4.2 Get ECR Login

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

Replace `<account-id>` with your AWS account ID.

---

## 5. Build and Push Docker Images

### 5.1 Build Docker Image

```bash
cd ..  # Back to project root

docker build -t django-app:latest -f deployment/Dockerfile .
```

### 5.2 Tag Image

```bash
docker tag django-app:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-app:latest
```

### 5.3 Push to ECR

```bash
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-app:latest
```

---

## 6. Kubernetes Deployment

### 6.1 Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name django-app-dev
```

Verify:

```bash
kubectl cluster-info
kubectl get nodes
```

### 6.2 Create Namespaces

```bash
kubectl apply -f k8s/namespace.yaml
```

Verify:

```bash
kubectl get namespaces
```

### 6.3 Update Kubernetes Manifests

Update image references in `k8s/*.yaml`:

```bash
# Replace placeholder with your ECR URL
ECR_URL="<account-id>.dkr.ecr.us-east-1.amazonaws.com"
sed -i "s|your-registry/django-app:latest|$ECR_URL/django-app:latest|g" k8s/*.yaml
```

### 6.4 Create Secrets

```bash
# Create Django secret
kubectl create secret generic django-secrets \
  --from-literal=SECRET_KEY='your-super-secret-key-change-in-production' \
  -n django-app-dev

# Create database credentials
kubectl create secret generic postgres-credentials \
  --from-literal=POSTGRES_USER='postgres' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=POSTGRES_DB='django_app_db' \
  -n django-app-dev
```

Or apply secret file:

```bash
kubectl apply -f k8s/secret.yaml
```

### 6.5 Deploy ConfigMap

```bash
kubectl apply -f k8s/configmap.yaml
```

### 6.6 Deploy Database and Redis

```bash
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/redis-deployment.yaml
```

Wait for pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=postgres -n django-app-dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n django-app-dev --timeout=300s
```

### 6.7 Run Database Migrations

```bash
kubectl apply -f k8s/jobs.yaml
```

Wait for migration job:

```bash
kubectl wait --for=condition=complete job/django-migrations -n django-app-dev --timeout=300s
```

Check migration logs:

```bash
kubectl logs job/django-migrations -n django-app-dev
```

### 6.8 Deploy Application

```bash
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/celery-deployment.yaml
```

### 6.9 Deploy Ingress

First, install nginx-ingress controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

Then deploy application ingress:

```bash
kubectl apply -f k8s/ingress.yaml
```

### 6.10 Verify Deployments

```bash
# Check all resources
kubectl get all -n django-app-dev

# Check pods
kubectl get pods -n django-app-dev

# Check services
kubectl get svc -n django-app-dev

# Check ingress
kubectl get ingress -n django-app-dev
```

All pods should show STATUS: Running.

---

## 7. Monitoring Setup

### 7.1 Deploy Prometheus

```bash
cd monitoring
kubectl apply -f prometheus-deployment.yaml
```

### 7.2 Deploy Grafana

```bash
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-dashboards.yaml
```

### 7.3 Deploy Node Exporter

```bash
kubectl apply -f node-exporter.yaml
```

### 7.4 Verify Monitoring

```bash
kubectl get all -n monitoring
```

### 7.5 Access Grafana

Port forward:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Open http://localhost:3000

- Username: admin
- Password: admin (change immediately!)

### 7.6 Access Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Open http://localhost:9090

---

## 8. CI/CD Pipeline Configuration

### 8.1 Configure GitHub Secrets

Go to GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `DB_PASSWORD`: Database password
- `ANSIBLE_VAULT_PASSWORD`: Vault password (if using Ansible)
- `SLACK_WEBHOOK_URL`: (Optional) For notifications

### 8.2 Update Workflow Files

The workflows are already configured in `.github/workflows/`.

Review and update if needed:

- `.github/workflows/ci-cd.yml`
- `.github/workflows/destroy-infra.yml`

### 8.3 Test Pipeline

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

Monitor the pipeline in GitHub Actions tab.

---

## 9. DNS and SSL Configuration

### 9.1 Get Load Balancer URL

```bash
kubectl get ingress django-ingress -n django-app-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 9.2 Configure DNS

In your DNS provider (Route 53, Cloudflare, etc.):

1. Create A or CNAME record
2. Point to load balancer URL
3. Example: `app.example.com` → `<alb-url>.us-east-1.elb.amazonaws.com`

### 9.3 Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 9.4 Create ClusterIssuer

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 9.5 Update Ingress for SSL

The ingress configuration already includes TLS. Just update the host in `k8s/ingress.yaml`:

```yaml
spec:
  tls:
    - hosts:
        - app.example.com # Your domain
      secretName: django-tls-cert
  rules:
    - host: app.example.com # Your domain
```

Apply:

```bash
kubectl apply -f k8s/ingress.yaml
```

---

## 10. Verification and Testing

### 10.1 Health Checks

```bash
# Check pod health
kubectl get pods -n django-app-dev

# Check services
kubectl get svc -n django-app-dev

# Check ingress
kubectl describe ingress django-ingress -n django-app-dev
```

### 10.2 Application Tests

```bash
# Test database connectivity
kubectl exec -n django-app-dev deployment/backend -- python manage.py check --database default

# Test Redis connectivity
kubectl exec -n django-app-dev deployment/redis -- redis-cli ping

# Test Celery workers
kubectl exec -n django-app-dev deployment/celery-worker -- celery -A project_name inspect ping
```

### 10.3 Access Application

Using port-forward:

```bash
kubectl port-forward -n django-app-dev svc/backend-service 8000:8000
```

Open http://localhost:8000

Or access via ingress:

```bash
# Get ingress URL
kubectl get ingress -n django-app-dev
```

### 10.4 Create Admin User

```bash
kubectl exec -it -n django-app-dev deployment/backend -- python manage.py createsuperuser
```

Follow prompts to create admin user.

### 10.5 Load Testing (Optional)

```bash
# Install k6
brew install k6  # macOS
# or download from https://k6.io/

# Run load test
k6 run - <<EOF
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let res = http.get('http://your-app-url/');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
EOF
```

---

## 11. Post-Deployment Tasks

### 11.1 Configure Backups

Database backups are configured via CronJob in `k8s/jobs.yaml`.

Verify:

```bash
kubectl get cronjob -n django-app-dev
```

### 11.2 Set Up Alerts

Configure alert notifications in Alertmanager:

```bash
kubectl edit configmap alertmanager-config -n monitoring
```

### 11.3 Configure Log Aggregation

Set up CloudWatch Logs Insights or ELK stack for log aggregation.

### 11.4 Security Hardening

- [ ] Change default passwords
- [ ] Enable MFA for AWS
- [ ] Review security group rules
- [ ] Enable GuardDuty
- [ ] Configure AWS Config
- [ ] Enable CloudTrail

### 11.5 Cost Monitoring

Set up AWS Cost Explorer and billing alerts:

```bash
aws ce create-cost-category-definition \
  --name "Django-App" \
  --rules file://cost-rules.json
```

### 11.6 Documentation

Update internal documentation with:

- Access URLs
- Credentials (securely stored)
- Runbooks for common tasks
- Incident response procedures

---

## 12. Troubleshooting

### Issue: Pods in CrashLoopBackOff

**Diagnosis:**

```bash
kubectl describe pod <pod-name> -n django-app-dev
kubectl logs <pod-name> -n django-app-dev
kubectl logs <pod-name> -n django-app-dev --previous
```

**Common causes:**

- Missing environment variables
- Database connection issues
- Image pull errors

### Issue: Can't Access Application

**Check ingress:**

```bash
kubectl describe ingress django-ingress -n django-app-dev
```

**Check nginx-ingress logs:**

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Issue: High Memory Usage

**Check resource usage:**

```bash
kubectl top pods -n django-app-dev
kubectl top nodes
```

**Adjust resource limits:**
Edit deployment and increase memory limits.

### Issue: Database Connection Timeout

**Verify database:**

```bash
kubectl exec -it -n django-app-dev deployment/backend -- \
  psql -h postgres-service -U postgres -d django_app_db
```

**Check security groups:**
Ensure security groups allow traffic between EKS nodes and RDS.

### Issue: Terraform State Locked

```bash
terraform force-unlock <lock-id>
```

Use with caution!

---

## Next Steps

After successful deployment:

1. ✅ **Monitor Application**: Watch Grafana dashboards
2. ✅ **Review Logs**: Check CloudWatch or kubectl logs
3. ✅ **Run Tests**: Execute smoke tests
4. ✅ **Update Documentation**: Document any changes
5. ✅ **Train Team**: Conduct knowledge transfer
6. ✅ **Plan Rollback**: Test rollback procedures
7. ✅ **Optimize Costs**: Review and optimize AWS costs
8. ✅ **Security Audit**: Conduct security review
9. ✅ **Performance Tuning**: Optimize application performance
10. ✅ **Disaster Recovery**: Test DR procedures

---

## Support

If you encounter issues:

1. Check this troubleshooting section
2. Review logs: `kubectl logs <pod-name> -n django-app-dev`
3. Check documentation in individual README files
4. Open an issue on GitHub
5. Contact DevOps team

---

**Congratulations! Your Django application is now running in production on AWS EKS! 🎉**
