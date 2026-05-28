# Diagramas draw.io — Especificaciones exactas
## TFM — FIWARE GitOps · AWS eu-west-1 · cuenta 101490102336

Cada sección describe con exactitud qué elementos poner, qué textos, qué conexiones
y cómo organizarlos. Los valores provienen directamente del `aws-personal.tfvars` y
del código Terraform. Usar draw.io en https://app.diagrams.net (sin instalación).

---

## Diagrama 1 — Red AWS: VPC y subnets

**Nombre de archivo:** `docs/images/diagrama-red-vpc.png`
**Tamaño canvas:** A4 horizontal (3508 × 2480 px a 300 DPI)
**Paleta de colores:**
- Fondo VPC: azul muy claro `#EBF5FB`
- Subnets públicas: verde claro `#E9F7EF`
- Subnets privadas: naranja muy claro `#FEF9E7`
- Internet/exterior: gris `#F2F3F4`
- Líneas de red: gris oscuro `#5D6D7E`
- Líneas de ruta: azul `#2E86C1`

### Elementos y texto exacto

#### Caja exterior — Internet
```
Texto: "Internet"
Forma: rectángulo redondeado, fondo gris #F2F3F4
Posición: arriba del todo, centrado
```

#### Caja VPC (contenedor grande)
```
Texto cabecera: "VPC: tfm-fiware-vpc  |  10.0.0.0/16  |  eu-west-1"
Forma: rectángulo con borde azul #2E86C1, fondo #EBF5FB
```

#### Internet Gateway (dentro de VPC, arriba)
```
Texto: "Internet Gateway
tfm-fiware-igw"
Forma: cilindro o hexágono, color naranja AWS #FF9900
```

#### NAT Gateway (dentro de subnet pub-a)
```
Texto: "NAT Gateway
tfm-fiware-nat
(EIP pública)"
Forma: cilindro, color naranja #FF9900
```

#### Tres columnas de AZs (dentro de VPC)

**Columna 1 — eu-west-1a**
```
Cabecera AZ: "eu-west-1a"  (borde punteado gris)

Subnet pública — caja verde:
  Título: "pub-a (pública)"
  Línea 1: "10.0.101.0/24"
  Línea 2: "ip_public_auto = true"
  Línea 3: "kubernetes.io/role/elb = 1"
  Ícono: nube pequeña (auto-assign IP)

  Contiene: NAT Gateway (ver arriba)

Subnet privada — caja amarilla:
  Título: "priv-app-a (privada)"
  Línea 1: "10.0.1.0/24"
  Línea 2: "kubernetes.io/role/internal-elb = 1"
  Ícono: candado pequeño
```

**Columna 2 — eu-west-1b**
```
Cabecera AZ: "eu-west-1b"

Subnet pública:
  Título: "pub-b (pública)"
  "10.0.102.0/24"
  "ip_public_auto = true"
  "kubernetes.io/role/elb = 1"

Subnet privada:
  Título: "priv-app-b (privada)"
  "10.0.2.0/24"
  "kubernetes.io/role/internal-elb = 1"
```

**Columna 3 — eu-west-1c**
```
Cabecera AZ: "eu-west-1c"

Subnet pública:
  Título: "pub-c (pública)"
  "10.0.103.0/24"
  "ip_public_auto = true"
  "kubernetes.io/role/elb = 1"

Subnet privada:
  Título: "priv-app-c (privada)"
  "10.0.3.0/24"
  "kubernetes.io/role/internal-elb = 1"
```

#### Route Tables (caja separada dentro de VPC, abajo)
```
Caja 1 — Route Table pública:
  Título: "rt-public  (tfm-fiware-rt-public)"
  Asociada a: pub-a, pub-b, pub-c
  Rutas:
    0.0.0.0/0  →  fiware-igw

Caja 2 — Route Table privada:
  Título: "rt-private  (tfm-fiware-rt-private)"
  Asociada a: priv-app-a, priv-app-b, priv-app-c
  Rutas:
    0.0.0.0/0  →  fiware-nat
```

