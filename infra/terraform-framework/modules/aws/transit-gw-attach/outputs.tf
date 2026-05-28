output "transit_gateway_attachment_ids" {
  description = "Map of Transit Gateway Attachment name to Attachment ID"
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment : k => v.id }
}
