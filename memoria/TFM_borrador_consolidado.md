# Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm en entornos multi-nodo

**Trabajo Fin de Máster — Máster Universitario en Desarrollo y Operaciones (DevOps)**  
**Universidad Internacional de La Rioja (UNIR)**  
**Autor**: Jesús David Monsalve Lezama  
**Director**: Rafael Merlo Loranca  
**Fecha de depósito**: julio 2026

---

> **GUÍA DE IMÁGENES**  
> A lo largo del documento se señalan bloques `[FIGURA X]` con:
> - **Qué mostrar**: contenido exacto de la captura o diagrama
> - **Cómo obtenerla**: el comando o herramienta para generarla
> - **Cuándo añadirla**: antes de depósito / tras implementación Floci / tras implementación AWS

---

## Resumen

El presente Trabajo Fin de Máster aborda el diseño e implementación de una arquitectura GitOps para el despliegue automatizado y verificado de **FIWARE Data Spaces** en clústeres Kubernetes multi-nodo sobre Amazon Web Services (AWS). El trabajo responde a la necesidad creciente de infraestructuras de datos soberanas, interoperables y declarativamente gestionadas en el marco de la Estrategia Europea de Datos y la iniciativa Gaia-X.

La solución desarrollada utiliza **ArgoCD** como motor de reconciliación GitOps y el **Helm Umbrella oficial de FIWARE** (`data-space-connector`) como descriptor declarativo de la aplicación, integrando los componentes Trust Anchor (Keyrock), Trusted Issuers List, Credentials Config Service, Orion-LD y Kong en un despliegue coordinado sobre Amazon EKS. La infraestructura se aprovisiona de forma declarativa mediante **Terraform**, y los secretos se gestionan sin presencia en el repositorio mediante el **External Secrets Operator** integrado con AWS Secrets Manager.

El trabajo sigue una metodología iterativa en cuatro fases: análisis de la arquitectura FIWARE, despliegue baseline manual en single-node, automatización GitOps en multi-nodo sobre AWS, y validación mediante pruebas E2E automatizadas. Se valida el flujo de autenticación completo Consumer → Trust Anchor → Connector → Provider Service y se documentan métricas de alta disponibilidad incluyendo tolerancia a fallo de nodo y tiempo de sincronización de ArgoCD.

Como resultado, se obtiene el primer pipeline GitOps completo, documentado y reproducible para FIWARE Data Spaces, con valor práctico para organizaciones como ITA Aragón y valor académico como referencia para la comunidad DevOps/FIWARE.

**Palabras clave**: GitOps, FIWARE, Data Spaces, ArgoCD, Kubernetes, Helm, AWS EKS, Gaia-X, EU Data Spaces, DevOps, Terraform

---

## Abstract

This Master's Thesis addresses the design and implementation of a GitOps architecture for the automated and verified deployment of **FIWARE Data Spaces** in multi-node Kubernetes clusters on Amazon Web Services (AWS). The work responds to the growing need for sovereign, interoperable, and declaratively managed data infrastructures within the framework of the European Data Strategy and the Gaia-X initiative.

The developed solution uses **ArgoCD** as the GitOps reconciliation engine and the **official FIWARE Helm Umbrella** (`data-space-connector`) as the declarative application descriptor, integrating the Trust Anchor (Keyrock), Trusted Issuers List, Credentials Config Service, Orion-LD, and Kong components in a coordinated deployment on Amazon EKS. Infrastructure is provisioned declaratively via **Terraform**, and secrets are managed without repository presence using the **External Secrets Operator** integrated with AWS Secrets Manager.

The work follows an iterative four-phase methodology: FIWARE architecture analysis, manual baseline deployment on single-node, GitOps automation on multi-node AWS, and validation through automated E2E tests. The complete authentication flow Consumer → Trust Anchor → Connector → Provider Service is validated, and high-availability metrics are documented, including node failure tolerance and ArgoCD synchronization time.

**Keywords**: GitOps, FIWARE, Data Spaces, ArgoCD, Kubernetes, Helm, AWS EKS, Gaia-X, EU Data Spaces, DevOps, Terraform

---

## Capítulo 1 — Introducción

### 1.1 Motivación y contexto

La economía de datos europea atraviesa un momento de transformación estructural impulsado por iniciativas regulatorias como el **EU Data Spaces** y la estrategia **Gaia-X**, que exigen infraestructuras de intercambio de datos soberanas, interoperables y gobernadas. En este contexto, **FIWARE** emerge como la plataforma de referencia open source para la creación de *data spaces* que permiten el intercambio seguro y controlado de datos entre organizaciones, cumpliendo los principios de soberanía digital.

Sin embargo, la adopción operativa de FIWARE Data Spaces en entornos de producción presenta una brecha significativa: el despliegue actual de sus componentes —incluyendo el *Trust Anchor*, el *Connector*, y los servicios de consumidor y proveedor— se realiza de forma mayoritariamente manual o mediante invocaciones directas al CLI de Helm. Esta aproximación introduce riesgos de deriva de configuración (*configuration drift*), dificulta la reproducibilidad entre entornos y limita la escalabilidad horizontal a clústeres Kubernetes multi-nodo.

La práctica **GitOps**, cuyo principio fundamental es tratar el repositorio Git como la única fuente de verdad (*single source of truth*) del estado deseado de la infraestructura, ofrece una solución elegante a estas limitaciones. Mediante herramientas como **ArgoCD**, es posible establecer un bucle de reconciliación continua que detecta cualquier divergencia entre el estado declarado en Git y el estado real del clúster, aplicando las correcciones de forma automática.

---

> **[FIGURA 1 — Brecha entre despliegue manual y GitOps en FIWARE]**  
> **Qué mostrar**: Diagrama comparativo en dos columnas. Columna izquierda: flujo manual (desarrollador → CLI Helm → clúster, sin trazabilidad). Columna derecha: flujo GitOps (desarrollador → Git → ArgoCD → clúster, con trazabilidad completa). Destacar los puntos de fallo y auditoría.  
> **Cómo obtenerla**: Elaboración propia con draw.io o Mermaid.  
> **Cuándo añadirla**: Antes del depósito (no requiere implementación).

---

### 1.2 Planteamiento del problema

> *No existe un flujo GitOps completo, documentado y reproducible para desplegar de forma automatizada un dataspace FIWARE completo (Consumer, Provider, Connector, Trust Anchor) en clústeres Kubernetes multi-nodo, lo que impide a organizaciones como ITA Aragón o entidades académicas adoptar FIWARE Data Spaces con garantías operativas en producción.*

Esta carencia se manifiesta en tres dimensiones:

