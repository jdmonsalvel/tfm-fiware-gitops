# 5. Implementación

Este capítulo describe la implementación técnica del sistema GitOps para FIWARE Data Spaces en AWS, organizada en tres capas: infraestructura (Terraform), orquestación GitOps (ArgoCD) y componentes FIWARE (Helm). Las secciones marcadas con `[EVIDENCIA PENDIENTE]` se completarán con capturas del entorno activo tras el despliegue de EKS en la Fase 2.

## 5.1 Aprovisionamiento de Infraestructura con Terraform

### 5.1.1 Framework de Módulos Reutilizables

La infraestructura se organiza como un framework de 25 módulos Terraform reutilizables en `infra/terraform-framework/modules/aws/`. El patrón de diseño común a todos los módulos es:

- **Variable de entrada:** `map(object({...}))` — permite definir múltiples instancias del recurso en un único bloque de configuración
- **Recursos:** `for_each` sobre el mapa, generando un recurso por entrada
- **Outputs planos:** `{ nombre → id }` y `{ nombre → arn }` — compatibles con el lookup directo desde el módulo raíz
- **Tags:** `merge(var.tags, each.value.tags, { Name = each.value.name })` en todos los recursos

El módulo raíz (`infra/terraform-framework/main.tf`) actúa como orquestador: instancia cada módulo con `count = length(var.<recurso>) > 0 ? 1 : 0`, resuelve los nombres a IDs en `locals.tf` y los pasa a los módulos dependientes:

```hcl
# Resolución nombre → ID en locals.tf
locals {
  subnet_ids = merge(
    module.subnet.subnet_ids,
    { for k, v in data.aws_subnet.existing : k => v.id }
  )
}

# Paso de IDs resueltos al módulo EKS
module "eks" {
  count      = length(var.eks_clusters) > 0 ? 1 : 0
  source     = "./modules/aws/eks"
  subnet_ids = local.subnet_ids   # mapa nombre → ID
  ...
}
```

Los módulos implementados cubren la totalidad de los recursos necesarios para el entorno de laboratorio:

| Módulo | Recurso principal |
|--------|-------------------|
| `vpc` | `aws_vpc` con Flow Logs opcionales |
| `subnet` | `aws_subnet` con asociación a ACL de red |
| `network-acl` | `aws_network_acl` con reglas dinámicas |
| `dhcp` | `aws_vpc_dhcp_options` |
| `intenet-gw` | `aws_internet_gateway` |
| `nat-gw` | `aws_nat_gateway` + EIP |
| `regional-nat-gw` | NAT Gateway regional (multi-VPC) |
| `security-group` | `aws_security_group` con ingress/egress dinámicos |
| `subnet-route-table` | `aws_route_table` + asociaciones por subnet |
| `transit-gw` | `aws_ec2_transit_gateway` |
| `transit-gw-attach` | `aws_ec2_transit_gateway_vpc_attachment` |
| `transit-gw-route-table` | Rutas y asociaciones de Transit Gateway |
| `ec2` | `aws_instance` con acceso SSM (sin SSH) |
| `keypair` | `aws_key_pair` almacenado en SSM Parameter Store |
| `auto-scaling-group` | ALB + Launch Template + ASG + CloudWatch Alarms |
| `db-subnet-group` | `aws_db_subnet_group` compartido por RDS y DocumentDB |
| `rds` | `aws_db_instance` con Multi-AZ opcional |
| `eks` | Clúster EKS + node groups + IRSA + addons |
| `iam` | Roles, políticas, usuarios y grupos IAM |
| `s3` | Buckets S3 con versionado y cifrado obligatorio |
| `ecr` | Repositorios ECR con escaneo de imágenes |
| `kms` | Claves KMS con rotación automática |
| `acm` | Certificados ACM con validación DNS opcional |
| `route53` | Zonas y registros Route53 |
| `secrets-manager` | Secretos en AWS Secrets Manager con generación de contraseñas |

### 5.1.2 Arquitectura de Red en Tres Capas

La VPC `fiware-vpc` (`10.0.0.0/16`) en la región `eu-west-1` implementa una segmentación en tres capas con nueve subnets distribuidas en tres AZs:

