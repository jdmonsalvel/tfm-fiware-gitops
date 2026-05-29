# Diagramas de Arquitectura
## TFM — Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm

Todos los diagramas están en formato **Mermaid**. Compatibles con GitHub Markdown, Obsidian, MkDocs y Pandoc (con `mermaid-filter`).

---

## Diagrama 1 — Arquitectura AWS: single account, VPC 3 capas

Muestra la infraestructura completa desplegada en AWS: tres niveles de subnets (pública, aplicación, datos), clúster EKS con los componentes FIWARE, bases de datos gestionadas (RDS MySQL para Keyrock/TIL y DocumentDB para Orion-LD), gestión de secretos mediante IRSA y estado Terraform en S3.

```mermaid
flowchart TB
    subgraph EXT["Agentes externos"]
        CONSUMER["Consumer Client\n(navegador / app)"]
        GITHUB["GitHub\ntfm-fiware-gitops"]
        DEVOPS["Operador\n(terraform apply)"]
    end

    subgraph CLOUD["AWS Single Account · eu-west-1"]
        direction TB

        subgraph VPC["VPC 10.0.0.0/16"]
            direction TB
            IGW(["Internet Gateway"])

            subgraph PUB["Subnets Públicas · 10.0.101-103.0/24 × 3 AZs"]
                ALB["ALB\n(Ingress Controller)"]
                NAT(["NAT Gateway"])
            end

            subgraph APP["Subnets Privadas App · 10.0.1-3.0/24 × 3 AZs"]
                subgraph EKS["Amazon EKS 1.29 · 3 × t3.xlarge"]
                    ARGOCD["ArgoCD\nApp of Apps"]
                    ESO["External Secrets\nOperator"]
                    AUTOSCALER["Cluster Autoscaler\n(node provisioning)"]

                    subgraph WAVE1["Sync Wave 1 · ns: trust-anchor"]
                        KEYROCK["Keyrock\nTrust Anchor"]
                        TIL["Trusted Issuers List"]
                        CCS["Credentials Config Service"]
                    end

                    subgraph WAVE2["Sync Wave 2 · ns: provider"]
                        KONG["Kong\nAPI Gateway / PEP"]
                        ORION["Orion-LD\nContext Broker NGSI-LD"]
                    end
                end
            end

            subgraph DATA["Subnets Privadas Datos · 10.0.201-203.0/24 × 3 AZs"]
                RDS[("Amazon RDS\nMySQL 8.0\nKeyrock · TIL")]
                DOCDB[("Amazon DocumentDB\nMongoDB compat.\nOrion-LD")]
            end
        end

        SM["AWS Secrets Manager\nfiware/*"]
        OIDC["IAM OIDC Provider\nIRSA"]
        S3["S3 + DynamoDB\nTerraform State Backend"]
    end

    %% Tráfico de red entrante
    CONSUMER -->|"HTTPS"| IGW
    IGW --> ALB
    ALB -->|"route"| KONG
    KONG -->|"PEP proxy"| ORION
    KONG -->|"auth check"| KEYROCK
    KONG -->|"verify VC"| TIL

    %% Persistencia
    KEYROCK -->|"MySQL 3306"| RDS
    TIL -->|"MySQL 3306"| RDS
    ORION -->|"MongoDB API 27017"| DOCDB

    %% GitOps
    GITHUB -. "poll cada 3 min" .-> ARGOCD
    ARGOCD -->|"Wave 1: helm sync"| KEYROCK
    ARGOCD -->|"Wave 2: helm sync"| KONG

    %% Secretos via IRSA
    ESO -->|"OIDC token\nAssumeRoleWithWebIdentity"| OIDC
    ESO -->|"GetSecretValue"| SM
    ESO -->|"K8s Secret"| KEYROCK
    ESO -->|"K8s Secret"| ORION

    %% Egress
    APP -. "egress\n(image pull, updates)" .-> NAT
    NAT -. "egress" .-> IGW

    %% IaC
    DEVOPS -->|"terraform apply\nVPC + EKS + RDS + DocDB"| VPC
    DEVOPS -->|"state lock"| S3
```

