# Pendientes manuales — separado por fase

> Estado actual: **nada implementado**. Este archivo está dividido en lo que debes
> hacer HOY (entrega) y lo que debes hacer DESPUÉS de completar la implementación AWS.

---

## FASE A — Para la entrega de hoy (sin implementación)

### A1. Diagramas a crear (puedes hacerlos antes de tener AWS)

Los diagramas se crean sobre papel o draw.io a partir de la arquitectura diseñada.
No requieren que el sistema esté desplegado — son representaciones del diseño.
Guardar en: `docs/images/`

**Diagrama 1 — Arquitectura AWS** (obligatorio, va en Cap. 3 y en Entregable 1)
Herramienta: [draw.io](https://app.diagrams.net/) — gratuito, sin instalación
Contenido:
- VPC 10.0.0.0/16 con 3 AZs (eu-west-1a/b/c)
- Subnets públicas (10.0.101-103.x) con Internet Gateway
- Subnets privadas (10.0.1-3.x) con NAT Gateway
- EKS Control Plane (caja gris, gestionado por AWS)
- 3 Worker Nodes t3.xlarge en subnets privadas (1 por AZ)
- AWS Load Balancer (NLB) en subnet pública → Kong
- AWS Secrets Manager (lateral) → flecha punteada → ESO → pods
- Namespaces sobre los Workers: `argocd` | `trust-anchor` | `provider`

Guardar como: `docs/images/arquitectura-aws.png`

---

**Diagrama 2 — Flujo GitOps** (obligatorio, va en Cap. 4)
Herramienta: draw.io (swimlane/carriles) o Mermaid
Carriles:
- Desarrollador: `git push` → GitHub
- GitHub Actions: `helm lint` → `kubeval` → status check en PR
- ArgoCD: polling (3 min) → diff → sync
- EKS Cluster: `helm upgrade` → pods Running → smoke test
- Tiempos orientativos: ArgoCD sync < 3 min; lead time total < 10 min

Guardar como: `docs/images/flujo-gitops.png`

---

**Diagrama 3 — Flujo autenticación E2E FIWARE** (importante, va en Cap. 4)
Herramienta: draw.io (diagrama de secuencia UML)
Participantes: Consumer App | Provider Kong | Trust Anchor | Trusted Issuers List | Orion-LD
Pasos: los 9 ya documentados en §4.1.2

Guardar como: `docs/images/flujo-autenticacion-e2e.png`

---

**Diagrama 4 — App of Apps ArgoCD** (recomendado, va en Cap. 4)
Herramienta: draw.io (árbol jerárquico)
- app-of-apps (raíz)
  - wave 0: argocd-install
  - wave 1: fiware-trust-anchor
  - wave 2: fiware-dataspace

Guardar como: `docs/images/app-of-apps.png`

---

### A2. Conversión a formato UNIR

**Opción A — Word** (más rápida para hoy):
1. Abrir `Definicion_de_trabajo/plantilla_indiv.docx`
2. Copiar el contenido de `ENTREGABLE_1_PLANIFICACION.md` sección por sección
3. Aplicar estilos de la plantilla: Titulo1, Titulo2, Normal, Código
4. En los puntos `[INSERTAR DIAGRAMA X]` pegar el PNG correspondiente
5. Generar tabla de contenido automática desde Word
6. Exportar a PDF

**Opción B — LaTeX** (más profesional):
1. Descomprimir `Definicion_de_trabajo/UNIR-TFM-LaTeX-Template-main.zip`
2. Mapear cada sección de los `.md` a su `.tex` correspondiente
3. Compilar con `pdflatex` o usar Overleaf (sube el ZIP)

---

### A3. Datos de portada (rellenar en la plantilla)

```
Título:       Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm
              en entornos multi-nodo sobre Amazon Web Services
Autor:        Jesús David Monsalve Lezama
Máster:       Máster Universitario en Desarrollo y Operaciones (DevOps)
Universidad:  Universidad Internacional de La Rioja (UNIR)
Fecha:        Mayo 2026
Tutor:        [verificar en portal UNIR]
```

### A4. Checklist de entrega de hoy

- [ ] Portada con todos los campos completados
- [ ] Tabla de contenido generada
- [ ] Numeración de páginas activa
- [ ] Diagramas insertados (o placeholder "Figura X — pendiente" si no da tiempo)
- [ ] Bibliografía en APA 7ª (ya está en `docs/bibliografia.md`)
- [ ] Revisar que no hay referencias a herramientas de IA en el texto
- [ ] Revisión ortográfica
- [ ] PDF exportado

---

## FASE B — Después de implementar en AWS (para entrega final de memoria)

> Nada de esto existe todavía. Se completa durante y tras la implementación técnica.

### B1. Capturas de pantalla a tomar

Guardar en: `docs/evidencias/`

- [ ] `kubectl get nodes` — 3 nodos en estado Ready
- [ ] `kubectl get pods -A` — todos los pods Running
- [ ] ArgoCD UI — pantalla principal: todas las Applications en Synced/Healthy
- [ ] ArgoCD UI — detalle `fiware-trust-anchor` (sync history con timestamps)
- [ ] ArgoCD UI — detalle `fiware-dataspace` (sync history con timestamps)
- [ ] Terminal — output del `./tests/smoke-test.sh` con los 4 checks en verde
- [ ] GitHub Actions — workflow de validación ejecutado correctamente
- [ ] Terraform output con IDs de recursos AWS creados
- [ ] (Opcional) Prometheus/Grafana — dashboard de disponibilidad de pods

### B2. Datos reales para rellenar en `docs/05_resultados.md`

Los campos marcados `*[A completar]*` se llenan así:

| Métrica | Cómo medirlo |
|---------|-------------|
| Deployment Lead Time | `date` justo antes del push → `date` cuando ArgoCD pone todo en Healthy |
| ArgoCD Sync Time | Campo "Last Sync" en ArgoCD UI vs timestamp del commit en GitHub |
| Node Failure Recovery | Timer desde `kubectl drain <nodo>` hasta que el smoke test vuelve a pasar |
| E2E Test Pass Rate | Output del script: 4/4 pasos = 100% |
| Configuration Drift | Editar un recurso K8s manualmente → medir cuánto tarda ArgoCD en revertirlo |

### B3. Secciones de la memoria con placeholders activos

- `docs/05_resultados.md` §5.1.1 — tabla de tiempos de arranque por componente
- `docs/05_resultados.md` §5.2.1 — columna "Resultado Obtenido" en tabla de métricas
- `docs/05_resultados.md` §5.2.2 — capturas ArgoCD
- `docs/05_resultados.md` §5.2.4 — métricas de tolerancia a fallos
