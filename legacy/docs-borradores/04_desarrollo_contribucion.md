# Capítulo 4 — Desarrollo de la Contribución

## 4.0 Plataforma de despliegue: Amazon Web Services

El despliegue de producción del pipeline GitOps se realiza sobre **Amazon Web Services (AWS)** en la región **eu-west-1 (Irlanda)**. Esta elección se fundamenta en los siguientes criterios técnicos:

| Criterio | Decisión AWS | Alternativa descartada | Razón |
|---------|-------------|----------------------|-------|
| Kubernetes gestionado | Amazon EKS 1.29 | EKS self-managed / GKE | EKS managed elimina overhead de control plane; LTS con soporte extendido |
| Autenticación cloud | IRSA (IAM Roles for Service Accounts) via OIDC | Credenciales estáticas en Secrets | IRSA no expone credenciales long-lived; alineado con política de seguridad |
| Secretos | AWS Secrets Manager | HashiCorp Vault (self-hosted) | Integración nativa ESO sin infraestructura adicional; coste operativo cero |
| Networking | VPC 3-tier: pública + app privada + datos privada | VPC 2-tier (sin subnet de datos dedicada) | Aislamiento de red entre cómputo y persistencia; RDS/DocDB sin ruta a Internet |
| Ingress | AWS Load Balancer Controller (ALB) | NGINX Ingress manual | Provisionamiento automático desde anotaciones K8s; integración nativa con Route 53 y ACM |
| Instancias | t3.xlarge (4 vCPU / 16 GB) | t3.large (2 vCPU / 8 GB) | Los componentes FIWARE requieren 8-10 GB RAM en conjunto; t3.large produce OOMKilled |
| Persistencia Keyrock + TIL | Amazon RDS MySQL 8.0 | StatefulSet MySQL en EKS | Desacopla estado del clúster de cómputo; backups automáticos, Multi-AZ nativo, encriptación en reposo |
| Persistencia Orion-LD | Amazon DocumentDB (MongoDB compat.) | StatefulSet MongoDB en EKS | Misma justificación que RDS; evita gestión de PersistentVolumes para datos operacionales |
| Terraform state | S3 bucket + DynamoDB Lock | Local state | Estado remoto auditable; bloqueo evita aplicaciones concurrentes destructivas |
| Alta disponibilidad de pods | PodDisruptionBudgets + Anti-Affinity | Sin PDB | PDB impide evicción simultanea de todas las réplicas durante drain de nodo |

La infraestructura se destruye tras la demo para minimizar costes (estimado: $16/día On-Demand, $5-6/día con Spot instances).

## 4.1 Análisis del FIWARE Data Space Connector

### 4.1.1 Arquitectura de componentes

El FIWARE Data Space Connector implementa el modelo de referencia DSBA (Data Spaces Business Alliance) para el intercambio de datos basado en Verifiable Credentials (VC) y el protocolo SIOP-2/OIDC4VP. La arquitectura de confianza se fundamenta en tres roles:

**Trust Anchor**: Entidad raíz del data space que gestiona el registro de participantes y la emisión de credenciales verificables. En la implementación FIWARE, el componente que cumple este rol es **Keyrock**, el gestor de identidades open source de FIWARE.

**Provider**: Organización que expone datos o servicios. Sus componentes principales son:
- **Orion-LD**: Context broker NGSI-LD que almacena y sirve los datos
- **Kong**: API Gateway que actúa como PEP (Policy Enforcement Point)
- **APISIX / Scorpio**: Alternativas al stack Orion+Kong según la variante del chart

**Consumer**: Organización que accede a los datos del Provider. Incluye:
- **Wallet**: Almacén de credenciales verificables del Consumer
- **VCVerifier**: Verifica las credenciales presentadas durante el flujo de autenticación

### 4.1.2 Flujo de autenticación E2E

El flujo de autenticación implementado sigue el protocolo **SIOP-2** (Self-Issued OpenID Provider v2):

