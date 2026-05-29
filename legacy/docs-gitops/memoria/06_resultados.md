# 6. Resultados y Evaluación

Este capítulo presenta los resultados de la implementación estructurados en torno a los KPIs definidos en §3 (Metodología). Los resultados estáticos (validación de código, seguridad, arquitectura) se presentan con evidencia disponible. Los resultados dinámicos que requieren el clúster EKS activo están señalados con `[EVIDENCIA PENDIENTE]` y se completarán en la Fase 2 del proyecto.

## 6.1 Validación de la Reproducibilidad del Despliegue (KPIs RD)

### RD-1: Tiempo de Despliegue Completo

La infraestructura se despliega en dos fases con tiempos estimados basados en el framework Terraform implementado:

| Fase | Componentes | Tiempo estimado | Estado |
|------|-------------|----------------|--------|
| Fase 1 — Base | VPC, 9 subnets, 4 SGs, reglas cross-SG, 3 S3, Route53, ACM, 4 Secrets Manager | ~3 min | ✅ Desplegado |
| Fase 2 — Cómputo | EKS cluster + 3× t3.xlarge node group | ~15-17 min | Pendiente |
| Fase 2 — Base de datos | RDS MySQL db.t3.micro | ~10-12 min | Pendiente |
| Fase 2 — Addons | EBS CSI, ALB Controller, ESO (via IRSA) | ~3-5 min | Pendiente |
| GitOps — ArgoCD | Instalación + sincronización inicial | ~3-5 min | Pendiente |
| GitOps — FIWARE | Ola 0 (DBs) + ola 1 (IdP) + ola 2 (Broker) | ~10-15 min | Pendiente |
| **Total Fase 2** | **Desde cero hasta stack FIWARE Healthy** | **~40-50 min** | — |

La infraestructura base (Fase 1, sin coste de cómputo) se desplegó exitosamente con el siguiente output:

```
Apply complete! Resources: 74 added, 0 changed, 0 destroyed.
```

Los recursos creados incluyen: VPC `fiware-vpc`, 9 subnets en 3 AZs (3 públicas + 3 aplicación + 3 datos), Internet Gateway, 3 NAT Gateways, 3 tablas de rutas, 4 Security Groups, 4 reglas cross-SG, bucket de estado Terraform, bucket Velero, bucket Loki, zona Route53 `lab-jdmonsalvel.com`, certificado ACM wildcard `*.lab-jdmonsalvel.com` y 4 secretos en Secrets Manager.

> `[EVIDENCIA PENDIENTE]` Output de `terraform apply` con EKS y RDS. Tiempo real de despliegue Fase 2 en minutos.

### RD-2: Pasos Manuales Requeridos

El proceso de despliegue requiere los siguientes pasos manuales no automatizables, documentados como parte del resultado:

| Paso | Razón | Frecuencia |
|------|-------|-----------|
| Aprobar despliegue en GitHub Environments | Control de cambios en infraestructura de producción | Cada `terraform apply` en CI |
| Delegar NS de `lab-jdmonsalvel.com` a Route53 en Cloudflare | Cambio de proveedor DNS externo — no automatizable sin acceso API Cloudflare | Una sola vez |
| Solicitar aumento de quota Lambda (≥ 50 ejecuciones concurrentes) | Límite de cuenta AWS — requiere caso de soporte | Una sola vez (para Instance Scheduler) |

Todos los demás pasos — creación de clúster, configuración de addons, sincronización de secretos, despliegue de componentes FIWARE — están completamente automatizados.

### RD-3: Idempotencia del Despliegue

El framework garantiza idempotencia en múltiples niveles:

- **Terraform:** `terraform apply` sobre un estado ya desplegado produce `0 changes` si el tfvars no ha cambiado
- **Scripts:** `bootstrap.sh` usa `--dry-run=client | kubectl apply -f -` para crear namespaces de forma idempotente
- **ArgoCD:** La política `selfHeal: true` reconcilia automáticamente cualquier desviación — hacer `kubectl apply` manual sobre un recurso gestionado por ArgoCD resulta en su corrección en el siguiente ciclo de reconciliación (< 60 segundos)
- **Secrets Manager:** `lifecycle { ignore_changes = [secret_string] }` impide que Terraform sobreescriba contraseñas rotadas manualmente

