# tfm-fiware-gitops

> **TFM** — Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm en entornos multi-nodo sobre Amazon EKS  
> Máster DevOps UNIR · Jesús David Monsalve Lezama · Depósito: 22 julio 2026

**Repositorio GitOps puro** — source of truth que ArgoCD observa para sincronizar el clúster.  
El framework Terraform vive en [`tfm-terraform-framework`](https://github.com/jdmonsalvel/tfm-terraform-framework) y la documentación académica en [`tfm-fiware-docs`](https://github.com/jdmonsalvel/tfm-fiware-docs).

---

## Tres repositorios del TFM

| Repositorio | Propósito |
|---|---|
| **tfm-fiware-gitops** (este) | GitOps — ArgoCD config, Helm values, scripts, tests |
| [tfm-terraform-framework](https://github.com/jdmonsalvel/tfm-terraform-framework) | IaC — 25+ módulos AWS reutilizables, `v1.0.12` |
| [tfm-fiware-docs](https://github.com/jdmonsalvel/tfm-fiware-docs) | Documentación académica — memoria capítulos 00-07 |

---

## Arquitectura

```
GitHub (tfm-fiware-gitops)
        │  push → infra/environments/**  /  workflow_dispatch
        ▼
GitHub Actions (infra-deploy.yml)
        │  OIDC → github-actions-terraform-role
        │  backend-setup.sh → S3 devops-575124957370-* + DynamoDB lock
        │  terraform apply (framework v1.0.12)
        │  post-apply.sh → IRSA ARNs en values + Secrets Manager
        ▼
AWS eu-west-1 (cuenta 575124957370)
  ├── VPC fiware-vpc (10.0.0.0/16) — 3 AZs, 9 subnets
  ├── EKS tfm-dev-fiware-gitops (1.34) — SPOT t3.medium×2, SSM habilitado
  ├── Route53 lab-jdmonsalvel.com + ACM wildcard
  └── Secrets Manager /fiware/* → ESO → K8s Secrets
        │
        ▼  kubectl apply gitops/app-of-apps.yaml
ArgoCD (namespace argocd)
        │  App of Apps → gitops/apps/
        ▼
  Sync waves:
  -3  cert-manager
  -2  external-secrets · ingress-nginx
  -1  external-secrets-config (ClusterSecretStore + ExternalSecrets)
   0  mysql · mongodb
   1  keyrock · trusted-issuers-list · credentials-config-service
   2  orion-ld
```

---

## Estructura del repositorio

```
tfm-fiware-gitops/
├── .github/workflows/
│   ├── infra-deploy.yml          # push/dispatch: terraform apply + post-apply
│   ├── gitops-validate.yml       # PR: helm lint + kubeconform
│   └── security-scan.yml         # push: TruffleHog + Checkov K8s
│
├── infra/environments/dev/
│   └── terraform.tfvars          # Única fuente de verdad IaC — sin backend.tf
│
├── gitops/
│   ├── app-of-apps.yaml          # Root Application ArgoCD
│   ├── apps/
│   │   ├── platform/             # cert-manager, external-secrets, ingress-nginx, monitoring
│   │   └── fiware/               # mysql, mongodb, keyrock, til, ccs, orion
│   ├── external-secrets/
│   │   ├── cluster-secret-store.yaml   # ClusterSecretStore → AWS Secrets Manager
│   │   └── fiware-secrets.yaml         # ExternalSecrets keyrock / mysql / mongodb
│   └── values/
│       ├── platform/             # external-secrets.yaml (IRSA ARN — post-apply)
│       ├── trust-anchor/         # keyrock, mysql, til, ccs
│       └── provider/             # orion, mongodb
│
├── scripts/
│   ├── bootstrap.sh              # Bootstrap EKS: instala ArgoCD + App of Apps
│   ├── post-apply.sh             # Post-terraform: inyecta IRSA ARNs + crea secretos SM
│   ├── create-secrets.sh         # Crea K8s Secrets manualmente (modo local/test)
│   └── teardown.sh               # Destruye el entorno completo
│
└── tests/
    └── smoke-test.sh             # Test E2E 4 pasos
```

---

## Estado de implementación — 31 mayo 2026

### Capa 1 — Infraestructura AWS (Terraform framework v1.0.12)

| Componente | Estado | Notas |
|---|---|---|
| Backend S3 + DynamoDB lock | ✅ Activo | `devops-575124957370-terraform-state-bucket` |
| OIDC GitHub Actions + rol IAM | ✅ Activo | Zero credenciales estáticas |
| VPC + subnets + NAT GW + SG | 🔄 Desplegando | Pipeline activo |
| EKS `tfm-dev-fiware-gitops` 1.34 | 🔄 Desplegando | SPOT t3.medium×2, SSM habilitado |
| EKS admin `jdmonsalvel` | 🔄 Desplegando | Access Entry dinámica (`data.aws_iam_user`) |
| IRSA roles (ESO, LBC, cert-manager) | 🔄 Desplegando | |
| Route53 `lab-jdmonsalvel.com` | 🔄 Desplegando | ⚠️ NS pendiente delegar en registrador |
| ACM `*.lab-jdmonsalvel.com` | 🔄 Desplegando | Valida automáticamente al delegar NS |
| Secrets Manager `/fiware/*` | 🔄 Desplegando | 4 secretos creados por post-apply.sh |
| S3 velero-backups + loki-logs | 🔄 Desplegando | |

### Capa 2 — GitOps (ArgoCD)

| Componente | Estado | Notas |
|---|---|---|
| Bootstrap ArgoCD | ⏳ Pendiente | `bash scripts/bootstrap.sh` tras EKS healthy |
| App of Apps | ⏳ Pendiente | Aplicado por bootstrap.sh |
| cert-manager | ⏳ Pendiente | wave -3 |
| external-secrets + IRSA | ⏳ Pendiente | wave -2, ARN inyectado por post-apply |
| ingress-nginx + NLB | ⏳ Pendiente | wave -2 |
| ClusterSecretStore + ExternalSecrets | ⏳ Pendiente | wave -1 |
| MySQL + MongoDB | ⏳ Pendiente | wave 0 |
| Keyrock + TIL + CCS | ⏳ Pendiente | wave 1 |
| Orion-LD | ⏳ Pendiente | wave 2 |

### Capa 3 — DNS / TLS / Validación

| Componente | Estado | Notas |
|---|---|---|
| Delegación NS `lab-jdmonsalvel.com` | ⏳ Pendiente | NS de Route53 → registrador del dominio |
| Certificados Let's Encrypt | ⏳ Pendiente | Auto tras delegación DNS |
| Smoke test E2E | ⏳ Pendiente | 4 pasos: health → token → acceso → NGSI-LD |

---

## Bootstrap (una vez EKS activo)

```bash
# 1. Kubeconfig
aws eks update-kubeconfig \
  --name tfm-dev-fiware-gitops \
  --region eu-west-1 \
  --profile tfm-account-lab

# 2. Verificar nodos y acceso SSM
kubectl get nodes
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=tfm-dev-fiware-gitops" \
  --query "Reservations[].Instances[].[InstanceId,PrivateIpAddress]" \
  --output table --region eu-west-1 --profile tfm-account-lab
aws ssm start-session --target <i-xxxxx> --region eu-west-1 --profile tfm-account-lab

# 3. Bootstrap ArgoCD + App of Apps
bash scripts/bootstrap.sh

# 4. UI ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# https://localhost:8080  — usuario: admin
# password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# 5. Test E2E (tras DNS activo)
export TRUST_ANCHOR_URL=https://keyrock.lab-jdmonsalvel.com
export PROVIDER_URL=https://orion.lab-jdmonsalvel.com
bash tests/smoke-test.sh
```

---

## Gestión de secretos

Los secretos **nunca están en Git**. Flujo completo:

```
AWS Secrets Manager (/fiware/*)
        ↓  ClusterSecretStore (ESO + IRSA)
  ExternalSecret → Kubernetes Secret
        ↓  existingSecret: <nombre>
   Helm values (bitnami/fiware charts)
```

| Secret K8s | Namespace | Claves |
|---|---|---|
| `keyrock-credentials` | trust-anchor | `adminPassword`, `dbPassword` |
| `mysql-credentials` | trust-anchor | `mysql-root-password`, `mysql-password` |
| `mongodb-root-secret` | provider | `mongodb-root-password` |