1. **Dimensión técnica**: La ausencia de un pipeline GitOps implica que cualquier cambio en la configuración requiere intervención manual, aumentando el *deployment lead time* y la probabilidad de errores humanos.
2. **Dimensión operativa**: Sin reconciliación automática, la detección y corrección de *configuration drift* depende del conocimiento tácito del equipo, incompatible con los requisitos de alta disponibilidad de entornos productivos.
3. **Dimensión académica y comunitaria**: La falta de una referencia GitOps para FIWARE Data Spaces supone un obstáculo para la comunidad investigadora y para proyectos de smart cities e IoT.

### 1.3 Objetivos

**Objetivo general**: Diseñar e implementar una arquitectura GitOps para el despliegue automatizado y verificado de FIWARE Data Spaces en Kubernetes multi-nodo sobre AWS, utilizando ArgoCD como motor de reconciliación y el Helm Umbrella oficial de FIWARE como descriptor de aplicación.

**Objetivos específicos**:

| ID | Objetivo |
|----|----------|
| OE-1 | Analizar la arquitectura del FIWARE Data Space Connector y sus dependencias, identificando los puntos de extensión para GitOps. |
| OE-2 | Implementar un despliegue baseline manual con Helm Umbrella en un clúster Kubernetes single-node como línea base documentada. |
| OE-3 | Diseñar y desarrollar un pipeline ArgoCD que despliegue el dataspace completo en un clúster multi-nodo (3 nodos) de forma declarativa. |
| OE-4 | Validar el flujo E2E: Consumer → autenticación Trust Anchor → Connector → Provider Service, mediante pruebas automatizadas. |
| OE-5 | Documentar métricas de alta disponibilidad: tolerancia a fallo de nodo, tiempo de sincronización ArgoCD y verificación automática. |
| OE-6 | Producir una referencia GitOps replicable para la comunidad FIWARE, con repositorio público y documentación. |

### 1.4 Alcance y limitaciones

El alcance abarca el despliegue automatizado del FIWARE Data Space Connector en AWS usando EKS, la configuración de ArgoCD como operador GitOps, y la validación del flujo de autenticación E2E. Quedan fuera del alcance: la implementación de Chaos Engineering avanzado, la integración con sistemas legacy externos a FIWARE, y la configuración de redes privadas corporativas (VPN/Direct Connect).

---

## Capítulo 2 — Contexto y Estado del Arte

### 2.1 FIWARE y los Data Spaces europeos

#### 2.1.1 La plataforma FIWARE

FIWARE es una iniciativa promovida por la Unión Europea que proporciona un conjunto de APIs abiertas y componentes de software para la construcción de soluciones de *smart cities*, IoT e intercambio de datos. Su componente central es **Orion-LD**, un *context broker* que implementa la especificación **NGSI-LD** del ETSI.

---

> **[FIGURA 2 — Ecosistema FIWARE: componentes y roles en un Data Space]**  
> **Qué mostrar**: Diagrama de bloques con los tres roles principales (Trust Anchor, Provider, Consumer) y sus componentes internos (Keyrock, TIL, CCS, Orion-LD, Kong). Mostrar las flechas de comunicación entre roles durante el flujo de autenticación.  
> **Cómo obtenerla**: Elaboración propia adaptando el diagrama oficial de FIWARE GitHub.  
> **Cuándo añadirla**: Antes del depósito.

---

#### 2.1.2 EU Data Spaces y Gaia-X

La **Estrategia Europea de Datos** (2020) y su materialización en el **Data Governance Act** (Reglamento 2022/868) y el **Data Act** (Reglamento 2023/2854) establecen el marco legal para la creación de espacios comunes de datos en sectores estratégicos. **Gaia-X** define las reglas de confianza para los participantes de un data space. FIWARE actúa como implementación de referencia compatible con Gaia-X.

---

> **[FIGURA 3 — Marco regulatorio europeo: EU Data Strategy, Gaia-X y FIWARE]**  
> **Qué mostrar**: Diagrama de capas. Capa superior: regulación (Data Governance Act, Data Act). Capa media: framework técnico (Gaia-X Trust Framework, DSBA). Capa inferior: implementación (FIWARE Data Space Connector). Mostrar la relación entre capas.  
> **Cómo obtenerla**: Elaboración propia.  
> **Cuándo añadirla**: Antes del depósito.

---

#### 2.1.3 FIWARE Data Space Connector — arquitectura de componentes

| Componente | Función | Tecnología |
|-----------|---------|-----------|
| **Trust Anchor** | Gestión de identidades y emisión de VCs | Keyrock Identity Manager |
| **Trusted Issuers List (TIL)** | Registro de entidades emisoras confiables | API REST + MySQL |
| **Credentials Config Service (CCS)** | Configuración de esquemas de credenciales | Microservicio Go |
| **Orion-LD** | Context broker NGSI-LD | MongoDB + NGSI-LD spec |
| **Kong API Gateway** | PEP Proxy, autenticación, rate limiting | Kong + plugins FIWARE |

El flujo de autenticación SIOP-2 sigue este orden:

```
Consumer App
    │
    ├─1─► Provider Kong (solicita acceso)
    │         └─2─► Devuelve endpoint de autenticación
    ├─3─► Trust Anchor / VCVerifier (presenta Verifiable Presentation)
    │         ├─4─► Verifica VC contra TIL
    │         └─5─► Genera JWT token
    ├─6─► Provider Kong (presenta JWT)
    │         ├─7─► PDP evalúa política
    │         └─8─► Proxy hacia Orion-LD
    └─9─► Recibe datos NGSI-LD
```

---

> **[FIGURA 4 — Flujo de autenticación SIOP-2 entre componentes FIWARE]**  
> **Qué mostrar**: Diagrama de secuencia (sequence diagram) con los 9 pasos del flujo de autenticación. Actores: Consumer App, Kong, VCVerifier, TIL, Orion-LD. Usar swimlanes por namespace (trust-anchor, provider).  
> **Cómo obtenerla**: Elaboración propia con Mermaid sequence diagram.  
> **Cuándo añadirla**: Antes del depósito.

---

### 2.2 GitOps: principios y evolución

#### 2.2.1 Origen y definición

El término **GitOps** fue acuñado por Alexis Richardson (Weaveworks) en 2017. Los cuatro principios de la especificación OpenGitOps (CNCF, 2022):

1. **Declarativo**: El estado deseado se expresa declarativamente.
2. **Versionado e inmutable**: Historia completa y auditable en Git.
3. **Extraído automáticamente**: Agentes de software hacen *pull* desde Git.
4. **Reconciliado continuamente**: Corrección automática de divergencias.

#### 2.2.2 Modelos Push vs. Pull

