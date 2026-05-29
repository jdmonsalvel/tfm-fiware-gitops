# TRABAJO FIN DE MÁSTER
## Máster Universitario en Desarrollo y Operaciones (DevOps)
## Universidad Internacional de La Rioja (UNIR)

---

**Título**: Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm en entornos multi-nodo sobre Amazon Web Services

**Autor**: Jesús David Monsalve Lezama

**Fecha**: Mayo 2026

**Tutor**: [Nombre del tutor — completar desde portal UNIR]

---

> **PRIMER ENTREGABLE — Planteamiento y documentación del proyecto**
> Este documento cubre el planteamiento completo del proyecto, arquitectura propuesta,
> metodología y plan de implementación sobre Amazon Web Services (AWS).

---

## Índice

1. Resumen ejecutivo
2. Introducción y motivación
3. Planteamiento del problema
4. Objetivos
5. Contexto tecnológico
6. Arquitectura propuesta en AWS
7. Metodología e iteraciones
8. Plan de implementación
9. Gestión de riesgos
10. Bibliografía

---

## 1. Resumen ejecutivo

El presente Trabajo Fin de Máster (TFM) aborda el diseño e implementación de un pipeline GitOps para el despliegue automatizado y reproducible de **FIWARE Data Spaces** en un clúster Kubernetes multi-nodo sobre **Amazon Web Services (AWS)**. El trabajo responde a la necesidad creciente de infraestructuras de datos soberanas e interoperables en el marco de la Estrategia Europea de Datos (EU Data Strategy) y la iniciativa Gaia-X.

La solución propuesta integra tres capas tecnológicas sobre AWS:

- **Capa de infraestructura**: Amazon EKS (Elastic Kubernetes Service) sobre VPC multi-AZ, aprovisionado declarativamente con Terraform.
- **Capa GitOps**: ArgoCD como motor de reconciliación continua, siguiendo el patrón *App of Apps*.
- **Capa de aplicación**: FIWARE Data Space Connector desplegado mediante el Helm Umbrella oficial (`fiware/data-space-connector`), integrando Keyrock, Orion-LD, Kong, Trusted Issuers List y Credentials Config Service.

La gestión de secretos se realiza sin exposición en repositorios Git mediante **AWS Secrets Manager** integrado con el **External Secrets Operator** (ESO).

La validación se realiza mediante un flujo E2E automatizado que verifica la cadena completa: Consumer → Trust Anchor → Connector → Provider Service.

**Palabras clave**: GitOps, FIWARE, Data Spaces, ArgoCD, Kubernetes, AWS EKS, Terraform, Helm, Gaia-X

---

## 2. Introducción y motivación

### 2.1 Contexto regulatorio europeo

La economía de datos europea atraviesa un momento de transformación estructural impulsado por el **Data Governance Act** (Reglamento UE 2022/868) y el **Data Act** (Reglamento UE 2023/2854), que establecen el marco legal para espacios comunes de datos (*data spaces*) en sectores estratégicos como salud, energía y transporte.

**Gaia-X**, la iniciativa federada europea para infraestructura de datos soberana, define el *Trust Framework* para los participantes de un data space. **FIWARE** actúa como implementación de referencia compatible con Gaia-X, proporcionando los componentes necesarios para los roles de Consumer, Provider, Trust Anchor y Connector.

### 2.2 Brecha operativa en el despliegue de FIWARE

A pesar de la madurez tecnológica de los componentes FIWARE, la adopción operativa en entornos de producción presenta una brecha significativa: el despliegue actual se realiza predominantemente de forma manual mediante Helm CLI o instrucciones en repositorios de ejemplo. Esta aproximación introduce:

- **Deriva de configuración** (*configuration drift*) entre entornos
- **Baja reproducibilidad**: cada despliegue depende del conocimiento tácito del operador
- **Ausencia de auditoría**: sin trazabilidad de cambios en la configuración del clúster
- **Escalabilidad limitada**: no existe un mecanismo declarativo para gestionar múltiples entornos

### 2.3 GitOps como solución

La metodología **GitOps** —en la que el repositorio Git constituye la única fuente de verdad (*single source of truth*) del estado deseado del sistema— ofrece una solución directa a estas limitaciones. Mediante **ArgoCD** como operador GitOps, se establece un bucle de reconciliación continua que detecta y corrige automáticamente cualquier divergencia entre el estado declarado en Git y el estado real del clúster Kubernetes.

