# Pendientes — Estado 27 mayo 2026

---

## COMPLETADO ✅

- Terraform framework implementado (24 módulos AWS)
- Backend S3 configurado (`devops-101490102336-terraform-state-bucket`)
- IAM roles creados (`automate-cicd-role` en cuenta 101490102336)
- `terraform validate` + `terraform plan` OK contra AWS real (28 recursos, $0)
- GitOps manifests: App of Apps + 6 Applications ArgoCD
- Values Helm: trust-anchor (Keyrock, TIL, CCS, MySQL) + provider (Orion, MongoDB)
- Scripts: bootstrap.sh, bootstrap-kind.sh, create-secrets.sh, teardown.sh, smoke-test.sh
- Memoria: caps 1-4, 6, bibliografía completos
- Eliminadas todas las referencias a Floci del código

---

## PENDIENTE INMEDIATO — Semana 26-31 mayo

### 1. Apply Fase 1 ($0) — VPC + S3 + SGs

```bash
cd infra/terraform-framework
AWS_PROFILE=personal-account-lab terraform apply --var-file="variables/aws-personal.tfvars"
```

### 2. Apply Fase 2 — EKS (~$0.10/h cluster + EC2 nodes)

Descomentar bloque `eks` en `variables/aws-personal.tfvars` y aplicar.
Coste estimado demo de 4h: ~$3-5 total.

### 3. Bootstrap ArgoCD + FIWARE

```bash
bash scripts/bootstrap.sh
```

### 4. Evidencias para Cap 5

Guardar en `docs/evidencias/`:

- [ ] `kubectl get nodes` — nodos en Ready
- [ ] `kubectl get pods -A` — todos Running
- [ ] ArgoCD UI — Applications en Synced/Healthy
- [ ] ArgoCD UI — sync history con timestamps (para medir Sync Time)
- [ ] `bash tests/smoke-test.sh` — 4/4 PASSED
- [ ] Terraform output con IDs de recursos creados
- [ ] Medición Node Failure Recovery: `kubectl drain <nodo>` + timer

### 5. Rellenar placeholders en Cap 5

`docs/memoria/06_resultados.md` contiene campos `*[A completar]*`:

| Métrica | Cómo medirla |
|---|---|
| Deployment Lead Time | `date` antes del push → `date` cuando ArgoCD pone Healthy |
| ArgoCD Sync Time | "Last Sync" en UI vs timestamp del commit |
| Node Failure Recovery | Timer desde `kubectl drain` hasta que smoke test pasa |
| E2E Test Pass Rate | Output smoke-test.sh: 4/4 = 100% |
| Configuration Drift | Editar recurso K8s manualmente → tiempo hasta que ArgoCD revierte |

### 6. Diagramas

Guardar en `docs/images/` (draw.io o exportar PNG):

- [ ] `arquitectura-aws.png` — VPC + AZs + EKS + ALB + ASM
- [ ] `flujo-gitops.png` — swimlane: dev → GitHub → ArgoCD → EKS
- [ ] `flujo-autenticacion-e2e.png` — secuencia UML 9 pasos FIWARE
- [ ] `app-of-apps.png` — árbol jerárquico ArgoCD wave 0→1→2

### 7. Formato final

- [ ] Copiar memoria a plantilla Word UNIR (`Definicion_de_trabajo/plantilla_indiv.docx`)
- [ ] Insertar diagramas y capturas de pantalla
- [ ] Generar tabla de contenido automática
- [ ] Verificar bibliografía en APA 7ª (25+ referencias)
- [ ] Exportar a PDF
- [ ] Revisar que no hay referencias a herramientas de IA en el texto

---

## Datos de portada

```
Título:       Automatización GitOps de FIWARE Data Spaces con ArgoCD y Helm
              en entornos multi-nodo sobre Amazon Web Services
Autor:        Jesús David Monsalve Lezama
Máster:       Máster Universitario en Desarrollo y Operaciones (DevOps)
Universidad:  Universidad Internacional de La Rioja (UNIR)
Fecha:        Julio 2026
Tutor:        [verificar en portal UNIR]
```
