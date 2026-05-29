# 4. Arquitectura y Diseño

## 4.1 Principios de Diseño

El diseño del modelo de referencia se guía por los siguientes principios arquitectónicos, derivados de los paradigmas GitOps (CNCF, 2022), de los principios de diseño cloud-native (CNCF, 2023) y de los requisitos de los Data Spaces europeos (DSBA, 2023):

1. **Declaratividad:** Todo estado del sistema —tanto la infraestructura como las aplicaciones— se define mediante archivos declarativos versionados en Git. Las operaciones imperativas se eliminan del flujo operacional nominal.
2. **Inmutabilidad:** Los artefactos desplegados (imágenes de contenedor, charts Helm) se referencian mediante *digests* o versiones fijadas, garantizando que el mismo commit siempre produce el mismo despliegue.
3. **Mínimo privilegio:** Los componentes solo obtienen los permisos estrictamente necesarios para su función. Los roles IAM de AWS siguen el principio de least-privilege con granularidad de servicio. Los roles Kubernetes se definen mediante RBAC con scope de namespace.
4. **Defense in depth:** La seguridad se implementa en múltiples capas: red (Security Groups, Network Policies), identidad (IRSA, OIDC), aplicación (PEP Proxy, JWT validation) y datos (cifrado en reposo con KMS).
5. **Observabilidad by design:** Los componentes exponen métricas en formato Prometheus, logs estructurados y trazas distribuidas desde el momento del despliegue inicial.
6. **Soberanía de datos:** Los datos nunca salen del perímetro definido sin pasar por el mecanismo de control de acceso. Los secretos nunca se almacenan en el repositorio Git ni en imágenes de contenedor.

## 4.2 Vista Contextual (C4 — Level 1)

> Ver diagrama D1 en `docs/diagrams/README.md` — Figura 4.1

El sistema se contextualiza en un ecosistema con tres actores externos y dos sistemas externos:

- **Ingeniero DevOps (actor primario):** Gestiona el repositorio Git (manifests, IaC, configuración). Es el único actor con acceso de escritura al repositorio.
- **Consumidor de Datos (actor externo):** Aplicación o servicio que accede a datos de contexto mediante la API NGSI-LD. Solo tiene acceso de lectura, mediado por Wilma.
- **Proveedor de Datos (actor externo):** Produce y publica entidades NGSI-LD en el Context Broker. Puede tener acceso de escritura condicionado por políticas.
- **GitHub (sistema externo):** Repositorio Git que actúa como *Single Source of Truth*. Almacena tanto el estado deseado del sistema como el historial completo de cambios.
- **iSHARE Satellite (sistema externo):** Ancla de confianza del Data Space. Valida que los participantes están certificados y son de confianza antes de emitir tokens de acceso.

## 4.3 Vista de Contenedores (C4 — Level 2)

> Ver diagrama D2 en `docs/diagrams/README.md` — Figura 4.2

La plataforma se despliega en un clúster Amazon EKS estructurado en cuatro namespaces Kubernetes con responsabilidades claramente separadas:

### 4.3.1 Namespace `argocd`

Contiene el operador GitOps. ArgoCD se instala mediante su chart Helm oficial y se configura para monitorizar el repositorio Git del proyecto. El patrón **App of Apps** (ArgoCD, 2023) se implementa mediante una Application raíz que gestiona el ciclo de vida del resto de Applications, garantizando bootstrapping idempotente del sistema completo desde un único punto de entrada.

### 4.3.2 Namespace `fiware`

Contiene los componentes del Data Space:

- **Orion-LD:** Context Broker NGSI-LD. Expone la API REST en el puerto 1026. Persiste entidades en MongoDB mediante el driver oficial `ngsi-orion`.
- **Keyrock:** Identity Manager. Expone la interfaz de administración en el puerto 3000 y los endpoints OAuth2 en `/oauth2/token` y `/oauth2/authorize`. Persiste usuarios, aplicaciones y políticas en MySQL. Actúa como Authorization Server en el flujo iSHARE.
- **Wilma PEP Proxy:** Proxy inverso en el puerto 1027. Intercepta toda solicitud destinada a Orion-LD y delega la decisión de autorización en Keyrock antes de reenviar la solicitud al Context Broker.
- **MongoDB:** Base de datos documental para Orion-LD. Se despliega en modo standalone para el entorno de laboratorio (modo réplica para producción).
- **MySQL:** Base de datos relacional para Keyrock. Gestiona usuarios, organizaciones, aplicaciones y permisos.

### 4.3.3 Namespace `platform`

Servicios de plataforma transversales:

- **External Secrets Operator:** Sincroniza secretos desde AWS Secrets Manager hacia Kubernetes Secrets mediante el CRD `ExternalSecret`. Utiliza IRSA (IAM Roles for Service Accounts) para autenticarse en AWS sin credenciales estáticas.
- **Cert-Manager:** Gestiona certificados TLS/X.509. Provisiona y renueva automáticamente certificados Let's Encrypt para los Ingress de la plataforma.
- **Nginx Ingress Controller:** Enruta el tráfico HTTPS externo hacia los servicios internos. Termina TLS en el borde del clúster.

### 4.3.4 Namespace `monitoring`