```
fiware-vpc (10.0.0.0/16)  ·  eu-west-1
├── PÚBLICA  (10.0.101-103.0/24)  → Internet Gateway
│     Recursos: ALB, NAT Gateway EIPs
├── APLICACIÓN (10.0.1-3.0/24)   → NAT Gateway
│     SG: eks-node-sg  (ingress VPC 1025-65535)
│     Recursos: nodos EKS
└── DATOS (10.0.11-13.0/24)      → NAT Gateway
      SG: data-sg  (ingress exclusivo desde eks-node-sg)
           ├── 27017/TCP  MongoDB  (Orion-LD)
           ├── 3306/TCP   MySQL    (Keyrock)
           ├── 5432/TCP   PostgreSQL
           └── 6379/TCP   Redis
```

Las reglas entre Security Groups se gestionan con `aws_vpc_security_group_ingress_rule` a nivel del módulo raíz, después de que el módulo `security-group` ha creado todos los SGs. Este orden evita dependencias circulares que ocurrirían si las referencias cruzadas estuvieran dentro del mismo módulo:

```hcl
resource "aws_vpc_security_group_ingress_rule" "cross_sg" {
  for_each = var.security_group_rules

  security_group_id            = module.security_group.security_group_ids[each.value.sg_name]
  referenced_security_group_id = module.security_group.security_group_ids[each.value.source_sg_name]
  from_port   = each.value.from_port
  to_port     = each.value.to_port
  ip_protocol = each.value.ip_protocol
}
```

### 5.1.3 Gestión de Estado Remoto

El estado de Terraform se almacena en S3 con las siguientes características de seguridad:

- **Bucket:** `devops-101490102336-terraform-state-bucket`
- **Key:** `terraform-aws-tfm-lab-eu-west-1.tfstate`
- **Versionado:** habilitado (recuperación ante corrupción de estado)
- **Cifrado:** SSE-S3 (Server-Side Encryption)
- **Acceso:** restringido mediante política de bucket a la identidad IAM del pipeline CI/CD

### 5.1.4 Gestión de Secretos en Terraform

El módulo `secrets-manager` genera contraseñas aleatorias con el provider `random` y las almacena como secretos en AWS Secrets Manager. La clave del diseño es `lifecycle { ignore_changes = [secret_string] }`: garantiza que Terraform no sobreescriba contraseñas rotadas manualmente tras el primer despliegue.

```hcl
resource "random_password" "generated" {
  for_each = { for k, v in var.secrets_manager_secrets : k => v if v.generate_password }
  length   = 32
  special  = false   # solo alfanumérico — compatible con cadenas de conexión MySQL/MongoDB
}

resource "aws_secretsmanager_secret_version" "secret" {
  for_each      = var.secrets_manager_secrets
  secret_id     = aws_secretsmanager_secret.secret[each.key].id
  secret_string = each.value.generate_password ? random_password.generated[each.key].result : each.value.secret_string
  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

Se crean cuatro secretos FIWARE bajo el prefijo `/fiware/`:

| Secreto | Uso |
|---------|-----|
| `/fiware/keyrock/admin-password` | Contraseña del administrador de Keyrock |
| `/fiware/keyrock/db-password` | Contraseña de la base de datos de Keyrock |
| `/fiware/mysql/root-password` | Contraseña root de MySQL |
| `/fiware/mongodb/root-password` | Contraseña root de MongoDB |

### 5.1.5 Autenticación AWS en CI/CD (OIDC)

La autenticación entre GitHub Actions y AWS se implementa mediante OpenID Connect (OIDC), eliminando la necesidad de credenciales estáticas en los secretos del repositorio. El flujo es:

1. GitHub Actions solicita un token JWT firmado por el proveedor OIDC `token.actions.githubusercontent.com`
2. AWS IAM verifica el token contra el proveedor OIDC registrado en la cuenta
3. Se asume el rol `automate-cicd-role` mediante `AssumeRoleWithWebIdentity`
4. Terraform ejecuta con las credenciales temporales del rol asumido

```yaml
- name: Configure AWS credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::101490102336:role/automate-cicd-role
    aws-region: eu-west-1
    role-session-name: github-actions-terraform