```
Consumer App
    │
    ├─1─► Provider Kong (solicita acceso a recurso protegido)
    │         │
    │         └─2─► Devuelve endpoint de autenticación
    │
    ├─3─► Trust Anchor / VCVerifier (presenta Verifiable Presentation)
    │         │
    │         ├─4─► Verifica VC contra Trusted Issuers List
    │         └─5─► Genera JWT token
    │
    ├─6─► Provider Kong (presenta JWT)
    │         │
    │         ├─7─► PDP evalúa política de acceso
    │         └─8─► Proxy hacia Orion-LD
    │
    └─9─► Recibe datos NGSI-LD del context broker
```

### 4.1.3 Dependencias del Helm Umbrella

El chart `data-space-connector` declara las siguientes dependencias (sub-charts):

```yaml
# Chart.yaml (simplificado)
dependencies:
  - name: trust-anchor
    repository: https://fiware.github.io/helm-charts
    version: "~0.1"
  - name: trusted-issuers-list
    repository: https://fiware.github.io/helm-charts
    version: "~0.5"
  - name: credentials-config-service
    repository: https://fiware.github.io/helm-charts
    version: "~0.3"
  - name: orion-ld
    repository: https://fiware.github.io/helm-charts
    version: "~1.4"
  - name: kong
    repository: https://charts.konghq.com
    version: "~2.26"
```

## 4.2 Fase 2: Despliegue baseline con Helm directo

### 4.2.1 Entorno single-node (k3s en EC2)

Para la línea base, se utiliza un clúster k3s en una instancia EC2 `t3.xlarge` (4 vCPU, 16 GB RAM), suficiente para ejecutar todos los componentes FIWARE en un único nodo.

**Aprovisionamiento del nodo:**

```bash
# Instalar k3s sin traefik (usaremos NGINX Ingress)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Instalar NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

**Despliegue manual del Trust Anchor:**

```bash
helm repo add fiware https://fiware.github.io/helm-charts
helm repo update

helm install trust-anchor fiware/trust-anchor \
  --namespace trust-anchor --create-namespace \
  --values values/trust-anchor/values-baseline.yaml \
  --wait --timeout 10m
```

**Despliegue del Data Space Connector (Provider):**

```bash
helm install fiware-provider fiware/data-space-connector \
  --namespace provider --create-namespace \
  --values values/dataspace/values-provider-baseline.yaml \
  --wait --timeout 15m
```

### 4.2.2 Validación baseline — Smoke Test

```bash
#!/usr/bin/env bash
# tests/smoke-test.sh — Validación E2E baseline

set -euo pipefail

TRUST_ANCHOR_URL="${TRUST_ANCHOR_URL:-http://trust-anchor.local}"
PROVIDER_URL="${PROVIDER_URL:-http://provider.local}"

echo "=== [1/4] Verificando Trust Anchor health ==="
curl -sf "${TRUST_ANCHOR_URL}/health" | jq '.status' | grep -q "OK"
echo "  ✓ Trust Anchor disponible"