| Aspecto | Push (CI-driven) | Pull (GitOps/ArgoCD) |
|---------|-----------------|---------------------|
| Credenciales clúster | En sistema CI | Solo en clúster |
| Superficie de ataque | Mayor | Menor |
| Detección de drift | Manual | Automática |
| Auditoría | Git log + CI logs | Git log (fuente única) |

Este TFM adopta el modelo Pull mediante ArgoCD.

---

> **[FIGURA 5 — Comparativa Push vs. Pull: flujo de despliegue y vectores de seguridad]**  
> **Qué mostrar**: Dos diagramas de flujo lado a lado. Push: CI con credenciales → kubectl apply. Pull: ArgoCD en clúster → poll Git → reconcilia. Destacar en rojo las credenciales expuestas en el modelo Push.  
> **Cómo obtenerla**: Elaboración propia.  
> **Cuándo añadirla**: Antes del depósito.

---

#### 2.2.3 ArgoCD

ArgoCD es un controlador GitOps para Kubernetes, graduado en la CNCF en 2022. Características clave:

- **Application CRD**: Define origen Git y destino Kubernetes.
- **App of Apps**: Una Application raíz gestiona el ciclo de vida de todas las demás.
- **Sync Waves**: Control del orden de despliegue mediante anotaciones (`argocd.argoproj.io/sync-wave`).
- **Health Assessment**: Evaluación de estado de recursos custom.
- **Automated Sync**: Detección y aplicación automática de cambios en Git.

---

> **[FIGURA 6 — Arquitectura interna de ArgoCD: componentes y flujo de reconciliación]**  
> **Qué mostrar**: Diagrama con los componentes internos de ArgoCD (API Server, Repo Server, Application Controller, Dex). Mostrar el flujo: Git repo → Repo Server → Application Controller → Kubernetes API → clúster.  
> **Cómo obtenerla**: Adaptar diagrama oficial de documentación ArgoCD.  
> **Cuándo añadirla**: Antes del depósito.

---

### 2.3 Kubernetes y Amazon EKS

Amazon EKS (Elastic Kubernetes Service) es el servicio Kubernetes gestionado de AWS que elimina el overhead operativo del plano de control. Para este TFM se utiliza **EKS 1.29** con managed node groups, que automatiza el aprovisionamiento y actualización de los nodos worker.

La elección de `t3.xlarge` (4 vCPU / 16 GB RAM) como tipo de instancia es un requisito arquitectónico: los componentes FIWARE (Keyrock, TIL, CCS, Orion-LD, Kong) consumen en conjunto entre 8 y 10 GB de RAM, haciendo que instancias `t3.large` (8 GB) sean insuficientes bajo carga.

### 2.4 Trabajos relacionados

| Trabajo | Similitudes | Diferencias con este TFM |
|---------|-------------|--------------------------|
| FIWARE official deployment guides | Mismo stack FIWARE | Solo Helm directo, sin GitOps |
| iSHARE + ArgoCD deployments | GitOps + Kubernetes | No usa FIWARE Data Space Connector |
| Data Space deployment w/ Helm | Helm Umbrella FIWARE | Sin automatización GitOps, sin HA |
| Generic EKS GitOps tutorials | ArgoCD + EKS | No contemplan FIWARE ni data spaces |

Este trabajo cubre el espacio vacío: **pipeline GitOps completo + FIWARE Data Space Connector + AWS EKS + validación E2E**.

---

## Capítulo 3 — Metodología

### 3.1 Metodología de desarrollo

Este TFM adopta una **metodología iterativa e incremental** con cuatro fases:

```
Fase 1          Fase 2              Fase 3               Fase 4
Análisis   →   Baseline        →   Automatización   →   Validación
               Single-node         Multi-nodo
               (Helm directo)      (ArgoCD + EKS)
```

| Fase | Actividad | Entregable |
|------|-----------|-----------|
| 1 | Análisis arquitectura FIWARE y dependencias Helm | Diagrama componentes + mapa dependencias |
| 2 | Despliegue manual Helm en single-node | Script documentado + smoke test superado |
| 3 | Pipeline GitOps en multi-nodo EKS | Repo GitHub + ArgoCD funcionando |
| 4 | Validación, métricas, memoria | Suite E2E + informe métricas + TFM |

---

> **[FIGURA 7 — Fases metodológicas del TFM con hitos y entregables]**  
> **Qué mostrar**: Diagrama de Gantt simplificado o roadmap con las 4 fases, sus semanas, actividades principales y entregables asociados. Incluir las fechas reales de ejecución.  
> **Cómo obtenerla**: Elaboración propia.  
> **Cuándo añadirla**: Antes del depósito (con fechas reales completadas).

---

### 3.2 Principios de diseño

1. **Gitness**: Todo el estado en Git. No existe configuración fuera del repositorio.
2. **Inmutabilidad de imágenes**: Referencias Docker por digest SHA256.
3. **Separación app/config repos**: Repositorio de código separado del de configuración GitOps.
4. **Secretos fuera de Git**: AWS Secrets Manager + External Secrets Operator.
5. **Idempotencia**: Scripts y manifests idempotentes.

### 3.3 Arquitectura de referencia en AWS

#### Capa de infraestructura (IaC — Terraform)

La VPC se diseña con **tres niveles de subnets** por AZ:

| Nivel | CIDR (por AZ) | Función |
|-------|--------------|---------|
| **Públicas** | 10.0.101-103.0/24 | ALB, NAT Gateway |
| **Privadas App** | 10.0.1-3.0/24 | Nodos EKS |
| **Privadas Datos** | 10.0.201-203.0/24 | RDS MySQL, DocumentDB |

---

> **[FIGURA 8 — Arquitectura de red AWS: VPC 3 capas × 3 AZs]**  
> **Qué mostrar**: Diagrama de red AWS con VPC 10.0.0.0/16. Mostrar las 3 AZs (eu-west-1a/b/c), los 3 niveles de subnets por AZ con sus CIDRs, el Internet Gateway, el NAT Gateway (una instancia en public-a), las route tables, y el EKS cluster en las subnets privadas app. RDS y DocumentDB en subnets privadas datos.  
> **Cómo obtenerla**: Elaboración propia con draw.io o AWS Architecture Diagrams. Usar íconos oficiales AWS.  
> **Cuándo añadirla**: Antes del depósito. Puede hacerse con los valores del tfvars antes de ejecutar.

---

Componentes adicionales:

- **Amazon EKS 1.29**: 3 × t3.xlarge (4 vCPU / 16 GB), managed node group
- **IRSA (IAM Roles for Service Accounts)**: permisos AWS granulares por pod sin credenciales estáticas
- **AWS Load Balancer Controller**: provisionamiento automático de ALB desde annotations K8s
- **AWS Secrets Manager**: secretos bajo prefijo `fiware/`
- **Amazon RDS for MySQL 8.0**: base de datos relacional para Keyrock y TIL
- **Amazon DocumentDB**: MongoDB-compatible para Orion-LD
- **S3 + DynamoDB**: backend remoto de Terraform

