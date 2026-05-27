# Capítulo 6 — Conclusiones y Trabajo Futuro

## 6.1 Conclusiones

Este Trabajo Fin de Máster ha abordado el diseño e implementación de una arquitectura GitOps para el despliegue automatizado de FIWARE Data Spaces en Kubernetes multi-nodo sobre AWS, respondiendo a una necesidad real de la comunidad FIWARE y al creciente imperativo regulatorio europeo de infraestructuras de datos soberanas.

### 6.1.1 Conclusiones respecto al objetivo general

El objetivo general del trabajo —diseñar e implementar una arquitectura GitOps para el despliegue automatizado y verificado de FIWARE Data Spaces en Kubernetes multi-nodo— ha sido alcanzado mediante la combinación de ArgoCD como motor de reconciliación, el Helm Umbrella oficial de FIWARE como descriptor declarativo de la aplicación, y AWS EKS como plataforma de ejecución en la nube.

### 6.1.2 Conclusiones respecto a los objetivos específicos

**OE-1 (Análisis arquitectónico FIWARE)**: El análisis del FIWARE Data Space Connector reveló una arquitectura distribuida con dependencias de arranque críticas entre componentes, especialmente la dependencia del Connector respecto al Trust Anchor. Este conocimiento fue determinante para la configuración correcta de las Sync Waves en ArgoCD.

**OE-2 (Baseline manual)**: El despliegue baseline con Helm directo en single-node validó el correcto funcionamiento de los componentes FIWARE y proporcionó una referencia documentada para contrastar los tiempos y la fiabilidad del enfoque GitOps automatizado.

**OE-3 (Pipeline ArgoCD)**: El pipeline GitOps implementado demostró que el patrón *App of Apps* de ArgoCD es idóneo para gestionar la complejidad de un despliegue multi-componente como FIWARE, proporcionando visibilidad del estado de cada componente y reconciliación automática ante cualquier desviación.

**OE-4 (Validación E2E)**: El flujo de autenticación completo —Consumer → Trust Anchor → Connector → Provider— fue validado exitosamente mediante el script de smoke test automatizado, confirmando la correcta interoperabilidad de todos los componentes en el entorno multi-nodo.

**OE-5 (Métricas HA)**: Las métricas obtenidas demuestran que el despliegue GitOps en AWS EKS proporciona alta disponibilidad real: la pérdida de un nodo del clúster no interrumpe el servicio gracias a la distribución multi-AZ y al comportamiento de rescheduling de Kubernetes.

**OE-6 (Referencia comunitaria)**: El repositorio público del proyecto constituye la primera referencia GitOps completa y reproducible para FIWARE Data Spaces, cubriendo una laguna identificada en la documentación oficial y en la literatura técnica.

### 6.1.3 Reflexión sobre el valor del enfoque GitOps

La comparación entre el despliegue manual (Fase 2) y el pipeline GitOps (Fase 3) evidencia de forma inequívoca las ventajas del segundo enfoque:

- La **reproducibilidad** aumenta drásticamente al eliminar los pasos manuales y sus variaciones implícitas.
- La **observabilidad** del estado del sistema mejora gracias al dashboard de ArgoCD y a la trazabilidad completa en Git.
- La **seguridad** mejora al eliminar las credenciales del clúster del sistema CI y adoptar el modelo Pull.
- El **tiempo de recuperación** ante fallos se reduce al contar con un estado declarado que ArgoCD puede reaplicar automáticamente.

Estas ventajas son especialmente relevantes en el contexto de FIWARE Data Spaces, donde la integridad y la trazabilidad de las configuraciones son requisitos de cumplimiento normativo bajo el EU Data Governance Act.

## 6.2 Trabajo futuro

Las líneas de trabajo futuro identificadas a partir de los resultados y limitaciones de este TFM son:

### 6.2.1 Extensiones técnicas inmediatas

1. **Soporte multi-clúster con ArgoCD ApplicationSets**: La arquitectura actual despliega el dataspace en un único clúster EKS. Una extensión natural sería utilizar ApplicationSets para gestionar despliegues en múltiples clústeres (e.g., uno por región AWS), implementando un data space federado multi-región.

2. **Chaos Engineering con Chaos Mesh**: La validación de alta disponibilidad se realizó mediante `kubectl drain`. Una validación más rigurosa emplearía Chaos Mesh para simular fallos de red, latencia, pérdida de paquetes y OOM kills, obteniendo métricas de resiliencia más representativas.

3. **Pipeline CI completo con image promotion**: El trabajo actual actualiza los valores Helm manualmente. Un pipeline CI completo automatizaría la detección de nuevas versiones de los charts FIWARE y su promoción a través de los entornos (dev → staging → production) mediante Pull Requests automáticos.

### 6.2.2 Extensiones funcionales

4. **Integración con Gaia-X Trust Framework**: La implementación actual utiliza el Trust Anchor FIWARE sin validación contra el Gaia-X Trust Framework. La integración con el **Gaia-X Federation Services** (GXFS) permitiría certificar el data space como conforme con Gaia-X.

5. **Soporte para múltiples Consumer organizations**: El escenario actual valida un único Consumer. Un trabajo futuro interesante sería la gestión GitOps del ciclo de alta/baja de organizaciones Consumer en el data space.

6. **Observabilidad avanzada con OpenTelemetry**: La integración de trazas distribuidas mediante OpenTelemetry permitiría correlacionar los tiempos de latencia en el flujo de autenticación E2E entre los distintos componentes FIWARE.

### 6.2.3 Aplicabilidad y transferencia

7. **Plantilla para ITA Aragón y otras organizaciones**: El repositorio generado puede ser adaptado como plantilla para que ITA Aragón u otras organizaciones del ecosistema FIWARE desplieguen su propio data space con mínimas modificaciones a los valores Helm y las credenciales.

8. **Contribución upstream a FIWARE**: Los manifests ArgoCD y la documentación GitOps generados en este TFM podrían contribuirse al repositorio oficial `FIWARE/data-space-connector` como ejemplos de despliegue en producción, beneficiando a toda la comunidad.

## 6.3 Reflexión personal

El desarrollo de este TFM ha permitido integrar de forma práctica las competencias adquiridas a lo largo del Máster en Desarrollo y Operaciones (DevOps), aplicándolas a un proyecto real con tecnologías de vanguardia y relevancia profesional directa.

La profundización en la arquitectura de FIWARE Data Spaces ha ampliado significativamente la comprensión de los mecanismos de intercambio de datos soberano, un área de creciente demanda en el mercado europeo. La implementación del pipeline GitOps sobre AWS ha consolidado las competencias en Kubernetes, Helm, ArgoCD y Terraform, herramientas que forman el núcleo del perfil de AI Platform Engineer al que se orienta el desarrollo profesional del autor.

El mayor reto técnico del trabajo fue la comprensión de las interdependencias entre los componentes del FIWARE Helm Umbrella y la configuración del orden de despliegue correcto, lo que requirió análisis directo del código fuente de los charts y múltiples ciclos de depuración. Esta experiencia refuerza la importancia de la documentación exhaustiva como entregable de cualquier proyecto DevOps.
