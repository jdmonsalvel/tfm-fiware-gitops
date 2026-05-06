# Arquitectura del sistema

## Flujo GitOps

```mermaid
flowchart TD
    Dev["Developer"] -->|git push| GH["GitHub\ntfm-fiware-gitops"]
    GH -->|poll cada 3 min| ArgoCD["ArgoCD\nnamespace: argocd"]

    subgraph App-of-Apps
        ArgoCD -->|sync| AoA["Application\nfiware-data-space"]
        AoA -->|crea Applications| Apps["6 Applications\nwave 0 / 1 / 2"]
    end

    subgraph "Wave 0 — Bases de datos"
        Apps -->|wave 0| MySQL["MySQL 9\nnamespace: trust-anchor"]
        Apps -->|wave 0| MongoDB["MongoDB 8\nnamespace: provider"]
    end

    subgraph "Wave 1 — Trust Anchor"
        MySQL -->|ready| Keyrock["Keyrock 8.3\nIdP / emisor VC"]
        Apps -->|wave 1| Keyrock
        Apps -->|wave 1| TIL["Trusted Issuers List\nregistro emisores"]
        Apps -->|wave 1| CCS["Credentials Config\nconfiguración VC"]
    end

    subgraph "Wave 2 — Provider"
        MongoDB -->|ready| Orion["Orion-LD 1.10\nContext Broker NGSI-LD"]
        Apps -->|wave 2| Orion
    end

    NGINX["NGINX Ingress\n127.0.0.1:80"] --> Keyrock
    NGINX --> TIL
    NGINX --> CCS
    NGINX --> Orion
```

## Namespaces

| Namespace | Componentes | Descripcion |
|-----------|-------------|-------------|
| `argocd` | ArgoCD server, controller, repo-server, redis | Motor GitOps |
| `ingress-nginx` | NGINX ingress controller | Proxy de entrada (hostPort 80/443) |
| `trust-anchor` | Keyrock, TIL, CCS, MySQL | Identity Provider + registros VC |
| `provider` | Orion-LD, MongoDB | Context Broker NGSI-LD |

## Patron de secretos

```
[Local — kind]                     [AWS — EKS]
scripts/create-secrets.sh    -->   AWS Secrets Manager (/fiware/*)
        |                                   |
kubectl create secret generic     External Secrets Operator
        |                          ClusterSecretStore + ExternalSecret
        v                                   v
  K8s Secret: mysql-credentials      K8s Secret: mysql-credentials
  K8s Secret: keyrock-credentials    K8s Secret: keyrock-credentials
        |                                   |
        +---------> existingSecret: <name> <---+
                   (mismo values.yaml para ambos entornos)
```

## Sync Waves — orden de despliegue

```
Wave 0  MySQL, MongoDB           bases de datos
   |
   v (esperar Healthy)
Wave 1  Keyrock, TIL, CCS        trust anchor (dependen de MySQL)
   |
   v (esperar Healthy)
Wave 2  Orion-LD                 provider (depende de MongoDB)
```

## URLs locales (kind + nip.io)

| Servicio | URL |
|----------|-----|
| ArgoCD UI | http://argocd.127.0.0.1.nip.io |
| Keyrock IdP | http://keyrock.127.0.0.1.nip.io |
| Trusted Issuers List | http://til.127.0.0.1.nip.io |
| Trusted Issuers Registry | http://tir.127.0.0.1.nip.io |
| Credentials Config Service | http://ccs.127.0.0.1.nip.io |
| Orion-LD Context Broker | http://orion.127.0.0.1.nip.io |

## Metricas objetivo

| Metrica | Objetivo |
|---------|----------|
| Deployment Lead Time (push a Healthy) | < 10 min |
| ArgoCD Sync Time | < 3 min |
| Configuration Drift Detection | < 60 seg |
| Smoke Test Pass Rate | 100% |