```

### 5.1.6 Ejecución del Despliegue

El despliegue de la infraestructura base (sin EKS) se realiza con:

```bash
cd infra/terraform-framework
AWS_PROFILE=personal-account-lab terraform init
AWS_PROFILE=personal-account-lab terraform plan \
  -var-file="variables/aws-personal.tfvars" -out=tfplan
AWS_PROFILE=personal-account-lab terraform apply tfplan
```

**Recursos desplegados en la Fase 1 (sin coste de cómputo):**

```
Apply complete! Resources: 74 added, 0 changed, 0 destroyed.

Outputs:
  vpc_ids                  = { "fiware-vpc" = "vpc-0..." }
  subnet_ids               = { "pub-a" = "subnet-0...", ... }   # 9 subnets
  security_group_ids       = { "eks-cluster-sg" = "sg-0...", "eks-node-sg" = "sg-0...",
                               "alb-fiware-sg" = "sg-0...", "data-sg" = "sg-0..." }
  route53_zone_ids         = { "lab-jdmonsalvel-com" = "Z07068241AJ8YGJPUT6BO" }
  acm_certificate_arns     = { "wildcard-lab" = "arn:aws:acm:eu-west-1:..." }
  secret_arns              = { "keyrock-admin" = "arn:aws:secretsmanager:..." }
  s3_bucket_ids            = { "velero-backups" = "fiware-velero-...", ... }
```

**Tiempo estimado de despliegue (Fase 2, con EKS y RDS):** 40-50 minutos — ver desglose en §6.1.

> `[EVIDENCIA PENDIENTE]` Captura de pantalla: output completo de `terraform apply` con EKS desplegado, mostrando los outputs `eks_cluster_endpoints` y `eks_oidc_provider_arns`.

## 5.2 Bootstrap del Operador GitOps (ArgoCD)

### 5.2.1 Instalación de ArgoCD

ArgoCD se instala mediante `scripts/bootstrap.sh` en el namespace `argocd`. El script está diseñado para ser idempotente: verifica si cada componente ya existe antes de crearlo.

```bash
# Fragmento de scripts/bootstrap.sh
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "7.*" \
  --set server.service.type=LoadBalancer \
  --wait --timeout 300s

# Aplicar la Application raíz — desencadena la sincronización de todo el stack
kubectl apply -f gitops/apps/app-of-apps.yaml
```

El despliegue objetivo es exclusivamente AWS EKS — no se contempla entorno local con kind.

### 5.2.2 Patrón App of Apps

El patrón App of Apps se implementa con una Application raíz (`gitops/apps/app-of-apps.yaml`) que apunta al directorio `gitops/apps/applications/`. ArgoCD detecta automáticamente todos los manifests de tipo `Application` en ese directorio y los gestiona como un árbol jerárquico.

```yaml
# gitops/apps/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fiware-data-space
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/jdmonsalvel/tfm-fiware-gitops
    targetRevision: HEAD
    path: gitops/apps/applications
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

La política `automated.selfHeal: true` garantiza que cualquier desviación entre el estado del clúster y el repositorio Git sea corregida automáticamente por ArgoCD — esto implementa el principio de reconciliación continua del patrón GitOps.

### 5.2.3 Sincronización por Olas (Sync Waves)

Las dependencias entre componentes se gestionan mediante la anotación `argocd.argoproj.io/sync-wave`. ArgoCD no avanza a la siguiente ola hasta que todos los recursos de la ola actual están en estado `Healthy`:

| Ola | Componentes | Razón |
|-----|------------|-------|
| 0 | MySQL (trust-anchor), MongoDB (provider) | Bases de datos deben estar listas antes de los servicios |
| 1 | Keyrock, Trusted Issuers List, Credentials Config Service | IdP y registro de emisores antes del broker |
| 2 | Orion-LD | El Context Broker requiere MongoDB ya inicializado |

```yaml
# Ejemplo: fiware-keyrock.yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Esta secuencia evita errores de conexión durante el arranque inicial: Keyrock no intentará conectar a MySQL hasta que el pod de MySQL esté en estado `Running`, y Orion-LD no intentará conectar a MongoDB hasta que el Replica Set esté inicializado.

### 5.2.4 Multi-source Helm Applications

Las Applications FIWARE utilizan la característica *multi-source* de ArgoCD para separar el chart Helm (origen externo) de los values de configuración (repositorio propio del TFM):

```yaml
# gitops/apps/applications/fiware-keyrock.yaml
spec:
  sources:
    - repoURL: https://fiware.github.io/helm-charts
      chart: keyrock
      targetRevision: "0.8.*"
      helm:
        valueFiles:
          - $values/gitops/values/trust-anchor/keyrock.yaml
    - repoURL: https://github.com/jdmonsalvel/tfm-fiware-gitops
      targetRevision: HEAD
      ref: values      # referencia nombrada para $values
