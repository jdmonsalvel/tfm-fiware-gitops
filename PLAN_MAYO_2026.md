# Plan de trabajo — Mayo 2026
## TFM: Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm

**Depósito ordinario límite**: 22 julio 2026  
**Objetivo operativo**: memoria entregable + demo técnica funcionando en mayo

---

## Respuesta clave: ¿necesitamos el despliegue para documentar?

| Capítulo | ¿Requiere despliegue? | Puede avanzar hoy |
|----------|----------------------|-------------------|
| Cap 1 — Introducción | No | ✅ |
| Cap 2 — Estado del Arte | No | ✅ |
| Cap 3 — Metodología | No | ✅ |
| Cap 4 §4.0-4.1 Análisis FIWARE | No | ✅ |
| Cap 4 §4.2 Baseline k3s | Sí — k3s local o EC2 (~$2) | Solo documentar si ya existe |
| Cap 4 §4.3-4.4 GitOps EKS | Sí — EKS o k3s 3-nodos | Bloquea resultados reales |
| Cap 5 — Resultados | Sí — métricas reales | Bloquea hasta semana 3 |
| Cap 6 — Conclusiones | Depende de Cap 5 | Boceto posible |

**Conclusión**: el 60% del documento puede escribirse sin infraestructura activa.  
La semana crítica de bloqueo técnico es la semana 3 (19-25 mayo).

---

## Decisión arquitectónica: k3s multi-nodo vs EKS

El trabajo original planteaba AWS EKS (~$16/día, ~$200 total). Una alternativa válida académicamente:

| Opción | Coste total estimado | Validez académica | Complejidad |
|--------|---------------------|-------------------|-------------|
| **k3s HA (3 EC2 t3.medium)** | ~$15-20 total | ✅ Multi-nodo demostrable | Baja |
| **k3s local (Docker/k3d)** | $0 | ⚠️ Single-nodo real | Muy baja |
| **AWS EKS** | ~$150-200 total | ✅ Referencia industria | Alta |

**Recomendación**: k3s en 3 EC2 t3.medium con k3s HA mode (embedded etcd). Cubre el requisito multi-nodo, tolerancia a fallos y ArgoCD a un coste de $15-20 total. El EKS puede documentarse como arquitectura de referencia para producción sin desplegarse completamente.

---

## Cronograma mayo 2026

### Semana 1 — 6 al 11 mayo | DOCUMENTACIÓN TEÓRICA

**Objetivo principal**: completar los capítulos que NO requieren despliegue.

| Día | Actividad | Entregable |
|-----|-----------|------------|
| 6 mayo (hoy) | Borrador inicial v1 (compilación + envío a tutor) | `docs/borrador_inicial_v1.md` |
| 7-8 mayo | Expandir Cap 2: §2.1 FIWARE en profundidad + §2.2 Marco normativo EU (5 páginas) | `docs/02_contexto_estado_arte.md` |
| 9-10 mayo | Expandir Cap 2: §2.3 GitOps comparativo + §2.4 Seguridad cloud-native + §2.5 Trabajos relacionados (8-10 refs académicas) | ídem |
| 11 mayo | Expandir Cap 3: riesgos, Gantt real, justificación metodológica con citas | `docs/03_metodologia.md` |

**Meta**: Cap 2 pasa de 3.5 a 15+ páginas. Cap 3 de 3 a 8 páginas.

### Semana 2 — 12 al 18 mayo | IMPLEMENTACIÓN TÉCNICA

**Objetivo principal**: tener k3s 3-nodos funcionando con FIWARE + ArgoCD.

| Día | Actividad | Entregable |
|-----|-----------|------------|
| 12-13 mayo | Crear 3 EC2 t3.medium en AWS (Terraform o manual) + instalar k3s HA | Clúster k3s running |
| 14-15 mayo | Instalar ArgoCD + App of Apps + desplegar Trust Anchor | `kubectl get pods` Trust Anchor healthy |
| 16-17 mayo | Desplegar Data Space Connector completo + smoke test E2E | `smoke-test.sh` 4/4 PASSED |
| 18 mayo | Capturar evidencias (screenshots, logs, kubectl outputs) | Carpeta `evidencias/` |

**Plan B si AWS falla**: k3d (k3s en Docker) en máquina local para baseline. Menos impresionante pero 100% gratis y funciona para demostrar el concepto.

### Semana 3 — 19 al 25 mayo | RESULTADOS + CAP 4 COMPLETO

**Objetivo principal**: documentar la implementación real con datos reales.

| Día | Actividad | Entregable |
|-----|-----------|------------|
| 19-20 mayo | Cap 4 §4.2-4.4: documentar la implementación k3s con comandos reales | `docs/04_desarrollo_contribucion.md` |
| 21 mayo | Prueba tolerancia a fallos: `kubectl drain` nodo + smoke test durante el drain | Métricas HA reales |
| 22-23 mayo | Cap 5 Resultados: llenar con métricas reales (tiempos, recovery, sync ArgoCD) | `docs/05_resultados.md` |
| 24 mayo | Comparativa Manual vs GitOps con números reales | ídem |
| 25 mayo | **ENTREGA 2: Borrador Intermedio** → enviar a tutor caps 1-5 con resultados | `docs/borrador_intermedio_v1.md` |

### Semana 4 — 26 al 31 mayo | CIERRE Y FORMATO

**Objetivo principal**: memoria completa lista para depósito.

| Día | Actividad | Entregable |
|-----|-----------|------------|
| 26-27 mayo | Cap 6 Conclusiones: expandir con reflexión sobre resultados reales | `docs/06_conclusiones.md` |
| 28 mayo | Bibliografía: ampliar a 25+ referencias, verificar formato APA7 | `docs/bibliografia.md` |
| 29 mayo | Anexos: Glosario + Instrucciones reproducibilidad + código completo smoke test | `docs/anexos.md` |
| 30 mayo | Convertir a Word con plantilla UNIR + revisar formato (márgenes, fuentes, numeración) | `.docx` final |
| 31 mayo | Revisión final + pre-depósito | Memoria lista |

---

## Metas por capítulo (páginas objetivo)

| Capítulo | Estado hoy | Objetivo | Semana |
|----------|------------|---------|--------|
| Abstract | 1 pág ✅ | 1.5 pág | — |
| Cap 1 Introducción | 2.5 pág | 6 pág | S1 (ajuste menor) |
| Cap 2 Estado del Arte | 3.5 pág | 18 pág | **S1 prioridad máxima** |
| Cap 3 Metodología | 3 pág | 9 pág | S1 |
| Cap 4 Desarrollo | 5 pág | 18 pág | S3 (con datos reales) |
| Cap 5 Resultados | 2 pág (vacío) | 9 pág | S3 |
| Cap 6 Conclusiones | 2.5 pág | 5 pág | S4 |
| Bibliografía | 1.5 pág | 3.5 pág | S4 |
| Anexos | 0 pág | 5 pág | S4 |
| **TOTAL** | **~21 pág** | **~75 pág** | |

---

## Checklist de bloqueos técnicos que resolver esta semana

- [ ] Cuenta AWS activa con presupuesto disponible (~$20-30 para k3s en EC2)
- [ ] GitHub repo `tfm-fiware-gitops` creado y público
- [ ] Dominio o IP para exponer servicios FIWARE (puede ser IP pública de EC2 + `/etc/hosts`)
- [ ] Helm ≥ 3.14 instalado localmente
- [ ] kubectl instalado localmente

Si alguno falla → escalar a k3d local esta semana y AWS la semana 2.