---

## Diagrama 2 — Flujo GitOps end-to-end

Representa el ciclo completo desde un `git push` hasta la verificación del estado del clúster, incluyendo la validación en CI y el ciclo de reconciliación de ArgoCD.

```mermaid
flowchart LR
    DEV["Desarrollador"]

    subgraph GIT["Control de versiones"]
        direction TB
        BRANCH["feature branch\n(values / manifests)"]
        PR["Pull Request"]
        MAIN["rama main\n(fuente de verdad)"]
    end

    subgraph CI["GitHub Actions CI"]
        LINT["helm lint\n(trust-anchor values)"]
        KUBEVAL["kubeval\n(ArgoCD manifests)"]
        APPROVE["Code Review\n+ Approve"]
    end

    subgraph ARGOCD["ArgoCD (en EKS)"]
        POLL["Poll Git\ncada 3 min"]
        DIFF["Calcula diff\nGit vs clúster"]
        SYNC["helm upgrade\nkubectl apply"]
        HEALTH["Health Check\n(pods Ready)"]
    end

    subgraph SMOKE["Post-sync (GitHub Actions)"]
        SMOKETEST["smoke-test.sh\n4 pasos E2E"]
        NOTIFY["Status check\nen el PR"]
    end

    DEV -->|"git push"| BRANCH
    BRANCH -->|"abre PR"| PR
    PR --> LINT & KUBEVAL
    LINT & KUBEVAL --> APPROVE
    APPROVE -->|"merge"| MAIN

    MAIN -->|"detecta cambio"| POLL
    POLL --> DIFF
    DIFF -->|"drift detectado"| SYNC
    SYNC --> HEALTH
    HEALTH -->|"Synced / Healthy"| SMOKETEST
    SMOKETEST --> NOTIFY

    NOTIFY -->|"✅ pass"| DEV
```

---

## Diagrama 3 — Flujo de autenticación SIOP-2 (E2E)

Diagrama de secuencia del protocolo SIOP-2 (Self-Issued OpenID Provider v2) implementado en FIWARE Data Spaces. Muestra los pasos desde la solicitud del Consumer hasta la respuesta de datos NGSI-LD del Provider.

```mermaid
sequenceDiagram
    actor Consumer
    participant Kong as Kong API GW<br/>(PEP Proxy)
    participant VCVerifier as VCVerifier /<br/>Trust Anchor
    participant TIL as Trusted<br/>Issuers List
    participant PDP as Policy Decision<br/>Point (OPA)
    participant OrionLD as Orion-LD<br/>(Context Broker)

    Consumer->>Kong: GET /ngsi-ld/v1/entities<br/>(sin token)
    Kong-->>Consumer: 401 Unauthorized<br/>WWW-Authenticate: VC endpoint

    Note over Consumer,VCVerifier: Flujo SIOP-2 / OIDC4VP

    Consumer->>VCVerifier: POST /oid4vp/authorize<br/>(Verifiable Presentation con VC)
    VCVerifier->>TIL: GET /issuers/{did}<br/>(verifica emisor de la VC)
    TIL-->>VCVerifier: 200 OK — emisor confiable

    VCVerifier->>VCVerifier: Valida firma VC<br/>(clave pública del emisor)
    VCVerifier-->>Consumer: JWT access_token (scoped)

    Note over Consumer,Kong: Acceso autorizado al Provider

    Consumer->>Kong: GET /ngsi-ld/v1/entities<br/>Authorization: Bearer JWT
    Kong->>PDP: POST /v1/data/policy/allow<br/>(JWT claims + recurso)
    PDP-->>Kong: { "allow": true }

    Kong->>OrionLD: GET /ngsi-ld/v1/entities<br/>(proxy interno)
    OrionLD-->>Kong: 200 OK [ {...NGSI-LD entities...} ]
    Kong-->>Consumer: 200 OK [ {...NGSI-LD entities...} ]
```

---

## Diagrama 4 — Patrón App of Apps con Sync Waves

Muestra la jerarquía de Applications en ArgoCD y el orden de despliegue garantizado por las Sync Waves. El Trust Anchor debe estar en estado `Healthy` antes de que el Connector inicie su proceso de registro.