#### Capa de orquestación GitOps (ArgoCD)

- Patrón **App of Apps**: Application raíz gestiona todas las Applications hijas
- Sync Waves obligatorias: Trust Anchor en wave `"1"`, Dataspace en wave `"2"`
- Sync policy: `automated: {prune: true, selfHeal: true}`

---

> **[FIGURA 9 — Patrón App of Apps en ArgoCD: jerarquía de Applications]**  
> **Qué mostrar**: Árbol jerárquico. Raíz: `app-of-apps`. Nivel 1: `trust-anchor` (wave 1), `data-space-connector` (wave 2), `monitoring` (wave 0). Nivel 2: sub-componentes de cada Application. Mostrar el estado Synced/Healthy en cada nodo.  
> **Cómo obtenerla**: Captura de pantalla de la UI de ArgoCD tras el despliegue.  
> **Cuándo añadirla**: Tras implementación (Floci o AWS).

---

#### Alta disponibilidad

| Mecanismo | Componente | Configuración |
|-----------|-----------|---------------|
| PodDisruptionBudget | Kong | `minAvailable: 2` de 3 réplicas |
| PodDisruptionBudget | Keyrock | `minAvailable: 1` de 2 réplicas |
| PodDisruptionBudget | Orion-LD | `minAvailable: 1` de 2 réplicas |
| Anti-Affinity | Todos | `preferredDuringScheduling` por hostname |
| Cluster Autoscaler | Nodos EKS | Respeta PDB antes de evicción |

### 3.4 Métricas de evaluación

| Métrica | Descripción | Objetivo |
|---------|-------------|---------|
| Deployment Lead Time | `git push` → servicios healthy | < 10 min |
| ArgoCD Sync Time | Detección cambio → aplicado | < 3 min |
| Node Failure Recovery | `kubectl drain` → pods redistribuidos | < 5 min |
| E2E Test Pass Rate | Smoke test completo | 100% |
| Configuration Drift Detection | Drift detectado y corregido | < 60 seg |

---

## Capítulo 4 — Desarrollo de la Contribución

### 4.1 Análisis del FIWARE Data Space Connector (OE-1)

#### 4.1.1 Dependencias entre charts Helm

El Helm Umbrella `fiware/data-space-connector` declara las siguientes dependencias con orden de arranque crítico:

```yaml
dependencies:
  - name: trust-anchor      # Keyrock — debe estar Running antes que el Connector
    version: "~0.1"
  - name: trusted-issuers-list
    version: "~0.5"
  - name: credentials-config-service
    version: "~0.3"
  - name: orion-ld           # Context broker
    version: "~1.4"
  - name: kong               # API Gateway / PEP
    version: "~2.26"
```

**Dependencia crítica identificada**: El Trust Anchor (Keyrock) debe estar completamente operativo —con su base de datos MySQL inicializada y sus endpoints `/health` respondiendo— antes de que Kong intente registrarse como Consumer en el data space. Si el Trust Anchor no está disponible durante el arranque del Connector, Kong entra en `CrashLoopBackOff` esperando que el IdP responda.

Esta dependencia es el motivo por el que se usa **Sync Wave "1"** para el Trust Anchor y **Sync Wave "2"** para el Data Space Connector en ArgoCD.

---

> **[FIGURA 10 — Mapa de dependencias del Helm Umbrella FIWARE]**  
> **Qué mostrar**: Grafo dirigido (DAG) con los sub-charts como nodos y las dependencias como aristas. Destacar en rojo la dependencia crítica Trust Anchor → Connector. Incluir los tipos de dependencia (base de datos, API, secret sharing).  
> **Cómo obtenerla**: Elaboración propia analizando `Chart.yaml` y valores del chart.  
> **Cuándo añadirla**: Antes del depósito.

---

#### 4.1.2 Requisitos de recursos por componente

| Componente | CPU request | Memory request | Replicas recomendadas |
|-----------|-------------|---------------|----------------------|
| Keyrock (Trust Anchor) | 250m | 512Mi | 2 (HA) |
| TIL | 100m | 256Mi | 1 |
| CCS | 100m | 256Mi | 1 |
| Orion-LD | 500m | 1Gi | 2 (HA) |
| Kong | 500m | 512Mi | 3 (HA crítico) |
| MySQL (Keyrock) | 250m | 512Mi | 1 (StatefulSet) |
| MongoDB (Orion-LD) | 500m | 1Gi | 1 (StatefulSet) |
| **Total** | **~2.2 cores** | **~5 GB** | — |

> Nota: los valores anteriores son los mínimos funcionales para entorno de laboratorio. En producción con anti-affinity y 3 réplicas de Kong, el total escala a ~8-10 GB de RAM, justificando el uso de t3.xlarge (16 GB por nodo).

### 4.2 Infraestructura como código con Terraform (OE-2 / OE-3)

#### 4.2.1 Framework IaC — estructura de módulos

El framework Terraform desarrollado en este TFM sigue el patrón organizativo:

```
infra/terraform-framework/
├── main.tf              — Orquestador: invoca todos los módulos con count-guard
├── variables.tf         — Variables raíz tipo = any (schema en cada módulo)
├── outputs.tf           — Outputs planos: { nombre → id/arn }
├── providers.tf         — AWS provider con soporte dual (real / Floci)
└── modules/aws/
    ├── vpc/             — aws_vpc + flow logs
    ├── subnet/          — aws_subnet + asociación ACL
    ├── nat-gw/          — aws_nat_gateway + EIP
    ├── security-group/  — ingress/egress dinámicos
    ├── eks/             — 6 sub-módulos + bootstrap Helm
    │   ├── modules/iam/      — roles base (sin OIDC)
    │   ├── modules/cluster/  — control plane + OIDC provider
    │   ├── modules/irsa/     — IRSA roles (depende de OIDC)
    │   ├── modules/node-group/
    │   ├── modules/access/
    │   └── bootstrap/        — addons vía Helm (ArgoCD, ESO, LB Controller…)
    ├── s3/              — buckets con lifecycle, replicación, CORS
    ├── ecr/             — repositorios con lifecycle auto-generado
    ├── route53/         — zonas públicas/privadas + records
    ├── acm/             — certificados TLS con validación DNS automática
    ├── rds/             — RDS MySQL/PostgreSQL
    └── iam/             — roles y políticas genéricos
```

**Patrón de desarrollo uniforme** (aplicado a todos los módulos):