### 2.4 Elección de Amazon Web Services

AWS se selecciona como plataforma de despliegue por las siguientes razones técnicas y profesionales:

| Criterio | Justificación |
|---------|--------------|
| **Amazon EKS** | Control plane gestionado con HA nativa; sin overhead de gestión de etcd |
| **IAM + OIDC (IRSA)** | Asignación de permisos AWS a pods individuales sin credenciales estáticas; alineado con principio de mínimo privilegio |
| **AWS Secrets Manager** | Almacenamiento seguro y auditado de credenciales, con rotación automática |
| **AWS Load Balancer Controller** | Provisionamiento automático de NLB/ALB para exposición de servicios FIWARE |
| **Multi-AZ nativo** | Alta disponibilidad geográfica en eu-west-1 (Irlanda) con 3 AZs |
| **Madurez y documentación** | Estándar en la industria DevOps; alineado con el perfil profesional del autor |

---

## 3. Planteamiento del problema

El problema central puede enunciarse en los siguientes términos:

> *No existe un flujo GitOps completo, documentado y reproducible para desplegar de forma automatizada un dataspace FIWARE completo (Consumer, Provider, Connector, Trust Anchor) en clústeres Kubernetes multi-nodo sobre plataformas cloud, lo que impide a organizaciones como ITA Aragón adoptar FIWARE Data Spaces con garantías operativas en producción.*

Esta carencia se manifiesta en tres dimensiones:

**Dimensión técnica**: Sin un pipeline GitOps, cualquier cambio en la configuración de FIWARE requiere intervención manual en el clúster, aumentando el tiempo de despliegue y la probabilidad de errores humanos. La ausencia de reconciliación automática hace indetectable la configuración drift hasta que produce un incidente.

**Dimensión operativa**: La dependencia del conocimiento tácito del operador para mantener el estado del clúster es incompatible con los requisitos de alta disponibilidad (HA) de entornos productivos que sirven datos regulados bajo el EU Data Governance Act.

**Dimensión académica**: La falta de una referencia GitOps para FIWARE Data Spaces supone un obstáculo para la comunidad investigadora y para proyectos de smart cities e IoT que deseen adoptar esta tecnología con prácticas DevOps maduras.

---

## 4. Objetivos

### 4.1 Objetivo general

Diseñar e implementar una arquitectura GitOps para el despliegue automatizado y verificado de FIWARE Data Spaces en Kubernetes multi-nodo sobre Amazon Web Services, utilizando ArgoCD como motor de reconciliación y el Helm Umbrella oficial de FIWARE como descriptor declarativo de la aplicación.

### 4.2 Objetivos específicos

| ID | Objetivo |
|----|----------|
| OE-1 | Analizar la arquitectura del FIWARE Data Space Connector e identificar los puntos de extensión para GitOps y las dependencias de arranque entre componentes. |
| OE-2 | Implementar un despliegue baseline documentado con Helm directo en clúster single-node (k3s en EC2) como línea de referencia medible. |
| OE-3 | Aprovisionar la infraestructura AWS (VPC + EKS multi-AZ + addons) de forma declarativa con Terraform siguiendo el principio de infraestructura inmutable. |
| OE-4 | Diseñar e implementar un pipeline ArgoCD con patrón App of Apps que despliegue el dataspace FIWARE completo en EKS multi-nodo con Sync Waves. |
| OE-5 | Validar el flujo E2E: Consumer → autenticación Trust Anchor → Connector → Provider Service, mediante pruebas automatizadas con bash + curl + jq. |
| OE-6 | Medir métricas de alta disponibilidad: tiempo de sincronización ArgoCD, tolerancia a fallo de nodo y detección de configuration drift. |
| OE-7 | Producir una referencia GitOps replicable para la comunidad FIWARE, con repositorio público documentado. |

---

## 5. Contexto tecnológico

### 5.1 FIWARE Data Space Connector

El **FIWARE Data Space Connector** es el Helm Umbrella oficial que empaqueta todos los componentes para un dataspace FIWARE completo:

