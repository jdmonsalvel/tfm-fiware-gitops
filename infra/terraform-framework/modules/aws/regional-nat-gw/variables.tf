variable "tags" {
  type    = map(string)
  default = {}
}

# Regional NAT Gateway no requiere subnet_id ni AZ — opera a nivel de región.
# Requiere AWS provider >= 5.55 (hashicorp/aws).
variable "regional_nat_gateways" {
  description = "Mapa de Regional NAT Gateways. Un único NAT por región sirve todas las AZs sin cargos cross-AZ."
  type = map(object({
    name              = string
    connectivity_type = optional(string, "public") # "public" | "private"
    eip_allocation_id = optional(string)           # reutilizar EIP existente (solo public)
    tags              = optional(map(string), {})
  }))
  default = {}
}