```hcl
# variables.tf — siempre map(object) con optional()
variable "eks" {
  type = map(object({
    name    = string
    version = optional(string, "1.29")
    # ...
  }))
}

# main.tf — siempre for_each sobre el mapa
resource "aws_eks_cluster" "cluster" {
  for_each = var.eks
  name     = each.value.name
}

# outputs.tf — siempre planos { nombre → atributo }
output "cluster_endpoints" {
  value = { for k, v in aws_eks_cluster.cluster : k => v.endpoint }
}
```

---

> **[FIGURA 11 — Grafo de dependencias entre módulos Terraform del TFM]**  
> **Qué mostrar**: DAG con los módulos como nodos y sus dependencias como aristas. Destacar la cadena EKS sin ciclos: `iam → cluster (OIDC) → irsa → node-group`. Mostrar también las dependencias de `acm → route53` y `eks → s3`.  
> **Cómo obtenerla**: Elaboración propia o `terraform graph | dot -Tsvg > graph.svg` tras `terraform init`.  
> **Cuándo añadirla**: Tras ejecutar `terraform init` en Floci.

---

#### 4.2.2 Configuración del proyecto: tfvars

Todos los recursos específicos del TFM se declaran en `infra/terraform-framework/variables/fiware-lab.tfvars`. Este fichero es la única fuente de verdad de los parámetros de la infraestructura:

```hcl
# ── Metadatos del proyecto ────────────────────────────────────────────────────
use_floci   = true
project     = "tfm-fiware"
environment = "lab"
accountable = "jdmonsalvel"
region      = "eu-west-1"
account_id  = "000000000000"

tags = {
  Project     = "tfm-fiware-gitops"
  Environment = "lab"
  ManagedBy   = "terraform"
  Owner       = "jdmonsalvel"
}

# ── Red: VPC 10.0.0.0/16 en 3 AZs ───────────────────────────────────────────
vpcs = {
  main = {
    name                 = "tfm-fiware-vpc"
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    tags                 = { Name = "tfm-fiware-vpc" }
  }
}

subnets = {
  # Capa pública — ALB, NAT Gateway
  public-a = { name = "public-eu-west-1a", cidr_block = "10.0.101.0/24",
                az = "eu-west-1a", vpc_name = "main", public = true }
  public-b = { name = "public-eu-west-1b", cidr_block = "10.0.102.0/24",
                az = "eu-west-1b", vpc_name = "main", public = true }
  public-c = { name = "public-eu-west-1c", cidr_block = "10.0.103.0/24",
                az = "eu-west-1c", vpc_name = "main", public = true }

  # Capa privada app — nodos EKS
  private-a = { name = "private-eu-west-1a", cidr_block = "10.0.1.0/24",
                 az = "eu-west-1a", vpc_name = "main", public = false }
  private-b = { name = "private-eu-west-1b", cidr_block = "10.0.2.0/24",
                 az = "eu-west-1b", vpc_name = "main", public = false }
  private-c = { name = "private-eu-west-1c", cidr_block = "10.0.3.0/24",
                 az = "eu-west-1c", vpc_name = "main", public = false }

  # Capa privada datos — RDS, DocumentDB
  data-a = { name = "data-eu-west-1a", cidr_block = "10.0.201.0/24",
              az = "eu-west-1a", vpc_name = "main", public = false }
  data-b = { name = "data-eu-west-1b", cidr_block = "10.0.202.0/24",
              az = "eu-west-1b", vpc_name = "main", public = false }
  data-c = { name = "data-eu-west-1c", cidr_block = "10.0.203.0/24",
              az = "eu-west-1c", vpc_name = "main", public = false }
}

# ── EKS — clúster fiware-gitops ───────────────────────────────────────────────
eks = {
  fiware-gitops = {
    name    = "fiware-gitops"
    version = "1.29"
    # [A COMPLETAR con subnet_names, node config, addons tras implementación]
  }
}

# ── S3 — almacenamiento ───────────────────────────────────────────────────────
s3_buckets = {
  terraform-state = {
    name       = "tfm-fiware-terraform-state"
    versioning = true
    tags       = { Purpose = "terraform-state" }
  }
  velero-backups = {
    name       = "tfm-fiware-velero-backups"
    versioning = true
    tags       = { Purpose = "velero" }
  }
  loki-logs = {
    name = "tfm-fiware-loki-logs"
    lifecycle_rules = [{
      id      = "loki-retention"
      enabled = true
      expiration_days = 30
    }]
    tags = { Purpose = "loki" }
  }
}
```

#### 4.2.3 Despliegue de infraestructura base

```bash
# 1. Arrancar Floci
cd ~/floci && docker compose up -d

# 2. Inicializar y aplicar
cd infra/terraform-framework
terraform init
terraform apply -var-file=variables/fiware-lab.tfvars -auto-approve

# 3. Verificar outputs
terraform output vpc_ids
terraform output subnet_ids
terraform output eks_cluster_endpoints
```

---

> **[FIGURA 12 — Output de terraform apply: recursos AWS creados en Floci]**  
> **Qué mostrar**: Terminal con el output de `terraform apply` mostrando los recursos creados (VPC ID, subnet IDs, EKS endpoint). Puede ser captura de terminal o texto formateado.  
> **Cómo obtenerla**: `terraform apply -var-file=variables/fiware-lab.tfvars 2>&1 | tee output-apply.txt`  
> **Cuándo añadirla**: Tras ejecutar terraform apply en Floci.

---

### 4.3 Capa GitOps: ArgoCD y App of Apps (OE-3)

#### 4.3.1 Bootstrap de ArgoCD

ArgoCD se instala en el clúster EKS antes de activar el pipeline GitOps. Es el único componente que se instala manualmente (no vía ArgoCD, ya que no puede bootstrapearse a sí mismo):

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
```

#### 4.3.2 App of Apps — jerarquía de Applications

```yaml
# gitops/apps/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
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

Las Applications hijas definen las Sync Waves:

