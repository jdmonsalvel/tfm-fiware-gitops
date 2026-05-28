# Module: instance-scheduler

Despliega la solución **AWS Instance Scheduler on AWS** mediante CloudFormation y gestiona
schedules, periods y asociaciones de recursos directamente desde Terraform.

La solución crea: Lambda scheduler, tabla DynamoDB de configuración, regla EventBridge y roles IAM.
Los schedules y periods definidos en el módulo se escriben en DynamoDB tras el despliegue del stack.

## Arquitectura

```
tfvars
  └── instance_schedulers
        ├── role: "hub"         → aws_cloudformation_stack.hub  (Lambda + DDB + EventBridge)
        │     ├── periods       → aws_dynamodb_table_item.period
        │     └── schedules
        │           └── compute_resources
        │                 ├── ec2 → data.aws_instances + aws_ec2_tag
        │                 └── rds → data.aws_db_instance + aws_ec2_tag (ARN)
        └── role: "spoke"       → aws_cloudformation_stack.spoke (cross-account IAM role)
```

## Uso — single-account

```hcl
instance_schedulers = {
  main = {
    role               = "hub"
    tag_name           = "Schedule"
    scheduled_services = "EC2"          # "EC2" | "RDS" | "Both"
    default_timezone   = "Europe/Madrid"
    regions            = []             # [] = región del stack
    scheduling_active  = true
    log_retention_days = 7
    memory_size        = 128

    periods = {
      office-hours = {
        begintime = "08:00"
        endtime   = "20:00"
        weekdays  = ["mon-fri"]
      }
      weekend = {
        begintime = "10:00"
        endtime   = "18:00"
        weekdays  = ["sat", "sun"]
      }
    }

    schedules = {
      office-hours = {
        periods            = ["office-hours"]
        timezone           = "Europe/Madrid"
        description        = "Activo lunes-viernes 08:00-20:00"
        stop_new_instances = true
        compute_resources = {
          ec2 = ["web-server", "app-server"]
          rds = ["production-db"]
        }
      }
    }

    tags = { Component = "cost-control" }
  }
}
```

## Uso — cross-account (hub + spoke)

```hcl
# ── Cuenta hub (schedulera) — tfvars cuenta 111111111111 ──────────────────────
instance_schedulers = {
  main = {
    role                = "hub"
    cross_account_roles = ["arn:aws:iam::222222222222:role/instance-scheduler-spoke-main-role"]
    # ... resto de configuración
  }
}

# ── Cuenta spoke (gestionada) — tfvars cuenta 222222222222 ───────────────────
# Tras el apply del hub, obtener el ARN del rol:
#   terraform output instance_scheduler_hub_role_arns
instance_schedulers = {
  main = {
    role                   = "spoke"
    hub_account_id         = "111111111111"
    hub_scheduler_role_arn = "arn:aws:iam::111111111111:role/instance-scheduler-main-role"
    tag_name               = "Schedule"   # debe coincidir con el hub
    tags                   = { Component = "cost-control" }
  }
}
```

## Variables

| Variable | Tipo | Requerido | Descripción |
|---|---|---|---|
| `role` | `string` | ✅ | `"hub"` o `"spoke"` |
| `tag_name` | `string` | — | Tag key para el scheduler (default: `"Schedule"`) |
| `scheduled_services` | `string` | — | `"EC2"`, `"RDS"` o `"Both"` (default: `"EC2"`) |
| `default_timezone` | `string` | — | Timezone Olson (default: `"UTC"`) |
| `regions` | `list(string)` | — | Regiones a gestionar; `[]` = región del stack |
| `scheduling_active` | `bool` | — | Activar/desactivar el scheduler (default: `true`) |
| `create_rds_snapshot` | `bool` | — | Snapshot RDS antes de parar (default: `true`) |
| `cross_account_roles` | `list(string)` | — | ARNs de roles spoke para cross-account |
| `memory_size` | `number` | — | RAM Lambda en MB (default: `128`) |
| `log_retention_days` | `number` | — | Retención CloudWatch Logs (default: `30`) |
| `periods` | `map(object)` | — | Ventanas horarias |
| `periods[*].begintime` | `string` | ✅ | Hora de inicio `"HH:MM"` |
| `periods[*].endtime` | `string` | ✅ | Hora de fin `"HH:MM"` |
| `periods[*].weekdays` | `list(string)` | — | Días: `["mon-fri"]`, `["mon","wed","fri"]` |
| `periods[*].months` | `list(string)` | — | Meses: `["jan-mar"]`, `["jan","jul"]` |
| `periods[*].monthdays` | `list(string)` | — | Días del mes: `["1-15"]`, `["1","15"]` |
| `schedules` | `map(object)` | — | Schedules que agrupan periods |
| `schedules[*].periods` | `list(string)` | ✅ | Claves del mapa `periods` |
| `schedules[*].timezone` | `string` | — | Timezone (default: `default_timezone` del hub) |
| `schedules[*].stop_new_instances` | `bool` | — | Parar instancias sin schedule activo (default: `true`) |
| `schedules[*].compute_resources.ec2` | `list(string)` | — | Name tags de instancias EC2 a asociar |
| `schedules[*].compute_resources.rds` | `list(string)` | — | DB identifiers RDS a asociar |
| `hub_account_id` | `string` | spoke | Account ID de la cuenta hub |
| `hub_scheduler_role_arn` | `string` | spoke | ARN del rol Lambda del hub |

## Outputs

| Output | Descripción |
|---|---|
| `hub_scheduler_role_arns` | ARN del rol Lambda por hub — usar en spokes cross-account |
| `hub_config_table_names` | Nombre de la tabla DynamoDB de configuración |
| `hub_stack_ids` | Stack ID CloudFormation del hub |
| `spoke_stack_ids` | Stack ID CloudFormation del spoke |
| `ec2_tagged_instance_ids` | IDs de EC2 a los que se aplicó el tag de schedule |

## Notas

- Los periods y schedules se gestionan en DynamoDB; un `terraform apply` los actualiza.
- `compute_resources` busca instancias en el momento del apply: si no existen aún,
  el tag se aplica en el siguiente apply una vez estén creadas.
- El nombre del schedule (clave del mapa `schedules`) es el valor del tag. Por ejemplo,
  si el schedule se llama `office-hours` y `tag_name = "Schedule"`, la instancia debe
  tener el tag `Schedule = office-hours`.
- Cross-account: desplegar primero el hub, obtener `hub_scheduler_role_arns` via output,
  y usarlo en el tfvars del spoke.
