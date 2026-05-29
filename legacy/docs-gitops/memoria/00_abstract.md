# Resumen / Abstract

---

## Resumen (Español)

El presente Trabajo Fin de Máster propone el diseño, implementación y validación de un modelo de referencia arquitectónico para el despliegue automatizado, reproducible y auditable de una plataforma de *Data Space* basada en componentes FIWARE sobre infraestructura de nube pública (AWS), aplicando el paradigma GitOps mediante ArgoCD y Helm como mecanismo central de gestión del ciclo de vida del sistema.

La motivación del trabajo se fundamenta en la creciente relevancia de los espacios de datos soberanos en el contexto de la Estrategia Europea de Datos, impulsada por iniciativas como Gaia-X, el International Data Spaces Association (IDSA) y el marco regulatorio del *Data Governance Act* (DGA, Reglamento UE 2022/868). FIWARE, como tecnología habilitadora alineada con los estándares ETSI NGSI-LD (ETSI GS CIM 009), se posiciona como alternativa de código abierto para la implementación de intermediarios de datos interoperables y auditables.

La contribución principal consiste en la definición e implementación de un modelo de referencia que integra: (i) Infrastructure as Code (IaC) mediante Terraform para el aprovisionamiento reproducible de clústeres EKS en AWS; (ii) gestión declarativa de aplicaciones con ArgoCD siguiendo el patrón *App of Apps*; (iii) integración del marco de confianza iSHARE/DSBA para el control de acceso federado mediante XACML y JWT; y (iv) pipelines de integración continua con validación de seguridad estática mediante Checkov y TruffleHog.

Los resultados demuestran la viabilidad del modelo propuesto en términos de reproducibilidad del despliegue, tiempo de recuperación ante fallos (*Recovery Time Objective*, RTO), trazabilidad de cambios mediante historial Git auditado y alineación con los requisitos de interoperabilidad de los Data Spaces europeos definidos por la DSBA Technical Convergence Framework.

**Palabras clave:** GitOps, FIWARE, Data Space, ArgoCD, Kubernetes, NGSI-LD, iSHARE, Infrastructure as Code, AWS EKS, Helm, Orion-LD, Keyrock.

---

## Abstract (English)

This Master's Thesis proposes the design, implementation, and validation of a reference architectural model for the automated, reproducible, and auditable deployment of a Data Space platform based on FIWARE components on public cloud infrastructure (AWS), applying the GitOps paradigm through ArgoCD and Helm as the central mechanism for system lifecycle management.

The motivation stems from the growing relevance of sovereign data spaces within the European Data Strategy, driven by initiatives such as Gaia-X, the International Data Spaces Association (IDSA), and the regulatory framework of the Data Governance Act (DGA, EU Regulation 2022/868). FIWARE, as an enabling technology aligned with ETSI NGSI-LD standards (ETSI GS CIM 009), positions itself as an open-source alternative for implementing interoperable and auditable data intermediaries.

The main contribution consists of the definition and implementation of a reference model integrating: (i) Infrastructure as Code (IaC) via Terraform for reproducible provisioning of EKS clusters on AWS; (ii) declarative application management with ArgoCD following the App of Apps pattern; (iii) integration of the iSHARE/DSBA trust framework for federated access control using XACML and JWT; and (iv) continuous integration pipelines with static security validation through Checkov and TruffleHog.

The results demonstrate the viability of the proposed model in terms of deployment reproducibility, Recovery Time Objective (RTO), change traceability through audited Git history, and alignment with the interoperability requirements of European Data Spaces as defined by the DSBA Technical Convergence Framework.

**Keywords:** GitOps, FIWARE, Data Space, ArgoCD, Kubernetes, NGSI-LD, iSHARE, Infrastructure as Code, AWS EKS, Helm, Orion-LD, Keyrock.
