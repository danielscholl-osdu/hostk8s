# Airflow Foundation Stack

Complete Apache Airflow environment with PostgreSQL, Redis, and example DAGs.

## Components Deployed

1. **PostgreSQL** - Database backend with dedicated `airflow` database
2. **Redis** - Celery broker for distributed task execution
3. **Airflow** - Workflow orchestrator with web UI
4. **Example DAGs** - Hello world and data pipeline examples

## Quick Start

```bash
# Deploy the stack
make up foundation/airflow

# Check status
make status

# Access UI
open http://airflow.localhost

# View logs
kubectl logs -n airflow -l component=scheduler
```

## Default Credentials

- **Airflow Admin**: username: `admin`, password: (check Vault)
- **PgAdmin**: http://pgadmin.localhost (admin@hostk8s.com)

## Storage

- **DAGs**: `/data/pv/airflow-dags` (1Gi, persistent)
- **Logs**: `/data/pv/airflow-logs` (5Gi, persistent)
- **Database**: `/data/pv/postgres` (via postgres component)

## Example DAGs

### Hello World DAG
- Runs every 30 minutes
- Demonstrates basic Python and Bash operators
- Task dependencies and parallel execution

### Data Pipeline DAG
- Daily schedule
- Shows branching logic based on data size
- XCom data passing between tasks

## Adding Custom DAGs

1. **Via ConfigMap** (for testing):
   ```bash
   kubectl edit configmap airflow-example-dags -n airflow
   ```

2. **Via Volume Mount** (production):
   - Place DAG files in `/data/pv/airflow-dags/`
   - They'll be auto-discovered by scheduler

3. **Via Git Sync** (advanced):
   - Enable git-sync in the HelmRelease
   - Configure repository and credentials

## Troubleshooting

```bash
# Check Airflow components
kubectl get pods -n airflow

# View scheduler logs
kubectl logs -n airflow -l component=scheduler

# Check database connection
kubectl exec -it -n postgres airflow-db-cluster-1 -- psql -U airflow -d airflow

# Restart scheduler to pick up new DAGs
kubectl rollout restart deployment/airflow-scheduler -n airflow
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │────▶│  NGINX Ingress  │
└─────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Airflow Webserver  │
                    └─────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Scheduler   │     │   Workers    │     │  Triggerer   │
└──────────────┘     └──────────────┘     └──────────────┘
        │                      │                      │
        ├──────────┬───────────┴──────────────────────┤
        │          │                                  │
        ▼          ▼                                  ▼
┌──────────────┐  ┌──────────────┐          ┌──────────────┐
│  PostgreSQL  │  │    Redis     │          │  DAG Storage │
└──────────────┘  └──────────────┘          └──────────────┘
```

## Secrets Management

All sensitive data managed via Vault:
- Webserver secret key
- Fernet key for encryption
- Database credentials
- Admin password

Access secrets:
```bash
kubectl port-forward -n hostk8s svc/vault 8200:8200
open http://localhost:8200
# Token: root
```
