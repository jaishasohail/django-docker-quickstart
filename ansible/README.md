# Ansible Automation

This directory contains Ansible playbooks and roles for automating the deployment and configuration of the Django application on Kubernetes.

## Prerequisites

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.10
- [Python](https://www.python.org/downloads/) >= 3.8
- AWS CLI configured with appropriate credentials
- kubectl configured for your EKS cluster

### Install Required Ansible Collections

```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.general
```

### Install Python Dependencies

```bash
pip install boto3 botocore kubernetes openshift
```

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── deploy.yml                  # Main deployment playbook
├── configure_nodes.yml         # Node configuration playbook
├── inventory/
│   ├── hosts.ini              # Static inventory
│   └── aws_ec2.yml            # Dynamic AWS inventory
├── vars/
│   ├── common.yml             # Common variables
│   └── secrets.yml            # Encrypted secrets (use ansible-vault)
└── roles/
    ├── kubectl/               # Install kubectl
    ├── helm/                  # Install Helm
    ├── k8s_secrets/           # Deploy Kubernetes secrets
    ├── k8s_configmaps/        # Deploy ConfigMaps
    └── ...                    # Other roles
```

## Configuration

### 1. Configure Variables

Edit `vars/common.yml` with your environment-specific values:

```yaml
app_name: django-app
environment: dev
aws_region: us-east-1
eks_cluster_name: django-app-dev
```

### 2. Encrypt Secrets

Use Ansible Vault to encrypt sensitive data:

```bash
# Create encrypted secrets file
ansible-vault create vars/secrets.yml

# Or encrypt existing file
ansible-vault encrypt vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml
```

Add your secrets to `vars/secrets.yml`:

```yaml
django_secret_key: "your-secret-key"
db_password: "your-db-password"
```

### 3. Configure Inventory

#### Option A: Static Inventory

Edit `inventory/hosts.ini` with your EC2 instance IPs:

```ini
[eks_nodes]
10.0.1.10
10.0.1.11

[eks_nodes:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/.ssh/your-key.pem
```

#### Option B: Dynamic AWS Inventory

Use the AWS EC2 dynamic inventory plugin:

```bash
# Test dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --list

# Use with playbook
ansible-playbook -i inventory/aws_ec2.yml configure_nodes.yml
```

## Playbooks

### 1. Deploy Application to Kubernetes

Deploys the Django application, database, Redis, and Celery to Kubernetes:

```bash
# Deploy with vault password prompt
ansible-playbook deploy.yml --ask-vault-pass

# Deploy with vault password file
ansible-playbook deploy.yml --vault-password-file ~/.vault_pass

# Deploy with specific variables
ansible-playbook deploy.yml --ask-vault-pass -e "environment=prod"

# Dry run (check mode)
ansible-playbook deploy.yml --ask-vault-pass --check
```

This playbook:

- Configures kubectl for EKS
- Creates Kubernetes namespaces
- Deploys secrets and ConfigMaps
- Deploys all application components
- Runs database migrations
- Collects static files
- Creates Django superuser

### 2. Configure EKS Nodes

Configures EKS worker nodes with required packages and optimizations:

```bash
# Using static inventory
ansible-playbook -i inventory/hosts.ini configure_nodes.yml

# Using dynamic inventory
ansible-playbook -i inventory/aws_ec2.yml configure_nodes.yml

# Specific hosts
ansible-playbook -i inventory/hosts.ini configure_nodes.yml --limit eks_nodes
```

This playbook:

- Updates system packages
- Installs required tools (Docker, kubectl, AWS CLI)
- Configures kernel parameters
- Sets up log rotation
- Installs monitoring agents

## Common Tasks

### Verify Cluster Connectivity

```bash
ansible localhost -m shell -a "kubectl cluster-info"
```

### Check Deployment Status

```bash
ansible-playbook deploy.yml --ask-vault-pass --tags verify
```

### Update Application Configuration

```bash
# Edit variables
vim vars/common.yml

# Apply changes
ansible-playbook deploy.yml --ask-vault-pass --tags configmap
```

### Run Database Migrations

```bash
ansible-playbook deploy.yml --ask-vault-pass --tags migrations
```

### Scale Deployments

Edit `vars/common.yml`:

```yaml
replicas_backend: 3
replicas_celery_worker: 3
```

Then apply:

```bash
ansible-playbook deploy.yml --ask-vault-pass --tags scale
```

## Roles

### kubectl Role

Installs kubectl on target hosts.

```bash
ansible-playbook -i inventory/hosts.ini configure_nodes.yml --tags kubectl
```

### helm Role

Installs Helm 3 on target hosts.

```bash
ansible-playbook -i inventory/hosts.ini configure_nodes.yml --tags helm
```

### k8s_secrets Role

Creates Kubernetes secrets for the application.

Variables:

- `django_secret_key`: Django SECRET_KEY
- `db_password`: Database password
- `redis_password`: Redis password (optional)

### k8s_configmaps Role

Creates ConfigMaps with application configuration.

Variables defined in `vars/common.yml`.

## AWS Dynamic Inventory

The AWS EC2 dynamic inventory automatically discovers EKS nodes based on tags.

### Configure AWS Credentials

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1

# Or use AWS profiles
export AWS_PROFILE=your_profile
```

### List Discovered Hosts

```bash
ansible-inventory -i inventory/aws_ec2.yml --graph
```

### Test Connectivity

```bash
ansible -i inventory/aws_ec2.yml all -m ping
```

## Tags

Use tags to run specific parts of playbooks:

```bash
# Available tags
ansible-playbook deploy.yml --list-tags

# Run specific tags
ansible-playbook deploy.yml --ask-vault-pass --tags "secrets,configmap"

# Skip specific tags
ansible-playbook deploy.yml --ask-vault-pass --skip-tags "migrations"
```

## Troubleshooting

### Cannot Connect to Hosts

Check SSH connectivity:

```bash
ansible -i inventory/hosts.ini all -m ping
```

Verify SSH key:

```bash
ssh -i ~/.ssh/your-key.pem ec2-user@<instance-ip>
```

### Kubectl Configuration Issues

Manually configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name django-app-dev
kubectl cluster-info
```

### Vault Password Issues

Save vault password to file:

```bash
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

ansible-playbook deploy.yml --vault-password-file ~/.vault_pass
```

### AWS Credentials

Verify AWS credentials:

```bash
aws sts get-caller-identity
aws eks describe-cluster --name django-app-dev --region us-east-1
```

### Playbook Fails Midway

Resume from specific task:

```bash
ansible-playbook deploy.yml --ask-vault-pass --start-at-task="Task Name"
```

## Best Practices

### 1. Use Ansible Vault

Always encrypt sensitive data:

```bash
ansible-vault encrypt vars/secrets.yml
ansible-vault encrypt inventory/hosts.ini
```

### 2. Use Dynamic Inventory

Prefer AWS EC2 dynamic inventory over static inventory for auto-scaling environments.

### 3. Idempotency

All playbooks are designed to be idempotent - safe to run multiple times.

### 4. Testing

Test playbooks in check mode first:

```bash
ansible-playbook deploy.yml --ask-vault-pass --check --diff
```

### 5. Version Control

- Commit playbooks and roles to version control
- DO NOT commit unencrypted secrets
- Use `.gitignore` for sensitive files

### 6. Documentation

Document custom variables and their purposes in playbooks.

## Advanced Usage

### Run Specific Role

```bash
ansible localhost -m include_role -a name=kubectl
```

### Override Variables

```bash
ansible-playbook deploy.yml --ask-vault-pass \
  -e "app_namespace=staging" \
  -e "replicas_backend=4"
```

### Limit to Specific Hosts

```bash
ansible-playbook configure_nodes.yml -i inventory/hosts.ini \
  --limit "10.0.1.10,10.0.1.11"
```

### Parallel Execution

```bash
ansible-playbook configure_nodes.yml -f 20  # 20 parallel forks
```

## Integration with CI/CD

### Jenkins

```groovy
stage('Deploy with Ansible') {
    steps {
        withCredentials([file(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
            sh '''
                ansible-playbook ansible/deploy.yml \
                  --vault-password-file $VAULT_PASS \
                  -e "environment=${ENV}"
            '''
        }
    }
}
```

### GitHub Actions

```yaml
- name: Deploy with Ansible
  run: |
    echo "${{ secrets.VAULT_PASSWORD }}" > .vault_pass
    ansible-playbook ansible/deploy.yml \
      --vault-password-file .vault_pass
```

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Collection](https://galaxy.ansible.com/kubernetes/core)
- [AWS Collection](https://galaxy.ansible.com/amazon/aws)
- [Ansible Vault Guide](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
