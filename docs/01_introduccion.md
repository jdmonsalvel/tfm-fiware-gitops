# Capítulo 1 — Introducción

## 1.1 Motivación y contexto

La economía de datos europea atraviesa un momento de transformación estructural impulsado por iniciativas regulatorias como el **EU Data Spaces** y la estrategia **Gaia-X**, que exigen infraestructuras de intercambio de datos soberanas, interoperables y gobernadas. En este contexto, **FIWARE** emerge como la plataforma de referencia open source para la creación de *data spaces* que permiten el intercambio seguro y controlado de datos entre organizaciones, cumpliendo los principios de soberanía digital.

Sin embargo, la adopción operativa de FIWARE Data Spaces en entornos de producción presenta una brecha significativa: el despliegue actual de sus componentes —incluyendo el *Trust Anchor*, el *Connector*, y los servicios de consumidor y proveedor— se realiza de forma mayoritariamente manual o mediante invocaciones directas al CLI de Helm. Esta aproximación introduce riesgos de deriva de configuración (*configuration drift*), dificulta la reproducibilidad entre entornos y limita la escalabilidad horizontal a clústeres Kubernetes multi-nodo.

La práctica **GitOps**, cuyo principio fundamental es tratar el repositorio Git como la única fuente de verdad (*single source of truth*) del estado deseado de la infraestructura, ofrece una solución elegante a estas limitaciones. Mediante herramientas como **ArgoCD**, es posible establecer un bucle de reconciliación continua que detecta cualquier divergencia entre el estado declarado en Git y el estado real del clúster, aplicando las correcciones de forma automática.

El presente Trabajo Fin de Máster (TFM) propone desarrollar una solución *end-to-end* que automatice mediante GitOps el despliegue del **FIWARE Data Space Connector** —el Helm Umbrella oficial de FIWARE— sobre clústeres Kubernetes multi-nodo en AWS, garantizando alta disponibilidad, reproducibilidad total y verificación automática del flujo E2E completo.

## 1.2 Planteamiento del problema

El problema central que aborda este trabajo puede enunciarse en los siguientes términos:

> *No existe un flujo GitOps completo, documentado y reproducible para desplegar de forma automatizada un dataspace FIWARE completo (Consumer, Provider, Connector, Trust Anchor) en clústeres Kubernetes multi-nodo, lo que impide a organizaciones como ITA Aragón o entidades académicas adoptar FIWARE Data Spaces con garantías operativas en producción.*

Esta carencia se manifiesta en tres dimensiones:

1. **Dimensión técnica**: La ausencia de un pipeline GitOps implica que cualquier cambio en la configuración requiere intervención manual, aumentando el tiempo de despliegue (*deployment lead time*) y la probabilidad de errores humanos.

2. **Dimensión operativa**: Sin reconciliación automática, la detección y corrección de *configuration drift* depende del conocimiento tácito del equipo, lo cual es incompatible con los requisitos de alta disponibilidad (HA) de entornos productivos.

3. **Dimensión académica y comunitaria**: La falta de una referencia GitOps para FIWARE Data Spaces supone un obstáculo para la comunidad investigadora y para proyectos de smart cities e IoT que deseen adoptar esta tecnología con prácticas DevOps maduras.

## 1.3 Objetivos

### Objetivo general

Diseñar e implementar una arquitectura GitOps para el despliegue automatizado y verificado de FIWARE Data Spaces en Kubernetes multi-nodo sobre AWS, utilizando ArgoCD como motor de reconciliación y el Helm Umbrella oficial de FIWARE como descriptor de aplicación.

### Objetivos específicos

| ID | Objetivo |
|----|----------|
| OE-1 | Analizar la arquitectura del FIWARE Data Space Connector y sus dependencias, identificando los puntos de extensión y personalización para GitOps. |
| OE-2 | Implementar un despliegue manual con Helm Umbrella en un clúster Kubernetes single-node como línea base (*baseline*) documentada. |
| OE-3 | Diseñar y desarrollar un pipeline ArgoCD que despliegue el dataspace completo en un clúster multi-nodo (2-3 nodos) de forma declarativa. |
| OE-4 | Validar el flujo E2E: Consumer → autenticación Trust Anchor → Connector → Provider Service, mediante pruebas automatizadas. |
| OE-5 | Documentar métricas de alta disponibilidad: tolerancia a fallo de nodo, tiempo de sincronización ArgoCD y verificación automática del flujo. |
| OE-6 | Producir una referencia GitOps replicable para la comunidad FIWARE, con README automatizado y diagramas de arquitectura. |

## 1.4 Estructura del documento

El presente TFM se organiza en los siguientes capítulos:

- **Capítulo 2 — Contexto y Estado del Arte**: Revisión de las tecnologías involucradas (FIWARE, GitOps, ArgoCD, Kubernetes, EU Data Spaces) y análisis de trabajos relacionados.
- **Capítulo 3 — Objetivos y Metodología**: Detalle del enfoque metodológico iterativo adoptado y justificación de las decisiones de diseño.
- **Capítulo 4 — Desarrollo de la Contribución**: Descripción técnica de la arquitectura implementada, el pipeline GitOps, las configuraciones Helm y los scripts de validación.
- **Capítulo 5 — Resultados**: Presentación y análisis de los resultados obtenidos, incluyendo métricas de rendimiento, disponibilidad y tiempo de despliegue.
- **Capítulo 6 — Conclusiones y Trabajo Futuro**: Síntesis de los hallazgos, lecciones aprendidas y líneas de investigación abiertas.

## 1.5 Alcance y limitaciones

El alcance de este trabajo abarca el despliegue automatizado del FIWARE Data Space Connector en AWS usando EKS (o EC2 con k3s para desarrollo), la configuración de ArgoCD como operador GitOps, y la validación del flujo de autenticación E2E. Quedan fuera del alcance: la implementación de Chaos Engineering avanzado, la integración con sistemas legacy externos a FIWARE, y la configuración de redes privadas corporativas (VPN/Direct Connect).