#### Security Groups (caja separada, lateral derecho)
```
SG 1:
  Nombre: "tfm-fiware-eks-cluster"
  Ingress:  TCP 443  desde 10.0.0.0/8
  Egress:   ALL  a 0.0.0.0/0

SG 2:
  Nombre: "tfm-fiware-eks-nodes"
  Ingress:  TCP 1025-65535  desde 10.0.0.0/8
  Egress:   ALL  a 0.0.0.0/0

SG 3:
  Nombre: "tfm-fiware-alb"
  Ingress:  TCP 80   desde 0.0.0.0/0
            TCP 443  desde 0.0.0.0/0
  Egress:   ALL  a 0.0.0.0/0
```

### Conexiones (flechas)

```
Internet  ──►  Internet Gateway          etiqueta: "tráfico entrante"
Internet Gateway  ──►  pub-a/b/c        etiqueta: "rutas públicas"
pub-a (NAT GW)  ──►  Internet Gateway   etiqueta: "egress nodos" (flecha punteada)
priv-app-a/b/c  ──►  NAT Gateway        etiqueta: "0.0.0.0/0" (flecha punteada)
rt-public  ---  pub-a, pub-b, pub-c     línea de asociación (sin punta)
rt-private  ---  priv-app-a, priv-app-b, priv-app-c   línea de asociación
```

---

## Diagrama 2 — Infraestructura AWS completa (EKS + componentes)

**Nombre de archivo:** `docs/images/diagrama-infra-aws.png`
**Tamaño canvas:** A3 horizontal
**Nota:** Este diagrama muestra la Fase 2 (EKS desplegado).

### Elementos y texto exacto

#### Exterior (fuera de la VPC)

```
Elemento: "Usuario / Consumer App"
Forma: persona o rectángulo redondeado, gris

Elemento: "GitHub
tfm-fiware-gitops (repo)"
Forma: rectángulo, negro/gris oscuro

Elemento: "Operador DevOps
(terraform + kubectl)"
Forma: persona, azul

Elemento (fuera VPC, derecho):
"S3 Buckets (globales)
─────────────────────
tfm-fiware-terraform-state
  versioning: ON · AES-256
tfm-fiware-velero-backups
  versioning: ON · AES-256
tfm-fiware-loki-logs
  versioning: OFF · AES-256"
Forma: rectángulo con ícono S3, color amarillo #F9E79F

Elemento (fuera VPC, derecho):
"AWS Secrets Manager
/fiware/keyrock/adminPassword
/fiware/keyrock/signingKey
/fiware/orion/mongoPassword"
Forma: rectángulo con candado, color naranja #FF9900

Elemento (fuera VPC, derecho):
"IAM OIDC Provider
oidc.eks.eu-west-1.amazonaws.com
─────────────────────
IRSA Roles:
  external-secrets-irsa
  alb-controller-irsa
  cert-manager-irsa"
Forma: rectángulo, color naranja pálido

Elemento (fuera VPC, abajo):
"Terraform State Backend
s3://devops-101490102336-terraform-state-bucket
key: 101490102336/terraform-aws-tfm-fiware-gitops-lab-eu-west-1.tfstate"
Forma: rectángulo con ícono S3, pequeño
```

#### Dentro de VPC (mismo contenedor que Diagrama 1, más compacto)

```
Subnets públicas (pub-a/b/c) contienen:
  "AWS ALB
  (creado por ALB Ingress Controller)
  ─────────────────────
  SG: tfm-fiware-alb
  HTTP :80 → HTTPS :443
  Targets: Kong pods"
  Forma: rectángulo, color azul AWS

  "NAT Gateway
  tfm-fiware-nat
  (en pub-a)"
  Forma: cilindro naranja
```

