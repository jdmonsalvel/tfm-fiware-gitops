# Catálogo de Diagramas — TFM GitOps FIWARE

Todos los diagramas están en formato **Mermaid** y se renderizan automáticamente en GitHub.
Para incluirlos en la memoria LaTeX, ver la sección [Guía de Exportación](#guía-de-exportación-para-latex) al final de este documento.

---

## D1 — Arquitectura Global del Sistema (Vista Contextual C4 — Level 1)

> **Capítulo de referencia:** 4. Arquitectura y Diseño — Figura 4.1  
> **Descripción:** Identifica los actores principales, el sistema central y los sistemas externos con los que interactúa la plataforma. Corresponde al nivel más alto de abstracción del modelo C4 (Brown, 2018).

```mermaid
graph TB
    DEV["👤 Ingeniero DevOps\n(Actor Primario)"]
    CONSUMER["👤 Consumidor de Datos\n(Actor Externo)"]
    PROVIDER["👤 Proveedor de Datos\n(Actor Externo)"]

    subgraph CENTRAL["Sistema Central — Plataforma GitOps FIWARE"]
        GITOPS["GitOps Layer\nArgoCD + GitHub"]
        FIWARE_SYS["FIWARE Data Space\nOrion-LD + Keyrock + Wilma"]
        INFRA["Infraestructura AWS\nEKS + VPC + Secrets"]
    end

    TRUST["iSHARE Satellite\n(Trust Anchor Externo)"]
    REPO["GitHub Repository\n(Source of Truth)"]

    DEV -->|"Gestiona IaC y manifests"| REPO
    REPO -->|"Sincroniza estado deseado"| GITOPS
    GITOPS -->|"Despliega y reconcilia"| FIWARE_SYS
    GITOPS -->|"Provisiona infraestructura"| INFRA
    FIWARE_SYS -->|"Valida políticas de acceso"| TRUST
    CONSUMER -->|"NGSI-LD REST API"| FIWARE_SYS
    PROVIDER -->|"Publica datasets"| FIWARE_SYS
```

---

## D2 — Arquitectura de Contenedores (Vista C4 — Level 2)

> **Capítulo de referencia:** 4. Arquitectura y Diseño — Figura 4.2  
> **Descripción:** Desglosa el sistema central en sus contenedores software (procesos, servicios, almacenes de datos), sus tecnologías y las interfaces de comunicación entre ellos.

```mermaid
graph TB
    subgraph GITHUB["GitHub (VCS + CI)"]
        REPO_IaC["infrastructure/terraform\n[HCL]"] 
        REPO_GO["gitops/apps + charts\n[YAML / Helm]"]
        GA["GitHub Actions\n[Workflows CI/CD]"]
    end

    subgraph AWS["AWS Cloud (eu-west-1)"]
        subgraph VPC["VPC / EKS Cluster 1.30"]
            subgraph GITOPS_NS["Namespace: argocd"]
                ARGOCD["ArgoCD Server\n+ Application Controller"]
                APPOFAPPS["App of Apps\n[ArgoCD CRD raíz]"]
            end
            subgraph FIWARE_NS["Namespace: fiware"]
                ORION["Orion-LD\nContext Broker :1026"]
                KEYROCK["Keyrock IdM\n:3000"]
                WILMA["Wilma PEP Proxy\n:1027"]
                MONGO["MongoDB :27017\n[NGSI-LD Store]"]
                MYSQL["MySQL :3306\n[Keyrock Store]"]
            end
            subgraph PLATFORM_NS["Namespace: platform"]
                ESO["External Secrets Operator\n[IRSA → Secrets Manager]"]
                CERTMGR["Cert-Manager\n[Let's Encrypt]"]
                NGINX["Nginx Ingress Controller"]
            end
            subgraph OBS_NS["Namespace: monitoring"]
                PROM["Prometheus"]
                GRAFANA["Grafana"]
            end
        end
        SM["AWS Secrets Manager"]
        ECR["ECR"]
    end

    REPO_GO -->|"webhook / poll 3min"| ARGOCD
    ARGOCD --> APPOFAPPS
    APPOFAPPS -->|"sync"| ORION & KEYROCK & WILMA & ESO
    ESO -->|"ExternalSecret CRD"| SM
    SM -->|"Secret values"| ESO
    ESO -->|"K8s Secret"| KEYROCK & ORION
    WILMA -->|"auth request (HTTP)"| KEYROCK
    WILMA -->|"forward NGSI-LD"| ORION
    ORION --> MONGO
    KEYROCK --> MYSQL
    NGINX -->|"route /ngsi-ld/v1"| WILMA
    NGINX -->|"route /idm"| KEYROCK
    GA -->|"validate + lint"| REPO_GO
    GA -->|"terraform apply"| AWS
```

---

## D3 — Topología de Red AWS

> **Capítulo de referencia:** 4. Arquitectura y Diseño — Figura 4.3  
> **Descripción:** Representa la distribución de subredes en tres Zonas de Disponibilidad (AZ) dentro de la VPC, garantizando alta disponibilidad y aislamiento de red según el modelo de responsabilidad compartida de AWS.

```mermaid
graph TB
    INTERNET["Internet"]
    IGW["Internet Gateway"]

    subgraph AWS["AWS Region: eu-west-1"]
        subgraph VPC["VPC 10.0.0.0/16"]
            subgraph AZA["AZ: eu-west-1a"]
                PUB_A["Public Subnet\n10.0.1.0/24\n(ALB, NAT Gateway)"]
                PRV_A["Private Subnet\n10.0.10.0/24\n(EKS Worker Nodes)"]
            end
            subgraph AZB["AZ: eu-west-1b"]
                PUB_B["Public Subnet\n10.0.2.0/24\n(ALB)"]
                PRV_B["Private Subnet\n10.0.11.0/24\n(EKS Worker Nodes)"]
            end
            subgraph AZC["AZ: eu-west-1c"]
                PUB_C["Public Subnet\n10.0.3.0/24\n(ALB)"]
                PRV_C["Private Subnet\n10.0.12.0/24\n(EKS Worker Nodes)"]
            end
            NAT["NAT Gateway\n(Egress privado)"]
            ALB["Application Load Balancer\n(Entrada pública HTTPS)"]
        end
        EKS_CP["EKS Control Plane\n(AWS Fully Managed)"]
        SM["Secrets Manager\n(VPC Endpoint)"]
        ECR["ECR\n(VPC Endpoint)"]
    end

    INTERNET --> IGW --> ALB
    ALB --- PUB_A & PUB_B & PUB_C
    PUB_A --> NAT
    PRV_A & PRV_B & PRV_C -->|egress| NAT --> IGW
    PRV_A & PRV_B & PRV_C <-->|ENI| EKS_CP
    EKS_CP -.->|VPC Endpoint| SM & ECR
```

---

## D4 — Flujo de Acceso Controlado en el Data Space (iSHARE)

> **Capítulo de referencia:** 4. Arquitectura y Diseño — Figura 4.4  
> **Descripción:** Protocolo de acceso federado siguiendo el marco de confianza iSHARE. El flujo implementa el patrón de delegación de autorización mediante JWT + XACML policy evaluation.

```mermaid
sequenceDiagram
    participant DC as Data Consumer
    participant WILMA as Wilma PEP Proxy
    participant KEYROCK as Keyrock IdM
    participant SATELLITE as iSHARE Satellite
    participant ORION as Orion-LD

    DC->>KEYROCK: ① POST /oauth2/token\n(client_credentials + iSHARE JWT)
    KEYROCK->>SATELLITE: ② Validate participant certificate\n(eIDAS / X.509)
    SATELLITE-->>KEYROCK: ③ Trusted party confirmed
    KEYROCK-->>DC: ④ Access Token (JWT, exp: 30s)

    DC->>WILMA: ⑤ GET /ngsi-ld/v1/entities\nAuthorization: Bearer <JWT>
    WILMA->>KEYROCK: ⑥ POST /authzforce/pdp\n(JWT + resource + action)
    KEYROCK->>KEYROCK: ⑦ Evaluate XACML policy\n(AuthzForce CE)
    KEYROCK-->>WILMA: ⑧ Permit / Deny

    alt Permit
        WILMA->>ORION: ⑨ Forward NGSI-LD request\n(stripped Authorization header)
        ORION-->>WILMA: ⑩ Entity data (JSON-LD)
        WILMA-->>DC: ⑪ 200 OK + datos NGSI-LD
    else Deny
        WILMA-->>DC: ⑪ 403 Forbidden
    end
```

---

## D5 — Pipeline CI/CD

> **Capítulo de referencia:** 5. Implementación — Figura 5.1  
> **Descripción:** Flujo completo del pipeline de integración y entrega continua, con gates de seguridad y aprobación manual para cambios de infraestructura.

```mermaid
flowchart TD
    PUSH["git push"] --> BRANCH{Tipo de rama}

    BRANCH -->|"feature/* fix/*"| PR_CHECKS["Pull Request Checks"]
    BRANCH -->|"main"| MAIN_PIPE["Main Branch Pipeline"]

    subgraph PR_CHECKS["Checks PR — en paralelo"]
        PC1["helm lint charts/"]
        PC2["kubeconform gitops/"]
        PC3["terraform validate"]
        PC4["checkov --check CKV_AWS"]
        PC5["truffleHog3 scan"]
    end
    PC1 & PC2 & PC3 & PC4 & PC5 --> PR_GATE{¿Todo OK?}
    PR_GATE -->|"✓"| PR_OK["✅ PR aprobable"]
    PR_GATE -->|"✗"| PR_FAIL["❌ Bloquear merge\n+ comentario automático"]

    subgraph MAIN_PIPE["Main Pipeline"]
        MP1["terraform plan\n+ diff output"]
        MP2["gitops diff\nvs cluster actual"]
        MP3{¿Cambios en\ninfra Terraform?}
    end
    MP1 & MP2 --> MP3
    MP3 -->|"Sí"| GATE["⏸️ Manual Approval\n(GitHub Environment: prod)"]
    MP3 -->|"No"| ARGO_SYNC
    GATE -->|"Aprobado"| TF_APPLY["terraform apply\n(remote state S3 + DynamoDB lock)"]
    TF_APPLY --> ARGO_SYNC["ArgoCD webhook → reconcile"]
    ARGO_SYNC --> HEALTH{¿Healthy?}
    HEALTH -->|"✓"| DONE["✅ Deploy OK"]
    HEALTH -->|"✗"| ROLLBACK["⚠️ ArgoCD rollback\n+ alerta"]
```

---

## D6 — Ciclo de Vida de Sincronización ArgoCD

> **Capítulo de referencia:** 4. Arquitectura y Diseño — Figura 4.5  
> **Descripción:** Máquina de estados que representa el ciclo de vida de una Application ArgoCD, desde su creación hasta la detección de drift y re-sincronización.

```mermaid
stateDiagram-v2
    [*] --> Unknown : Application CRD creada
    Unknown --> OutOfSync : ArgoCD calcula desired state
    OutOfSync --> Syncing : auto-sync habilitado\no sync manual
    Syncing --> Synced : kubectl apply OK\ntodos los recursos Healthy
    Synced --> OutOfSync : nuevo commit en repo\no drift manual en cluster
    Syncing --> Degraded : health check falla\ntras kubectl apply
    Degraded --> OutOfSync : fix en repo → retry
    Synced --> [*] : Application eliminada

    note right of Synced
        Estado objetivo sostenido.
        ArgoCD continúa monitorizando
        desviaciones del estado deseado.
    end note
    note right of OutOfSync
        El repositorio Git es la única
        fuente de verdad (Single Source
        of Truth). El cluster debe
        converger hacia este estado.
    end note
```

---

## D7 — Modelo de Datos NGSI-LD

> **Capítulo de referencia:** 2. Estado del Arte — Figura 2.2  
> **Descripción:** Modelo conceptual de una entidad NGSI-LD según la especificación ETSI GS CIM 009. Define la estructura de propiedades, relaciones y metadatos temporales.

```mermaid
classDiagram
    class Entity {
        +URI id
        +URI type
        +Context @context
    }

    class Property {
        +String type = "Property"
        +Any value
        +DateTime observedAt
        +String unitCode
        +Number datasetId
    }

    class Relationship {
        +String type = "Relationship"
        +URI object
        +DateTime observedAt
    }

    class GeoProperty {
        +String type = "GeoProperty"
        +GeoJSON value
    }

    class TemporalProperty {
        +Array~Property~ values
        +DateTime from
        +DateTime to
    }

    Entity --> "1..*" Property : hasProperty
    Entity --> "0..*" Relationship : hasRelationship
    Entity --> "0..*" GeoProperty : hasGeoProperty
    Property --> "0..*" Property : subProperty
    Property --|> TemporalProperty : extends
    Relationship --> Entity : pointsTo
```

---

## Guía de Exportación para LaTeX

### Opción A — Mermaid Live (Recomendada para TFM)

1. Ir a [https://mermaid.live](https://mermaid.live)
2. Pegar el bloque Mermaid del diagrama deseado
3. Seleccionar theme `neutral` (fondo blanco, adecuado para impresión académica)
4. Exportar como **SVG**
5. Convertir SVG → PDF vectorial con Inkscape:
   ```bash
   inkscape --export-type=pdf --export-filename=d1_arquitectura.pdf d1_arquitectura.svg
   ```

### Opción B — CLI mmdc

```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i d1_arquitectura.mmd -o d1_arquitectura.pdf \
     -t neutral -b white --width 1400 --height 900
```

### Opción C — draw.io (Para diagramas de mayor calidad visual)

Para D1, D2 y D3 se recomienda recrearlos en [draw.io](https://draw.io) con iconos oficiales:
- **AWS Architecture Icons:** https://aws.amazon.com/architecture/icons/
- **Kubernetes Icons:** https://github.com/kubernetes/community/tree/master/icons
- **FIWARE logos:** https://www.fiware.org/brand-guide/

### Tabla de figuras para LaTeX

| Diagrama | Archivo recomendado | Capítulo | Etiqueta LaTeX |
|---------|---------------------|---------|----------------|
| D1 — Contexto global | `d1_contexto_global.pdf` | Cap. 4 | `fig:d1-contexto` |
| D2 — Contenedores C4 | `d2_contenedores.pdf` | Cap. 4 | `fig:d2-contenedores` |
| D3 — Topología red | `d3_topologia_red.pdf` | Cap. 4 | `fig:d3-red` |
| D4 — Flujo iSHARE | `d4_flujo_ishare.pdf` | Cap. 4 | `fig:d4-ishare` |
| D5 — Pipeline CI/CD | `d5_pipeline.pdf` | Cap. 5 | `fig:d5-pipeline` |
| D6 — Estados ArgoCD | `d6_estados_argocd.pdf` | Cap. 4 | `fig:d6-argocd` |
| D7 — Modelo NGSI-LD | `d7_ngsi_ld.pdf` | Cap. 2 | `fig:d7-ngsi-ld` |

### Snippet LaTeX de referencia

```latex
\begin{figure}[htbp]
  \centering
  \includegraphics[width=0.95\textwidth]{figuras/d1_contexto_global.pdf}
  \caption{Arquitectura global del sistema — vista contextual (C4 Level 1).}
  \label{fig:d1-contexto}
\end{figure}
```
