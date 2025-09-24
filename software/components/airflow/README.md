# Airflow Component

Apache Airflow workflow orchestrator component providing task scheduling, dependency management, and workflow automation with CeleryExecutor and web UI for HostK8s stacks.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|----------|-------------|-----------|----------------|--------------|---------|
| Scheduler | 1 | 100m | 500m | 256Mi | 512Mi | - |
| API Server | 1 | 100m | 500m | 256Mi | 512Mi | - |
| Webserver | 1 | 100m | 500m | 128Mi | 512Mi | - |
| Triggerer | 1 | 50m | 200m | 128Mi | 256Mi | - |
| DAG Processor | 1 | 50m | 200m | 128Mi | 256Mi | - |
| StatSD | 1 | 50m | 100m | 64Mi | 128Mi | - |
| **Total Component Resources** | | **450m** | **2000m** | **960Mi** | **2176Mi** | **-** |

## Services & Access

| Service | Endpoint | Port | Purpose | Credentials |
|---------|----------|------|---------|-------------|
| Airflow Web UI | `http://airflow.localhost:8080` | 8080 | Workflow management dashboard | `admin` user |
| API Server | `airflow-api-server.airflow.svc.cluster.local` | 8080 | REST API for automation | Same credentials |
| Scheduler | Internal only | - | Task scheduling engine | - |

**Default Credentials:**
- **Username**: `admin`
- **Password**: Retrieved from Vault secret `foundation/airflow/airflow/airflow-credentials`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Airflow Component                       │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────┐ │
│  │                 │    │                 │    │          │ │
│  │   Scheduler     │───►│   API Server    │───►│ Web UI   │ │
│  │   + executor    │    │   + REST API    │    │ + tasks  │ │
│  │   + DAG parser  │    │   + auth        │    │          │ │
│  │                 │    │                 │    │          │ │
│  └─────────────────┘    └─────────────────┘    └──────────┘ │
│          │                       │                    │     │
│          ▼                       ▼                    ▼     │
│    ┌──────────┐            ┌──────────┐         ┌─────────┐ │
│    │Triggerer │            │   DAG    │         │ StatSD  │ │
│    │  async   │            │Processor │         │metrics  │ │
│    └──────────┘            └──────────┘         └─────────┘ │
│                                                             │
│  External Dependencies: PostgreSQL (metadata) + Redis (Celery) │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

Add to your stack's `stack.yaml`:

```yaml
- name: component-postgres
  namespace: flux-system
  path: ./software/components/postgres
- name: component-redis
  namespace: flux-system
  path: ./software/components/redis
- name: component-airflow
  namespace: flux-system
  path: ./software/components/airflow
```

## Connection Configuration

**Database Connection** (automatically configured):
```yaml
env:
- name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
  value: "postgresql://airflow:password@airflow-db-rw.postgres:5432/airflow"
- name: AIRFLOW__CELERY__BROKER_URL
  value: "redis://redis-master.redis:6379/0"
- name: AIRFLOW__CELERY__RESULT_BACKEND
  value: "redis://redis-master.redis:6379/0"
```

**External API Access**:
```bash
# Access Airflow API from applications
curl -u admin:password http://airflow-api-server.airflow:8080/api/v1/dags
```

## DAG Management

**DAG Storage**: `/opt/airflow/dags` (persistent across restarts)

**Adding Custom DAGs**:
1. Mount DAGs via ConfigMap (development):
```yaml
# In your stack manifests
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dags
  namespace: airflow
data:
  my_dag.py: |
    from airflow import DAG
    from airflow.operators.bash import BashOperator
    # DAG definition here
```

2. Persistent volume (production-like):
```bash
# Copy DAGs to persistent storage
kubectl cp my_dag.py airflow/airflow-scheduler-0:/opt/airflow/dags/
```

## Dependencies

- **PostgreSQL component**: Database backend for metadata
- **Redis component**: Celery broker and result backend
- **Vault addon**: Credential and secret management
- **NGINX Ingress**: Web UI access via `airflow.localhost`
