# Módulo bootstrap EKS — Capa 2
#
# Este módulo se ejecuta como raíz separado desde scripts/bootstrap.sh
# después de que el clúster EKS esté Ready (Capa 1 completada).
#
# Archivos en este directorio (todos procesados por Terraform como parte de este módulo):
#   providers.tf          — providers aws, helm, kubernetes con exec token
#   variables.tf          — inputs: cluster coords, IRSA roles, addons, monitoring
#   namespaces.tf         — crea todos los namespaces necesarios
#   addon_*.tf            — un fichero por addon Helm
#   monitoring_*.tf       — stacks de monitorización (standard | centralized)
#   outputs.tf            — outputs del módulo bootstrap
