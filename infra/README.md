# Terraform Infrastructure

This directory contains Infrastructure as Code (IaC) for provisioning AWS resources for the Django application.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS account with necessary permissions

## Infrastructure Components

- **VPC**: Virtual Private Cloud with public, private, and database subnets across 3 availability zones
- **EKS**: Managed Kubernetes cluster with autoscaling node groups
- **RDS**: PostgreSQL database with automated backups
- **ElastiCache**: Redis cluster for caching and message queuing
- **S3**: Buckets for static files, media files, and backups
- **Security Groups**: Network security configurations for all components
- **IAM Roles**: Service roles for EKS, ALB Controller, and EBS CSI Driver

## Getting Started

### 1. Configure Variables

Copy the example tfvars file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

- AWS region
- Project name and environment
- Database credentials (use strong passwords!)
- Cluster sizing

### 2. Configure Backend (Optional but Recommended)

Create an S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
    --bucket your-terraform-state-bucket \
    --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1
```

Update the backend configuration in `provider.tf` with your bucket name.

### 3. Initialize Terraform

```bash
cd infra
terraform init
```

### 4. Plan Infrastructure

Review the resources that will be created:

```bash
terraform plan
```

### 5. Apply Infrastructure

Create the infrastructure:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

**Note**: Provisioning takes 15-20 minutes, primarily for EKS cluster creation.

### 6. Configure kubectl

After successful deployment, configure kubectl to access your EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name django-app-dev
```

Verify access:

```bash
kubectl get nodes
```

### 7. View Outputs

Display important resource information:

```bash
terraform output
```

Save sensitive outputs:

```bash
terraform output -json > outputs.json
```

## Cost Estimation

Estimated monthly costs for dev environment (us-east-1):

- **EKS Cluster**: $73/month
- **EC2 Instances (2x t3.medium)**: ~$60/month
- **RDS (db.t3.micro)**: ~$15/month
- **ElastiCache (2x cache.t3.micro)**: ~$25/month
- **NAT Gateway**: ~$32/month
- **Data Transfer & Storage**: Variable

**Total**: ~$205/month (excluding data transfer and storage)

## Infrastructure Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including databases. Ensure you have backups!

## Important Notes

### Security Best Practices

1. **Secrets Management**: Store sensitive values in AWS Secrets Manager (already configured)
2. **Database Passwords**: Never commit passwords to version control
3. **IAM Permissions**: Follow principle of least privilege
4. **Network Security**: Resources in private subnets, access controlled via security groups
5. **Encryption**: Enabled for RDS, ElastiCache, and S3

### Backup Strategy

- **RDS**: Automated daily backups with 7-day retention
- **S3**: Versioning enabled on all buckets
- **Backup bucket**: 30-day lifecycle policy

### High Availability

- Multi-AZ deployment for RDS and ElastiCache
- EKS nodes distributed across 3 availability zones
- Auto-scaling enabled for EKS node groups

## Troubleshooting

### EKS Cluster Access Issues

If you can't access the cluster:

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name django-app-dev

# Check cluster status
aws eks describe-cluster --name django-app-dev --region us-east-1
```

### RDS Connection Issues

Check security group rules:

```bash
aws ec2 describe-security-groups --group-ids <rds-security-group-id>
```

### State Lock Issues

If state is locked:

```bash
# Force unlock (use with caution!)
terraform force-unlock <lock-id>
```

## Resource Tagging

All resources are tagged with:

- `Project`: Project name
- `Environment`: dev/staging/prod
- `ManagedBy`: Terraform

## Maintenance Windows

- **RDS**: Mondays 04:00-05:00 UTC
- **ElastiCache**: Sundays 05:00-07:00 UTC

## Scaling

### EKS Node Group

Modify in `terraform.tfvars`:

```hcl
eks_desired_size = 3
eks_min_size     = 2
eks_max_size     = 6
```

### RDS Instance

Modify in `terraform.tfvars`:

```hcl
db_instance_class = "db.t3.small"
```

Apply changes:

```bash
terraform apply
```

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
