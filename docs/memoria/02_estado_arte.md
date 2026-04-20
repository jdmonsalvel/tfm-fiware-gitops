# 2. Estado del Arte

## 2.1 Espacios de Datos Europeos: Fundamentos y Marco Normativo

### 2.1.1 La Estrategia Europea de Datos

La Comisión Europea define un espacio de datos (*Data Space*) como «un marco de acuerdos técnicos y normativos que permite a personas y organizaciones compartir datos de forma segura y eficiente, manteniendo el control sobre los propios datos» (European Commission, 2020). Esta definición encierra tres principios que condicionan las decisiones de diseño técnico: (i) soberanía sobre los datos, (ii) interoperabilidad entre participantes, y (iii) aplicación de reglas de acceso verificables y auditables.

El marco regulatorio que sustenta esta estrategia está compuesto por cuatro instrumentos principales:

| Instrumento | Referencia | Año | Relevancia para el TFM |
|-------------|-----------|-----|------------------------|
| Data Governance Act (DGA) | Reglamento UE 2022/868 | 2022 | Define los intermediarios de datos y sus obligaciones |
| Data Act | Reglamento UE 2023/2854 | 2023 | Regula el acceso a datos generados por dispositivos IoT |
| Directiva Open Data | Directiva UE 2019/1024 | 2019 | Reutilización de datos del sector público |
| AI Act | Reglamento UE 2024/1689 | 2024 | Gobernanza de datos para sistemas de IA |

### 2.1.2 Iniciativas de Referencia: IDSA y Gaia-X

El **International Data Spaces Reference Architecture Model** (IDSA RAM v4, IDSA, 2022) define los componentes lógicos de un Data Space mediante una arquitectura de capas: (i) capa de datos, (ii) capa de servicios, (iii) capa de conectores y (iv) capa de gobernanza. El componente central es el *IDS Connector*, un intermediario técnico que implementa los protocolos de intercambio seguro de datos con soporte para políticas de uso expresadas en ODRL (*Open Digital Rights Language*).

**Gaia-X** (Gaia-X, 2021) complementa el enfoque IDSA con un marco de confianza basado en la verificación de atributos de participantes mediante *Verifiable Credentials* (W3C VC) y un catálogo federado de servicios cloud conformes. Su Arquitectura de Referencia define tres planos: plano de datos, plano de control y plano de confianza (*trust plane*).

### 2.1.3 Marco de Confianza iSHARE

iSHARE (iSHARE Foundation, 2023) es un esquema de confianza interoperable originalmente diseñado para el sector logístico holandés y adoptado progresivamente como referencia técnica por la Data Spaces Business Alliance (DSBA). Define un conjunto de convenciones sobre OAuth2/OpenID Connect que permiten la autenticación y autorización federada entre participantes que no necesariamente comparten directorio de identidades.

Los elementos clave de iSHARE relevantes para este trabajo son:
- **Trusted List / Satellite:** Registro de participantes certificados que actúa como ancla de confianza
- **iSHARE JWT:** Token de autenticación firmado con certificado eIDAS (X.509)
- **Delegation Evidence:** Mecanismo para delegar permisos de acceso entre participantes
- **Autorización M2M:** Flujo *client_credentials* de OAuth2 adaptado para identidades de máquina

## 2.2 FIWARE y la Especificación NGSI-LD

### 2.2.1 El Ecosistema FIWARE

FIWARE (FIWARE Foundation, 2023) es una iniciativa de código abierto, originalmente financiada por la UE en el programa FP7, que proporciona componentes reutilizables (*Generic Enablers*, GE) para el desarrollo de plataformas de datos de contexto. Su especificación técnica central es la API NGSI-LD, estandarizada por ETSI en el documento ETSI GS CIM 009 v1.6 (ETSI, 2023).

NGSI-LD extiende el modelo anterior (NGSI v2) incorporando semántica formal basada en JSON-LD y el estándar de linked data RDF, lo que permite la representación de conocimiento contextual interoperable mediante vocabularios compartidos (*context*). El modelo de datos define tres tipos de atributos para una entidad: *Property*, *Relationship* y *GeoProperty* (ver Figura 2.2 en docs/diagrams/).

### 2.2.2 Componentes FIWARE Utilizados

**Orion-LD Context Broker** es la implementación de referencia de la API NGSI-LD. Gestiona el ciclo de vida de entidades de contexto (creación, actualización, suscripciones) y ofrece capacidades de notificación en tiempo real mediante el patrón *publish-subscribe*. Desde la versión 1.0.0, incluye soporte nativo para NGSI-LD v1.3 y persistencia en MongoDB (FIWARE Foundation, 2023b).

**Keyrock Identity Manager** implementa gestión de identidades con soporte para OAuth2, OpenID Connect y SAML2. En el contexto de Data Spaces, actúa como Proveedor de Autorización (*Authorization Server*) y evalúa políticas de control de acceso mediante el motor XACML AuthzForce CE. Su integración con iSHARE permite la validación de participantes certificados (FIWARE Foundation, 2023c).

**Wilma PEP Proxy** (*Policy Enforcement Point*) intercepta las solicitudes a los servicios protegidos y delega las decisiones de autorización en Keyrock. Implementa el patrón arquitectónico de proxy inverso con verificación JWT, siendo transparente para el consumidor de datos (FIWARE Foundation, 2023d).

### 2.2.3 Análisis Comparativo: Alternativas a FIWARE

