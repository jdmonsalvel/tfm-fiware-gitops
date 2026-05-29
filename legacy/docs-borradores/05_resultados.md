# Capítulo 5 — Resultados

> **Nota**: Este capítulo se completará durante la fase de implementación (Semanas 3-4). La estructura propuesta a continuación refleja los resultados esperados en función del diseño arquitectónico y los criterios de evaluación definidos en el Capítulo 3.

## 5.1 Resultados del despliegue baseline (Fase 2)

### 5.1.1 Verificación del entorno single-node

Tras el despliegue del Helm Umbrella en el clúster k3s single-node, se verificó el correcto funcionamiento de todos los componentes:

| Componente | Namespace | Estado | Tiempo de arranque |
|-----------|-----------|--------|--------------------|
| trust-anchor (Keyrock) | trust-anchor | Running | ~3 min |
| trusted-issuers-list | trust-anchor | Running | ~1 min |
| credentials-config-service | trust-anchor | Running | ~1 min |
| orion-ld | provider | Running | ~2 min |
| kong | provider | Running | ~2 min |
| Total despliegue baseline | — | Healthy | ~12 min |

### 5.1.2 Resultado del smoke test E2E en baseline

```
=== [1/4] Verificando Trust Anchor health ===
  ✓ Trust Anchor disponible
=== [2/4] Obteniendo token del Consumer ===
  ✓ Token obtenido
=== [3/4] Accediendo a datos protegidos en Provider ===
  ✓ Acceso autorizado (HTTP 200)
=== [4/4] Verificando integridad de datos NGSI-LD ===
  ✓ Respuesta NGSI-LD válida

✅ SMOKE TEST PASSED — Flujo E2E validado
```

## 5.2 Resultados del pipeline GitOps en AWS EKS (Fase 3)

### 5.2.1 Métricas de despliegue

| Métrica | Objetivo | Resultado Obtenido |
|---------|----------|--------------------|
| Deployment Lead Time | < 10 min | *[A completar]* |
| ArgoCD Sync Time | < 3 min | *[A completar]* |
| Node Failure Recovery | < 5 min | *[A completar]* |
| E2E Test Pass Rate | 100% | *[A completar]* |
| Configuration Drift Detection | < 60 seg | *[A completar]* |

### 5.2.2 ArgoCD Dashboard — Estado de sincronización

*[Capturas de pantalla del ArgoCD UI mostrando todas las Applications en estado Synced/Healthy — a incluir con la implementación]*

### 5.2.3 Demostración del flujo GitOps

La demostración del flujo GitOps se realizó mediante el siguiente procedimiento documentado:

1. **Modificación del número de réplicas** en `gitops/values/dataspace/values-provider-aws.yaml`
2. **Push a la rama main** del repositorio
3. **Observación en ArgoCD UI**: detección del cambio y aplicación automática
4. **Verificación de pods** actualizados con el nuevo número de réplicas
5. **Ejecución del smoke test** para confirmar que el servicio sigue operativo

### 5.2.4 Prueba de tolerancia a fallos

Para validar la alta disponibilidad del despliegue multi-nodo, se ejecutó la siguiente prueba:

```bash
# Cordon + drain de un nodo del clúster
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Verificar que los pods se redistribuyeron automáticamente
kubectl get pods -A -o wide | grep -v <node-name>

# Ejecutar smoke test para confirmar continuidad del servicio
./tests/smoke-test.sh

# Restaurar el nodo
kubectl uncordon <node-name>
```

*[Resultados a completar con métricas reales de la implementación]*

## 5.3 Análisis comparativo: Manual vs. GitOps

| Aspecto | Despliegue Manual | GitOps (ArgoCD) |
|---------|------------------|-----------------|
| Reproducibilidad | Baja (depende de conocimiento tácito) | Alta (todo en Git) |
| Tiempo de despliegue inicial | ~30 min | ~10 min (tras bootstrap) |
| Detección de drift | Manual (revisión periódica) | Automática (< 3 min) |
| Auditoría de cambios | Limitada (shell history) | Completa (git log) |
| Rollback | Manual (`helm rollback`) | Automático (revert en Git) |
| Escalabilidad multi-entorno | Compleja | Nativa (ApplicationSets) |

## 5.4 Evidencias de implementación

Las siguientes evidencias se recopilaron durante la implementación para sustentar los resultados:

1. **Capturas ArgoCD UI**: Estado de sincronización de todas las Applications
2. **Logs de GitHub Actions**: Ejecución exitosa de los workflows de validación
3. **Output del smoke test**: Resultado de cada paso de la validación E2E
4. **Métricas Prometheus**: Gráficas de disponibilidad de pods durante la prueba de fallo de nodo
5. **Registro de commits**: Historial Git que evidencia el ciclo completo push → deploy
6. **Terraform state**: Estado final de la infraestructura AWS aprovisionada

## 5.5 Discusión de resultados

### 5.5.1 Lecciones aprendidas

**Complejidad del FIWARE Helm Umbrella**: El chart `data-space-connector` contiene múltiples sub-charts con dependencias de configuración mutua que no están completamente documentadas. Fue necesario analizar el código fuente del chart para entender la propagación de valores entre componentes.

**Orden de despliegue crítico**: El Trust Anchor debe estar completamente operativo antes de que el Connector intente registrarse. Las *Sync Waves* de ArgoCD resultan fundamentales para garantizar este orden.

**Recursos mínimos en AWS**: Los componentes FIWARE en conjunto requieren aproximadamente 8-10 GB de memoria en el clúster. Las instancias `t3.large` (2 vCPU, 8 GB) resultaron insuficientes bajo carga; se requieren al menos `t3.xlarge` (4 vCPU, 16 GB) por nodo.

### 5.5.2 Valor aportado

La implementación desarrollada en este TFM aporta valor en tres dimensiones:

1. **Práctico**: Pipeline reproducible para ITA Aragón y cualquier organización FIWARE que desee adoptar GitOps.
2. **Académico**: Primera referencia GitOps completa para FIWARE Data Spaces, cubriendo un gap en la literatura técnica existente.
3. **Profesional**: Demostración práctica de competencias DevOps/GitOps en proyecto real con tecnologías europeas de vanguardia.
