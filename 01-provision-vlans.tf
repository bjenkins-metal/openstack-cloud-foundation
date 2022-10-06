provider "equinix" {
  auth_token = var.auth_token
}

# Provision VLANs
resource "equinix_metal_vlan" "admin_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.admin_vlan.vxlan 
  description = var.admin_vlan.name
}

resource "equinix_metal_vlan" "internal_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.internal_vlan.vxlan 
  description = var.internal_vlan.name
}

resource "equinix_metal_vlan" "public_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.public_vlan.vxlan 
  description = var.public_vlan.name
}

resource "equinix_metal_vlan" "storage_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.storage_vlan.vxlan 
  description = var.storage_vlan.name
}

resource "equinix_metal_vlan" "storagerep_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.storagerep_vlan.vxlan 
  description = var.storagerep_vlan.name
}

resource "equinix_metal_vlan" "data_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.data_vlan.vxlan 
  description = var.data_vlan.name
}

resource "equinix_metal_vlan" "overlay_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.overlay_vlan.vxlan 
  description = var.overlay_vlan.name
}

resource "equinix_metal_vlan" "external_vlan" {
  project_id  = var.project_id
  metro       = var.metro
  vxlan       = var.external_vlan.vxlan 
  description = var.external_vlan.name
}

# provision external provider subnet
resource "equinix_metal_reserved_ip_block" "external" {
  project_id = var.project_id
  metro      = var.metro
  quantity   = var.os_external_subnet_size
  type       = "public_ipv4"
  tags       = var.os_external_subnet_tag
}

# Create Metal Gateway
resource "equinix_metal_gateway" "os_external_gw" {
  project_id        = var.project_id
  vlan_id           = equinix_metal_vlan.external_vlan.id
  ip_reservation_id = equinix_metal_reserved_ip_block.external.id
  depends_on = [equinix_metal_vlan.external_vlan]
}