| Componente | Namespace | Función |
|-----------|-----------|---------|
| Keyrock (Trust Anchor) | `trust-anchor` | Gestor de identidades, emisión de Verifiable Credentials |
| Trusted Issuers List | `trust-anchor` | Registro de entidades emisoras confiables |
| Credentials Config Service | `trust-anchor` | Configuración de esquemas de credenciales |
| Orion-LD | `provider` | Context broker NGSI-LD |
| Kong | `provider` | API Gateway — PEP Proxy |

El flujo de autenticación implementado sigue el protocolo **SIOP-2** (Self-Issued OpenID Provider v2), donde el Consumer presenta Verifiable Credentials al Trust Anchor para obtener un JWT que autoriza el acceso al Provider.

### 5.2 GitOps con ArgoCD

**ArgoCD** (CNCF Graduated, 2022) es el motor de reconciliación GitOps seleccionado. Sus características clave para este proyecto:

- **Sync Waves**: permiten ordenar el despliegue de componentes (Trust Anchor antes que Connector)
- **App of Apps pattern**: una Application raíz gestiona el ciclo de vida de todas las demás
- **Automated sync policy**: `prune: true` + `selfHeal: true` garantizan que el clúster siempre refleja Git
- **Multi-source Applications**: permite separar el chart Helm (OCI registry) de los values (Git)

### 5.3 Infraestructura AWS con Terraform

La infraestructura se define con **Terraform ≥ 1.7** utilizando módulos del Terraform Registry:

- `terraform-aws-modules/vpc/aws ~> 5.0`: VPC multi-AZ con subnets públicas y privadas
- `terraform-aws-modules/eks/aws ~> 20.0`: EKS 1.29 con managed node groups
- IRSA (IAM Roles for Service Accounts): permisos AWS granulares por pod sin credenciales estáticas
- External Secrets Operator: proyección de secretos desde AWS Secrets Manager a Kubernetes Secrets

---

## 6. Arquitectura propuesta en AWS

[INSERTAR DIAGRAMA 1 — arquitectura-aws.png]

### 6.1 Capa de infraestructura (Terraform)

```
Región AWS: eu-west-1 (Irlanda)
├── VPC: 10.0.0.0/16
│   ├── AZ eu-west-1a
│   │   ├── Subnet pública:  10.0.101.0/24
│   │   └── Subnet privada:  10.0.1.0/24
│   ├── AZ eu-west-1b
│   │   ├── Subnet pública:  10.0.102.0/24
│   │   └── Subnet privada:  10.0.2.0/24
│   └── AZ eu-west-1c
│       ├── Subnet pública:  10.0.103.0/24
│       └── Subnet privada:  10.0.3.0/24
│
├── Internet Gateway → subnets públicas
├── NAT Gateway (single, cost optimization) → subnets privadas
│
├── EKS Cluster: fiware-gitops (v1.29)
│   ├── Control Plane: gestionado por AWS (HA automática)
│   └── Managed Node Group: fiware
│       ├── Instancia: t3.xlarge (4 vCPU / 16 GB) — mínimo para FIWARE
│       ├── Desired: 3 nodos | Min: 2 | Max: 4
│       └── Distribución: 1 nodo por AZ
│
├── AWS Load Balancer Controller (IRSA)
├── External Secrets Operator (IRSA → Secrets Manager)
└── AWS Secrets Manager: prefijo fiware/*
```

### 6.2 Capa GitOps (ArgoCD)

```
ArgoCD (namespace: argocd)
└── app-of-apps [root Application]
    ├── Wave "0": argocd-install (autogestión)
    ├── Wave "1": fiware-trust-anchor
    │   ├── Chart: fiware/trust-anchor 0.1.*
    │   ├── Namespace: trust-anchor
    │   └── Values: gitops/values/trust-anchor/values-aws.yaml
    └── Wave "2": fiware-dataspace-provider
        ├── Chart: fiware/data-space-connector 7.*
        ├── Namespace: provider
        └── Values: gitops/values/dataspace/values-provider-aws.yaml
```

**Política de sincronización** (aplicada a todas las Applications):
```yaml
syncPolicy:
  automated:
    prune: true      # Eliminar recursos no declarados en Git
    selfHeal: true   # Revertir cambios manuales en el clúster
  syncOptions:
    - CreateNamespace=true
```

### 6.3 Gestión de secretos