- **Prometheus:** Recopila métricas de todos los componentes del clúster mediante *scraping* activo. Almacena series temporales con retención de 15 días.
- **Grafana:** Visualiza métricas con dashboards preconfigurados para ArgoCD, Kubernetes (Node Exporter) y FIWARE.

## 4.4 Topología de Red AWS

> Ver diagrama D3 en `docs/diagrams/README.md` — Figura 4.3

La infraestructura de red sigue el patrón recomendado por la AWS EKS Best Practices Guide (AWS, 2023) para clústeres de producción:

- **VPC:** Bloque CIDR `/16` (65.536 IPs) en la región `eu-west-1` (Irlanda), seleccionada por su conformidad con el RGPD y la proximidad a los nodos del ecosistema Gaia-X europeo.
- **Subredes públicas (3× `/24`):** Alojan el Application Load Balancer y el NAT Gateway. El tráfico de entrada (ingress) se concentra en el ALB.
- **Subredes privadas (3× `/24`):** Alojan los nodos worker de EKS. Los nodos no tienen IPs públicas y acceden a internet mediante el NAT Gateway.
- **NAT Gateway:** Punto único de salida para los nodos privados. Permite la descarga de imágenes de contenedor desde ECR y registros externos sin exponer los nodos a internet.
- **VPC Endpoints:** Los servicios AWS Secrets Manager y ECR se acceden mediante VPC Endpoints de tipo Interface, eliminando el tránsito por internet y reduciendo costes.

## 4.5 Modelo de Identidades y Acceso

### 4.5.1 IAM para AWS (IRSA)

La integración entre pods Kubernetes y servicios AWS se implementa mediante **IRSA** (*IAM Roles for Service Accounts*). Este mecanismo asocia un rol IAM a una ServiceAccount de Kubernetes mediante una anotación y un proveedor OIDC, permitiendo a los pods asumir permisos AWS sin credenciales estáticas. External Secrets Operator utiliza este mecanismo para acceder a AWS Secrets Manager con el principio de mínimo privilegio.

### 4.5.2 Control de Acceso al Data Space (iSHARE)

> Ver diagrama D4 en `docs/diagrams/README.md` — Figura 4.4

El flujo de acceso implementa el protocolo iSHARE M2M (*Machine-to-Machine*) sobre OAuth2, con los siguientes pasos:

1. El Consumidor presenta un *iSHARE JWT* firmado con su clave privada (certificado eIDAS/X.509) a Keyrock.
2. Keyrock verifica la validez del JWT y consulta al iSHARE Satellite que el Consumidor es un participante certificado (*trusted party*).
3. Tras confirmación, Keyrock emite un *Access Token* JWT con tiempo de expiración corto (30 segundos, según la especificación iSHARE).
4. El Consumidor presenta el Access Token a Wilma en cada solicitud NGSI-LD.
5. Wilma delega la decisión de autorización en Keyrock, que evalúa la política XACML correspondiente al recurso solicitado.
6. Wilma reenvía (o bloquea) la solicitud a Orion-LD según el veredicto de Keyrock.

## 4.6 Decisiones de Arquitectura (ADR)

### ADR-001: Selección de ArgoCD sobre FluxCD

**Estado:** Aceptado  
**Contexto:** Se requiere un operador GitOps para el despliegue declarativo de componentes FIWARE en Kubernetes.  
**Decisión:** Se selecciona ArgoCD v2.11 sobre FluxCD v2.3.  
**Justificación:** ArgoCD proporciona una interfaz gráfica que facilita la demostración y supervisión visual del estado de sincronización (relevante para el contexto académico), soporte nativo para el patrón App of Apps sin dependencias adicionales, y una mayor adopción empresarial que incrementa la transferibilidad del modelo.  
**Consecuencias:** Mayor consumo de memoria en el clúster (~512 MB adicionales frente a Flux). Aceptable para el entorno de laboratorio.

### ADR-002: Región AWS eu-west-1

**Estado:** Aceptado  
**Contexto:** Se requiere seleccionar una región AWS para el despliegue de la infraestructura.  
**Decisión:** Se utiliza la región `eu-west-1` (Irlanda).  
**Justificación:** Conformidad con el RGPD y la residencia de datos en la UE. Disponibilidad de todos los servicios AWS requeridos (EKS, Secrets Manager, ECR). Menor latencia hacia nodos del ecosistema Gaia-X europeo.  
**Consecuencias:** Ninguna consecuencia negativa identificada para el alcance del trabajo.

### ADR-003: MongoDB en modo standalone

**Estado:** Aceptado (con nota de deuda técnica)  
**Contexto:** Orion-LD requiere MongoDB como base de datos de persistencia.  
**Decisión:** Se despliega MongoDB en modo standalone (un único pod) para el entorno de laboratorio.  
**Justificación:** El modo *replica set* (3 nodos) incrementaría los costes AWS en ~$5/día y la complejidad operacional sin aportar valor de investigación adicional para los objetivos definidos.  
**Deuda técnica:** En entornos de producción, MongoDB debe desplegarse en modo *replica set* con 3 miembros para garantizar HA y consistencia fuerte. Documentado como mejora en el Capítulo 7.
