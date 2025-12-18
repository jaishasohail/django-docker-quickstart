# Monitoring Stack with Prometheus and Grafana

This directory contains configurations for setting up a complete monitoring solution using Prometheus and Grafana for the Django application.

## Components

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System-level metrics from Kubernetes nodes
- **Kube State Metrics**: Kubernetes cluster metrics
- **Alert Manager**: Alert management (optional)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       Grafana                            │
│              (Visualization & Dashboards)                │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     Prometheus                           │
│              (Metrics Collection & Storage)              │
└─────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Django Pods  │ │Node Exporter │ │  PostgreSQL  │ │    Redis     │
│  (metrics)   │ │   (system)   │ │  (exporter)  │ │  (exporter)  │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

## Installation

### Option 1: Manual Installation (Kubernetes Manifests)

```bash
cd monitoring

# Make install script executable
chmod +x install.sh

# Run installation
./install.sh
```

### Option 2: Helm Installation (Recommended)

```bash
cd monitoring

# Make install script executable
chmod +x helm-install.sh

# Install complete monitoring stack
./helm-install.sh
```

This installs the `kube-prometheus-stack` which includes:

- Prometheus
- Grafana
- Alertmanager
- Node Exporter
- Kube State Metrics
- Prometheus Operator

### Option 3: Manual Step-by-Step

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus
kubectl apply -f prometheus-deployment.yaml

# Install Grafana
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-dashboards.yaml

# Install Node Exporter
kubectl apply -f node-exporter.yaml

# Verify installations
kubectl get all -n monitoring
```

## Accessing the Services

### Grafana

#### Port Forward (Local Access)

```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Then open http://localhost:3000

**Default Credentials:**

- Username: `admin`
- Password: `admin` (change immediately!)

#### Ingress (Production)

Update [grafana-deployment.yaml](grafana-deployment.yaml) with your domain and apply:

```bash
kubectl apply -f grafana-deployment.yaml
```

Access at: https://grafana.your-domain.com

### Prometheus

#### Port Forward (Local Access)

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Then open http://localhost:9090

#### Verify Targets

Check that Prometheus is scraping all targets:

1. Open Prometheus UI
2. Go to Status → Targets
3. Verify all targets show "UP"

## Grafana Dashboards

### Pre-configured Dashboards

1. **Django Application Metrics**

   - Request rate
   - Response time (p95, p99)
   - Error rate
   - Database connections
   - Cache hit rate

2. **Kubernetes Cluster Metrics**
   - Pod CPU/Memory usage
   - Node metrics
   - Pod status
   - Resource quotas

### Import Additional Dashboards

1. Log into Grafana
2. Go to Dashboards → Import
3. Use dashboard IDs from [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/):
   - **3119**: Kubernetes cluster monitoring
   - **6417**: Kubernetes Deployment
   - **747**: PostgreSQL Database
   - **763**: Redis
   - **1860**: Node Exporter Full

Or import JSON files directly from `grafana-dashboards.yaml`.

### Create Custom Dashboard

1. Go to Dashboards → New Dashboard
2. Add Panel
3. Use PromQL queries, for example:

   ```promql
   # Request rate
   rate(http_requests_total[5m])

   # Memory usage
   container_memory_usage_bytes{namespace="django-app-dev"}

   # Pod restarts
   kube_pod_container_status_restarts_total
   ```

## Prometheus Queries

### Common PromQL Queries

#### Application Metrics

```promql
# HTTP request rate
rate(http_requests_total[5m])

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m])

# Response time percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Active requests
http_requests_in_progress
```

#### Kubernetes Metrics

```promql
# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="django-app-dev"}[5m])) by (pod)

# Pod memory usage
sum(container_memory_usage_bytes{namespace="django-app-dev"}) by (pod)

# Pod status
kube_pod_status_phase{namespace="django-app-dev"}

# Available nodes
count(kube_node_info)
```

#### Database Metrics

```promql
# Active connections
pg_stat_activity_count

# Connection pool usage
pg_stat_database_numbackends

# Database size
pg_database_size_bytes
```

#### Redis Metrics

```promql
# Connected clients
redis_connected_clients

# Memory usage
redis_memory_used_bytes

# Hit rate
rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
```

## Alerts

### Configured Alerts

Alerts are defined in [prometheus-deployment.yaml](prometheus-deployment.yaml):

1. **HighErrorRate**: Triggered when 5xx error rate exceeds 5%
2. **HighMemoryUsage**: Triggered when memory usage > 90%
3. **PodDown**: Triggered when a pod is down for 5+ minutes
4. **DatabaseDown**: Triggered when PostgreSQL is unreachable
5. **RedisDown**: Triggered when Redis is unreachable

### View Active Alerts

