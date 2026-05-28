# tfm-fiware-gitops

> **TFM** — Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm en entornos multi-nodo sobre Amazon Web Services
> Máster DevOps UNIR · Jesús David Monsalve Lezama · Depósito: 22 julio 2026

---

## Estado de implementación — 28 mayo 2026

### Capa 1 — Infraestructura AWS (Terraform)

| Componente | Estado | Notas |
|---|---|---|
| Terraform framework (módulos) | ✅ Desplegado | 25 módulos AWS — vpc, subnet, eks, iam, s3, acm, route53, secrets-manager… |
| Backend S3 | ✅ Activo | `devops-101490102336-terraform-state-bucket` · key `terraform-aws-tfm-lab-eu-west-1.tfstate` |
| VPC `fiware-vpc` (10.0.0.0/16) | ✅ Desplegado | 3 AZs eu-west-1a/b/c |
| Subnets — 3 tiers, 9 subnets | ✅ Desplegado | public (101-103/24) · app (1-3/24) · data (11-13/24) |
| NAT Gateway · IGW · Route Tables | ✅ Desplegado | rt-public / rt-app / rt-data |
| Security Groups | ✅ Desplegado | eks-cluster, eks-node, alb-fiware, data-sg |
| Cross-SG rules (app → data) | ✅ Desplegado | Mongo 27017, MySQL 3306, PG 5432, Redis 6379 |
| DB subnet group | ✅ Desplegado | `tfm-lab-db-subnet-group` (subnets priv-data-*) |
| S3 buckets | ✅ Desplegado | fiware-terraform-state, fiware-velero-backups, fiware-loki-logs |
| Route53 zona `lab-jdmonsalvel.com` | ✅ Desplegado | Zona `Z07068241AJ8YGJPUT6BO` · pendiente delegación NS en Cloudflare |
| ACM wildcard `*.lab-jdmonsalvel.com` | ⏳ PENDING_VALIDATION | Validará al delegar NS · ARN `arn:aws:acm:eu-west-1:101490102336:certificate/964709a7…` |
| Secrets Manager (4 secretos) | ✅ Desplegado | `/fiware/keyrock/*` · `/fiware/mysql/*` · `/fiware/mongodb/*` |
| EKS cluster + node groups | ⏳ Pendiente (coste) | Descomentar bloque `eks` en tfvars · ~$0.60/h activo |
| RDS MySQL (`db.t3.micro`) | ⏳ Pendiente | Módulo RDS existe · pendiente configurar en tfvars |
| IRSA roles (ESO, ALB, EBS, Velero…) | ⏳ Auto (vía EKS) | Creados automáticamente por módulo EKS al desplegarlo |
| Instance Scheduler | ⏳ Bloqueado | Lambda concurrency = 5 en cuenta · solicitar quota increase |

### CI/CD — GitHub Actions

| Workflow | Trigger | Estado |
|---|---|---|
| `terraform-validate.yml` | PR / push en `infra/**` | ✅ Activo · fmt + validate + Checkov |
| `terraform-apply.yml` | Push a `main` en `infra/**` | ✅ Creado · OIDC → `automate-cicd-role` · env `aws-lab` con aprobación |
| `gitops-validate.yml` | PR / push en `gitops/**` | ✅ Activo · helm lint + kubeconform |
| `security-scan.yml` | Push / PR | ✅ Activo · TruffleHog + Checkov K8s |

> **Prerequisito terraform-apply**: crear OIDC provider de GitHub Actions en IAM (`token.actions.githubusercontent.com`) y añadir trust al rol `automate-cicd-role`.

### Capa 2 — GitOps (ArgoCD)

| Componente | Estado | Notas |
|---|---|---|
| App of Apps manifest | ✅ Implementado | `gitops/apps/app-of-apps.yaml` |
| Applications ArgoCD (×6) | ✅ Implementados | Wave 0 (DBs) → 1 (Keyrock, TIL, CCS) → 2 (Orion) |
| Values Helm trust-anchor | ✅ Implementados | Keyrock, TIL, CCS, MySQL |
| Values Helm provider | ✅ Implementados | Orion-LD, MongoDB |
| ExternalSecret manifests (ESO) | ⏳ Pendiente | Crear `ClusterSecretStore` + `ExternalSecret` para proyectar ASM → K8s |

### Capa 3 — FIWARE Data Space Connector

| Componente | Namespace | Estado |
|---|---|---|
| Keyrock (IdP / Trust Anchor) | `trust-anchor` | ✅ Chart configurado |
| Trusted Issuers List | `trust-anchor` | ✅ Chart configurado |
| Credentials Config Service | `trust-anchor` | ✅ Chart configurado |
| Orion-LD (Context Broker) | `provider` | ✅ Chart configurado |
| Kong / Wilma (PEP) | `provider` | ✅ Chart configurado |

### Scripts y automatización

| Script | Estado |
|---|---|
| `scripts/bootstrap.sh` | ✅ Implementado |
| `scripts/bootstrap-kind.sh` | ❌ Eliminado (solo AWS EKS) |
| `scripts/create-secrets.sh` | ✅ Implementado |
| `scripts/teardown.sh` | ✅ Implementado |
| `tests/smoke-test.sh` | ✅ Implementado |
| `infra/terraform-framework/backend-setup.sh` | ✅ Implementado |

### Memoria académica

| Capítulo | Estado |
|---|---|
| Abstract | ✅ Completo |
| Cap 1 — Introducción | ✅ Completo |
| Cap 2 — Estado del Arte | ✅ Completo |
| Cap 3 — Metodología | ✅ Completo |
| Cap 4 — Desarrollo y contribución | ✅ Completo |
| Cap 5 — Resultados | ⏳ Placeholders — requiere evidencias reales (métricas EKS) |
| Cap 6 — Conclusiones | ✅ Completo |
| Bibliografía | ✅ Completo |