```
Subnets privadas (priv-app-a/b/c) contienen:
  Gran contenedor EKS:
  ┌─────────────────────────────────────────────┐
  │  Amazon EKS 1.33  |  fiware-gitops          │
  │  SG: tfm-fiware-eks-cluster (:443)          │
  │  3 × t3.xlarge  |  ON_DEMAND               │
  │  disk: 100 GB gp3 por nodo                  │
  │                                             │
  │  ┌── namespace: argocd ──────────────────┐  │
  │  │  ArgoCD Server                        │  │
  │  │  App of Apps → 6 Applications        │  │
  │  └───────────────────────────────────────┘  │
  │                                             │
  │  ┌── namespace: kube-system ─────────────┐  │
  │  │  AWS ALB Ingress Controller (IRSA)   │  │
  │  │  External Secrets Operator (IRSA)    │  │
  │  │  cert-manager (IRSA)                 │  │
  │  │  CoreDNS · kube-proxy · vpc-cni      │  │
  │  │  aws-ebs-csi-driver                  │  │
  │  └───────────────────────────────────────┘  │
  │                                             │
  │  ┌── namespace: trust-anchor ────────────┐  │
  │  │  Keyrock 8.3  (IdP / Trust Anchor)   │  │
  │  │  Trusted Issuers List                │  │
  │  │  Credentials Config Service          │  │
  │  │  MySQL 9 (DB Keyrock + TIL)         │  │
  │  └───────────────────────────────────────┘  │
  │                                             │
  │  ┌── namespace: provider ────────────────┐  │
  │  │  Orion-LD 1.10 (Context Broker)      │  │
  │  │  Kong (API GW / PEP Proxy)           │  │
  │  │  MongoDB 8 (DB Orion-LD)             │  │
  │  └───────────────────────────────────────┘  │
  │                                             │
  │  ┌── namespace: monitoring ───────────────┐ │
  │  │  Prometheus + Grafana                 │ │
  │  │  Loki  →  s3://tfm-fiware-loki-logs  │ │
  │  └───────────────────────────────────────┘ │
  └─────────────────────────────────────────────┘
```

### Conexiones (flechas Diagrama 2)

```
Usuario  ──HTTPS──►  ALB (subnets públicas)
ALB  ──►  Kong (namespace: provider)
Kong  ──auth──►  Keyrock
Kong  ──verify issuer──►  TIL
Kong  ──proxy──►  Orion-LD

GitHub  ──poll 3 min──►  ArgoCD
ArgoCD  ──helm sync wave 1──►  namespace trust-anchor
ArgoCD  ──helm sync wave 2──►  namespace provider

External Secrets Operator  ──IRSA──►  IAM OIDC Provider
External Secrets Operator  ──GetSecretValue──►  AWS Secrets Manager
AWS Secrets Manager  ──K8s Secret──►  Keyrock pod
AWS Secrets Manager  ──K8s Secret──►  Orion-LD pod

Nodos EKS (priv-app-a/b/c)  ──egress──►  NAT Gateway  ──►  Internet
ALB Controller  ──crea──►  ALB

Operador DevOps  ──terraform apply──►  VPC + EKS (línea punteada)
Operador DevOps  ──state──►  Terraform State Backend S3

Loki  ──logs──►  S3 (tfm-fiware-loki-logs)
Velero  ──backups──►  S3 (tfm-fiware-velero-backups)
```

---

## Diagrama 3 — Flujo GitOps end-to-end

**Nombre de archivo:** `docs/images/diagrama-flujo-gitops.png`
**Layout:** swimlane horizontal, 4 carriles

### Carriles y pasos