Los secretos (credenciales Keyrock, claves JWT) nunca se almacenan en Git. El flujo es:

```
AWS Secrets Manager (fiware/trust-anchor, fiware/dataspace)
        ↕ IRSA (IAM Role sin credenciales estáticas)
External Secrets Operator (ClusterSecretStore)
        ↓ refreshInterval: 1h
Kubernetes Secret (en namespace trust-anchor / provider)
        ↓
Pod FIWARE consume el Secret como variable de entorno
```

### 6.4 Flujo GitOps completo

[INSERTAR DIAGRAMA 2 — flujo-gitops.png]

```
git push → GitHub → GitHub Actions (lint + kubeval)
                         ↓ merge a main
                    ArgoCD polling (3 min)
                         ↓ diff detectado
                    helm upgrade en EKS
                         ↓ health checks
                    smoke test automático
                    Lead time total: < 10 min
```

---

## 7. Metodología e iteraciones

El trabajo adopta una **metodología iterativa de cuatro fases**, coherente con los principios DevOps de entrega continua de valor y validación temprana:

### Fase 1 — Análisis y comprensión (completada)
Estudio de la arquitectura del FIWARE Data Space Connector: análisis del repositorio GitHub, dependencias entre charts Helm, requisitos de red entre componentes y protocolo SIOP-2.

**Entregable**: Mapa de dependencias Helm + diagrama de flujo de autenticación.

### Fase 2 — Despliegue baseline manual en single-node
Despliegue del Helm Umbrella en instancia EC2 t3.xlarge con k3s (sin EKS), para establecer una línea base documentada que permita comparar tiempos y fiabilidad con el enfoque GitOps.

**Justificación de k3s para baseline**: k3s elimina la complejidad del control plane EKS y permite iterar rápidamente en la configuración de los values Helm antes de llevarlo a AWS EKS.

**Entregable**: Script de despliegue documentado + smoke test E2E superado.

### Fase 3 — Automatización GitOps en AWS EKS
Implementación del pipeline completo:
1. Terraform: VPC + EKS + addons en eu-west-1
2. Bootstrap ArgoCD en el clúster
3. App of Apps con Sync Waves para Trust Anchor y Connector
4. Gestión de secretos con External Secrets Operator + AWS Secrets Manager

**Entregable**: Repositorio GitHub público con IaC + manifests ArgoCD funcionando.

### Fase 4 — Validación, métricas y documentación
Ejecución de pruebas E2E, medición de métricas de alta disponibilidad y elaboración de la memoria TFM completa.

**Entregable**: Suite de pruebas E2E + informe de métricas + memoria final.

---

## 8. Plan de implementación

### 8.1 Cronograma

| Semana | Actividad | Estado |
|--------|-----------|--------|
| Sem. 1 (20-23 abr) | Creación repo GitHub + Terraform VPC/EKS + estructura GitOps | En progreso |
| Sem. 1 (22-23 abr) | Despliegue baseline k3s single-node + smoke test E2E | Pendiente |
| Sem. 2 (24-27 abr) | Bootstrap EKS en AWS (Terraform apply) + instalar ArgoCD | Pendiente |
| Sem. 2 (26-27 abr) | Configurar App of Apps + values FIWARE para AWS | Pendiente |
| Sem. 3 (28 abr-1 may) | Despliegue Trust Anchor vía ArgoCD + validación | Pendiente |
| Sem. 3 (30 abr-1 may) | Despliegue Dataspace completo (Consumer + Provider) | Pendiente |
| Sem. 4 (2-3 may) | Smoke test E2E en EKS multi-nodo + prueba HA | Pendiente |
| Sem. 4 (4-5 may) | Capturas evidencias + Prometheus/Grafana básico | Pendiente |
| **6 mayo 2026** | **Demo GitOps funcionando en AWS** | **Objetivo** |

### 8.2 Estructura del repositorio técnico

El repositorio de implementación (`tfm-fiware-gitops` en GitHub) sigue esta estructura:

