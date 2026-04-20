# 6. Resultados y Evaluación

> **Nota de redacción:** Este capítulo debe completarse durante la Fase 4 (3-5 de mayo de 2026) con las mediciones reales del entorno desplegado. Las secciones marcadas con `[MEDICIÓN PENDIENTE]` requieren datos cuantitativos del entorno real.

## 6.1 Validación de la Reproducibilidad del Despliegue (KPIs RD)

### RD-1: Tiempo de Despliegue Completo

Se midió el tiempo transcurrido desde la ejecución de `terraform apply` (con plan ya generado) hasta la disponibilidad de todos los servicios FIWARE en estado `Healthy` según ArgoCD.

| Fase | Tiempo medido | Notas |
|------|--------------|-------|
| Terraform apply (VPC + EKS) | `[MEDICIÓN PENDIENTE]` min | Dominado por EKS node group |
| ArgoCD bootstrap | `[MEDICIÓN PENDIENTE]` min | Descarga de imágenes incluida |
| FIWARE stack (Orion-LD + Keyrock + Wilma) | `[MEDICIÓN PENDIENTE]` min | Incluye jobs de inicialización |
| **Total** | `[MEDICIÓN PENDIENTE]` min | Objetivo: < 30 min |

> `[EVIDENCIA PENDIENTE]` Captura del dashboard ArgoCD con todos los componentes en estado `Synced / Healthy`.

### RD-2: Pasos Manuales Requeridos

> `[MEDICIÓN PENDIENTE]` Documentar los pasos manuales necesarios durante el despliegue y justificar si son reducibles.

### RD-3: Re-despliegue tras Destrucción Total

> `[EVIDENCIA PENDIENTE]` Documentar el resultado del ciclo `teardown.sh` → `bootstrap.sh`, verificando que el sistema se recupera al estado equivalente al inicial.

## 6.2 Validación de Resiliencia (KPIs RS)

### RS-1: Recovery Time Objective (RTO)

Se simuló un fallo de nodo mediante el drenado forzado (`kubectl drain`) de uno de los nodos worker del clúster EKS. Se midió el tiempo hasta la restauración completa de los servicios afectados.

> `[MEDICIÓN PENDIENTE]` Tiempo de recuperación medido en segundos/minutos.
> `[EVIDENCIA PENDIENTE]` Logs de los eventos Kubernetes durante el proceso de recuperación.

### RS-2: Re-sincronización ArgoCD tras Drift

Se introdujo un cambio manual en el clúster (`kubectl scale deployment orion-ld --replicas=0`) para simular un drift entre el estado deseado (Git) y el estado real (cluster). Se midió el tiempo hasta que ArgoCD detectó y corrigió el drift.

> `[MEDICIÓN PENDIENTE]` Tiempo de detección y corrección del drift.

## 6.3 Validación de Seguridad (KPIs SE)

### SE-1: Resultados Checkov

> `[EVIDENCIA PENDIENTE]` Output del escaneo Checkov sobre el código Terraform, mostrando el número de checks pasados, fallados y suprimidos con justificación.

### SE-2: Resultados TruffleHog

> `[EVIDENCIA PENDIENTE]` Output del escaneo TruffleHog confirmando ausencia de secretos en el repositorio.

### SE-3: Validación de Autenticación

Se ejecutaron las siguientes pruebas de autenticación sobre la API NGSI-LD protegida por Wilma:

| Escenario | Resultado esperado | Resultado obtenido |
|-----------|-------------------|--------------------|
| Solicitud sin token Authorization | 401 Unauthorized | `[PENDIENTE]` |
| Solicitud con token expirado | 401 Unauthorized | `[PENDIENTE]` |
| Solicitud con token de participante no registrado | 403 Forbidden | `[PENDIENTE]` |
| Solicitud con token válido de participante autorizado | 200 OK + datos | `[PENDIENTE]` |

## 6.4 Validación del Flujo Data Space (KPIs CF)

### CF-1: Flujo Completo iSHARE

Se ejecutó el flujo completo de acceso al Data Space siguiendo el protocolo iSHARE M2M:

```bash
# Paso 1: Obtener token iSHARE
TOKEN=$(curl -s -X POST https://keyrock.<dominio>/oauth2/token \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  -d "assertion=<iSHARE_JWT>" \
  -d 'scope=iSHARE' | jq -r '.access_token')

# Paso 2: Consultar Orion-LD via Wilma
curl -s -H "Authorization: Bearer $TOKEN" \
  https://orion.<dominio>/ngsi-ld/v1/entities \
  -H 'Link: <https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"'
```

> `[EVIDENCIA PENDIENTE]` Output de la respuesta NGSI-LD con entidades de prueba.

### CF-2: Conformidad NGSI-LD

> `[EVIDENCIA PENDIENTE]` Verificación de que la respuesta de Orion-LD incluye `@context` correcto y estructura JSON-LD válida.

## 6.5 Análisis de Costes AWS

> `[MEDICIÓN PENDIENTE]` Coste real del entorno durante el período de pruebas, desglosado por servicio.