```

Esta arquitectura de multi-source garantiza que la versión del chart está fijada semánticamente (`0.8.*` acepta parches pero no cambios de API) y que los valores de configuración están versionados junto con el resto del repositorio.

## 5.3 Despliegue de Componentes FIWARE

### 5.3.1 Trust Anchor (namespace: `trust-anchor`)

El Trust Anchor comprende tres componentes que implementan la infraestructura de identidad del Data Space:

**Keyrock** actúa como Identity Provider (IdP) raíz. Emite Verifiable Credentials (VCs) a los participantes del Data Space e implementa el protocolo iSHARE para la autenticación M2M. Su values de configuración referencia un `existingSecret` para las credenciales, nunca valores en texto plano en Git:

```yaml
# gitops/values/trust-anchor/keyrock.yaml
existingSecret: keyrock-credentials   # K8s Secret proyectado por ESO desde AWS Secrets Manager
db:
  host: mysql
  user: keyrock
statefulset:
  resources:
    requests:
      memory: 512Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m
```

**Trusted Issuers List (TIL)** mantiene el registro de emisores de credenciales confiables, implementando la lista de autoridades reconocidas por el Data Space.

**Credentials Config Service (CCS)** proporciona la configuración de credenciales requerida por el flujo de autorización SIOP2/OIDC4VP.

### 5.3.2 Proveedor de Datos (namespace: `provider`)

**Orion-LD** es el Context Broker NGSI-LD que almacena y sirve los datos del Data Space. Se despliega contra MongoDB en la capa de datos, con la cadena de conexión inyectada como variable de entorno desde un Kubernetes Secret (gestionado por ESO):

```yaml
# gitops/values/provider/orion.yaml
mongodb:
  hosts: mongodb.provider.svc.cluster.local
  existingSecret: mongodb-credentials
replicaSet: false   # standalone en entorno de laboratorio
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m
```

**Kong** actúa como PEP (Policy Enforcement Point) / API Gateway delante de Orion-LD, interceptando todas las peticiones y verificando que el token Bearer presentado es válido según el flujo iSHARE.

### 5.3.3 Bases de Datos (ola 0)

**MySQL** (`bitnami/mysql 14.*`) proporciona el almacenamiento relacional para Keyrock, desplegado en el namespace `trust-anchor` en la ola 0. Utiliza un PersistentVolumeClaim gestionado por EBS CSI Driver (instalado vía IRSA en el módulo EKS).

**MongoDB** (`bitnami/mongodb 18.*`) proporciona el almacenamiento documental para Orion-LD, desplegado en el namespace `provider` en la ola 0 en modo standalone.

## 5.4 Gestión de Secretos (External Secrets Operator)

### 5.4.1 Arquitectura ESO

External Secrets Operator (ESO) sincroniza los secretos desde AWS Secrets Manager al clúster Kubernetes. La arquitectura tiene tres capas:

1. **AWS Secrets Manager:** Almacén canónico de secretos. Creados por Terraform con contraseñas generadas aleatoriamente. Nunca accesibles desde Git.
2. **ClusterSecretStore:** CRD de ESO que define la conexión al backend de AWS Secrets Manager, utilizando IRSA para autenticación sin credenciales estáticas.
3. **ExternalSecret:** CRD por namespace que define qué secreto de AWS proyectar como `Secret` nativo de Kubernetes, con qué nombre y con qué `refreshInterval`.

```yaml
# Ejemplo: ClusterSecretStore
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-west-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# Ejemplo: ExternalSecret para Keyrock
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: keyrock-credentials
  namespace: trust-anchor
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: keyrock-credentials
  data:
    - secretKey: adminPassword
      remoteRef:
        key: /fiware/keyrock/admin-password
    - secretKey: dbPassword
      remoteRef:
        key: /fiware/keyrock/db-password
