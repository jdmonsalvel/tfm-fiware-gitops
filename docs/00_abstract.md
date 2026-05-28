# Abstract / Resumen

## Resumen

El presente Trabajo Fin de Máster aborda el diseño e implementación de una arquitectura GitOps para el despliegue automatizado y verificado de **FIWARE Data Spaces** en clústeres Kubernetes multi-nodo sobre Amazon Web Services (AWS). El trabajo responde a la necesidad creciente de infraestructuras de datos soberanas, interoperables y declarativamente gestionadas en el marco de la Estrategia Europea de Datos y la iniciativa Gaia-X.

La solución desarrollada utiliza **ArgoCD** como motor de reconciliación GitOps y el **Helm Umbrella oficial de FIWARE** (data-space-connector) como descriptor declarativo de la aplicación, integrando los componentes Trust Anchor (Keyrock), Trusted Issuers List, Credentials Config Service, Orion-LD y Kong en un despliegue coordinado sobre Amazon EKS. La infraestructura se aprovisiona de forma declarativa mediante **Terraform**, y los secretos se gestionan sin presencia en el repositorio mediante el **External Secrets Operator** integrado con AWS Secrets Manager.

El trabajo sigue una metodología iterativa en cuatro fases: análisis de la arquitectura FIWARE, despliegue baseline manual en single-node, automatización GitOps en multi-nodo AWS, y validación mediante pruebas E2E automatizadas. Se valida el flujo de autenticación completo Consumer → Trust Anchor → Connector → Provider Service y se documentan métricas de alta disponibilidad incluyendo tolerancia a fallo de nodo y tiempo de sincronización de ArgoCD.

Como resultado, se obtiene el primer pipeline GitOps completo, documentado y reproducible para FIWARE Data Spaces, con valor práctico para organizaciones como ITA Aragón y valor académico como referencia para la comunidad DevOps/FIWARE.

**Palabras clave**: GitOps, FIWARE, Data Spaces, ArgoCD, Kubernetes, Helm, AWS EKS, Gaia-X, EU Data Spaces, DevOps

---

## Abstract (English)

This Master's Thesis addresses the design and implementation of a GitOps architecture for the automated and verified deployment of **FIWARE Data Spaces** in multi-node Kubernetes clusters on Amazon Web Services (AWS). The work responds to the growing need for sovereign, interoperable, and declaratively managed data infrastructures within the framework of the European Data Strategy and the Gaia-X initiative.

The developed solution uses **ArgoCD** as the GitOps reconciliation engine and the **official FIWARE Helm Umbrella** (data-space-connector) as the declarative application descriptor, integrating the Trust Anchor (Keyrock), Trusted Issuers List, Credentials Config Service, Orion-LD, and Kong components in a coordinated deployment on Amazon EKS. Infrastructure is provisioned declaratively via **Terraform**, and secrets are managed without repository presence using the **External Secrets Operator** integrated with AWS Secrets Manager.

The work follows an iterative four-phase methodology: FIWARE architecture analysis, manual baseline deployment on single-node, GitOps automation on multi-node AWS, and validation through automated E2E tests. The complete authentication flow Consumer → Trust Anchor → Connector → Provider Service is validated, and high-availability metrics are documented, including node failure tolerance and ArgoCD synchronization time.

As a result, the first complete, documented, and reproducible GitOps pipeline for FIWARE Data Spaces is produced, with practical value for organizations such as ITA Aragón and academic value as a reference for the DevOps/FIWARE community.

**Keywords**: GitOps, FIWARE, Data Spaces, ArgoCD, Kubernetes, Helm, AWS EKS, Gaia-X, EU Data Spaces, DevOps