```
Carril 1 — "Desarrollador"
  [1] git push → feature branch
  [2] Abre Pull Request

Carril 2 — "GitHub / GitHub Actions"
  [3] helm lint (values trust-anchor + provider)
  [4] kubeval (ArgoCD Application manifests)
  [5] Code Review + Approve
  [6] merge → rama main

Carril 3 — "ArgoCD (en EKS)"
  [7] Poll git cada 3 min
  [8] Detecta diff (Git vs clúster)
  [9] helm upgrade / kubectl apply
  [10] Health Check (pods Ready)
  Etiqueta tiempo: "< 3 min sync"

Carril 4 — "EKS Cluster"
  [11] Wave 1: trust-anchor → Healthy
  [12] Wave 2: provider → Healthy
  [13] smoke-test.sh: 4/4 PASSED
  Etiqueta tiempo total: "< 10 min lead time"
```

### Conexiones

```
[1] → [2] → [3] → [4] → [5] → [6] → [7] → [8] → [9] → [10] → [11] → [12] → [13]

Flecha de retorno: [13] → [1]  etiqueta: "✅ notificación status check"
```

---

## Diagrama 4 — App of Apps con Sync Waves

**Nombre de archivo:** `docs/images/diagrama-app-of-apps.png`
**Layout:** árbol de arriba a abajo

### Nodos exactos

```
Raíz:
  "Application: app-of-apps
  repo: github.com/jdmonsalvel/tfm-fiware-gitops
  path: gitops/apps/app-of-apps.yaml
  namespace: argocd"

↓ (crea)

Wave 0 (recuadro punteado azul):
  "Application: argocd-install
  chart: argo-cd 7.*
  namespace: argocd
  wave: '0'"

Wave 1 (recuadro punteado verde):
  "Application: fiware-trust-anchor
  chart: fiware/trust-anchor 0.1.*
  namespace: trust-anchor
  wave: '1'
  ──────────────────
  Pods creados:
  • Keyrock 8.3 (IdP)
  • Trusted Issuers List
  • Credentials Config Service
  • MySQL 9"

Wave 2 (recuadro punteado naranja):
  "Application: fiware-dataspace-provider
  chart: fiware/data-space-connector 7.*
  namespace: provider
  wave: '2'
  ──────────────────
  Pods creados:
  • Orion-LD 1.10
  • Kong API GW
  • MongoDB 8"

Nota entre wave 1 y wave 2:
  "⚠ Wave 2 no inicia hasta que
  todos los pods de Wave 1
  estén en estado Healthy"
```

---

## Guía rápida de uso en draw.io

### Pasos para cada diagrama

1. Ir a https://app.diagrams.net → "Create New Diagram" → "Blank"
2. En la barra superior: File → Page Setup → A4 horizontal (o A3)
3. Usar la búsqueda de formas: buscar "aws" para obtener íconos AWS oficiales
   - Internet Gateway → buscar "gateway"
   - NAT Gateway → buscar "nat"
   - EKS → buscar "eks"
   - S3 → buscar "s3"
4. Para contenedores anidados: arrastrar formas dentro de otras formas
5. Colores: Format → Fill Color con los códigos hexadecimales de arriba
6. Exportar: File → Export as → PNG (300 DPI, border 10px)
7. Guardar el `.drawio` en `docs/drawio/` para poder editar después

### Atajos útiles

| Acción | Atajo |
|---|---|
| Duplicar elemento | Ctrl+D |
| Alinear elementos | Ctrl+Shift+H (horizontal) / Ctrl+Shift+V (vertical) |
| Ajustar al contenido | Ctrl+Shift+H |
| Exportar PNG | Ctrl+Shift+X |
| Zoom fit | Ctrl+Shift+H |

---

## Resumen de archivos a crear

| Diagrama | Archivo | Sección memoria |
|---|---|---|
| Red VPC y subnets | `docs/images/diagrama-red-vpc.png` | Cap 4 §4.2 |
| Infra AWS completa (EKS) | `docs/images/diagrama-infra-aws.png` | Cap 3 §3.4 / Cap 4 |
| Flujo GitOps | `docs/images/diagrama-flujo-gitops.png` | Cap 4 §4.4 |
| App of Apps waves | `docs/images/diagrama-app-of-apps.png` | Cap 4 §4.3 |
| Fuentes draw.io | `docs/drawio/*.drawio` | — |
