# Capítulo 3 — Objetivos y Metodología

## 3.1 Metodología de desarrollo

Este TFM adopta una **metodología de desarrollo iterativo e incremental** con cuatro fases claramente diferenciadas, siguiendo los principios de entrega continua de valor y validación temprana de hipótesis técnicas. Este enfoque es coherente con las prácticas DevOps que constituyen el objeto de estudio del máster.

```
Fase 1          Fase 2              Fase 3               Fase 4
Análisis   →   Baseline        →   Automatización   →   Validación
Manual         Single-node         Multi-nodo            & Documentación
               (Helm directo)      (ArgoCD + EKS)
```

### Fase 1 — Análisis y comprensión (Semana 1-2)
Estudio de la arquitectura del FIWARE Data Space Connector: análisis del repositorio GitHub, estudio de las dependencias entre charts Helm, identificación de los parámetros configurables y los requisitos de red entre componentes.

**Entregable**: Diagrama de arquitectura de componentes y mapa de dependencias Helm.

### Fase 2 — Despliegue baseline manual (Semana 2-3)
Despliegue manual del Helm Umbrella en un clúster Kubernetes single-node (Minikube / k3s en EC2) para establecer una línea base documentada. Esta fase permite comprender el comportamiento de los componentes antes de automatizar.

**Entregable**: Script de despliegue manual documentado + prueba E2E superada en single-node.

### Fase 3 — Automatización GitOps en AWS (Semana 3-4)
Implementación del pipeline GitOps completo: provisioning EKS con Terraform, instalación de ArgoCD, creación del repositorio GitOps con Application manifests, y despliegue automatizado del dataspace en clúster multi-nodo.

**Entregable**: Repositorio GitHub con IaC + GitOps manifests + ArgoCD funcionando en EKS.

### Fase 4 — Validación, métricas y documentación (Semana 4-5)
Ejecución de pruebas E2E automatizadas, medición de métricas de HA (tiempo de recuperación tras fallo de nodo, tiempo de sincronización ArgoCD), y elaboración de la memoria del TFM.

**Entregable**: Suite de pruebas E2E + informe de métricas + memoria TFM completa.

## 3.2 Principios de diseño

Las decisiones arquitectónicas de este trabajo se rigen por los siguientes principios:

1. **Gitness**: Todo el estado del sistema —configuración, versiones, secrets references— está en Git. No existe configuración fuera del repositorio.

2. **Inmutabilidad de imágenes**: Los despliegues referencian siempre imágenes Docker etiquetadas por digest (SHA256), nunca por tags mutables como `latest`.

3. **Separación de repositorios**: Se mantiene la separación entre el repositorio de código de aplicación y el repositorio de configuración GitOps (*app repo* vs. *config repo*), siguiendo la recomendación de Weaveworks.

4. **Secretos fuera de Git**: Las credenciales nunca se almacenan en el repositorio. Se utiliza **AWS Secrets Manager** con integración mediante el *External Secrets Operator* (ESO).

5. **Idempotencia**: Todos los scripts y manifiestos son idempotentes; su ejecución repetida produce el mismo resultado sin efectos secundarios.

## 3.3 Arquitectura de referencia en AWS

La arquitectura implementada en este TFM comprende tres capas sobre **Amazon Web Services (región eu-west-1, Irlanda)**:

### Capa de infraestructura (IaC — Terraform sobre AWS)

La VPC se diseña con **tres niveles de subnets** por AZ, separando los planos de red, cómputo y datos:

| Nivel | CIDR (por AZ) | Función |
|-------|--------------|---------|
| **Públicas** | 10.0.101-103.0/24 | ALB, NAT Gateway — exposición controlada a Internet |
| **Privadas App** | 10.0.1-3.0/24 | Nodos EKS — cómputo aislado de Internet |
| **Privadas Datos** | 10.0.201-203.0/24 | RDS, DocumentDB — sin ruta directa a Internet |

Componentes adicionales de la capa de infraestructura:

- **Amazon VPC** 10.0.0.0/16 en 3 AZs (eu-west-1a/b/c), 9 subnets (3 niveles × 3 AZs)
- **NAT Gateway** único para salida de subnets privadas (optimización de costes en entorno de lab)
- **Amazon EKS 1.29** con managed node group: 3× t3.xlarge (4 vCPU / 16 GB) — mínimo obligatorio por los requisitos de memoria de FIWARE (8-10 GB en total)
- **IAM Roles for Service Accounts (IRSA)** con OIDC: permisos AWS granulares por pod, sin credenciales estáticas en el código
- **AWS Load Balancer Controller**: provisionamiento automático de NLB/ALB para exposición de Kong
- **AWS Secrets Manager**: almacenamiento seguro de credenciales bajo prefijo `fiware/`
- **Amazon RDS for MySQL 8.0** (subnets de datos): base de datos relacional para Keyrock (Trust Anchor) y Trusted Issuers List. Externalizar a RDS desacopla el estado de los pods y garantiza backups automáticos, encriptación en reposo y alta disponibilidad mediante Multi-AZ en producción.
- **Amazon DocumentDB** (subnets de datos): base de datos compatible con MongoDB para Orion-LD. Externalizar a DocumentDB evita desplegar StatefulSets con volúmenes persistentes en EKS, separando el plano de datos del plano de cómputo.
- **Terraform state backend**: S3 bucket con versionado + tabla DynamoDB para bloqueo de estado. Garantiza la idempotencia y la auditoría del aprovisionamiento.