echo "=== [2/4] Obteniendo token del Consumer ==="
TOKEN=$(curl -sf -X POST "${TRUST_ANCHOR_URL}/oauth2/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  | jq -r '.access_token')
[ -n "$TOKEN" ] && echo "  ✓ Token obtenido"

echo "=== [3/4] Accediendo a datos protegidos en Provider ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "${PROVIDER_URL}/ngsi-ld/v1/entities")
[ "$HTTP_CODE" = "200" ] && echo "  ✓ Acceso autorizado (HTTP 200)"

echo "=== [4/4] Verificando integridad de datos NGSI-LD ==="
curl -sf -H "Authorization: Bearer ${TOKEN}" \
  "${PROVIDER_URL}/ngsi-ld/v1/entities" \
  | jq 'type == "array"' | grep -q "true"
echo "  ✓ Respuesta NGSI-LD válida"

echo ""
echo "✅ SMOKE TEST PASSED — Flujo E2E validado"
```

## 4.3 Fase 3: Pipeline GitOps en AWS EKS

### 4.3.1 Aprovisionamiento de infraestructura con Terraform

La infraestructura se define mediante **archivos `tfvars`** que parametrizan los módulos existentes del framework IaC. Este patrón garantiza que los módulos permanecen genéricos y reutilizables, y que todos los recursos específicos del proyecto quedan expresados en un único punto de configuración.

El framework IaC incluye módulos para VPC, subnets, security groups, NAT Gateway, Internet Gateway y EC2. Los módulos de EKS, RDS y DocumentDB se añaden al framework siguiendo el mismo patrón `map(object({...}))` antes de ser invocados desde `tfvars`. La estructura de módulos no se toca para crear recursos: solo se extiende cuando hace falta funcionalidad que el tfvars no puede expresar con los módulos actuales.

**Estado remoto de Terraform (`infra/backend.tf`):**

El estado se almacena en S3 con bloqueo DynamoDB para garantizar idempotencia y evitar aplicaciones concurrentes destructivas. Este archivo es infraestructura del propio pipeline, no un recurso de aplicación:

```hcl
terraform {
  backend "s3" {
    bucket         = "tfm-fiware-terraform-state"
    key            = "fiware-gitops/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "tfm-fiware-terraform-lock"
  }
}
```

**Configuración de la infraestructura (`infra/variables/lab.tfvars`):**

Todos los recursos del proyecto — VPC con sus tres capas de subnets, security groups, clúster EKS, instancia RDS y clúster DocumentDB — se declaran en el fichero `tfvars`. El módulo `subnet` crea las subnets de las tres capas; `db-subnet-group` agrupa las de datos para RDS y DocumentDB; `security-group` define las reglas de acceso entre capas.

```hcl
# ── VPC ──────────────────────────────────────────────────────────────────────
vpc = {
  fiware-gitops = {
    name       = "fiware-gitops-vpc"
    cidr_block = "10.0.0.0/16"
    tags       = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
}

# ── Subnets: 3 capas × 3 AZs ────────────────────────────────────────────────
subnets = {
  # Capa 1 — pública: ALB, NAT Gateway
  public-a = { name = "public-eu-west-1a", cidr_block = "10.0.101.0/24", az = "eu-west-1a", vpc_name = "fiware-gitops", public = true }
  public-b = { name = "public-eu-west-1b", cidr_block = "10.0.102.0/24", az = "eu-west-1b", vpc_name = "fiware-gitops", public = true }
  public-c = { name = "public-eu-west-1c", cidr_block = "10.0.103.0/24", az = "eu-west-1c", vpc_name = "fiware-gitops", public = true }

  # Capa 2 — privada app: nodos EKS
  private-a = { name = "private-eu-west-1a", cidr_block = "10.0.1.0/24", az = "eu-west-1a", vpc_name = "fiware-gitops", public = false }
  private-b = { name = "private-eu-west-1b", cidr_block = "10.0.2.0/24", az = "eu-west-1b", vpc_name = "fiware-gitops", public = false }
  private-c = { name = "private-eu-west-1c", cidr_block = "10.0.3.0/24", az = "eu-west-1c", vpc_name = "fiware-gitops", public = false }

  # Capa 3 — privada datos: RDS y DocumentDB (sin ruta a Internet)
  data-a = { name = "data-eu-west-1a", cidr_block = "10.0.201.0/24", az = "eu-west-1a", vpc_name = "fiware-gitops", public = false }
  data-b = { name = "data-eu-west-1b", cidr_block = "10.0.202.0/24", az = "eu-west-1b", vpc_name = "fiware-gitops", public = false }
  data-c = { name = "data-eu-west-1c", cidr_block = "10.0.203.0/24", az = "eu-west-1c", vpc_name = "fiware-gitops", public = false }
}

# ── DB Subnet Group (agrupa subnets de datos para RDS y DocumentDB) ──────────
db_subnet_groups = {
  fiware-data = {
    name        = "fiware-data"
    description = "Subnets de datos para RDS y DocumentDB del proyecto FIWARE"
    subnet_names = ["data-eu-west-1a", "data-eu-west-1b", "data-eu-west-1c"]
  }
}

# ── Security Groups ──────────────────────────────────────────────────────────
security_groups = {
  # EKS nodes → RDS MySQL (3306)
  rds-fiware = {
    name        = "rds-fiware"
    description = "Acceso MySQL desde nodos EKS"
    vpc_name    = "fiware-gitops"
    ingress = {
      mysql = { from_port = 3306, to_port = 3306, protocol = "tcp", cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] }
    }
    egress = {}
    tags   = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
  # EKS nodes → DocumentDB (27017)
  docdb-fiware = {
    name        = "docdb-fiware"
    description = "Acceso MongoDB API desde nodos EKS"
    vpc_name    = "fiware-gitops"
    ingress = {
      mongo = { from_port = 27017, to_port = 27017, protocol = "tcp", cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] }
    }
    egress = {}
    tags   = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
}

# ── EKS cluster ──────────────────────────────────────────────────────────────
eks_clusters = {
  fiware-gitops = {
    name            = "fiware-gitops"
    version         = "1.29"
    vpc_name        = "fiware-gitops"
    subnet_names    = ["private-eu-west-1a", "private-eu-west-1b", "private-eu-west-1c"]
    node_groups = {
      fiware = {
        instance_type = "t3.xlarge"   # 4 vCPU / 16 GB — mínimo requerido por FIWARE
        min_size      = 2
        max_size      = 4
        desired_size  = 3
      }
    }
    tags = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
}

# ── RDS MySQL 8.0 (Keyrock + Trusted Issuers List) ───────────────────────────
rds_instances = {
  fiware-keyrock = {
    identifier         = "fiware-keyrock"
    engine             = "mysql"
    engine_version     = "8.0"
    instance_class     = "db.t3.micro"     # Lab; producción: db.t3.small + multi_az = true
    db_name            = "keyrock"
    username           = "keyrock"
    multi_az           = false
    storage_encrypted  = true
    allocated_storage  = 20
    storage_type       = "gp3"
    db_subnet_group    = "fiware-data"
    security_groups    = ["rds-fiware"]
    backup_retention   = 7
    deletion_protection = false            # Lab: destrucción permitida
    tags               = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
}

# ── DocumentDB (Orion-LD — MongoDB API) ──────────────────────────────────────
docdb_clusters = {
  fiware-orionld = {
    identifier        = "fiware-orionld"
    instance_class    = "db.t3.medium"
    instance_count    = 1              # Lab: 1 instancia; producción: 3 (una por AZ)
    storage_encrypted = true
    db_subnet_group   = "fiware-data"
    security_groups   = ["docdb-fiware"]
    backup_retention  = 7
    skip_final_snapshot = true         # Lab
    tags              = { Project = "tfm-fiware-gitops", ManagedBy = "terraform" }
  }
}
```

El ciclo de vida completo de la infraestructura se ejecuta con:

```bash
cd infra
./backend-setup.sh                                    # crea S3 + DynamoDB si no existen
terraform init
terraform plan  -var-file=variables/lab.tfvars
terraform apply -var-file=variables/lab.tfvars
```

### 4.3.2 Instalación de ArgoCD

ArgoCD se instala como la primera aplicación en el clúster, gestionando su propia actualización a través del patrón *App of Apps*.

```bash
# Bootstrap inicial de ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que ArgoCD esté disponible
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
```

### 4.3.3 Patrón App of Apps

El patrón *App of Apps* permite que una única Application raíz en ArgoCD gestione el ciclo de vida de todas las demás aplicaciones del clúster.

**Application raíz (`gitops/apps/app-of-apps.yaml`):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/jdmonsalvel/tfm-fiware-gitops
    targetRevision: main
    path: gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Application FIWARE Trust Anchor (`gitops/apps/fiware-trust-anchor.yaml`):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fiware-trust-anchor
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: https://fiware.github.io/helm-charts
    chart: trust-anchor
    targetRevision: "0.1.*"
    helm:
      valueFiles:
        - $values/gitops/values/trust-anchor/values-aws.yaml
  sources:
    - repoURL: https://github.com/jdmonsalvel/tfm-fiware-gitops
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: trust-anchor
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Application FIWARE Dataspace (`gitops/apps/fiware-dataspace.yaml`):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fiware-dataspace-provider
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  source:
    repoURL: https://fiware.github.io/helm-charts
    chart: data-space-connector
    targetRevision: "7.*"
    helm:
      valueFiles:
        - $values/gitops/values/dataspace/values-provider-aws.yaml
  sources:
    - repoURL: https://github.com/jdmonsalvel/tfm-fiware-gitops
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: provider
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 4.3.4 Gestión de secretos con External Secrets Operator

Los secretos (credenciales de Keyrock, claves de firma JWT) se almacenan en AWS Secrets Manager y se proyectan en Kubernetes mediante el External Secrets Operator, evitando su presencia en el repositorio Git.

```yaml
# ExternalSecret para credenciales del Trust Anchor
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: trust-anchor-credentials
  namespace: trust-anchor
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: trust-anchor-credentials
  data:
    - secretKey: adminPassword
      remoteRef:
        key: fiware/trust-anchor
        property: adminPassword
    - secretKey: signingKey
      remoteRef:
        key: fiware/trust-anchor
        property: signingKey
```

## 4.3.5 Alta disponibilidad: PodDisruptionBudgets y Anti-Affinity

La tolerancia a fallo de nodo documentada en §3.5 (objetivo: recuperación < 5 min) requiere configurar explícitamente los mecanismos de HA en los Helm values de cada componente FIWARE. Sin esta configuración, Kubernetes permite que una operación de `kubectl drain` evicte todos los pods de un componente simultáneamente, interrumpiendo el servicio.

**PodDisruptionBudgets en `values-provider-aws.yaml`:**

```yaml
# Kong API Gateway — 3 réplicas, mínimo 2 disponibles durante mantenimiento
kong:
  replicaCount: 3
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

# Orion-LD — 2 réplicas, mínimo 1 disponible
orion-ld:
  replicaCount: 2
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

**Anti-Affinity en `values-trust-anchor/values-aws.yaml`:**

```yaml
# Keyrock — 2 réplicas distribuidas en nodos distintos
keyrock:
  replicaCount: 2
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            topologyKey: kubernetes.io/hostname
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: keyrock
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

Con esta configuración, un `kubectl drain` sobre cualquiera de los 3 nodos del clúster desencadena el siguiente comportamiento verificable:
1. El Cluster Autoscaler consulta los PDB antes de iniciar la evicción
2. Los pods se redistribuyen a los nodos restantes respetando las reglas de Anti-Affinity
3. El smoke test ejecutado durante el drain confirma continuidad del servicio (HTTPs 200 en todos los endpoints)

## 4.4 Flujo GitOps completo

El flujo de trabajo GitOps implementado puede resumirse en los siguientes pasos:

```
Desarrollador
    │
    ├─1─► git push → rama feature/update-values
    │
    ├─2─► GitHub Actions: validación (helm lint, kubeval)
    │
    ├─3─► Pull Request → revisión → merge a main
    │
    ├─4─► ArgoCD detecta cambio en main (polling cada 3 min)
    │         │
    │         ├─5─► Calcula diff entre estado Git y estado K8s
    │         └─6─► Aplica cambios (helm upgrade / kubectl apply)
    │
    ├─7─► Health checks: ArgoCD verifica readiness de todos los pods
    │
    └─8─► Smoke test automático (GitHub Actions workflow_run)
              └─ Resultado notificado en el PR como status check
```

### 4.4.1 GitHub Actions para validación de manifests

```yaml
# .github/workflows/validate.yml
name: Validate GitOps Manifests

on:
  pull_request:
    paths:
      - 'gitops/**'

jobs:
  helm-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v3
        with:
          version: '3.14.0'
      - name: Helm lint trust-anchor values
        run: |
          helm repo add fiware https://fiware.github.io/helm-charts
          helm repo update
          helm lint fiware/trust-anchor \
            -f gitops/values/trust-anchor/values-aws.yaml

  kubeval:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate ArgoCD manifests
        uses: instrumenta/kubeval-action@master
        with:
          files: gitops/apps/
```
