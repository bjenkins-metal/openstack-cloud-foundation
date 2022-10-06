output "Edge_host_management_IP" {
description = "Edge host management IP"
value = equinix_metal_device.edge.access_public_ipv4
}

output "Openstack_External_Subnet" {
description = "External Subnet for Openstack"
value = equinix_metal_reserved_ip_block.external.cidr_notation
}