> `[EVIDENCIA PENDIENTE]` Resultado del ciclo `scripts/teardown.sh` → `scripts/bootstrap.sh` verificando recuperación completa al estado inicial.

## 6.2 Validación de Resiliencia (KPIs RS)

### RS-1: Recovery Time Objective (RTO) — Fallo de Nodo

El módulo EKS configura el Cluster Autoscaler con las siguientes garantías de disponibilidad:

- **Node groups en múltiples AZs:** Los 3 nodos de EKS se distribuyen en `eu-west-1a`, `eu-west-1b` y `eu-west-1c`. El fallo de una AZ completa no interrumpe el servicio.
- **Pod Disruption Budget:** Los componentes FIWARE definen mínimo 1 réplica disponible durante operaciones disruptivas.
- **EKS Managed Node Groups:** AWS reemplaza automáticamente nodos en estado `NotReady` sin intervención manual.

La arquitectura garantiza teóricamente un RTO < 5 minutos para fallos de nodo individual (tiempo de arranque de instancia EC2 t3.xlarge: ~2-3 min + descarga de imagen si no está en caché).

> `[EVIDENCIA PENDIENTE]` Tiempo medido de recuperación tras `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`. Logs de eventos Kubernetes durante la recuperación.

### RS-2: Detección y Corrección de Drift por ArgoCD

ArgoCD con `automated.selfHeal: true` detecta desviaciones en el ciclo de reconciliación (configurable, por defecto 3 minutos). Para el objetivo de < 60 segundos se requiere configurar:

```yaml
# En argocd-values.yaml
controller:
  args:
    appResyncPeriod: "30"    # reconciliación cada 30 segundos
```

> `[EVIDENCIA PENDIENTE]` Tiempo medido desde `kubectl scale deployment orion-ld --replicas=0` hasta restauración automática por ArgoCD.

## 6.3 Validación de Seguridad (KPIs SE)

### SE-1: Resultados Checkov sobre Código Terraform

El workflow `terraform-validate.yml` ejecuta Checkov con seis checks de seguridad específicos para el entorno EKS:

| Check | Control | Configuración en el TFM |
|-------|---------|------------------------|
| CKV_AWS_58 | Cifrado de secrets de EKS con KMS | Configurado en módulo `eks` con clave KMS propia |
| CKV_AWS_79 | Actualizaciones automáticas de nodos habilitadas | `update_config: max_unavailable = 1` en node group |
| CKV_AWS_111 | S3 sin acceso público | `block_public_acls = true` en todos los buckets del módulo `s3` |
| CKV_AWS_115 | Lambda con límite de concurrencia reservada | Configurado en módulo `instance-scheduler` |
| CKV_AWS_116 | Lambda con DLQ configurada | Configurado en CFN del Instance Scheduler |
| CKV_AWS_117 | Lambda dentro de VPC | Configurado en módulo `instance-scheduler` |

Los resultados del escaneo se publican como reporte SARIF en GitHub Security → Code Scanning, visible en el repositorio.

> `[EVIDENCIA PENDIENTE]` Captura del reporte SARIF en GitHub Security con el número total de checks pasados, fallados y suprimidos con justificación.

### SE-2: Resultados TruffleHog

El workflow `security-scan.yml` ejecuta TruffleHog con la opción `--only-verified` en cada push, verificando el historial completo de commits en busca de secretos comprometidos.

**Diseño de gestión de secretos:** El repositorio no contiene ningún valor de secreto. Los mecanismos de protección implementados son:

1. **Terraform:** Los secretos se generan con el provider `random` y se almacenan directamente en AWS Secrets Manager. El estado de Terraform (que sí contiene los valores) se almacena en S3 con acceso restringido.
2. **Helm values:** Todos los `values.yaml` referencian `existingSecret: <nombre>` — nunca valores en texto plano.
3. **Scripts:** `scripts/create-secrets.sh` lee valores de variables de entorno, nunca de archivos con credenciales hardcoded.
4. **`.gitignore`:** Incluye `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*.pem`, `*.key` y `*.env`.

> `[EVIDENCIA PENDIENTE]` Output de TruffleHog confirmando `Found 0 verified results`.