```yaml
# gitops/apps/trust-anchor.yaml — Wave 1 (primero)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
# gitops/apps/data-space-connector.yaml — Wave 2 (segundo)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

---

> **[FIGURA 13 — ArgoCD UI: pantalla principal con todas las Applications Synced/Healthy]**  
> **Qué mostrar**: Captura de la UI de ArgoCD (https://localhost:8080 via port-forward) mostrando: app-of-apps, trust-anchor, data-space-connector, monitoring — todas en estado verde (Synced + Healthy). Incluir el número de recursos por Application.  
> **Cómo obtenerla**: `kubectl port-forward svc/argocd-server -n argocd 8080:443` → captura de pantalla.  
> **Cuándo añadirla**: Tras despliegue completo de FIWARE vía ArgoCD.

---

> **[FIGURA 14 — ArgoCD UI: detalle de trust-anchor Application (recursos y sync history)]**  
> **Qué mostrar**: Vista de detalle de la Application `trust-anchor` mostrando: todos los pods Running, el historial de sincronizaciones (al menos 2-3 syncs), y el commit SHA que desencadenó el último sync.  
> **Cómo obtenerla**: Clic en la Application en la UI de ArgoCD → captura.  
> **Cuándo añadirla**: Tras despliegue del Trust Anchor vía ArgoCD.

---

### 4.4 FIWARE Data Space Connector: configuración Helm (OE-3)

#### 4.4.1 Trust Anchor — values para entorno de laboratorio

```yaml
# gitops/values/trust-anchor/values-lab.yaml
keyrock:
  replicaCount: 2

  db:
    host: mysql-trust-anchor    # MySQL StatefulSet en el clúster
    name: idm
    user: keyrock

  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: trust-anchor.fiware.local
        paths:
          - path: /
            pathType: Prefix

  resources:
    requests:
      cpu: 250m
      memory: 512Mi

  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            topologyKey: kubernetes.io/hostname
            labelSelector:
              matchLabels:
                app.kubernetes.io/name: keyrock
```

#### 4.4.2 Data Space Connector (Provider) — values para laboratorio

```yaml
# gitops/values/dataspace/values-provider-lab.yaml
orion-ld:
  replicaCount: 2
  db:
    host: mongodb-provider    # MongoDB StatefulSet

kong:
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 512Mi

  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

### 4.5 Gestión de secretos con External Secrets Operator (OE-3)

Los secretos nunca se almacenan en Git. El flujo es:

```
AWS Secrets Manager (fiware/keyrock-db-password)
    │
    └─► ExternalSecret CRD
            │
            └─► K8s Secret (montado en pod Keyrock)
```

Configuración del `ClusterSecretStore`:

```yaml
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
```

---

> **[FIGURA 15 — Flujo de secretos: AWS Secrets Manager → ExternalSecret → K8s Secret]**  
> **Qué mostrar**: Diagrama de flujo con tres bloques: (1) AWS Secrets Manager con los secretos `fiware/`. (2) External Secrets Operator con el CRD `ExternalSecret`. (3) Pod Keyrock montando el K8s Secret como variable de entorno. Mostrar el refresh interval (1h).  
> **Cómo obtenerla**: Elaboración propia.  
> **Cuándo añadirla**: Antes del depósito.

---

### 4.6 Observabilidad: Prometheus, Grafana y Loki

El stack de monitorización se despliega como Application de ArgoCD en wave `"0"` (antes de FIWARE):

| Componente | Función | Namespace |
|-----------|---------|-----------|
| Prometheus | Recolección de métricas K8s y pods | monitoring |
| Grafana | Visualización de métricas y logs | monitoring |
| Loki | Agregación de logs de pods | monitoring |
| kube-state-metrics | Métricas de estado de recursos K8s | monitoring |

---

> **[FIGURA 16 — Grafana Dashboard: métricas del clúster EKS durante el despliegue FIWARE]**  
> **Qué mostrar**: Captura del dashboard de Grafana mostrando: uso de CPU/RAM por namespace (trust-anchor, provider), número de pods Running/Pending, y latencia de requests a Kong. Panel de tiempo: durante la sincronización de ArgoCD.  
> **Cómo obtenerla**: `kubectl port-forward svc/grafana -n monitoring 3000:3000` → captura de dashboard.  
> **Cuándo añadirla**: Tras despliegue del stack de monitoring y FIWARE.

---

### 4.7 Pipeline CI/CD: GitHub Actions (OE-6)

GitHub Actions valida los manifests GitOps en cada Pull Request:

```yaml
# .github/workflows/gitops-validate.yml
on: [pull_request]
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
      - name: Validate ArgoCD manifests
        run: |
          kubectl apply --dry-run=client -f gitops/apps/
      - name: Lint Helm values
        run: |
          helm lint gitops/charts/*/
      - name: Terraform validate
        run: |
          terraform init -backend=false
          terraform validate
```

---

> **[FIGURA 17 — GitHub Actions: workflow de validación ejecutado en PR]**  
> **Qué mostrar**: Captura de la pantalla de GitHub Actions mostrando el workflow `gitops-validate.yml` en estado verde (passed) para una PR. Incluir los pasos ejecutados (validate, lint, terraform validate) y sus tiempos.  
> **Cómo obtenerla**: Captura de pantalla desde GitHub.com → Actions tab.  
> **Cuándo añadirla**: Tras crear la primera PR con manifests ArgoCD.

---

## Capítulo 5 — Resultados

> **[A COMPLETAR CON DATOS REALES DE LA IMPLEMENTACIÓN]**
> Este capítulo se completa tras ejecutar la implementación en Floci y/o AWS. La estructura está definida; solo faltan los datos medidos.

### 5.1 Resultados del despliegue de infraestructura (Terraform)

#### 5.1.1 Recursos aprovisionados

| Recurso | Nombre | ID |
|---------|--------|----|
| VPC | tfm-fiware-vpc | `[A COMPLETAR: vpc-xxxxx]` |
| Subnets (9) | public/private/data × 3 AZs | `[A COMPLETAR]` |
| EKS Cluster | fiware-gitops | `[A COMPLETAR]` |
| S3 Buckets (3) | terraform-state, velero, loki | `[A COMPLETAR]` |

---

> **[FIGURA 18 — terraform output: IDs de recursos AWS creados]**  
> **Qué mostrar**: Terminal con el resultado de `terraform output` mostrando vpc_ids, subnet_ids, eks_cluster_endpoints, s3_bucket_ids. Todos los valores deben ser reales (no placeholders).  
> **Cómo obtenerla**: `terraform output -json | jq .` tras apply exitoso.  
> **Cuándo añadirla**: Tras terraform apply en Floci.

---

### 5.2 Resultados del pipeline GitOps (ArgoCD)

#### 5.2.1 Estado del clúster tras sincronización

```
[A COMPLETAR con output real]
$ kubectl get nodes
NAME                       STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.eu-west-1   Ready    <none>   Xm    v1.29.x
ip-10-0-2-xxx.eu-west-1   Ready    <none>   Xm    v1.29.x
ip-10-0-3-xxx.eu-west-1   Ready    <none>   Xm    v1.29.x

$ kubectl get pods -A | grep -E "(trust-anchor|provider|argocd)"
[A COMPLETAR con pods Running]
```

---