```
tfm-fiware-gitops/
├── infra/
│   ├── vpc/             # Terraform: VPC multi-AZ
│   ├── eks/             # Terraform: EKS 1.29 + managed node group
│   └── addons/          # Terraform: ESO + AWS LB Controller (IRSA)
├── gitops/
│   ├── apps/
│   │   ├── app-of-apps.yaml           # Application raíz
│   │   ├── fiware-trust-anchor.yaml   # Wave "1"
│   │   └── fiware-dataspace.yaml      # Wave "2"
│   └── values/
│       ├── trust-anchor/
│       │   └── values-aws.yaml
│       └── dataspace/
│           ├── values-provider-aws.yaml
│           └── values-consumer-aws.yaml
├── tests/
│   ├── smoke-test.sh    # Validación E2E (4 pasos)
│   └── ha-test.sh       # Prueba tolerancia a fallos
└── .github/workflows/
    └── validate.yml     # Helm lint + kubeval en PR
```

### 8.3 Comandos de bootstrap (orden obligatorio)

```bash
# 1. Infraestructura AWS
cd infra/vpc  && terraform init && terraform apply -auto-approve
cd ../eks     && terraform init && terraform apply -auto-approve
cd ../addons  && terraform init && terraform apply -auto-approve

# 2. Kubeconfig
aws eks update-kubeconfig --name fiware-gitops --region eu-west-1

# 3. ArgoCD bootstrap
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# 4. App of Apps — activa el ciclo GitOps
kubectl apply -f gitops/apps/app-of-apps.yaml

# 5. Observar sincronización
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 8.4 Estimación de costes AWS

| Recurso | Tipo | Coste/día aprox. |
|---------|------|-----------------|
| EKS Control Plane | Managed | $0.10/h ≈ $2.40/día |
| 3× EC2 t3.xlarge | Worker nodes | 3 × $0.166/h ≈ $12.00/día |
| NAT Gateway | Networking | ≈ $1.00/día |
| EBS volumes (gp3) | Storage | ≈ $0.50/día |
| **Total estimado (On-Demand)** | | **≈ $16/día** |

**Optimización para entorno de lab**: Instancias Spot en el managed node group (70% de descuento estimado) → ≈ $5-6/día. Total para implementación completa (≈ 13 días activos): $65-80.

---

## 9. Gestión de riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|-----------|
| Recursos insuficientes en nodo (OOM) | Alta | Alto | t3.xlarge obligatorio; límites de recursos en values Helm |
| Trust Anchor no disponible antes del Connector | Media | Alto | Sync Waves ArgoCD (wave "1" antes de wave "2") |
| Coste AWS supera presupuesto | Media | Medio | Instancias Spot + destruir clúster tras demo |
| Chart FIWARE cambia API entre versiones | Baja | Alto | Fijar `targetRevision: "7.*"` en ArgoCD Applications |
| Secretos expuestos en Git | Baja | Crítico | External Secrets Operator; revisión pre-commit |
| Drift entre k3s baseline y EKS multi-nodo | Media | Medio | Values Helm separados por entorno; smoke test en ambos |

---

## 10. Bibliografía

European Commission. (2020). *A European strategy for data*. COM(2020) 66 final.

European Parliament. (2022). *Regulation (EU) 2022/868 on European data governance (Data Governance Act)*. Official Journal of the European Union.

European Parliament. (2023). *Regulation (EU) 2023/2854 on harmonised rules on fair access to and use of data (Data Act)*.

OpenGitOps. (2022). *GitOps Principles v1.0*. CNCF GitOps Working Group. https://opengitops.dev/

Argo Project. (2024). *ArgoCD Documentation v2.10*. https://argo-cd.readthedocs.io/

FIWARE Foundation. (2024). *FIWARE Data Space Connector*. https://github.com/FIWARE/data-space-connector

Amazon Web Services. (2024). *Amazon EKS User Guide*. https://docs.aws.amazon.com/eks/latest/userguide/

HashiCorp. (2024). *Terraform AWS Provider Documentation*. https://registry.terraform.io/providers/hashicorp/aws/

Gaia-X European Association for Data and Cloud. (2023). *Gaia-X Architecture Document v23.10*. https://docs.gaia-x.eu/

Kim, G., Humble, J., Debois, P., & Willis, J. (2016). *The DevOps Handbook*. IT Revolution Press.

External Secrets Operator. (2024). *External Secrets Operator Documentation v0.9*. https://external-secrets.io/

Corrales, D. C., Ledezma, A., & Corrales, J. C. (2022). From theory to practice: A survey of use cases for GitOps. *IEEE Access*, 10, 115233–115249.
