# tfm-fiware-gitops

> **TFM** — Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm
> Máster DevOps UNIR · Jesús David Monsalve Lezama

## Estado de implementación

| Fase | Entorno | Estado |
|------|---------|--------|
| Local demo | kind (3 nodos) | En progreso |
| AWS EKS | eu-west-1 (t3.xlarge) | Pendiente — jun 2026 |

## Inicio rápido (local kind)

### Prerequisitos

```bash
kind version    # >= 0.20
helm version    # >= 3.14
kubectl version # >= 1.27
```

### Bootstrap completo (un solo comando)

```bash
git clone https://github.com/jdmonsalvel/tfm-fiware-gitops
cd tfm-fiware-gitops
bash scripts/bootstrap.sh
```

El script ejecuta en orden:
1. Crea clúster kind `fiware-gitops` (1 control-plane + 2 workers)
2. Instala NGINX Ingress Controller (hostPort 80/443)
3. Instala ArgoCD con ingress en `argocd.127.0.0.1.nip.io`
4. Crea K8s Secrets fuera de Git (`scripts/create-secrets.sh`)
5. Aplica App of Apps - ArgoCD sincroniza los 6 componentes FIWARE

### Acceso a ArgoCD

```bash
open http://argocd.127.0.0.1.nip.io

# Contraseña inicial:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Verificar sincronización

```bash
watch kubectl get applications -n argocd
# Esperar: todos en Synced / Healthy
```

### Smoke test E2E

```bash
bash tests/smoke-test.sh
```

## Componentes FIWARE

| Componente | Chart | Namespace | URL local |
|-----------|-------|-----------|-----------|
| Keyrock (IdP) | `fiware/keyrock 0.8.*` | `trust-anchor` | `keyrock.127.0.0.1.nip.io` |
| Trusted Issuers List | `fiware/trusted-issuers-list 0.18.*` | `trust-anchor` | `til.127.0.0.1.nip.io` |
| Credentials Config Service | `fiware/credentials-config-service 2.*` | `trust-anchor` | `ccs.127.0.0.1.nip.io` |
| Orion-LD | `fiware/orion 1.6.*` | `provider` | `orion.127.0.0.1.nip.io` |
| MySQL (Keyrock DB) | `bitnami/mysql 14.*` | `trust-anchor` | interno |
| MongoDB (Orion DB) | `bitnami/mongodb 18.*` | `provider` | interno |

## Sync Waves (orden de despliegue)

```
Wave 0  MySQL, MongoDB        bases de datos
  |
  v (esperar Healthy)
Wave 1  Keyrock, TIL, CCS    trust anchor
  |
  v (esperar Healthy)
Wave 2  Orion-LD              provider
```

## Gestión de secretos

Los secretos **nunca están en Git**.

- **Local (kind):** `scripts/create-secrets.sh` crea K8s Secrets directamente.
- **AWS (EKS):** External Secrets Operator proyecta desde AWS Secrets Manager (`/fiware/*`).

Los `values.yaml` referencian `existingSecret: <nombre>` en ambos casos.

## Estructura del repositorio

```
tfm-fiware-gitops/
├── kind/
│   └── cluster-config.yaml        # Cluster 3 nodos + port-mappings
├── scripts/
│   ├── bootstrap.sh               # Bootstrap completo (idempotente)
│   └── create-secrets.sh          # K8s Secrets — NO en Git
├── gitops/
│   ├── apps/
│   │   ├── app-of-apps.yaml       # Root Application
│   │   └── applications/          # 6 Applications (wave 0-2)
│   └── values/
│       ├── trust-anchor/          # keyrock, til, ccs, mysql
│       └── provider/              # orion, mongodb
├── tests/
│   └── smoke-test.sh              # Test E2E 4 pasos
└── docs/
    └── architecture.md            # Diagrama Mermaid + tablas
```

## Métricas objetivo

| Métrica | Objetivo |
|---------|----------|
| Deployment Lead Time (push a Healthy) | < 10 min |
| ArgoCD Sync Time | < 3 min |
| Configuration Drift Detection | < 60 seg |
| Smoke Test Pass Rate | 100% |