| Criterio | FIWARE (Orion-LD) | Eclipse Ditto | FROST-Server |
|---------|-------------------|---------------|-------------|
| Especificación | ETSI NGSI-LD | W3C WoT / JSON-PATCH | OGC SensorThings API |
| Modelo semántico | JSON-LD / RDF | Digital Twin Description | OGC O&M |
| Soporte NGSI-LD | Nativo | Parcial (extensión) | No |
| Integración iSHARE | Sí (Keyrock + Wilma) | No nativa | No nativa |
| Licencia | AGPL-3.0 | EPL-2.0 | LGPL-3.0 |
| Madurez (prod.) | Alta | Alta | Media |
| Soporte EU Dataspcaes | Oficial (DSBA) | En desarrollo | No |

FIWARE resulta la alternativa más alineada con los requisitos del presente trabajo, especialmente por su integración oficial con el DSBA Technical Convergence Framework y su soporte nativo para NGSI-LD.

## 2.3 GitOps: Principios, Herramientas y Adopción

### 2.3.1 Fundamentos del Paradigma GitOps

El término GitOps fue acuñado por Weaveworks en 2017 (Limoncelli, 2018) para describir un modelo operacional en el que el estado deseado de los sistemas de producción se define de forma declarativa en un repositorio Git, y un operador de software garantiza la convergencia continua del estado real hacia el estado deseado mediante bucles de reconciliación. Los cuatro principios fundamentales de GitOps, formalizados en la especificación OpenGitOps v1.0 (CNCF, 2022), son:

1. **Declarativo:** El estado del sistema se define mediante manifests declarativos, no mediante scripts imperativos.
2. **Versionado e inmutable:** El estado deseado está almacenado en Git, con historial completo y capacidad de rollback.
3. **Extraído automáticamente (*Pull-based*):** El agente de reconciliación extrae los cambios del repositorio, en lugar de recibir instrucciones de sistemas externos (*push*).
4. **Reconciliación continua:** Un agente de software detecta y corrige de forma autónoma cualquier desviación entre el estado deseado y el estado real.

### 2.3.2 Comparativa ArgoCD vs FluxCD

| Criterio | ArgoCD v2.11 | FluxCD v2.3 |
|---------|-------------|------------|
| Interfaz gráfica | Sí (UI completa) | No (solo CLI) |
| Multi-tenancy | Sí (AppProjects) | Sí (Tenants) |
| Patrón App of Apps | Sí (nativo) | Sí (Kustomization) |
| Notificaciones | Plugin notifications | Sí (Alert CRD) |
| SSO / RBAC | Sí (OIDC + Dex) | Parcial |
| Soporte Helm | Sí (nativo) | Sí (HelmRelease CRD) |
| CNCF Graduated | Sí (2022) | Sí (2022) |
| Adopción enterprise | Muy alta | Alta |

La selección de ArgoCD para este trabajo se justifica por su interfaz gráfica (relevante para demostración académica), su soporte nativo para el patrón App of Apps y su amplia adopción empresarial que facilita la transferibilidad del modelo propuesto.

## 2.4 Infrastructure as Code y Kubernetes en AWS

### 2.4.1 Terraform como Herramienta IaC

Terraform (HashiCorp, 2014) es la herramienta de Infrastructure as Code más adoptada en entornos cloud heterogéneos (HashiCorp, 2023). Su modelo de ejecución basado en grafos de dependencias, junto con la gestión de estado remoto y el ecosistema de módulos públicos (Terraform Registry), lo posicionan como estándar *de facto* para el aprovisionamiento de infraestructura reproducible. En el contexto de este trabajo, se utiliza el módulo oficial `terraform-aws-modules/eks/aws` (versión 20.x) que encapsula las mejores prácticas para la creación de clústeres EKS documentadas en la AWS EKS Best Practices Guide (AWS, 2023).

### 2.4.2 Amazon EKS y el Modelo de Responsabilidad Compartida

Amazon Elastic Kubernetes Service (EKS) ofrece un plano de control Kubernetes gestionado por AWS, eliminando la complejidad operacional de los componentes *etcd*, *kube-apiserver* y *kube-controller-manager*. El modelo de responsabilidad compartida en EKS asigna al cliente la gestión de: (i) grupos de nodos (*node groups*), (ii) configuración de red (VPC, subnets, Security Groups), (iii) políticas IAM y (iv) configuración de add-ons (CSI drivers, CoreDNS, kube-proxy).

## 2.5 Gestión de Secretos en Entornos Kubernetes

La gestión segura de secretos en Kubernetes es un requisito crítico en arquitecturas de Data Space. El enfoque nativo de Kubernetes (*Secrets* como objetos base64-encoded) resulta insuficiente para entornos de producción por carecer de cifrado en reposo por defecto y de rotación automática. La solución adoptada en este trabajo, External Secrets Operator (ESO), implementa un patrón de sincronización desde fuentes externas (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault) hacia secretos nativos de Kubernetes, desacoplando el ciclo de vida de los secretos del ciclo de vida de las aplicaciones (External Secrets, 2023).

## 2.6 Trabajos Relacionados

La revisión de literatura identifica trabajos previos relevantes en tres categorías:

- **Despliegues FIWARE en cloud:** Llorente et al. (2023) presentan un análisis de despliegues FIWARE en entornos multi-cloud, pero no abordan el paradigma GitOps ni la integración con Data Spaces europeos.
- **GitOps para IoT/Edge:** Rahman et al. (2022) proponen un modelo GitOps para plataformas IoT basadas en Kubernetes, sin considerar el contexto específico de Data Spaces ni los marcos de confianza iSHARE.
- **Data Space técnicos:** El DSBA Technical Convergence Framework (DSBA, 2023) define la arquitectura de referencia para Data Spaces basados en FIWARE, pero no incluye guías de implementación operacional automatizada.

El presente trabajo contribuye a cubrir la intersección de estos tres ámbitos, que no ha sido abordada de forma integrada en la literatura existente.
