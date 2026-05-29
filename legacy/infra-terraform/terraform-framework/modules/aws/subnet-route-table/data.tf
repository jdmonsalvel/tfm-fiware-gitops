# data "aws_ec2_transit_gateway_attachment" suprimido:
# for_each sobre IDs de module output (unknown at plan time) no es soportado.
# El lookup del TGW ID se resuelve pasando transit_gateway_id directamente
# en el tfvars cuando se necesita Transit Gateway.
