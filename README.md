# TFM — Plataforma GitOps para Data Spaces basada en FIWARE sobre AWS

> **Trabajo Fin de Máster** — Máster Universitario en DevOps y Cloud  
> **Universidad Internacional de La Rioja (UNIR)** — Curso 2025-2026  
> **Autor:** Jesús Monsalve  
> **Fecha de entrega:** 6 de mayo de 2026

[![Terraform Validate](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/terraform-validate.yml)
[![GitOps Validate](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/gitops-validate.yml/badge.svg)](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/gitops-validate.yml)
[![Security Scan](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/security-scan.yml/badge.svg)](https://github.com/jdmonsalvel/tfm-fiware-gitops/actions/workflows/security-scan.yml)

---

## Descripción

Este repositorio contiene el artefacto técnico del TFM, que propone y valida un **modelo de referencia arquitectónico** para el despliegue automatizado, reproducible y auditable de una plataforma de **Data Space** basada en componentes FIWARE sobre infraestructura AWS, siguiendo el paradigma **GitOps** mediante ArgoCD y Helm.

La solución integra:
- **Orion-LD** como Context Broker NGSI-LD (ETSI GS CIM 009)
- **Keyrock** como Identity Manager con soporte OAuth2/OpenID Connect e iSHARE
- **Wilma** como PEP Proxy para aplicación de políticas de acceso (XACML)
- **iSHARE/DSBA** como marco de confianza interoperable para Data Spaces europeos
- **ArgoCD** como operador GitOps para sincronización continua declarativa
- **Terraform** para aprovisionamiento de infraestructura como código (IaC)
- **External Secrets Operator** + AWS Secrets Manager para gestión segura de secretos
- **GitHub Actions** para pipelines CI con validación, escaneo de seguridad y gates de aprobación

---

## Arquitectura Global del Sistema

```mermaid
graph TB
    subgraph GH["GitHub — Single Source of Truth"]
        GH_IaC[infrastructure/terraform]
        GH_GO[gitops/apps + charts]
        GH_DOC[docs/memoria]
    end

    subgraph CI["GitHub Actions — CI Pipeline"]
        GA1[Terraform Validate + Checkov]
        GA2[Helm Lint + Kubeconform]
        GA3[TruffleHog Secrets Scan]
    end

    subgraph AWS["AWS Cloud — eu-west-1"]
        subgraph VPC["VPC 10.0.0.0/16 — 3 AZs"]
            ALB[Application Load Balancer]
            subgraph EKS["EKS Cluster 1.30"]
                subgraph ARGO_NS["argocd namespace"]
                    ARGOCD[ArgoCD Controller]
                    APPOFAPPS[App of Apps]
                end
                subgraph FIWARE_NS["fiware namespace"]
                    ORION[Orion-LD\nContext Broker]
                    KEYROCK[Keyrock IdM]
                    WILMA[Wilma PEP Proxy]
                    MONGO[(MongoDB)]
                end
                subgraph PLATFORM_NS["platform namespace"]
                    ESO[External Secrets Operator]
                    CERTMGR[Cert-Manager]
                    NGINX[Nginx Ingress]
                    PROMETHEUS[Prometheus + Grafana]
                end
            end
        end
        SM[AWS Secrets Manager]
        ECR[Elastic Container Registry]
        CW[CloudWatch Logs]
    end

    subgraph DS["Data Space Ecosystem"]
        CONSUMER[Data Consumer]
        SATELLITE[iSHARE Satellite\nTrust Anchor]
    end

    GH_IaC -->|apply| AWS
    GH_GO -->|sync| ARGOCD
    GH_IaC --> GA1
    GH_GO --> GA2
    GH_GO --> GA3
    ARGOCD --> APPOFAPPS --> ORION & KEYROCK & WILMA & ESO & PROMETHEUS
    ESO --> SM
    ALB --> NGINX --> WILMA --> ORION
    KEYROCK --> SATELLITE
    CONSUMER --> ALB
```

---

## Flujo GitOps

```mermaid
sequenceDiagram
    participant Dev as Ingeniero DevOps
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ARGO as ArgoCD
    participant EKS as EKS / Kubernetes

    Dev->>GH: git push (feature/*)
    GH->>GA: trigger: pull_request
    GA->>GA: helm lint + kubeconform
    GA->>GA: checkov (IaC security)
    GA->>GA: truffleHog (secrets scan)
    GA-->>GH: ✓ status checks passed
    Dev->>GH: Merge PR → main
    GH->>GA: trigger: push to main
    GA->>GA: terraform validate + plan
    GA-->>Dev: plan output + manual gate
    Note over ARGO,EKS: Webhook / polling cada 3 min
    ARGO->>GH: detecta nuevo commit en main
    ARGO->>ARGO: calcula diff desired vs live state
    ARGO->>EKS: kubectl apply (reconcile loop)
    EKS-->>ARGO: health / readiness status
    ARGO-->>Dev: ✅ Synced / ⚠️ Degraded
```

---

## Flujo de Acceso en el Data Space

```mermaid
graph LR
    DC[Data Consumer] -->|"① JWT + Request"| WILMA[Wilma PEP Proxy]
    WILMA -->|"② Validate token"| KEYROCK[Keyrock IdM]
    KEYROCK -->|"③ Check policy"| SATELLITE[iSHARE Satellite]
    SATELLITE -->|"④ Policy decision"| KEYROCK
    KEYROCK -->|"⑤ Permit / Deny"| WILMA
    WILMA -->|"⑥ Forward NGSI-LD request"| ORION[Orion-LD]
    ORION -->|"⑦ Query"| MONGO[(MongoDB)]
    MONGO -->|"⑧ Data"| ORION
    ORION -->|"⑨ NGSI-LD response"| WILMA
    WILMA -->|"⑩ Response"| DC
```

---

## Estructura del Repositorio

```
tfm-fiware-gitops/
├── docs/
│   ├── memoria/          # Capítulos TFM — Markdown (→ LaTeX UNIR)
│   └── diagrams/         # Todos los diagramas Mermaid + guía exportación
├── infrastructure/
│   └── terraform/        # IaC: VPC, EKS, IAM, Secrets Manager
│       └── modules/
│           ├── vpc/
│           └── eks/
├── gitops/
│   ├── bootstrap/        # ArgoCD install + App of Apps root
│   ├── apps/             # ArgoCD Application CRDs
│   └── charts/           # Helm charts FIWARE personalizados
│       ├── orion-ld/
│       ├── keyrock/
│       └── wilma/
├── scripts/              # bootstrap.sh + teardown.sh
└── .github/workflows/    # CI/CD pipelines
```

---

## Cronograma de Implementación

| Fase | Período | Entregables |
|------|---------|-------------|
| 1 — Infraestructura | 20–25 Abr 2026 | VPC + EKS funcional via Terraform |
| 2 — GitOps Bootstrap | 26–28 Abr 2026 | ArgoCD operativo + App of Apps |
| 3 — FIWARE Stack | 29 Abr – 2 May 2026 | Orion-LD + Keyrock + Wilma desplegados |
| 4 — Integración Data Space | 3–4 May 2026 | Flujo E2E con iSHARE |
| 5 — Validación y evidencias | 5 May 2026 | Capturas, métricas, pruebas |
| 6 — Entrega final | 6 May 2026 | Demo + memoria LaTeX |

---

## Coste Estimado AWS

| Servicio | Tipo | Coste/día (est.) |
|---------|------|------------------|
| EKS Control Plane | Managed | ~$2.40 |
| EC2 Worker Nodes (2× t3.medium) | On-Demand | ~$4.80 |
| NAT Gateway | Managed | ~$1.08 |
| Application Load Balancer | Managed | ~$0.70 |
| Secrets Manager | Per secret | ~$0.12 |
| **Total estimado** | | **~$9–16/día** |

> Destruir el entorno con `scripts/teardown.sh` cuando no se use para minimizar costes.

---

## Licencia

MIT License — © 2026 Jesús Monsalve