```

### 5.4.2 IRSA para ESO

El rol IAM de ESO (`eso-irsa-role`) se crea automáticamente por el módulo EKS mediante el submodulo `irsa`. Este rol tiene una política de confianza que permite únicamente al Service Account `external-secrets-sa` del namespace `external-secrets` asumir el rol, y una política de permisos con acceso de lectura a todos los secretos bajo el prefijo `/fiware/`:

```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
  "Resource": "arn:aws:secretsmanager:eu-west-1:101490102336:secret:/fiware/*"
}
```

## 5.5 Pipeline CI/CD

### 5.5.1 Visión General

Se implementan cuatro workflows de GitHub Actions que cubren el ciclo de vida completo del repositorio:

| Workflow | Trigger | Propósito |
|----------|---------|-----------|
| `terraform-validate.yml` | PR y push a `main` en `infra/**` | Calidad y seguridad del código IaC |
| `terraform-apply.yml` | Push a `main` en `infra/**` | Despliegue automático con aprobación manual |
| `gitops-validate.yml` | PR y push a `main` en `gitops/**` | Validación de manifests Kubernetes y Helm |
| `security-scan.yml` | Push y PR (todas las ramas) | Detección de secretos y vulnerabilidades |

### 5.5.2 `terraform-validate.yml`

Ejecutado en pull requests y pushes sobre `infra/terraform-framework/**`. Realiza tres validaciones en secuencia:

```yaml
steps:
  - name: Terraform Format Check
    run: terraform fmt -check -recursive          # verifica estilo canónico HCL

  - name: Terraform Init (no backend)
    run: terraform init -backend=false            # descarga providers sin backend remoto

  - name: Terraform Validate
    run: terraform validate                        # valida sintaxis y tipos

  - name: Run Checkov
    uses: bridgecrewio/checkov-action@v12
    with:
      framework: terraform
      check: CKV_AWS_58,CKV_AWS_79,CKV_AWS_111,CKV_AWS_115,CKV_AWS_116,CKV_AWS_117
```

Los checks de Checkov verifican cifrado en reposo (CKV_AWS_58 — EKS secrets encryption), actualizaciones automáticas de nodos (CKV_AWS_79), S3 con acceso público bloqueado (CKV_AWS_111), Lambda con límite de concurrencia (CKV_AWS_115, CKV_AWS_116) y dentro de VPC (CKV_AWS_117).

### 5.5.3 `terraform-apply.yml`

Ejecutado exclusivamente en push a la rama `main` en `infra/terraform-framework/**`. Requiere aprobación manual en el entorno `aws-lab` de GitHub Environments antes de ejecutar el `apply`:

```yaml
jobs:
  apply:
    environment: aws-lab    # bloquea hasta aprobación manual en GitHub UI
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::101490102336:role/automate-cicd-role
          aws-region: eu-west-1
      - run: terraform plan -var-file="variables/aws-personal.tfvars" -out=tfplan
      - run: terraform apply tfplan
      - run: terraform output -json 2>/dev/null || true
```

La autenticación OIDC (permiso `id-token: write`) elimina la necesidad de almacenar credenciales AWS en los secretos del repositorio.

### 5.5.4 `gitops-validate.yml`

Valida todos los manifests Kubernetes y charts Helm antes de que ArgoCD los aplique al clúster:

```yaml
steps:
  - name: Helm Lint (trust-anchor)
    run: helm lint gitops/values/trust-anchor/ --strict

  - name: Kubeconform
    run: |
      kubeconform -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        -kubernetes-version 1.29.0 \
        gitops/apps/
```

### 5.5.5 `security-scan.yml`

Ejecuta TruffleHog en cada push para detectar secretos comprometidos en el historial de Git, y Checkov sobre los manifests Kubernetes para verificar configuraciones de seguridad:

```yaml
steps:
  - name: TruffleHog OSS
    uses: trufflesecurity/trufflehog@main
    with:
      path: ./
      base: ${{ github.event.repository.default_branch }}
      extra_args: --debug --only-verified

  - name: Checkov K8s manifests
    uses: bridgecrewio/checkov-action@v12
    with:
      directory: gitops/
      framework: kubernetes
```
