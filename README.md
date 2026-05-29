# tfm-fiware-gitops

> **TFM** — Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm en entornos multi-nodo sobre Amazon EKS  
> Máster DevOps UNIR · Jesús David Monsalve Lezama · Depósito: 22 julio 2026

**Repositorio GitOps puro** — source of truth que ArgoCD observa para sincronizar el clúster.  
El Terraform vive en [`tfm-terraform-framework`](https://github.com/jdmonsalvel/tfm-terraform-framework) y la documentación académica en [`tfm-fiware-docs`](https://github.com/jdmonsalvel/tfm-fiware-docs).

---

## Estructura

```
tfm-fiware-gitops/
├── .github/workflows/
│   ├── gitops-validate.yml       # PR: helm lint + kubeconform
│   └── security-scan.yml         # push: TruffleHog + Checkov K8s
│
├── gitops/
│   ├── app-of-apps.yaml          # Root Application ArgoCD (gestiona todo lo demás)
│   ├── apps/
│   │   ├── platform/             # Herramientas de plataforma k8s
│   │   │   ├── cert-manager.yaml     # wave -3
│   │   │   ├── external-secrets.yaml # wave -2
│   │   │   ├── ingress-nginx.yaml    # wave -2
│   │   │   └── monitoring.yaml       # wave -1
│   │   └── fiware/               # Componentes FIWARE Data Space
│   │       ├── mysql.yaml        # wave 0 — DB de Keyrock
│   │       ├── mongodb.yaml      # wave 0 — DB de Orion
│   │       ├── keyrock.yaml      # wave 1 — IdP / Trust Anchor
│   │       ├── til.yaml          # wave 1 — Trusted Issuers List
│   │       ├── ccs.yaml          # wave 1 — Credentials Config Service
│   │       └── orion.yaml        # wave 2 — Context Broker NGSI-LD
│   ├── values/
│   │   ├── trust-anchor/         # keyrock, til, ccs, mysql
│   │   └── provider/             # orion, mongodb
│   └── charts/                   # Charts Helm locales (keyrock, orion-ld, wilma)
│
├── scripts/
│   ├── bootstrap.sh              # Bootstrap EKS: ArgoCD + App of Apps
│   ├── create-secrets.sh         # Proyecta AWS Secrets Manager → K8s Secrets
│   └── teardown.sh               # Destruye el entorno completo
│
├── tests/
│   └── smoke-test.sh             # Test E2E 4 pasos
│
└── legacy/                       # Archivo histórico — no modificar
    ├── infra-terraform/          # Terraform (movido a tfm-terraform-framework)
    ├── gitops-v1/                # Apps ArgoCD v1 (namespace fiware, sin waves)
    ├── docs-borradores/          # Borradores antiguos de docs
    ├── docs-gitops/              # Docs de arquitectura (movidos a tfm-fiware-docs)
    ├── planificacion/            # ENTREGABLE_1, PLAN_MAYO_2026
    └── workflows-terraform/      # Pipelines Terraform (movidos a tfm-terraform-framework)
```

---

## Tres repositorios del TFM

| Repositorio | Propósito | Qué encontrarás |
|---|---|---|
| **tfm-fiware-gitops** (este) | GitOps — ArgoCD config | Apps ArgoCD, Helm values, scripts, tests |
| [tfm-terraform-framework](https://github.com/jdmonsalvel/tfm-terraform-framework) | IaC — Terraform | 25 módulos AWS, pipelines CI/CD, tfvars |
| [tfm-fiware-docs](https://github.com/jdmonsalvel/tfm-fiware-docs) | Documentación académica | Memoria TFM (caps 00-07), diagramas |

---

## Componentes FIWARE y sync waves

| Componente | Chart | Namespace | Sync Wave |
|---|---|---|---|
| cert-manager | `jetstack/cert-manager 1.*` | `cert-manager` | -3 |
| external-secrets | `external-secrets/external-secrets 0.9.*` | `external-secrets` | -2 |
| ingress-nginx | `ingress-nginx/ingress-nginx 4.*` | `ingress-nginx` | -2 |
| kube-prometheus-stack | `prometheus-community/kube-prometheus-stack` | `monitoring` | -1 |
| MySQL (Keyrock DB) | `bitnami/mysql 14.*` | `trust-anchor` | 0 |
| MongoDB (Orion DB) | `bitnami/mongodb 18.*` | `provider` | 0 |
| Keyrock (IdP) | `fiware/keyrock 0.8.*` | `trust-anchor` | 1 |
| Trusted Issuers List | `fiware/trusted-issuers-list 0.18.*` | `trust-anchor` | 1 |
| Credentials Config Service | `fiware/credentials-config-service 2.*` | `trust-anchor` | 1 |
| Orion-LD | `fiware/orion 1.6.*` | `provider` | 2 |

---

## Estado de implementación — mayo 2026

### Capa 1 — Infraestructura AWS (Terraform)

| Componente | Estado | Notas |
|---|---|---|
| VPC `fiware-vpc` (10.0.0.0/16) | ✅ Desplegado | 3 AZs eu-west-1a/b/c |
| Subnets — 3 tiers, 9 subnets | ✅ Desplegado | public · app · data |
| NAT Gateway · IGW · Route Tables | ✅ Desplegado | |
| Security Groups (4) + cross-SG rules | ✅ Desplegado | |
| S3 buckets (3) | ✅ Desplegado | state · velero · loki |
| Route53 zona `lab-jdmonsalvel.com` | ✅ Desplegado | ⚠️ Pendiente delegar NS en Cloudflare |
| ACM wildcard `*.lab-jdmonsalvel.com` | ⏳ PENDING_VALIDATION | Valida al delegar NS |
| Secrets Manager (4 secretos) | ✅ Desplegado | `/fiware/keyrock/*`, `/fiware/mysql/*`, `/fiware/mongodb/*` |
| IAM — OIDC GitHub Actions + rol | ✅ Desplegado | Zero credenciales estáticas |
| EKS cluster + node groups | ⏳ Pendiente (coste) | ~$0.60/h · descomentar bloque `eks` en tfvars |
| RDS MySQL | ⏳ Pendiente | Módulo listo · pendiente configurar en tfvars |

### Capa 2 — GitOps (ArgoCD)

| Componente | Estado |
|---|---|
| App of Apps | ✅ Implementado |
| Applications plataforma (×4) | ✅ Implementados |
| Applications FIWARE (×6) | ✅ Implementados |
| Helm values trust-anchor + provider | ✅ Implementados |
| ExternalSecret / ClusterSecretStore | ⏳ Pendiente (requiere EKS activo) |

---

## Bootstrap rápido (una vez desplegado EKS)

```bash
# 1. Kubeconfig
aws eks update-kubeconfig --name fiware-gitops --region eu-west-1

# 2. Bootstrap completo
bash scripts/bootstrap.sh

# 3. Test E2E
bash tests/smoke-test.sh
```

---

## Gestión de secretos

Los secretos **nunca están en Git**. AWS Secrets Manager → External Secrets Operator → K8s Secrets.

```
AWS Secrets Manager (/fiware/*)
        ↓  ClusterSecretStore (ESO)
  Kubernetes Secrets
        ↓  existingSecret: <nombre>
   Helm values
```

---

## Métricas objetivo

| Métrica | Objetivo |
|---|---|
| Deployment Lead Time (push → Healthy) | < 10 min |
| ArgoCD Sync Time | < 3 min |
| Node Failure Recovery | < 5 min |
| Configuration Drift Detection | < 60 seg |
| Smoke Test Pass Rate | 100% |