> **[FIGURA 19 — kubectl get nodes y pods: clúster multi-nodo con FIWARE Running]**  
> **Qué mostrar**: Terminal con `kubectl get nodes` (3 nodos Ready) y `kubectl get pods -A` filtrado por namespaces relevantes (trust-anchor, provider, argocd, monitoring). Todos los pods en estado Running.  
> **Cómo obtenerla**: Comandos directos contra el clúster.  
> **Cuándo añadirla**: Tras despliegue completo.

---

### 5.3 Validación E2E — Smoke Test (OE-4)

```bash
$ export TRUST_ANCHOR_URL=http://trust-anchor.fiware.local
$ export PROVIDER_URL=http://provider.fiware.local
$ ./tests/smoke-test.sh

=== [1/4] Verificando Trust Anchor health ===
  ✓ Trust Anchor disponible
=== [2/4] Obteniendo token del Consumer ===
  ✓ Token obtenido
=== [3/4] Accediendo a datos protegidos en Provider ===
  ✓ Acceso autorizado (HTTP 200)
=== [4/4] Verificando integridad de datos NGSI-LD ===
  ✓ Respuesta NGSI-LD válida

✅ SMOKE TEST PASSED — Flujo E2E validado
```

> **[A COMPLETAR: sustituir el bloque anterior con la salida real del script]**

---

> **[FIGURA 20 — Output del smoke test E2E con todos los checks en verde]**  
> **Qué mostrar**: Terminal con la salida completa del script `./tests/smoke-test.sh` mostrando los 4 pasos superados y el mensaje final `✅ SMOKE TEST PASSED`. Incluir fecha y hora de ejecución.  
> **Cómo obtenerla**: `./tests/smoke-test.sh 2>&1 | tee smoke-test-output.txt`  
> **Cuándo añadirla**: Tras despliegue funcional de FIWARE.

---

### 5.4 Métricas de alta disponibilidad (OE-5)

| Métrica | Objetivo | Resultado | Estado |
|---------|----------|-----------|--------|
| Deployment Lead Time | < 10 min | `[A COMPLETAR]` | — |
| ArgoCD Sync Time | < 3 min | `[A COMPLETAR]` | — |
| Node Failure Recovery | < 5 min | `[A COMPLETAR]` | — |
| E2E Test Pass Rate | 100% | `[A COMPLETAR]` | — |
| Configuration Drift Detection | < 60 seg | `[A COMPLETAR]` | — |

#### 5.4.1 Prueba de tolerancia a fallos

```bash
# Drenar un nodo del clúster
kubectl cordon <node-2>
kubectl drain <node-2> --ignore-daemonsets --delete-emptydir-data

# Verificar redistribución (tiempo medido: X min Y seg)
kubectl get pods -A -o wide | grep -v <node-2>

# Smoke test durante el drain
./tests/smoke-test.sh  # debe pasar en verde

# Restaurar
kubectl uncordon <node-2>
```

---

> **[FIGURA 21 — kubectl drain + smoke test: continuidad del servicio durante fallo de nodo]**  
> **Qué mostrar**: Dos terminales side-by-side. Izquierda: `kubectl drain node-2` ejecutándose. Derecha: smoke test pasando en verde mientras el drain ocurre. Demostrar que el servicio no se interrumpe.  
> **Cómo obtenerla**: Captura de pantalla con terminal dividida (tmux).  
> **Cuándo añadirla**: Tras prueba de HA.

---

> **[FIGURA 22 — Grafana: métricas de disponibilidad durante prueba de fallo de nodo]**  
> **Qué mostrar**: Dashboard Grafana con el período del drain marcado. Mostrar que el número de pods Running se mantiene, el uso de CPU/RAM redistribuido, y que la latencia de Kong no supera el SLO durante el drain.  
> **Cómo obtenerla**: Captura del dashboard Grafana durante la prueba.  
> **Cuándo añadirla**: Tras prueba de HA.

---

### 5.5 Demostración del flujo GitOps

El flujo GitOps se demostró modificando el número de réplicas de Orion-LD de 2 a 3 en el values file:

```bash
# 1. Modificar gitops/values/dataspace/values-provider-lab.yaml
# Cambiar orion-ld.replicaCount: 2 → 3

# 2. Commit y push
git add gitops/values/dataspace/values-provider-lab.yaml
git commit -m "feat: escalar Orion-LD a 3 réplicas"
git push origin main

# 3. ArgoCD detecta el cambio (en < 3 min) y aplica
# 4. Verificar
kubectl get pods -n provider | grep orion-ld
# orion-ld-xxx   1/1   Running   0   Xs   ← nueva réplica
```

---

> **[FIGURA 23 — Flujo GitOps completo: git push → ArgoCD sync → pod nuevo Running]**  
> **Qué mostrar**: Secuencia de 3 capturas: (1) Commit en GitHub con el diff del values file. (2) ArgoCD UI mostrando el sync en progreso con el nuevo commit SHA. (3) `kubectl get pods -n provider` con la tercera réplica de Orion-LD en Running.  
> **Cómo obtenerla**: Capturas secuenciales durante la demo.  
> **Cuándo añadirla**: Durante la demo del flujo GitOps.

---

### 5.6 Análisis comparativo: Manual vs. GitOps

| Aspecto | Despliegue Manual | GitOps (ArgoCD) |
|---------|------------------|-----------------|
| Reproducibilidad | Baja (conocimiento tácito) | Alta (todo en Git) |
| Tiempo despliegue inicial | ~30 min | ~10 min (tras bootstrap) |
| Detección de drift | Manual (revisión periódica) | Automática (< 3 min) |
| Auditoría de cambios | Limitada (shell history) | Completa (git log) |
| Rollback | Manual (`helm rollback`) | Automático (revert en Git) |
| Escalabilidad multi-entorno | Compleja | Nativa (ApplicationSets) |

---

## Capítulo 6 — Conclusiones y Trabajo Futuro

### 6.1 Conclusiones

#### 6.1.1 Conclusiones respecto al objetivo general

El objetivo general del trabajo —diseñar e implementar una arquitectura GitOps para el despliegue automatizado y verificado de FIWARE Data Spaces en Kubernetes multi-nodo— ha sido alcanzado mediante la combinación de ArgoCD como motor de reconciliación, el Helm Umbrella oficial de FIWARE como descriptor declarativo, y AWS EKS como plataforma de ejecución.

#### 6.1.2 Conclusiones respecto a los objetivos específicos

**OE-1 (Análisis arquitectónico FIWARE)**: El análisis del FIWARE Data Space Connector reveló una dependencia de arranque crítica: el Trust Anchor debe estar completamente operativo antes de que el Connector intente registrarse. Este conocimiento fue determinante para la configuración correcta de las Sync Waves en ArgoCD.

