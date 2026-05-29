# 7. Conclusiones y Trabajo Futuro

## 7.1 Síntesis de Contribuciones

El presente Trabajo Fin de Máster ha abordado el diseño, implementación y validación preliminar de un modelo de referencia arquitectónico para el despliegue automatizado de una plataforma de Data Space basada en componentes FIWARE sobre infraestructura AWS, aplicando el paradigma GitOps.

Las contribuciones principales del trabajo pueden resumirse en los siguientes puntos:

**Contribución 1 — Modelo de referencia integrado:** Se ha propuesto y documentado una arquitectura que integra de forma coherente tecnologías hasta ahora tratadas de forma aislada en la literatura: GitOps (ArgoCD), componentes FIWARE (Orion-LD, Keyrock, Wilma), infraestructura cloud (AWS EKS via Terraform) y marcos de confianza para Data Spaces (iSHARE/DSBA). Esta integración constituye, según la revisión de literatura realizada, una contribución original al campo.

**Contribución 2 — Artefacto técnico reproducible:** El repositorio GitHub generado constituye un artefacto técnico directamente utilizable por organizaciones que deseen implementar Data Spaces FIWARE. El diseño modular (módulos Terraform independientes, charts Helm reutilizables, GitOps declarativo) facilita la adaptación a diferentes contextos organizacionales.

**Contribución 3 — Formalización del pipeline de seguridad:** Se ha definido e implementado un pipeline CI/CD con capas de validación de seguridad (Checkov, TruffleHog, kubeconform) específicamente diseñado para el contexto de Data Spaces, donde la integridad de los manifests de despliegue es crítica para la conformidad regulatoria.

## 7.2 Cumplimiento de Objetivos Específicos

| Objetivo | Estado | Observaciones |
|----------|--------|---------------|
| OE-1: Análisis comparativo tecnologías | ✅ Cumplido | Capítulo 2, tablas comparativas FIWARE/ArgoCD |
| OE-2: Definición arquitectura de referencia | ✅ Cumplido | Capítulo 4, 7 diagramas C4 y flujos |
| OE-3: Implementación IaC Terraform | ✅ Cumplido | Módulos VPC + EKS, estado remoto S3 |
| OE-4: Repositorio GitOps App of Apps | ✅ Cumplido | ArgoCD + 6 Application manifests |
| OE-5: Pipeline CI/CD con seguridad | ✅ Cumplido | 3 workflows GitHub Actions |
| OE-6: Validación con métricas | 🔄 En progreso | Fase 4 — 3-5 mayo 2026 |

## 7.3 Limitaciones del Trabajo

El presente trabajo presenta las siguientes limitaciones que deben considerarse al interpretar los resultados:

1. **Escala de laboratorio:** El entorno de validación opera con 2 nodos worker de tipo `t3.medium`, insuficientes para simular cargas de producción reales. Las métricas de RTO y tiempo de despliegue deben considerarse como valores de referencia, no como garantías de producción.

2. **iSHARE en sandbox:** La integración con el marco de confianza iSHARE se ha realizado en modalidad sandbox, utilizando certificados de prueba en lugar de certificados eIDAS emitidos por una autoridad de certificación reconocida. Los flujos de autenticación son funcionalmente equivalentes, pero no aptos para participación en un Data Space productivo.

3. **MongoDB standalone:** La base de datos de Orion-LD se despliega en modo standalone, sin replicación, lo que implica un punto único de fallo para los datos de contexto. Esta elección se justifica por el alcance académico del trabajo.

4. **Ausencia de conectores IDSA:** El trabajo no implementa conectores de datos tipo IDS (*International Data Spaces Connector*), que serían necesarios para el intercambio de datos B2B según el modelo IDSA RAM. Se considera trabajo futuro.

## 7.4 Líneas de Investigación y Trabajo Futuro

Con base en las limitaciones identificadas y las tendencias emergentes en el campo de los Data Spaces, se proponen las siguientes líneas de trabajo futuro:

1. **Federación multi-clúster:** Extensión del modelo para gestionar múltiples clústeres EKS en diferentes regiones AWS o proveedores cloud, utilizando ArgoCD ApplicationSets para la gestión declarativa de flota (*fleet management*).

2. **Integración de conectores IDSA:** Incorporación de un conector IDS basado en el Eclipse Dataspace Connector (EDC) que permita el intercambio de datos B2B entre Data Spaces siguiendo el protocolo IDS-G.

3. **Observabilidad avanzada con OpenTelemetry:** Implementación de trazas distribuidas (*distributed tracing*) mediante el OpenTelemetry Collector para correlacionar transacciones a través de todos los componentes del Data Space (Wilma → Keyrock → Orion-LD → MongoDB).

4. **Evaluación de conformidad DGA:** Desarrollo de un conjunto de pruebas automatizadas que verifiquen la conformidad del intermediario de datos implementado con los requisitos técnicos del *Data Governance Act* (DGA, Reglamento UE 2022/868), incluyendo los mecanismos de portabilidad y revocación de consentimiento.

5. **Optimización de costes con Spot Instances:** Análisis e implementación de grupos de nodos EKS basados en EC2 Spot Instances para reducir los costes operacionales en hasta un 70%, con gestión de interrupciones mediante AWS Node Termination Handler.

6. **GitOps para pipelines de datos:** Extensión del paradigma GitOps a los pipelines de ingestión y transformación de datos, versionando los flujos de datos (Apache Spark, AWS Glue) junto con la infraestructura y la configuración de aplicaciones en el mismo repositorio.

## 7.5 Reflexión Final

Este trabajo evidencia que la convergencia entre los paradigmas GitOps e IaC, la tecnología habilitadora FIWARE y los marcos de gobernanza de Data Spaces europeos no solo es técnicamente viable, sino que produce un sistema con propiedades de auditabilidad, reproducibilidad y seguridad difícilmente alcanzables mediante enfoques operacionales tradicionales. La adopción de un repositorio Git como *Single Source of Truth* del estado del sistema —tanto para la infraestructura como para las aplicaciones— transforma el historial de versiones en un registro inmutable de auditoría, aspecto fundamental para la conformidad regulatoria en el contexto del *Data Governance Act*.

El modelo de referencia propuesto sienta las bases para una implementación de Data Space FIWARE que no solo sea funcionalmente correcta, sino operacionalmente sostenible y conforme con los estándares de la Estrategia Europea de Datos.
