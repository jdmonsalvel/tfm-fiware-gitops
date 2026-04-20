# 3. Metodología

## 3.1 Paradigma de Investigación: Design Science Research

El presente Trabajo Fin de Máster se enmarca en el paradigma de investigación **Design Science Research** (DSR), propuesto por Hevner et al. (2004) y ampliamente adoptado en la disciplina de Sistemas de Información y Computación. Este paradigma se orienta a la creación y evaluación de artefactos tecnológicos novedosos —en contraposición a la ciencia descriptiva, cuyo objetivo es explicar fenómenos existentes— con el propósito de resolver problemas de ingeniería bien definidos.

Señalando los dos ciclos fundamentales del DSR según Hevner (2007):

- **Ciclo de Relevancia:** El problema a resolver (despliegue automatizado de Data Spaces FIWARE) se extrae del contexto del mundo real —la práctica profesional y los requisitos regulatorios europeos— y los resultados del trabajo se evalúan en función de su utilidad práctica para ese contexto.
- **Ciclo de Rigor:** El diseño del artefacto se fundamenta en el conocimiento existente (literatura académica, estándares técnicos, mejores prácticas de la industria) y contribuye nuevos conocimientos al cuerpo científico de la disciplina.

El artefacto producido en este trabajo es un **modelo de referencia arquitectónico** que incluye: (i) una arquitectura de sistema documentada, (ii) código de infraestructura como código reproducible, (iii) manifests GitOps versionados y (iv) un conjunto de métricas de evaluación.

## 3.2 Fases del Proyecto

El desarrollo del trabajo se estructura en cuatro fases iterativas, siguiendo el ciclo de vida definido por el DSR:

### Fase 1 — Análisis y Diseño (Semanas 1-2)

**Objetivo:** Definir los requisitos técnicos del modelo de referencia y diseñar la arquitectura del sistema.

**Actividades:**
- Revisión sistemática de literatura sobre Data Spaces, FIWARE y GitOps
- Análisis de los estándares ETSI GS CIM 009, IDSA RAM v4 e iSHARE Framework
- Definición de requisitos funcionales y no funcionales
- Diseño de la arquitectura de referencia y elaboración de diagramas (C4 model)
- Documentación de Decisiones de Arquitectura (ADR)

**Entregables:** Documento de arquitectura (Capítulo 4), catálogo de diagramas

### Fase 2 — Infraestructura (Semanas 2-3)

**Objetivo:** Provisionar la infraestructura cloud de forma reproducible mediante IaC.

**Actividades:**
- Implementación de módulos Terraform para VPC (3 AZs), EKS 1.30 y roles IAM
- Configuración de estado remoto en S3 con bloqueo en DynamoDB
- Configuración de políticas IAM de mínimo privilegio y roles IRSA
- Validación mediante `terraform plan` y escaneo de seguridad con Checkov

**Entregables:** Módulos Terraform funcionales, clúster EKS operativo

### Fase 3 — Plataforma GitOps y FIWARE (Semanas 3-5)

**Objetivo:** Desplegar ArgoCD y todos los componentes FIWARE de forma declarativa.

**Actividades:**
- Bootstrap de ArgoCD con el patrón App of Apps
- Desarrollo de Helm charts para Orion-LD, Keyrock y Wilma
- Configuración de External Secrets Operator con AWS Secrets Manager
- Integración del flujo de autenticación iSHARE
- Configuración de Nginx Ingress con TLS (Cert-Manager + Let's Encrypt)

**Entregables:** Plataforma FIWARE desplegada y accesible via HTTPS

### Fase 4 — Validación y Documentación (Semanas 5-6)

**Objetivo:** Validar el modelo mediante pruebas funcionales y métricas operacionales.

**Actividades:**
- Ejecución de pruebas funcionales E2E (ciclo completo Data Space)
- Medición de métricas de evaluación (KPIs definidos)
- Recopilación de evidencias (capturas de pantalla, logs, métricas)
- Redacción final de la memoria académica
- Preparación de la presentación de defensa

**Entregables:** Memoria TFM completa, repositorio GitHub con evidencias

## 3.3 Criterios de Evaluación y KPIs

La validación del modelo propuesto se realiza mediante el siguiente conjunto de indicadores clave de rendimiento (KPIs), organizados en cuatro dimensiones:

### Dimensión 1 — Reproducibilidad

| KPI | Descripción | Umbral aceptable |
|-----|-------------|------------------|
| RD-1 | Tiempo de despliegue completo desde `terraform apply` hasta plataforma lista | < 30 minutos |
| RD-2 | Número de pasos manuales requeridos en el despliegue | ≤ 2 |
| RD-3 | Éxito en re-despliegue tras destrucción total (`teardown + bootstrap`) | 100% |

### Dimensión 2 — Resiliencia

| KPI | Descripción | Umbral aceptable |
|-----|-------------|------------------|
| RS-1 | Recovery Time Objective (RTO) tras simulación de fallo de nodo | < 5 minutos |
| RS-2 | Tiempo de re-sincronización ArgoCD tras drift manual en cluster | < 3 minutos |

### Dimensión 3 — Seguridad

| KPI | Descripción | Umbral aceptable |
|-----|-------------|------------------|
| SE-1 | Findings críticos en Checkov sobre código Terraform | 0 |
| SE-2 | Secrets expuestos detectados por TruffleHog en repositorio | 0 |
| SE-3 | Verificación de autenticación JWT rechazada sin token válido | 100% de rechazos |

### Dimensión 4 — Conformidad Data Space

| KPI | Descripción | Umbral aceptable |
|-----|-------------|------------------|
| CF-1 | Validación del flujo completo iSHARE (token → acceso datos) | Exitoso |
| CF-2 | Respuesta correcta a consulta NGSI-LD v1.6 (/entities) | HTTP 200 + JSON-LD |

## 3.4 Herramientas y Tecnologías

| Categoría | Herramienta | Versión | Justificación |
|-----------|-------------|---------|---------------|
| IaC | Terraform | ≥ 1.7 | Estándar industria, módulo EKS oficial |
| Orquestación | Kubernetes / EKS | 1.30 | LTS AWS, soporte hasta Nov 2025 |
| GitOps | ArgoCD | 2.11.x | CNCF Graduated, UI completa |
| Empaquetado | Helm | ≥ 3.14 | Estándar para charts Kubernetes |
| Context Broker | Orion-LD | 1.6.x | NGSI-LD v1.6 compliant |
| Identity Mgmt | Keyrock | 8.x | iSHARE compatible |
| PEP Proxy | Wilma | 8.x | Integración nativa Keyrock |
| Secrets | External Secrets | 0.9.x | Integración AWS Secrets Manager |
| CI/CD | GitHub Actions | - | Integración nativa con GitHub |
| Seguridad IaC | Checkov | ≥ 3.x | Escaneo Terraform + K8s manifests |
| Seguridad Git | TruffleHog | ≥ 3.x | Detección de secretos en repositorio |
| Linter | Ruff (Python) | ≥ 0.4 | Linting scripts Python |