### SE-3: Validación de Autenticación

La API NGSI-LD de Orion-LD está protegida por Kong (PEP Proxy) que verifica tokens iSHARE antes de enrutar la petición. Los escenarios de prueba planificados son:

| Escenario | Resultado esperado | Mecanismo |
|-----------|-------------------|-----------|
| Petición sin header `Authorization` | `401 Unauthorized` | Kong rechaza en pre-auth |
| Token JWT con firma inválida | `401 Unauthorized` | Keyrock rechaza verificación |
| Token de participante no registrado en TIL | `403 Forbidden` | TIL no encuentra el emisor |
| Token válido de participante registrado | `200 OK` + datos NGSI-LD | Flujo completo exitoso |

> `[EVIDENCIA PENDIENTE]` Output de `tests/smoke-test.sh` con los cuatro escenarios completados.

## 6.4 Validación del Flujo Data Space (KPIs CF)

### CF-1: Flujo Completo iSHARE M2M

El smoke test E2E en `tests/smoke-test.sh` valida los cuatro pasos del flujo Data Space:

```bash
# Paso 1: Health check del Trust Anchor
curl -sf "$TRUST_ANCHOR_URL/health" | jq '.status == "ok"'

# Paso 2: Obtención de token iSHARE
TOKEN=$(curl -s -X POST "$TRUST_ANCHOR_URL/oauth2/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=iSHARE" | jq -r '.access_token')

# Paso 3: Acceso autorizado al Provider (HTTP 200)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$PROVIDER_URL/ngsi-ld/v1/entities")
[ "$STATUS" = "200" ]

# Paso 4: Respuesta NGSI-LD válida (contiene @context)
curl -s -H "Authorization: Bearer $TOKEN" \
  "$PROVIDER_URL/ngsi-ld/v1/entities?type=WeatherObserved" \
  -H 'Accept: application/ld+json' | jq 'has("@context")'
```

> `[EVIDENCIA PENDIENTE]` Output de `tests/smoke-test.sh` con los cuatro pasos en `PASS`.

### CF-2: Conformidad NGSI-LD

Orion-LD implementa la especificación NGSI-LD 1.6.1 (ETSI GS CIM 009). La validación de conformidad verifica que las respuestas incluyen el `@context` correcto y la estructura JSON-LD válida.

> `[EVIDENCIA PENDIENTE]` Respuesta de Orion-LD con entidades de prueba mostrando `@context: "https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld"`.

## 6.5 Análisis de Costes AWS

### Coste Base (Fase 1 — sin EKS)

Los recursos de la Fase 1 tienen coste prácticamente nulo:

| Recurso | Coste/mes |
|---------|-----------|
| NAT Gateway (3×) | ~$0 (sin tráfico activo) |
| Route53 zona pública | ~$0.50 |
| S3 buckets (3×) | ~$0 (sin datos) |
| Secrets Manager (4×) | ~$0.16 (primeros 10.000 accesos gratis) |
| ACM certificado | $0 |
| **Total Fase 1** | **< $1/mes** |

### Coste Operacional (Fase 2 — con EKS activo)

| Recurso | Coste/hora | Coste/mes (24h×30d) |
|---------|-----------|---------------------|
| EKS cluster endpoint | $0.10 | $72 |
| 3× EC2 t3.xlarge (nodos) | $0.50 | $360 |
| RDS MySQL db.t3.micro | $0.02 | $14 |
| NAT Gateway (tráfico) | ~$0.045/GB | Variable |
| **Total activo** | **~$0.62/h** | **~$446/mes** |

### Optimización de Costes para Laboratorio

Con Instance Scheduler (lunes-viernes 08:00-20:00 UTC): **~$130-150/mes** (eliminando el coste nocturno y de fin de semana).

Con nodos Spot (70% de descuento en EC2): **~$60-70/mes**. Esta combinación hace viable el entorno de laboratorio para el período del TFM.

> **Nota:** El Instance Scheduler está temporalmente deshabilitado por la limitación de concurrencia Lambda en la cuenta de laboratorio (límite de 5 ejecuciones concurrentes, insuficiente para el CFN template de v3). Pendiente de solicitar quota increase a ≥ 50.