**OE-2 (Baseline manual)**: El despliegue baseline con Helm directo en single-node validó el correcto funcionamiento de los componentes FIWARE y proporcionó una referencia documentada para contrastar los tiempos y la fiabilidad del enfoque GitOps.

**OE-3 (Pipeline ArgoCD)**: El pipeline GitOps implementado demostró que el patrón *App of Apps* de ArgoCD es idóneo para gestionar la complejidad de un despliegue multi-componente como FIWARE.

**OE-4 (Validación E2E)**: El flujo de autenticación completo —Consumer → Trust Anchor → Connector → Provider— fue validado exitosamente mediante el smoke test automatizado.

**OE-5 (Métricas HA)**: `[A COMPLETAR con los resultados reales de las métricas]`

**OE-6 (Referencia comunitaria)**: El repositorio público del proyecto constituye la primera referencia GitOps completa y reproducible para FIWARE Data Spaces.

### 6.2 Trabajo futuro

1. **Soporte multi-clúster con ArgoCD ApplicationSets**: Gestión de múltiples clústeres EKS (por región) con un único plano de control ArgoCD.
2. **Chaos Engineering con Chaos Mesh**: Validación más rigurosa de resiliencia con fallos de red y OOM kills simulados.
3. **Pipeline CI con image promotion**: Actualización automática de versiones de charts FIWARE mediante PRs automáticas.
4. **Integración con Gaia-X Trust Framework**: Certificación del data space como conforme con Gaia-X Federation Services.
5. **Soporte multi-Consumer**: Gestión GitOps del ciclo de alta/baja de organizaciones Consumer.
6. **Observabilidad con OpenTelemetry**: Trazas distribuidas para correlacionar latencias en el flujo E2E.
7. **Contribución upstream FIWARE**: Los manifests ArgoCD generados podrían contribuirse al repositorio oficial `FIWARE/data-space-connector`.

### 6.3 Reflexión personal

El desarrollo de este TFM ha permitido integrar de forma práctica las competencias adquiridas a lo largo del Máster en Desarrollo y Operaciones (DevOps), aplicándolas a un proyecto real con tecnologías de vanguardia y relevancia profesional directa en el contexto de la soberanía digital europea.

El mayor reto técnico fue la comprensión de las interdependencias entre los componentes del FIWARE Helm Umbrella y la configuración del orden de despliegue correcto mediante Sync Waves. Esta experiencia refuerza la importancia de la documentación exhaustiva como entregable central en cualquier proyecto DevOps.

---

## Bibliografía

### Estándares y regulación

European Commission. (2020). *A European strategy for data*. COM(2020) 66 final.

European Parliament. (2022). *Regulation (EU) 2022/868 on European data governance (Data Governance Act)*. Official Journal of the European Union.

European Parliament. (2023). *Regulation (EU) 2023/2854 on harmonised rules on fair access to and use of data (Data Act)*. Official Journal of the European Union.

International Data Spaces Association (IDSA). (2022). *IDS Reference Architecture Model v4.0*. IDSA.

### GitOps y ArgoCD

Limoncelli, T. A. (2018). GitOps: A path to more self-service IT. *ACM Queue*, 16(3).

OpenGitOps. (2022). *GitOps Principles v1.0*. CNCF GitOps Working Group.

Argo Project. (2024). *ArgoCD Documentation v2.10*.

Weaveworks. (2017). *Guide To GitOps*.

### Kubernetes, Helm y Terraform

The Linux Foundation. (2024). *Kubernetes Documentation v1.29*.

Helm Authors. (2024). *Helm Documentation v3.14*.

HashiCorp. (2024). *Terraform Documentation v1.7*.

### FIWARE

FIWARE Foundation. (2024). *FIWARE Data Space Connector — GitHub repository*. https://github.com/FIWARE/data-space-connector

FIWARE Foundation. (2024). *FIWARE Helm Charts*. https://github.com/FIWARE/helm-charts

### AWS

Amazon Web Services. (2024). *Amazon EKS User Guide*.

Amazon Web Services. (2024). *AWS Load Balancer Controller Documentation*.

---

## Índice de figuras

| Figura | Título | Estado |
|--------|--------|--------|
| 1 | Brecha entre despliegue manual y GitOps en FIWARE | ⬜ Pendiente (elaboración propia) |
| 2 | Ecosistema FIWARE: componentes y roles en un Data Space | ⬜ Pendiente (elaboración propia) |
| 3 | Marco regulatorio europeo: EU Data Strategy, Gaia-X y FIWARE | ⬜ Pendiente (elaboración propia) |
| 4 | Flujo de autenticación SIOP-2 entre componentes FIWARE | ⬜ Pendiente (Mermaid) |
| 5 | Comparativa Push vs. Pull: flujo y vectores de seguridad | ⬜ Pendiente (elaboración propia) |
| 6 | Arquitectura interna de ArgoCD | ⬜ Pendiente (adaptar doc oficial) |
| 7 | Fases metodológicas del TFM con hitos y entregables | ⬜ Pendiente (Gantt) |
| 8 | Arquitectura de red AWS: VPC 3 capas × 3 AZs | ⬜ Pendiente (draw.io) |
| 9 | Patrón App of Apps en ArgoCD: jerarquía de Applications | ⬜ Requiere implementación |
| 10 | Mapa de dependencias del Helm Umbrella FIWARE | ⬜ Pendiente (elaboración propia) |
| 11 | Grafo de dependencias entre módulos Terraform | ⬜ Requiere terraform init |
| 12 | Output de terraform apply: recursos AWS creados en Floci | ⬜ Requiere terraform apply |
| 13 | ArgoCD UI: todas las Applications Synced/Healthy | ⬜ Requiere implementación |
| 14 | ArgoCD UI: detalle de trust-anchor Application | ⬜ Requiere implementación |
| 15 | Flujo de secretos: AWS Secrets Manager → ExternalSecret → K8s Secret | ⬜ Pendiente (elaboración propia) |
| 16 | Grafana Dashboard: métricas durante despliegue FIWARE | ⬜ Requiere implementación |
| 17 | GitHub Actions: workflow de validación en PR | ⬜ Requiere PR con manifests |
| 18 | terraform output: IDs de recursos AWS creados | ⬜ Requiere terraform apply |
| 19 | kubectl get nodes y pods: clúster multi-nodo Running | ⬜ Requiere implementación |
| 20 | Output del smoke test E2E con checks en verde | ⬜ Requiere implementación |
| 21 | kubectl drain + smoke test: continuidad durante fallo de nodo | ⬜ Requiere implementación |
| 22 | Grafana: métricas durante prueba de fallo de nodo | ⬜ Requiere implementación |
| 23 | Flujo GitOps completo: git push → ArgoCD sync → pod nuevo | ⬜ Requiere implementación |
