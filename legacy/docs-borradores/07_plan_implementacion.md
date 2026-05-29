# Plan de Implementación — Demo AWS (deadline: 6 de mayo 2026)

> Documento operativo para guiar la implementación técnica. No forma parte de la memoria TFM.

## Cronograma (16 días — 20 abril → 6 mayo)

| Días | Actividad | Estado |
|------|-----------|--------|
| 20-21 abr | Creación repo GitHub + estructura GitOps + Terraform VPC/EKS | ⬜ Pendiente |
| 22-23 abr | Despliegue baseline k3s single-node + smoke test E2E | ⬜ Pendiente |
| 24-25 abr | Bootstrap EKS en AWS (Terraform apply) + instalar ArgoCD | ⬜ Pendiente |
| 26-27 abr | Configurar App of Apps + values FIWARE para AWS | ⬜ Pendiente |
| 28-29 abr | Despliegue Trust Anchor vía ArgoCD + validar | ⬜ Pendiente |
| 30 abr-1 may | Despliegue Dataspace completo (Consumer + Provider) vía ArgoCD | ⬜ Pendiente |
| 2-3 may | Smoke test E2E en EKS multi-nodo + prueba tolerancia fallos | ⬜ Pendiente |
| 4-5 may | Capturas evidencias + Prometheus/Grafana básico + pulir memoria | ⬜ Pendiente |
| 6 may | **DEMO** — Demostración GitOps funcionando en AWS | 🎯 Objetivo |

## Prerequisitos técnicos

Antes de comenzar necesitas tener disponibles:

- [ ] Cuenta AWS con permisos: EKS, EC2, VPC, IAM, Secrets Manager, Load Balancer
- [ ] AWS CLI configurado (`aws configure` o variables de entorno)
- [ ] Terraform ≥ 1.7 instalado
- [ ] kubectl instalado
- [ ] helm ≥ 3.14 instalado
- [ ] GitHub account + repo creado para el GitOps
- [ ] Estimación de coste AWS: ~$5-8/día para 3 nodos t3.xlarge

## Estructura del repositorio GitHub a crear

```
tfm-fiware-gitops/                     # Repositorio GitHub público
├── README.md                          # Con badges ArgoCD + instrucciones
├── infra/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── addons/                        # External Secrets Operator, LB Controller
│       └── main.tf
├── gitops/
│   ├── bootstrap/
│   │   └── argocd-install.yaml        # ArgoCD initial install
│   ├── apps/
│   │   ├── app-of-apps.yaml           # Root Application
│   │   ├── fiware-trust-anchor.yaml
│   │   └── fiware-dataspace.yaml
│   └── values/
│       ├── trust-anchor/
│       │   └── values-aws.yaml
│       └── dataspace/
│           ├── values-provider-aws.yaml
│           └── values-consumer-aws.yaml
├── tests/
│   ├── smoke-test.sh                  # Prueba E2E completa
│   └── ha-test.sh                     # Prueba tolerancia a fallos
└── docs/
    └── architecture.md                # Diagrama Mermaid
```

## Comandos de bootstrap (orden de ejecución)

```bash
# 1. Provisioning AWS
cd infra/vpc && terraform init && terraform apply -auto-approve
cd ../eks && terraform init && terraform apply -auto-approve
cd ../addons && terraform init && terraform apply -auto-approve

# 2. Configurar kubeconfig
aws eks update-kubeconfig --name fiware-gitops --region eu-west-1

# 3. Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 4. Aplicar App of Apps
kubectl apply -f gitops/apps/app-of-apps.yaml

# 5. Observar sincronización
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Abrir https://localhost:8080

# 6. Ejecutar smoke test
export TRUST_ANCHOR_URL=https://trust-anchor.<tu-dominio>
export PROVIDER_URL=https://provider.<tu-dominio>
./tests/smoke-test.sh
```

## Checklist de evidencias para la demo

### Evidencias técnicas obligatorias
- [ ] Captura ArgoCD UI: todas las Applications en estado `Synced / Healthy`
- [ ] Output de `./tests/smoke-test.sh` con todos los checks en verde
- [ ] `kubectl get pods -A` mostrando todos los pods Running en 3 nodos
- [ ] `kubectl get nodes` mostrando 3 nodos Ready
- [ ] Git log mostrando el commit que desencadenó el sync automático

### Evidencias del flujo GitOps (demo en vivo)
- [ ] Modificar un valor en Git (e.g., réplicas) → push → ArgoCD sync automático
- [ ] Verificar que el cambio se aplicó (`kubectl get deployment`)
- [ ] Smoke test confirma que el servicio sigue funcionando

### Evidencias de alta disponibilidad
- [ ] `kubectl drain <nodo>` → verificar redistribución de pods
- [ ] Smoke test durante el drain confirma continuidad del servicio
- [ ] `kubectl uncordon <nodo>` → pods vuelven al nodo

### Capturas para la memoria TFM
- [ ] Terraform output con IDs de recursos AWS creados
- [ ] ArgoCD Application detail view (sync history)
- [ ] Prometheus/Grafana dashboard (si hay tiempo)
- [ ] GitHub Actions runs exitosos (validación manifests)

## Estimación de costes AWS

| Recurso | Tipo | Coste/día aprox. |
|---------|------|-----------------|
| EKS Control Plane | Managed | $0.10/h = ~$2.4/día |
| 3× EC2 t3.xlarge | Worker nodes | 3 × $0.166/h = ~$12/día |
| NAT Gateway | Networking | ~$1/día |
| EBS volumes | Storage | ~$0.5/día |
| **Total estimado** | | **~$16/día** |

> Para reducir costes: usar instancias Spot (hasta 70% descuento), o t3.large en lugar de t3.xlarge, o usar k3s en EC2 directamente (sin EKS).

**Alternativa económica**: 3× EC2 t3.xlarge On-Demand = ~$16/día × 13 días de implementación ≈ **$200 total**. Con Spot instances: ~$60-80 total.
