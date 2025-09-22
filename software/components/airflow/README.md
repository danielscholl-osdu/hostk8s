# Airflow Component

Apache Airflow workflow orchestrator component for HostK8s.

## Overview

This component provides Apache Airflow 2.10.1 with:
- CeleryExecutor with Redis backend
- External PostgreSQL database
- NGINX ingress for web UI
- Persistent DAG storage
- Vault-managed secrets

## Dependencies

- `postgres` component - Database backend
- `redis` component - Celery broker
- `vault` addon - Secret management

## Access

- Web UI: http://airflow.localhost
- Default user: admin (password generated in Vault)

## Configuration

The component uses the official Apache Airflow Helm chart with:
- 1 scheduler
- 2 workers (Celery)
- 1 triggerer
- Resource limits optimized for local development

## Usage

Deploy via foundation/airflow stack:
```bash
make up foundation/airflow
```

Or deploy component directly (requires dependencies):
```bash
kubectl apply -k software/components/airflow
```

## DAG Management

DAGs are stored in persistent volume at `/mnt/pv/airflow-dags`.
The foundation stack includes example DAGs:
- `hello_world.py` - Simple hello world DAG
- `data_pipeline.py` - Example pipeline with branching

Add custom DAGs by mounting to the PVC or updating the ConfigMap.
