# Capítulo 2 — Contexto y Estado del Arte

## 2.1 FIWARE y los Data Spaces europeos

### 2.1.1 La plataforma FIWARE

FIWARE es una iniciativa promovida por la Unión Europea y soportada por la FIWARE Foundation que proporciona un conjunto de APIs abiertas y componentes de software para la construcción de soluciones de *smart cities*, IoT e intercambio de datos. Su componente central es **Orion-LD**, un *context broker* que implementa la especificación **NGSI-LD** (Next Generation Service Interface — Linked Data) del ETSI, permitiendo la gestión y el intercambio de información contextual de forma estandarizada.

La plataforma FIWARE ha evolucionado desde su origen como proyecto de infraestructura para smart cities hacia convertirse en el substrato tecnológico preferente para la implementación de *data spaces* interoperables en el marco regulatorio europeo.

### 2.1.2 EU Data Spaces y Gaia-X

La **Estrategia Europea de Datos** (European Data Strategy, 2020) y su materialización en el **Data Governance Act** (Reglamento 2022/868) y el **Data Act** (Reglamento 2023/2854) establecen el marco legal para la creación de espacios comunes de datos (*data spaces*) en sectores estratégicos como salud, energía, agricultura y transporte.

**Gaia-X** es la iniciativa federada europea para una infraestructura de datos soberana que complementa el marco regulatorio definiendo las reglas de confianza (*Trust Framework*) para los participantes de un data space. FIWARE actúa como implementación de referencia compatible con Gaia-X, proporcionando los componentes necesarios para los roles de Consumer, Provider, Trust Anchor y Connector.

### 2.1.3 FIWARE Data Space Connector