---

## Próximos pasos

```
Fase 2 — despliegue con coste (EKS + RDS):
1. Solicitar Lambda quota increase (mín. 50) → habilitar Instance Scheduler
2. Delegar NS de lab-jdmonsalvel.com a Route53 en Cloudflare (4 NS records)
3. Descomentar bloque eks en variables/aws-personal.tfvars
4. Configurar bloque rds en variables/aws-personal.tfvars (db.t3.micro)
5. terraform apply → ~40 min (EKS ~10 min + RDS ~12 min + addons ~5 min)
6. Crear ExternalSecret / ClusterSecretStore manifests para ESO
7. bash scripts/bootstrap.sh  → ArgoCD + App of Apps
8. bash tests/smoke-test.sh   → evidencias cap 5
```

---

## Tiempos de despliegue estimados

| Fase | Tiempo | Coste acumulado |
|---|---|---|
| Infraestructura base (VPC, SGs, S3, DNS) | ~3 min | $0 (ya desplegado) |
| EKS cluster creation | ~8-10 min | ~$0.10/h cluster |
| EKS node group (3× t3.xlarge) | ~5-7 min | +~$0.50/h nodos |
| RDS MySQL db.t3.micro | ~10-12 min | +~$0.02/h |
| ArgoCD install + App of Apps | ~3-5 min | — |
| FIWARE sync (image pulls + init) | ~10-15 min | — |
| **Total desde cero** | **~40-50 min** | **~$0.62/h activo** |

Con Instance Scheduler (lun-vie 08:00-20:00): **~$130-150/mes**. Con Spot nodes (70% descuento en EC2): **~$60-70/mes**.

---

## Inicio rápido — AWS EKS

```bash
cd infra/terraform-framework
AWS_PROFILE=personal-account-lab terraform apply -var-file="variables/aws-personal.tfvars"
bash scripts/bootstrap.sh
bash tests/smoke-test.sh
```

---

## Arquitectura de red

```
fiware-vpc (10.0.0.0/16)  ·  eu-west-1
├── PUBLIC  (10.0.101-103.0/24)  → IGW   — ALB, NAT EIP
├── APP     (10.0.1-3.0/24)      → NAT   — EKS nodes, app servers
│     SG: eks-node-sg  (ingress VPC:1025-65535)
└── DATA    (10.0.11-13.0/24)    → NAT   — RDS, MongoDB, ElastiCache
      SG: data-sg  (ingress solo desde eks-node-sg)
           ├── 27017 MongoDB (Orion-LD)
           ├── 3306  MySQL   (Keyrock)
           ├── 5432  PostgreSQL
           └── 6379  Redis
```

## Componentes FIWARE y sync waves

| Componente | Chart | Namespace | Sync Wave |
|---|---|---|---|
| MySQL (Keyrock DB) | `bitnami/mysql 14.*` | `trust-anchor` | 0 |
| MongoDB (Orion DB) | `bitnami/mongodb 18.*` | `provider` | 0 |
| Keyrock (IdP) | `fiware/keyrock 0.8.*` | `trust-anchor` | 1 |
| Trusted Issuers List | `fiware/trusted-issuers-list 0.18.*` | `trust-anchor` | 1 |
| Credentials Config Service | `fiware/credentials-config-service 2.*` | `trust-anchor` | 1 |
| Orion-LD | `fiware/orion 1.6.*` | `provider` | 2 |

## Gestión de secretos

Los secretos **nunca están en Git**.

| Entorno | Mecanismo | Prefijo |
|---|---|---|
| AWS (EKS) | External Secrets Operator → AWS Secrets Manager | `/fiware/` |

Los `values.yaml` referencian `existingSecret: <nombre>` — los valores nunca en Git.

## Estructura del repositorio

```
tfm-fiware-gitops/
├── .github/workflows/
│   ├── terraform-validate.yml    # PR: fmt + validate + Checkov
│   ├── terraform-apply.yml       # push main: plan + apply (OIDC)
│   ├── gitops-validate.yml       # PR: helm lint + kubeconform
│   └── security-scan.yml         # push: TruffleHog + Checkov K8s
├── infra/terraform-framework/
│   ├── modules/aws/              # 25 módulos: vpc, subnet, eks, iam, s3, acm,
│   │                             #   route53, secrets-manager, instance-scheduler…
│   ├── variables/
│   │   └── aws-personal.tfvars  # Config cuenta lab (101490102336, eu-west-1)
│   ├── backend-setup.sh
│   └── main.tf
├── gitops/
│   ├── apps/
│   │   ├── app-of-apps.yaml     # Root Application ArgoCD
│   │   └── applications/        # fiware-mysql, -mongodb, -keyrock, -orion…
│   └── values/
│       ├── trust-anchor/        # keyrock, til, ccs, mysql
│       └── provider/            # orion, mongodb
├── scripts/
│   ├── bootstrap.sh             # Bootstrap EKS completo
│   └── create-secrets.sh        # K8s Secrets — NO en Git
├── tests/
│   └── smoke-test.sh            # Test E2E 4 pasos
└── docs/memoria/                # Capítulos 0-7 de la memoria TFM
```

## Métricas objetivo

| Métrica | Objetivo |
|---|---|
| Deployment Lead Time (push → Healthy) | < 10 min |
| ArgoCD Sync Time | < 3 min |
| Node Failure Recovery | < 5 min |
| Configuration Drift Detection | < 60 seg |
| Smoke Test Pass Rate | 100% |
