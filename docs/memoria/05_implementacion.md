# 5. Implementación

> **Nota de redacción:** Las secciones marcadas con `[EVIDENCIA PENDIENTE]` deben completarse con capturas de pantalla reales del entorno desplegado durante la Fase 4 del proyecto (3-5 de mayo de 2026).

## 5.1 Aprovisionamiento de Infraestructura con Terraform

### 5.1.1 Estructura de Módulos

La infraestructura se organiza en dos módulos Terraform reutilizables, siguiendo el principio de separación de responsabilidades:

- **Módulo `vpc`** (`infrastructure/terraform/modules/vpc/`): Provisiona la VPC, subredes públicas y privadas en tres AZs, Internet Gateway, NAT Gateway y tablas de rutas.
- **Módulo `eks`** (`infrastructure/terraform/modules/eks/`): Provisiona el clúster EKS, el grupo de nodos gestionado (*managed node group*), los roles IAM asociados y el proveedor OIDC necesario para IRSA.

El módulo `eks` utiliza internamente el módulo de la comunidad `terraform-aws-modules/eks/aws` (versión ~> 20.0), que encapsula las mejores prácticas documentadas en la AWS EKS Best Practices Guide.

### 5.1.2 Gestión de Estado Remoto

El estado de Terraform se almacena en un bucket S3 con las siguientes características de seguridad:
- Versionado habilitado (permite recuperación ante corrupción de estado)
- Cifrado del lado del servidor con AWS KMS (SSE-KMS)
- Bloqueo de estado mediante tabla DynamoDB (evita race conditions en aplicaciones concurrentes)
- Acceso restringido mediante política de bucket a la identidad del pipeline CI/CD

### 5.1.3 Ejecución del Despliegue

```bash
# Inicializar backend S3
terraform init \
  -backend-config="bucket=tfm-fiware-tfstate-<account_id>" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=eu-west-1"

# Revisar plan antes de aplicar
terraform plan -var-file="environments/prod/terraform.tfvars" -out=tfplan

# Aplicar (requiere aprobación manual en CI o ejecución local)
terraform apply tfplan
```

**Tiempo estimado de ejecución:** 12-18 minutos (dominado por la creación del clúster EKS y los grupos de nodos).

> `[EVIDENCIA PENDIENTE]` Captura de pantalla: output de `terraform apply` completado exitosamente, mostrando los outputs `cluster_name`, `cluster_endpoint` y `cluster_certificate_authority_data`.

## 5.2 Bootstrap del Operador GitOps (ArgoCD)

### 5.2.1 Instalación de ArgoCD

ArgoCD se instala mediante su chart Helm oficial en el namespace `argocd`, con las siguientes customizaciones respecto a los valores por defecto:

- **Alta disponibilidad del servidor:** `server.replicas: 2` para garantizar disponibilidad durante actualizaciones
- **Autenticación SSO:** Configuración de Dex como proveedor OIDC con GitHub como IdP
- **Metrics habilitadas:** Exposición de métricas Prometheus para el dashboard de Grafana
- **Repositorio Git registrado:** El repositorio del TFM se registra como fuente de confianza

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.x.x \
  --values gitops/bootstrap/argocd-values.yaml
```

### 5.2.2 Patrón App of Apps

El patrón App of Apps (ArgoCD, 2023) se implementa mediante una Application raíz (`gitops/bootstrap/app-of-apps.yaml`) que apunta al directorio `gitops/apps/`. ArgoCD detecta automáticamente todos los manifests de tipo `Application` en ese directorio y los gestiona como un árbol de aplicaciones jerárquico.

Esta arquitectura ofrece las siguientes ventajas operacionales:
- Despliegue del sistema completo mediante la aplicación de un único manifiesto
- Control de dependencias entre aplicaciones mediante *syncWaves*
- Propagación de cambios de configuración de forma unificada
- Rollback coordinado de múltiples aplicaciones

> `[EVIDENCIA PENDIENTE]` Captura de pantalla: interfaz ArgoCD mostrando el árbol de aplicaciones en estado `Synced / Healthy`.

## 5.3 Despliegue de Componentes FIWARE

### 5.3.1 Orion-LD Context Broker

Orion-LD se despliega mediante el Helm chart personalizado en `gitops/charts/orion-ld/`. Las customizaciones principales respecto a la imagen oficial incluyen:

- **Liveness y readiness probes:** Configuradas sobre el endpoint `GET /version` para garantizar que ArgoCD no considere el pod como *Healthy* hasta que el Context Broker esté completamente inicializado
- **Resource requests/limits:** Configurados para el entorno de laboratorio (`requests: {cpu: 250m, memory: 512Mi}`)
- **Configuración de MongoDB:** La cadena de conexión se inyecta desde un Kubernetes Secret generado por External Secrets Operator

### 5.3.2 Keyrock Identity Manager

Keyrock requiere una configuración inicial que incluye la creación de la aplicación OAuth2, la definición de roles y la integración del flujo iSHARE. Esta configuración se gestiona mediante un Kubernetes Job que ejecuta el script de inicialización al primer despliegue.

### 5.3.3 Wilma PEP Proxy

Wilma se configura como proxy inverso de Orion-LD. Su configuración principal incluye:
- URL del Keyrock IdM para validación de tokens
- URL de Orion-LD como servicio *upstream*
- Modo de autenticación: `iSHARE` (verificación JWT completa)

> `[EVIDENCIA PENDIENTE]` Captura de pantalla: logs de los tres pods (Orion-LD, Keyrock, Wilma) en estado `Running`, con el output de `kubectl get pods -n fiware`.

## 5.4 Gestión de Secretos

Todos los secretos de la plataforma (contraseñas de bases de datos, claves API, certificados) se almacenan en AWS Secrets Manager y se sincronizan al clúster mediante External Secrets Operator. El proceso es el siguiente:

1. Se crea el secreto en AWS Secrets Manager mediante la CLI de AWS o la consola
2. Se define un recurso `ExternalSecret` en el namespace correspondiente que especifica el secreto de origen y el mapeo a un `Secret` nativo de Kubernetes
3. ESO reconcilia el estado cada 1 hora (configurable), actualizando el Kubernetes Secret si el valor en AWS Secrets Manager ha cambiado
4. Los pods referencian el Kubernetes Secret de forma estándar (variable de entorno o volumen)

Ningún valor de secreto aparece en el repositorio Git. Los `ExternalSecret` CRDs contienen únicamente referencias (nombres de secrets en AWS), nunca valores.

## 5.5 Pipeline CI/CD

> Ver diagrama D5 en `docs/diagrams/README.md` — Figura 5.1

Se implementan tres workflows de GitHub Actions:

### `terraform-validate.yml`
Activado en pull requests que modifiquen archivos `infrastructure/**`. Ejecuta: `terraform fmt -check`, `terraform validate`, `checkov --check CKV_AWS` sobre todos los módulos Terraform.

### `gitops-validate.yml`
Activado en pull requests que modifiquen archivos `gitops/**`. Ejecuta: `helm lint` sobre todos los charts, `kubeconform` sobre todos los manifests YAML para validar conformidad con los schemas Kubernetes 1.30.

### `security-scan.yml`
Activado en todos los push a cualquier rama. Ejecuta `truffleHog3` para detectar secretos accidentalmente comprometidos en el historial del repositorio.
