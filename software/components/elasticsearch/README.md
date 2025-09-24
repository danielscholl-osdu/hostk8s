# Elasticsearch Component

Complete Elasticsearch stack with Kibana dashboard for full-text search, analytics, and log aggregation using ECK (Elastic Cloud on Kubernetes) operator. This component provides automated cluster management with integrated security for local development environments.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|----------|-------------|-----------|----------------|--------------|---------|
| ECK Operator | 1 | 100m | 200m | 150Mi | 256Mi | - |
| Elasticsearch | 1 | 100m | 1000m | 1536Mi | 1536Mi | 10Gi |
| Kibana | 1 | 100m | 500m | 512Mi | 768Mi | - |
| **Total Component Resources** | | **300m** | **1700m** | **2.19Gi** | **2.53Gi** | **10Gi** |

## Services & Access

| Service | Endpoint | Port | Purpose | Credentials |
|---------|----------|------|---------|-------------|
| Elasticsearch API | `http://elasticsearch.localhost:8080` | 9200 | Search and indexing API | `elastic` user |
| Kibana Dashboard | `http://kibana.localhost:8080` | 5601 | Data visualization and management | `elastic` user |
| Internal Service | `elasticsearch-es-http.elasticsearch.svc.cluster.local` | 9200 | Cluster-internal API access | Service accounts |

**Default Credentials:**
- **Username**: `elastic` (superuser)
- **Password**: Retrieved from Vault secret `foundation/elastic/elasticsearch/elasticsearch-credentials`
- **Service Account**: `kibana_system` (Kibana-to-Elasticsearch communication)

## Internal Components

| Component | Source Location | Purpose | Dependencies |
|-----------|----------------|---------|--------------|
| `operator/` | `software/components/elasticsearch/operator/` | ECK operator installation | None |
| `cluster/` | `software/components/elasticsearch/cluster/` | Elasticsearch cluster + secrets | ECK operator |
| `kibana/` | `software/components/elasticsearch/kibana/` | Kibana dashboard | Elasticsearch cluster |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Elasticsearch Component                  │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────┐ │
│  │                 │    │                 │    │          │ │
│  │   ECK Operator  │───►│  Elasticsearch  │───►│ Kibana   │ │
│  │   installation  │    │   cluster       │    │ dashboard│ │
│  │   + lifecycle   │    │   + search API  │    │ + UI     │ │
│  │   + security    │    │   + storage     │    │          │ │
│  └─────────────────┘    └─────────────────┘    └──────────┘ │
│          │                       │                    │     │
│          ▼                       ▼                    ▼     │
│      operator/                cluster/             kibana/  │
│                                                             │
│  Sequential Flux orchestration with dependency management  │
└─────────────────────────────────────────────────────────────┘
```

## Usage

**Stack Integration:**
```yaml
- name: component-elasticsearch
  namespace: flux-system
  path: ./software/components/elasticsearch
```

**Expected Kustomizations:**
- `component-elasticsearch-operator` (ECK operator installation)
- `component-elasticsearch-cluster` (Elasticsearch cluster + secrets)
- `component-elasticsearch-kibana` (Kibana dashboard)

**API Usage Examples:**
```bash
# Create index and search documents
curl -X PUT "http://elasticsearch.localhost:8080/logs" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"settings": {"number_of_shards": 1}}'

curl -X POST "http://elasticsearch.localhost:8080/logs/_doc" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"timestamp": "2025-01-01T12:00:00", "level": "INFO", "message": "Application started"}'
```

**Application Integration:**
```yaml
# Connect applications to Elasticsearch
env:
- name: ELASTICSEARCH_URL
  value: "http://elasticsearch-es-http.elasticsearch:9200"
- name: ELASTICSEARCH_USERNAME
  valueFrom:
    secretKeyRef:
      name: elasticsearch-credentials
      key: elastic
- name: ELASTICSEARCH_PASSWORD
  valueFrom:
    secretKeyRef:
      name: elasticsearch-credentials
      key: elastic-password
```

## Dependencies

- **Vault + External Secrets Operator**: Required for credential management
- **NGINX Ingress Controller**: Required for web access
- **Persistent Storage**: Required for data persistence (10Gi volume)