In Prometheus UI:

- Go to Alerts tab
- View firing and pending alerts

### Configure Alert Manager (Optional)

Install Alertmanager for alert routing and notifications:

```bash
helm install alertmanager prometheus-community/alertmanager \
  --namespace monitoring \
  --set config.receivers[0].name=email \
  --set config.receivers[0].email_configs[0].to=alerts@example.com
```

## Monitoring Django Application

### Add Prometheus Metrics to Django

Install Django Prometheus client:

```bash
pip install django-prometheus
```

Update `settings.py`:

```python
INSTALLED_APPS = [
    ...
    'django_prometheus',
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
    ...
    'django_prometheus.middleware.PrometheusAfterMiddleware',
]
```

Add metrics endpoint to `urls.py`:

```python
urlpatterns = [
    ...
    path('', include('django_prometheus.urls')),
]
```

Update Kubernetes deployment to add Prometheus annotations:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8000"
    prometheus.io/path: "/metrics"
```

## Exporters

### PostgreSQL Exporter

Deploy PostgreSQL exporter for database metrics:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-exporter
  template:
    metadata:
      labels:
        app: postgres-exporter
    spec:
      containers:
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:v0.13.2
        env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://user:password@postgres-service.django-app-dev:5432/django_app_db?sslmode=disable"
        ports:
        - containerPort: 9187
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-exporter
  namespace: monitoring
spec:
  ports:
  - port: 9187
    targetPort: 9187
  selector:
    app: postgres-exporter
EOF
```

### Redis Exporter

Deploy Redis exporter:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-exporter
  template:
    metadata:
      labels:
        app: redis-exporter
    spec:
      containers:
      - name: redis-exporter
        image: oliver006/redis_exporter:v1.52.0
        env:
        - name: REDIS_ADDR
          value: "redis-service.django-app-dev:6379"
        ports:
        - containerPort: 9121
---
apiVersion: v1
kind: Service
metadata:
  name: redis-exporter
  namespace: monitoring
spec:
  ports:
  - port: 9121
    targetPort: 9121
  selector:
    app: redis-exporter
EOF
```

## Retention and Storage

### Prometheus Data Retention

Configured in [prometheus-deployment.yaml](prometheus-deployment.yaml):

- Retention time: 30 days
- Storage: 50GB PVC

To change retention:

```yaml
args:
  - "--storage.tsdb.retention.time=60d" # 60 days
  - "--storage.tsdb.retention.size=100GB" # or by size
```

### Backup Prometheus Data

```bash
# Create backup
kubectl exec -n monitoring prometheus-xxx -- tar -czf /tmp/prometheus-backup.tar.gz /prometheus

# Copy backup
kubectl cp monitoring/prometheus-xxx:/tmp/prometheus-backup.tar.gz ./prometheus-backup.tar.gz
```

## Scaling

### Scale Prometheus

For high-load environments, consider:

1. **Horizontal sharding**: Multiple Prometheus instances with different scrape configs
2. **Thanos**: Long-term storage and global query view
3. **Cortex**: Horizontally scalable Prometheus

### Scale Grafana

Multiple Grafana replicas with shared database:

```yaml
spec:
  replicas: 3
  # Add PostgreSQL for shared storage
```

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus

# Verify service discovery
kubectl get servicemonitors -A

# Check network policies
kubectl get networkpolicies -A
```

### Grafana Can't Connect to Prometheus

```bash
# Test connectivity
kubectl exec -n monitoring deployment/grafana -- wget -O- http://prometheus:9090/-/healthy

# Check datasource configuration
kubectl describe configmap grafana-datasources -n monitoring
```

### High Memory Usage

```bash
# Check Prometheus metrics
kubectl top pod -n monitoring

# Reduce scrape frequency or retention
# Update prometheus-deployment.yaml
```

### Missing Metrics

```bash
# Check if target is being scraped
# In Prometheus UI: Status → Targets

# Verify metric endpoint
kubectl exec -n django-app-dev deployment/backend -- curl localhost:8000/metrics
```

## Security Best Practices

1. **Change default passwords** immediately
2. **Enable HTTPS** for Grafana ingress
3. **Use RBAC** for Prometheus service account
4. **Encrypt secrets** containing credentials
5. **Limit network access** with NetworkPolicies
6. **Enable authentication** on Prometheus (use reverse proxy)
7. **Regular backups** of Grafana dashboards and Prometheus data

## Clean Up

```bash
# Delete monitoring namespace (removes all resources)
kubectl delete namespace monitoring

# Or delete individual components
kubectl delete -f prometheus-deployment.yaml
kubectl delete -f grafana-deployment.yaml
kubectl delete -f node-exporter.yaml
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Kubernetes Monitoring Guide](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-monitoring/)