```mermaid
flowchart TD
    subgraph GIT["Repositorio Git · rama main"]
        ROOTFILE["gitops/apps/app-of-apps.yaml"]
        TAFILE["gitops/apps/fiware-trust-anchor.yaml\nannotation: sync-wave: '1'"]
        DSFILE["gitops/apps/fiware-dataspace.yaml\nannotation: sync-wave: '2'"]
        VALUES_TA["gitops/values/trust-anchor/\nvalues-aws.yaml"]
        VALUES_DS["gitops/values/dataspace/\nvalues-provider-aws.yaml"]
    end

    subgraph ARGOCD["ArgoCD · namespace argocd"]
        AOA["Application\napp-of-apps\n(root)"]

        subgraph W1["Sync Wave 1 — se ejecuta primero"]
            APP_TA["Application\nfiware-trust-anchor\nnamespace: trust-anchor"]
        end

        subgraph W2["Sync Wave 2 — espera Wave 1 Healthy"]
            APP_DS["Application\nfiware-dataspace-provider\nnamespace: provider"]
        end
    end

    subgraph EKS["Amazon EKS · estado del clúster"]
        NS_TA["namespace: trust-anchor\nKeyrock + TIL + CCS\nHEALTHY ✓"]
        NS_PROV["namespace: provider\nKong + Orion-LD\nHEALTHY ✓"]
    end

    subgraph HELM["Helm Charts (OCI Registry)"]
        CHART_TA["fiware/trust-anchor\ntargetRevision: 0.1.*"]
        CHART_DS["fiware/data-space-connector\ntargetRevision: 7.*"]
    end

    ROOTFILE -->|"gestiona"| AOA
    AOA -->|"crea"| APP_TA & APP_DS

    TAFILE -->|"define"| APP_TA
    DSFILE -->|"define"| APP_DS

    APP_TA --> CHART_TA
    APP_TA --> VALUES_TA
    CHART_TA -->|"helm sync\nWave 1"| NS_TA

    APP_DS --> CHART_DS
    APP_DS --> VALUES_DS
    NS_TA -->|"Healthy —\nhabilita Wave 2"| APP_DS
    CHART_DS -->|"helm sync\nWave 2"| NS_PROV
```

---

## Diagrama 5 — Gestión de secretos: IRSA + External Secrets Operator

Muestra el flujo completo de proyección de secretos desde AWS Secrets Manager hasta los pods FIWARE, sin que ninguna credencial transite por el repositorio Git.

```mermaid
flowchart LR
    subgraph GIT["Repositorio Git (público)"]
        ESO_MANIFEST["ExternalSecret YAML\n(referencias, no valores)"]
        STORE_MANIFEST["ClusterSecretStore YAML\n(roleArn: arn:aws:iam::...)"]
    end

    subgraph EKS["Amazon EKS"]
        subgraph ESO_NS["namespace: external-secrets"]
            ESO_OP["External Secrets\nOperator"]
            ESO_SA["ServiceAccount\nexternal-secrets\n(IRSA annotated)"]
        end

        subgraph TRUST_NS["namespace: trust-anchor"]
            K8S_SECRET["Kubernetes Secret\n(creado por ESO)"]
            KEYROCK_POD["Pod: Keyrock\n(lee env vars del Secret)"]
        end
    end

    subgraph AWS["AWS"]
        STS["AWS STS\nAssumeRoleWithWebIdentity"]
        SM["AWS Secrets Manager\nfiware/trust-anchor:\n  adminPassword: ****\n  signingKey: ****"]
        IRSA_ROLE["IAM Role\nexternal-secrets-role\n(Trust Policy: OIDC)"]
    end

    ESO_OP -->|"1. OIDC JWT token\ndel Service Account"| ESO_SA
    ESO_SA -->|"2. AssumeRoleWithWebIdentity\n(OIDC token)"| STS
    STS -->|"3. Verifica OIDC\ny emite credenciales\ntemporales"| IRSA_ROLE
    IRSA_ROLE -->|"4. Credenciales temporales\n(15 min TTL)"| ESO_OP
    ESO_OP -->|"5. GetSecretValue\n(credenciales temporales)"| SM
    SM -->|"6. Retorna secreto\ncifrado"| ESO_OP
    ESO_OP -->|"7. Crea / actualiza\nKubernetes Secret\n(refreshInterval: 1h)"| K8S_SECRET
    K8S_SECRET -->|"8. Montado como\nenv var / volume"| KEYROCK_POD

    ESO_MANIFEST -->|"aplicado por ArgoCD"| ESO_OP
    STORE_MANIFEST -->|"aplicado por ArgoCD"| ESO_OP

    style GIT fill:#f0f0f0,stroke:#999
    style AWS fill:#ff9900,color:#fff,stroke:#e88a00
    style EKS fill:#326CE5,color:#fff,stroke:#1a5ccc
```

