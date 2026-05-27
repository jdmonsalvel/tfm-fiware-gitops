locals {
  dhcp_dns = contains(["us-east-1"], var.region) ? ["10.255.252.221", "10.255.252.251"] : contains(["ap-southeast-1"], var.region) ? ["10.255.248.221", "10.255.248.251"] : contains(["eu-central-1"], var.region) ? ["10.255.178.250", "10.255.179.121"] : ["AmazonProvidedDNS"]
}