El **FIWARE Data Space Connector** (https://github.com/FIWARE/data-space-connector) es el Helm Umbrella oficial que empaqueta todos los componentes necesarios para desplegar un dataspace FIWARE completo:

| Componente | Función | Tecnología |
|-----------|---------|-----------|
| **Trust Anchor** | Gestión de identidades y emisión de credenciales verificables | Keyrock Identity Manager |
| **Trusted Issuers List** | Registro de entidades emisoras confiables | API REST + base de datos |
| **Credentials Config Service** | Configuración de esquemas de credenciales | Microservicio Go |
| **Data Space Connector Core** | Broker de contexto NGSI-LD | Orion-LD |
| **PDP (Policy Decision Point)** | Evaluación de políticas de acceso | OPA / DSBA-compatible |
| **Kong API Gateway** | PEP Proxy y gestión de APIs | Kong + plugins FIWARE |

El Helm Umbrella permite desplegar estos componentes de forma coordinada, gestionando las dependencias entre charts y la configuración de red interna del clúster Kubernetes.

## 2.2 GitOps: principios y evolución

### 2.2.1 Origen y definición

El término **GitOps** fue acuñado por Alexis Richardson (Weaveworks) en 2017 para describir un modelo operativo en el que el repositorio Git actúa como la única fuente de verdad (*single source of truth*) del estado deseado de la infraestructura y las aplicaciones. Los cuatro principios fundamentales de GitOps, formalizados por la **OpenGitOps** specification (CNCF Working Group, 2022), son:

1. **Declarativo**: El estado deseado del sistema se expresa de forma declarativa.
2. **Versionado e inmutable**: El estado deseado se almacena de forma que preserva la historia completa y permite auditoría.
3. **Extraído automáticamente** (*pulled automatically*): Los agentes de software extraen automáticamente las declaraciones de estado desde la fuente.
4. **Reconciliado continuamente**: Los agentes de software verifican y corrigen de forma continua cualquier divergencia entre el estado declarado y el estado observado.

### 2.2.2 Modelos Push vs. Pull

Existen dos paradigmas principales de despliegue en entornos de integración continua:

**Modelo Push (CI-driven)**: El pipeline de CI/CD (e.g., Jenkins, GitLab CI) tiene acceso directo al clúster Kubernetes y ejecuta `kubectl apply` o `helm upgrade` al detectar cambios. Este modelo introduce un vector de ataque al requerir credenciales del clúster en el sistema CI.

**Modelo Pull (GitOps)**: Un operador instalado dentro del propio clúster (e.g., ArgoCD, Flux) monitoriza el repositorio Git y reconcilia el estado del clúster con el estado declarado. Este modelo minimiza la superficie de ataque y se alinea con el principio de *least privilege*.

Este TFM adopta el modelo Pull mediante ArgoCD, dado que es el enfoque recomendado por la CNCF para entornos de producción con requisitos de seguridad.

### 2.2.3 ArgoCD

**ArgoCD** es un controlador GitOps declarativo para Kubernetes, graduado en la CNCF (Cloud Native Computing Foundation) como proyecto de nivel *Graduated* en 2022. Sus características principales relevantes para este trabajo son:

- **Application CRD**: Define el origen Git (repo, path, revision) y el destino (clúster, namespace) de una aplicación.
- **ApplicationSet**: Permite generar múltiples Applications desde plantillas, esencial para despliegues multi-clúster.
- **Sync Waves**: Control del orden de despliegue de recursos mediante anotaciones.
- **Health Assessment**: Evaluación del estado de recursos Kubernetes custom (Deployments, StatefulSets, CRDs).
- **UI Dashboard**: Interfaz web para observabilidad del estado de sincronización.
- **RBAC nativo**: Integración con OIDC para control de acceso granular.

### 2.2.4 Helm como gestor de paquetes Kubernetes

**Helm** es el gestor de paquetes estándar de Kubernetes, que permite parametrizar y versionar manifiestos mediante plantillas Go. En el contexto de GitOps con ArgoCD, Helm se utiliza de dos formas complementarias:

1. **ArgoCD como renderizador Helm**: ArgoCD puede renderizar charts Helm directamente, aplicando valores (`values.yaml`) almacenados en Git.
2. **Umbrella Charts**: Un chart Helm puede declarar dependencias sobre otros charts (sub-charts), creando una unidad de despliegue compuesta. El FIWARE Data Space Connector utiliza este patrón para agregar todos sus componentes.

## 2.3 Kubernetes en entornos cloud: Amazon EKS

**Amazon Elastic Kubernetes Service (EKS)** es el servicio gestionado de Kubernetes de AWS. Para este TFM, EKS proporciona:

- **Control Plane gestionado**: AWS gestiona la alta disponibilidad del control plane (etcd, API server) sin coste operativo adicional.
- **Integración con IAM**: *IAM Roles for Service Accounts* (IRSA) permite asignar permisos AWS a pods individuales sin credenciales estáticas, alineado con el requisito OIDC del perfil profesional del alumno.
- **EBS/EFS como PersistentVolumes**: Almacenamiento persistente para los componentes stateful de FIWARE (bases de datos).
- **AWS Load Balancer Controller**: Provisionamiento automático de NLB/ALB para exposición de servicios.

## 2.4 Trabajos relacionados

### 2.4.1 Despliegues FIWARE existentes

El repositorio oficial FIWARE/data-space-connector proporciona documentación para despliegue con Helm directo, pero no incluye configuración para ArgoCD ni para entornos multi-nodo. La comunidad FIWARE ha publicado tutoriales de despliegue single-node, pero la automatización GitOps end-to-end es un área no cubierta en la literatura disponible.

### 2.4.2 GitOps en entornos de investigación y data spaces

Trabajos como el de *Scrocca et al. (2023)* sobre "Data Space Connectors in Practice" analizan la adopción de IDSA/Gaia-X en entornos productivos, pero sin abordar la automatización del despliegue. El proyecto **IDS Reference Architecture** (IDSA) define el modelo conceptual pero delega la implementación operativa en los adopters.

La presente contribución se distingue al ser, según el conocimiento del autor, la primera referencia GitOps completa y reproducible para FIWARE Data Spaces con ArgoCD en Kubernetes multi-nodo.

## 2.5 Análisis comparativo de herramientas GitOps

| Herramienta | Tipo | Multiclúster | Helm nativo | Madurez CNCF | Selección |
|------------|------|-------------|------------|-------------|-----------|
| **ArgoCD** | Pull | Sí | Sí | Graduated | ✅ Seleccionada |
| Flux v2 | Pull | Sí | Sí | Graduated | Alternativa viable |
| Jenkins X | Push/Pull | Parcial | Sí | Sandbox | Descartada (complejidad) |
| Spinnaker | Push | Sí | Parcial | Graduated | Descartada (overhead) |

ArgoCD fue seleccionado por su madurez, adopción empresarial amplia, soporte nativo de Helm Umbrella, y la existencia de documentación extensa para integración con EKS.