---

## Diagrama 6 — Alta disponibilidad: PodDisruptionBudgets y Anti-Affinity

Muestra cómo se garantiza la disponibilidad del dataspace FIWARE durante fallos de nodo o actualizaciones voluntarias del clúster, mediante la combinación de PodDisruptionBudgets y reglas de Anti-Affinity entre nodos.

```mermaid
flowchart TB
    subgraph CLUSTER["Amazon EKS · 3 nodos distribuidos en 3 AZs"]
        direction LR

        subgraph AZ_A["AZ: eu-west-1a · Node-1"]
            KONG_A["Kong\npod-1"]
            KEYROCK_A["Keyrock\npod-1"]
            ORION_A["Orion-LD\npod-1"]
        end

        subgraph AZ_B["AZ: eu-west-1b · Node-2"]
            KONG_B["Kong\npod-2"]
            KEYROCK_B["Keyrock\npod-2"]
        end

        subgraph AZ_C["AZ: eu-west-1c · Node-3"]
            KONG_C["Kong\npod-3"]
        end
    end

    subgraph PDB["PodDisruptionBudgets (garantías de disponibilidad)"]
        PDB_KONG["PDB: kong\nminAvailable: 2"]
        PDB_KEYROCK["PDB: keyrock\nminAvailable: 1"]
        PDB_ORION["PDB: orion-ld\nminAvailable: 1"]
    end

    subgraph ANTIAFFINITY["Anti-Affinity Rules (distribución entre nodos)"]
        AA_RULE["preferredDuringSchedulingIgnoredDuringExecution\ntopologyKey: kubernetes.io/hostname\n(evita colocar replicas en el mismo nodo)"]
    end

    subgraph CA["Cluster Autoscaler"]
        CA_SCALE["Detecta pods Pending\n→ provisiona nuevo nodo EKS"]
        CA_DRAIN["Nodo drenado voluntariamente\n→ PDB impide evictar si viola mínimos"]
    end

    PDB_KONG -.->|"protege"| KONG_A & KONG_B & KONG_C
    PDB_KEYROCK -.->|"protege"| KEYROCK_A & KEYROCK_B
    PDB_ORION -.->|"protege"| ORION_A
    AA_RULE -.->|"distribuye"| AZ_A & AZ_B & AZ_C
    CA_DRAIN -->|"consulta PDB\nantes de drenar"| PDB
```

---

## Resumen de diagramas

| # | Diagrama | Tipo Mermaid | Sección TFM |
|---|----------|-------------|-------------|
| 1 | Arquitectura AWS completa (3 capas) | `flowchart TB` | Cap 3 §3.4 / Cap 4 §4.0 |
| 2 | Flujo GitOps end-to-end | `flowchart LR` | Cap 4 §4.4 |
| 3 | Flujo autenticación SIOP-2 | `sequenceDiagram` | Cap 4 §4.1 |
| 4 | App of Apps con Sync Waves | `flowchart TD` | Cap 4 §4.3 |
| 5 | Gestión de secretos IRSA + ESO | `flowchart LR` | Cap 4 §4.3.4 |
| 6 | Alta disponibilidad PDB + Anti-Affinity | `flowchart TB` | Cap 4 §4.5 |