### Capa de orquestación GitOps (ArgoCD)
- ArgoCD instalado en namespace dedicado (`argocd`)
- App of Apps pattern: una Application raíz que gestiona todas las demás
- ApplicationSet para despliegue parametrizado multi-nodo
- Sync policies: `automated` con `prune: true` y `selfHeal: true`

### Capa de aplicación (FIWARE Data Space Connector)
- Trust Anchor (Keyrock) en namespace `trust-anchor`
- Data Space Connector completo en namespace `consumer` y `provider`
- Ingress NGINX para exposición de servicios con TLS
- NetworkPolicies para aislamiento entre namespaces

## 3.4 Repositorio GitOps — estructura

```
tfm-fiware-gitops/
├── infra/                    # Terraform — aprovisionamiento AWS
│   ├── vpc/
│   ├── eks/
│   └── addons/
├── gitops/                   # Manifests ArgoCD
│   ├── apps/                 # ArgoCD Applications
│   │   ├── app-of-apps.yaml
│   │   ├── argocd-install.yaml
│   │   ├── fiware-trust-anchor.yaml
│   │   └── fiware-dataspace.yaml
│   └── values/               # Helm values por entorno
│       ├── trust-anchor/
│       │   └── values-aws.yaml
│       └── dataspace/
│           └── values-aws.yaml
└── tests/                    # Pruebas E2E automatizadas
    ├── smoke-test.sh
    └── e2e-validation.sh
```

## 3.4b Alta disponibilidad en el clúster EKS

Para que las métricas de tolerancia a fallo definidas en §3.5 sean alcanzables, la configuración de alta disponibilidad requiere tres mecanismos complementarios:

### PodDisruptionBudgets (PDB)

Los PodDisruptionBudgets limitan el número de pods que pueden ser evictados simultáneamente durante operaciones voluntarias (actualizaciones de nodo, `kubectl drain`, escalado del Cluster Autoscaler). Se definen en los Helm values de cada componente:

| Componente | PDB `minAvailable` | Justificación |
|-----------|-------------------|---------------|
| Kong | 2 de 3 réplicas | API Gateway crítico; degradación inaceptable |
| Keyrock | 1 de 2 réplicas | Trust Anchor necesario para autenticación |
| Orion-LD | 1 de 2 réplicas | Context broker de datos principal |
| TIL / CCS | 1 de 1 réplica | Componentes de soporte; 1 réplica suficiente en lab |

### Anti-Affinity rules

Las reglas de Anti-Affinity configuradas en los Helm values garantizan que las réplicas de un mismo componente no se planifiquen en el mismo nodo físico, distribuyéndolas entre las tres AZs disponibles:

```yaml
# Fragmento de values-provider-aws.yaml (Kong)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: kong
```

### Cluster Autoscaler

El **Cluster Autoscaler** de Kubernetes, instalado con IRSA, monitoriza los pods en estado `Pending` (sin nodo disponible) y provisionan nuevos nodos EKS del managed node group de forma automática. Cuando un nodo se drena voluntariamente, el Autoscaler respeta los PodDisruptionBudgets antes de iniciar la evicción, garantizando que el servicio no se interrumpe durante operaciones de mantenimiento.

La combinación de estas tres configuraciones es la que permite alcanzar el objetivo de **Node Failure Recovery < 5 minutos** definido en §3.5.

## 3.5 Métricas de evaluación

| Métrica | Descripción | Objetivo |
|---------|-------------|---------|
| **Deployment Lead Time** | Tiempo desde `git push` hasta servicios saludables | < 10 minutos |
| **ArgoCD Sync Time** | Tiempo desde detección de cambio hasta aplicación | < 3 minutos |
| **Node Failure Recovery** | Tiempo de recuperación tras cordon+drain de un nodo | < 5 minutos |
| **E2E Test Pass Rate** | Porcentaje de pruebas smoke superadas | 100% |
| **Configuration Drift** | Detección y corrección automática de drift | < 60 segundos |

## 3.6 Herramientas y tecnologías

| Categoría | Herramienta | Versión | Justificación |
|-----------|------------|---------|--------------|
| Cloud | Amazon Web Services | — | Estándar industria; EKS managed, IAM/OIDC nativo, Secrets Manager |
| IaC | Terraform | ≥ 1.7 | Módulos oficiales AWS VPC y EKS; estado remoto en S3 + DynamoDB lock |
| Kubernetes | Amazon EKS | 1.29 | LTS; control plane gestionado por AWS; integración IRSA sin credenciales estáticas |
| GitOps | ArgoCD | 2.10 | CNCF Graduated; Sync Waves para ordenar despliegue FIWARE; App of Apps nativo |
| Package Manager | Helm | 3.14 | Estándar K8s; requerido por FIWARE Umbrella Chart |
| CI | GitHub Actions | — | Validación (helm lint + kubeval) en cada PR; sin acceso directo al clúster |
| Secrets | External Secrets Operator | 0.9 | Integración nativa con AWS Secrets Manager via IRSA; refreshInterval 1h |
| Monitorización | Prometheus + Grafana | — | Stack CNCF para métricas K8s y medición de métricas de HA |
| Testing | bash + curl + jq | — | Smoke tests E2E ligeros sin dependencias adicionales |
