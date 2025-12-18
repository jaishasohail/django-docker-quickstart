# Django Application - Production DevOps Stack

A complete production-ready DevOps implementation for a Django web application with Infrastructure as Code, container orchestration, CI/CD automation, and comprehensive monitoring.

## 🎯 Project Overview

This project demonstrates enterprise-grade DevOps practices including:

- **Containerization**: Multi-stage Docker builds with optimization
- **Infrastructure as Code**: Terraform for AWS provisioning
- **Configuration Management**: Ansible for automated deployment
- **Orchestration**: Kubernetes (EKS) with auto-scaling
- **CI/CD**: GitHub Actions with automated testing and deployment
- **Monitoring**: Prometheus and Grafana for observability
- **Security**: Vulnerability scanning, secrets management, and RBAC

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Documentation](#documentation)
- [Project Structure](#project-structure)
- [Contributing](#contributing)

---

## ✨ Features

### Application Stack

- **Django 4.2.1**: Modern Python web framework
- **PostgreSQL 15.2**: Relational database with replication
- **Redis 7.0**: Caching and message broker
- **Celery 5.2.7**: Distributed task queue
- **Gunicorn**: WSGI HTTP server
- **Nginx**: Reverse proxy and static file serving

### Infrastructure

- **AWS EKS**: Managed Kubernetes cluster
- **RDS PostgreSQL**: Managed database with Multi-AZ
- **ElastiCache Redis**: Managed cache with failover
- **S3**: Object storage for static files and backups
- **VPC**: Network isolation with public/private subnets
- **ALB**: Application load balancing with SSL

### DevOps Tools

- **Terraform**: Infrastructure provisioning
- **Ansible**: Configuration management
- **Helm**: Kubernetes package management
- **Docker**: Containerization
- **GitHub Actions**: CI/CD pipelines

### Monitoring & Observability

- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Node Exporter**: System metrics
- **Alertmanager**: Alert routing
- **CloudWatch**: Log aggregation

### Security

- **Trivy**: Container vulnerability scanning
- **Bandit**: Python security linting
- **AWS Secrets Manager**: Secrets storage
- **RBAC**: Role-based access control
- **Network Policies**: Pod-to-pod security

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Internet/Users                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│          Application Load Balancer (ALB)            │
│                  SSL/TLS Termination                 │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│               AWS VPC (10.0.0.0/16)                  │
│  ┌───────────────────────────────────────────────┐  │
│  │     Amazon EKS Cluster (Kubernetes 1.28)      │  │
│  │                                                │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │ Backend  │  │  Celery  │  │  Redis   │   │  │
│  │  │  Pods    │  │ Workers  │  │   Pod    │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘   │  │
│  │                                                │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │Prometheus│  │ Grafana  │  │ Postgres │   │  │
│  │  │(Monitor) │  │(Dashboard│  │StatefulSet   │  │
│  │  └──────────┘  └──────────┘  └──────────┘   │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  ┌──────────────────┐      ┌──────────────────┐   │
│  │  RDS PostgreSQL  │      │ElastiCache Redis │   │
│  │    (Multi-AZ)    │      │    (Multi-AZ)    │   │
│  └──────────────────┘      └──────────────────┘   │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│    S3 Buckets (Static, Media, Backups)              │
└─────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### Required Software

- **Docker** 24.0+ & **Docker Compose** 2.0+
- **Python** 3.11+
- **Terraform** 1.6+
- **Ansible** 2.10+
- **kubectl** 1.28+
- **AWS CLI** 2.0+
- **Git**

### AWS Requirements

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- EC2 key pair for SSH access
- Domain name (optional, for SSL)

### Local Development

- 8GB+ RAM
- 20GB+ free disk space
- Minikube or Docker Desktop (for local Kubernetes)

---

## 🚀 Quick Start

### Option 1: Local Development (Docker Compose)

1. **Clone the repository:**

   ```bash
   git clone <your-repo-url>
   cd django-docker-quickstart
   ```

2. **Configure environment:**

   ```bash
   cp env.example .env
   # Edit .env with your settings
   ```

3. **Start services:**

   ```bash
   docker-compose up -d
   ```

4. **Run migrations:**

   ```bash
   docker-compose exec backend python manage.py migrate
   docker-compose exec backend python manage.py createsuperuser
   ```

5. **Access application:**
   - Application: http://localhost:8000
   - Admin: http://localhost:8000/admin

### Option 2: Minikube (Local Kubernetes)

1. **Start Minikube:**

   ```bash
   minikube start --cpus=4 --memory=8192
   minikube addons enable ingress
   minikube addons enable metrics-server
   ```

2. **Deploy application:**

   ```bash
   kubectl apply -f k8s/
   ```

3. **Access application:**
   ```bash
   minikube service backend-service -n django-app-dev
   ```

See [k8s/README.md](k8s/README.md) for detailed Kubernetes deployment instructions.

### Option 3: AWS EKS (Production)

1. **Configure AWS:**

   ```bash
   aws configure
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars
   ```

2. **Provision infrastructure:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configure kubectl:**

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name django-app-dev
   ```

4. **Deploy with Ansible:**

   ```bash
   cd ../ansible
   ansible-playbook deploy.yml --ask-vault-pass
   ```

5. **Verify deployment:**
   ```bash
   kubectl get all -n django-app-dev
   ```

See [infra/README.md](infra/README.md) and [ansible/README.md](ansible/README.md) for detailed instructions.

---

## 📚 Documentation

### Core Documentation

- **[DevOps Report](devops_report.md)**: Complete project documentation
- **[Infrastructure (Terraform)](infra/README.md)**: AWS infrastructure provisioning
- **[Configuration Management (Ansible)](ansible/README.md)**: Deployment automation
- **[Kubernetes Deployment](k8s/README.md)**: Kubernetes manifests and deployment
- **[Monitoring](monitoring/README.md)**: Prometheus and Grafana setup

### Quick Reference

- **[Project Structure](#project-structure)**: Directory organization
- **[Common Commands](#common-commands)**: Frequently used commands
- **[Troubleshooting](#troubleshooting)**: Common issues and solutions
- **[Contributing](#contributing)**: Contribution guidelines

---

## 📁 Project Structure

```
django-docker-quickstart/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml              # Main CI/CD pipeline
│       └── destroy-infra.yml      # Infrastructure teardown
│
├── ansible/                        # Configuration management
│   ├── deploy.yml                 # Main deployment playbook
│   ├── configure_nodes.yml        # Node configuration
│   ├── inventory/                 # Inventory files
│   ├── roles/                     # Ansible roles
│   ├── vars/                      # Variables and secrets
│   └── README.md
│
├── deployment/
│   ├── Dockerfile                 # Optimized multi-stage build
│   └── scripts/
│       ├── backend/start.sh
│       ├── celery/start-worker.sh
│       └── celery/start-beat.sh
│
├── infra/                         # Terraform infrastructure
│   ├── provider.tf                # AWS provider configuration
│   ├── variables.tf               # Input variables
│   ├── vpc.tf                     # VPC and networking
│   ├── eks.tf                     # EKS cluster
│   ├── rds.tf                     # PostgreSQL database
│   ├── elasticache.tf             # Redis cache
│   ├── s3.tf                      # S3 buckets
│   ├── security_groups.tf         # Security groups
│   ├── outputs.tf                 # Output values
│   ├── policies/                  # IAM policies
│   └── README.md
│
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Namespaces
│   ├── configmap.yaml             # Configuration
│   ├── secret.yaml                # Secrets
│   ├── postgres-deployment.yaml   # Database
│   ├── redis-deployment.yaml      # Cache
│   ├── backend-deployment.yaml    # Application
│   ├── celery-deployment.yaml     # Task queue
│   ├── ingress.yaml               # Ingress rules
│   ├── jobs.yaml                  # Jobs and CronJobs
│   └── README.md
│
├── monitoring/                    # Monitoring stack
│   ├── prometheus-deployment.yaml # Prometheus
│   ├── grafana-deployment.yaml    # Grafana
│   ├── grafana-dashboards.yaml    # Pre-configured dashboards
│   ├── node-exporter.yaml         # System metrics
│   ├── install.sh                 # Installation script
│   └── README.md
│
├── src/                           # Django application
│   ├── manage.py
│   ├── requirements.txt
│   ├── requirements.dev.txt
│   ├── project_name/              # Django project
│   │   ├── settings/
│   │   ├── celery.py
│   │   └── urls.py
│   ├── test_app/                  # Sample app
│   └── tests/
│
├── docker-compose.yml             # Development environment
├── docker-compose.prod.yml        # Production environment
├── env.example                    # Environment variables template
├── devops_report.md               # Comprehensive project report
├── Makefile                       # Convenience commands
└── README.md                      # This file
```

---

## 🔧 Common Commands

### Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backend

# Run migrations
docker-compose exec backend python manage.py migrate

# Create superuser
docker-compose exec backend python manage.py createsuperuser

# Run tests
docker-compose exec backend pytest

# Stop all services
docker-compose down

# Clean up volumes
docker-compose down -v
```

### Kubernetes

```bash
# View all resources
kubectl get all -n django-app-dev

# View pods
kubectl get pods -n django-app-dev

# View logs
kubectl logs -f deployment/backend -n django-app-dev

# Execute command in pod
kubectl exec -it deployment/backend -n django-app-dev -- bash

# Port forward
kubectl port-forward svc/backend-service 8000:8000 -n django-app-dev

# Restart deployment
kubectl rollout restart deployment/backend -n django-app-dev

# Scale deployment
kubectl scale deployment/backend --replicas=3 -n django-app-dev
```

### Terraform

```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy infrastructure
terraform destroy
```

### Ansible

```bash
# Run playbook
ansible-playbook deploy.yml --ask-vault-pass

# Check syntax
ansible-playbook deploy.yml --syntax-check

# Dry run
ansible-playbook deploy.yml --check

# Specific tags
ansible-playbook deploy.yml --tags "secrets,configmap"
```

---

## 🐛 Troubleshooting

### Docker Issues

**Problem**: Permission denied when running Docker commands  
**Solution**:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Problem**: Port already in use  
**Solution**:

```bash
# Find and kill process using port 8000
lsof -ti:8000 | xargs kill -9
```

### Kubernetes Issues

**Problem**: Pods not starting  
**Solution**:

```bash
kubectl describe pod <pod-name> -n django-app-dev
kubectl logs <pod-name> -n django-app-dev
```

**Problem**: Cannot connect to cluster  
**Solution**:

```bash
aws eks update-kubeconfig --region us-east-1 --name django-app-dev
kubectl cluster-info
```

### Database Issues

**Problem**: Connection refused to PostgreSQL  
**Solution**:

```bash
# Check if database service is running
kubectl get svc postgres-service -n django-app-dev

# Check database logs
kubectl logs statefulset/postgres -n django-app-dev
```

For more troubleshooting guides, see individual README files in each directory.

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Workflow

1. Set up local environment (see Quick Start)
2. Make changes
3. Run tests: `docker-compose exec backend pytest`
4. Run linting: `docker-compose exec backend flake8`
5. Format code: `docker-compose exec backend black .`
6. Commit and push

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

**DevOps Engineers**: Infrastructure, CI/CD, and deployment automation  
**Backend Developers**: Django application development  
**SRE Team**: Monitoring, alerting, and reliability

---

## 📞 Support

- **Issues**: Open an issue on GitHub
- **Email**: devops@example.com
- **Documentation**: See [devops_report.md](devops_report.md)

---

## 🎓 Learning Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Django Documentation](https://docs.djangoproject.com/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

## 🙏 Acknowledgments

- Django community for the amazing framework
- HashiCorp for Terraform
- Red Hat for Ansible
- Kubernetes community
- AWS for cloud infrastructure
- Open source monitoring tools (Prometheus, Grafana)

---

**Last Updated**: December 2025  
**Project Status**: Production Ready  
**Documentation Version**: 1.0
docker-compose up -d
```

4. **Run migrations:**

   ```bash
   docker-compose exec backend python manage.py migrate
   docker-compose exec backend python manage.py createsuperuser
   ```

5. **Access application:**
   - Application: http://localhost:8000
   - Admin: http://localhost:8000/admin
   - **For Windows (Command Prompt):**
     ```cmd
      Copy-Item -Path env.example -Destination .env
     ```

---

## Initial Setup ⚙️

### Development Prerequisites

1. **Create a virtual environment:**

   ```bash
   python -m venv venv
   ```

2. **Activate the virtual environment:**

   ```bash
   source venv/bin/activate
   ```

3. **(Optional) Install the development requirements specific to your IDE for enhanced functionality and support.**

   ```bash
   pip install -r src/requirements.dev.txt
   ```

4. **Build the image and run the container:**

   - If buildkit is not enabled, enable it and build the image:

     ```bash
     DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.yml up --build -d
     ```

   - If buildkit is enabled, build the image:

     ```bash
     docker-compose -f docker-compose.yml up --build -d
     ```

   - Or, use the shortcut:
     ```bash
     make build-dev
     ```

You can now access the application at http://localhost:8000. The development environment allows for immediate reflection of code changes.

### Production Setup

1. **Build the image and run the container:**

   - If buildkit is not enabled, enable it and build the image:

     ```bash
       DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.prod.yml up --build -d
     ```

   - If buildkit is enabled, build the image:
     ```bash
      docker-compose -f docker-compose.prod.yml up --build -d
     ```
   - Or, use the shortcut:
     ```bash
       make build-prod
     ```

---

## Shortcuts 🔑

This project includes several shortcuts to streamline the development process:

- **Create migrations:**

  ```bash
  make make-migrations
  ```

- **Run migrations:**

  ```bash
  make migrate
  ```

- **Run the linter:**

  ```bash
  make lint
  ```

- **Run the formatter:**

  ```bash
  make format
  ```

- **Run the tests:**

  ```bash
  make test
  ```

- **Create a super user:**

  ```bash
  make super-user
  ```

- **Build and run dev environment:**

  ```bash
  make build-dev
  ```

- **Build and run prod environment:**
  ```bash
  make build-prod
  ```

---
