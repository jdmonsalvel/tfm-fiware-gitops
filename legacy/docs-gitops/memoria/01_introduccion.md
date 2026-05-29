# 1. Introducción

## 1.1 Motivación y Contexto

En el año 2020, la Comisión Europea publicó su Estrategia Europea de Datos (European Commission, 2020), un marco político y regulatorio orientado a la creación de un mercado único de datos en el que personas, empresas e instituciones públicas puedan compartir información de forma segura, equitativa e interoperable. Esta estrategia se concretó progresivamente en instrumentos normativos como el *Data Governance Act* (DGA, Reglamento UE 2022/868), el *Data Act* (Reglamento UE 2023/2854) y la Directiva de Datos Abiertos (Directiva UE 2019/1024), conformando un ecosistema regulatorio sin precedentes en la gobernanza de datos a escala continental.

Paralelamente, iniciativas técnicas de referencia como Gaia-X (Gaia-X, 2021) y el International Data Spaces Association Reference Architecture Model (IDSA, 2022) han definido arquitecturas de referencia para la creación de espacios de datos (*Data Spaces*) basados en principios de soberanía, interoperabilidad y confianza. Estos espacios de datos requieren infraestructuras tecnológicas complejas que combinen componentes de gestión de identidades, intermediación de datos, aplicación de políticas de acceso y registro de transacciones.

FIWARE, fundación tecnológica de código abierto respaldada por la Unión Europea, ofrece un ecosistema de componentes (*Generic Enablers*) alineados con la especificación NGSI-LD (ETSI GS CIM 009, 2021) que dan respuesta técnica a estos requisitos. Sin embargo, la adopción empresarial de FIWARE enfrenta barreras operacionales significativas: la complejidad del despliegue, la heterogeneidad de configuraciones, la ausencia de estándares de automatización y la dificultad para garantizar reproducibilidad y auditabilidad en entornos de producción.

El paradigma GitOps (Weaveworks, 2017), consolidado en la industria mediante herramientas como ArgoCD y Flux, propone que el estado deseado de los sistemas se defina íntegramente en repositorios Git, empleando mecanismos declarativos de reconciliación continua que garantizan convergencia entre la especificación y el estado real del sistema. Este paradigma, combinado con los principios de Infrastructure as Code (IaC) y Continuous Delivery, ofrece una respuesta técnica rigurosa a los desafíos operacionales identificados.

## 1.2 Definición del Problema

El problema central que aborda este trabajo puede formularse de la siguiente manera:

> *¿Es posible definir un modelo de referencia arquitectónico reproducible, seguro y alineado con los estándares europeos de Data Spaces que permita el despliegue automatizado de una plataforma FIWARE sobre infraestructura cloud, utilizando el paradigma GitOps como mecanismo de gestión del ciclo de vida?*

Esta pregunta de investigación se articula en torno a tres brechas identificadas en la literatura y la práctica profesional:

1. **Brecha de automatización:** Los despliegues de componentes FIWARE documentados en la literatura se basan predominantemente en procedimientos manuales o semi-automatizados, sin integración con sistemas de control de versiones ni pipelines de validación.
2. **Brecha de reproducibilidad:** La ausencia de una definición declarativa e inmutable del estado del sistema dificulta la reproducción exacta de entornos, comprometiendo la fiabilidad de pruebas y la trazabilidad de cambios.
3. **Brecha de integración con marcos de confianza:** Los trabajos existentes no abordan de forma integrada la conexión entre la infraestructura GitOps y los marcos de confianza interoperables (iSHARE, DSBA) requeridos por los Data Spaces europeos.

## 1.3 Objetivos

### Objetivo General

Diseñar, implementar y validar un modelo de referencia arquitectónico para el despliegue automatizado de una plataforma de Data Space basada en FIWARE sobre AWS, aplicando el paradigma GitOps con ArgoCD y garantizando reproducibilidad, trazabilidad y conformidad con los estándares europeos de interoperabilidad.

### Objetivos Específicos

- **OE-1:** Analizar y comparar los estándares, marcos de referencia y tecnologías relevantes en el ámbito de los Data Spaces europeos, GitOps y FIWARE, identificando brechas y oportunidades de integración.
- **OE-2:** Definir una arquitectura de referencia que integre los principios GitOps con los componentes FIWARE (Orion-LD, Keyrock, Wilma) y el marco de confianza iSHARE/DSBA sobre infraestructura AWS EKS.
- **OE-3:** Implementar la infraestructura cloud mediante Terraform (VPC, EKS, IAM, Secrets Manager) siguiendo principios de Infrastructure as Code con gestión de estado remoto seguro.
- **OE-4:** Desarrollar el repositorio GitOps con manifests Helm y configuración ArgoCD (patrón App of Apps) que permita el despliegue declarativo y reproducible de todos los componentes de la plataforma.
- **OE-5:** Integrar pipelines de integración continua (GitHub Actions) con validación estática de seguridad, lint de manifests y gates de aprobación para cambios de infraestructura.
- **OE-6:** Validar el modelo mediante un conjunto de pruebas funcionales y métricas operacionales (tiempo de despliegue, RTO, trazabilidad de cambios, conformidad de seguridad).

## 1.4 Alcance y Limitaciones

**Dentro del alcance:**
- Diseño e implementación de la infraestructura AWS (VPC, EKS) mediante Terraform
- Configuración de ArgoCD como operador GitOps con el patrón App of Apps
- Despliegue de los componentes FIWARE: Orion-LD, Keyrock, Wilma y MongoDB
- Integración con el marco de confianza iSHARE para autenticación y autorización federada
- Gestión de secretos mediante External Secrets Operator y AWS Secrets Manager
- Pipelines CI/CD con validación de seguridad estática
- Documentación técnica y académica del modelo de referencia

**Fuera del alcance:**
- Implementación de conectores de datos (*Data Connectors*) tipo IDS/IDSA para intercambio B2B
- Federación multi-clúster o despliegue multi-región
- Integración con catálogos de datos Gaia-X (GXFS)
- Evaluación de rendimiento bajo carga (*load testing*) a escala de producción
- Certificación formal frente a requisitos normativos del DGA

**Limitaciones reconocidas:**
- El entorno de validación es de laboratorio (escala reducida) y no representa una instalación de producción de alta disponibilidad
- El marco iSHARE se integra en modalidad de simulación (*sandbox*) al no disponerse de un certificado eIDAS emitido
- Los costes AWS asociados limitan el tiempo de actividad del entorno de pruebas

## 1.5 Estructura del Documento

El presente documento se organiza en los siguientes capítulos:

- **Capítulo 2 — Estado del Arte:** Revisión sistemática de la literatura y análisis comparativo de tecnologías en los ámbitos de Data Spaces, FIWARE, GitOps e Infrastructure as Code.
- **Capítulo 3 — Metodología:** Descripción del paradigma de investigación (Design Science Research), fases del proyecto y criterios de evaluación.
- **Capítulo 4 — Arquitectura y Diseño:** Definición del modelo de referencia, decisiones de arquitectura (ADR) y diagramas de sistema.
- **Capítulo 5 — Implementación:** Descripción técnica de los componentes implementados, incluyendo IaC, GitOps manifests y pipelines CI/CD.
- **Capítulo 6 — Resultados y Evaluación:** Métricas de validación, evidencias de funcionamiento y análisis comparativo.
- **Capítulo 7 — Conclusiones:** Síntesis de contribuciones, limitaciones del trabajo y líneas de investigación futura.
