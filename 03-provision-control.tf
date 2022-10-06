# Provision Controller Hosts

# Deploy controller hosts for LXD use
resource "equinix_metal_device" "controller" {
  count             = length(var.controller_names)
  hostname          = var.controller_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.controller_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-control.sh", {
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    adminip            = var.controller_admin_ips[count.index].adminip,
    internalip         = var.controller_internal_ips[count.index].internalip,
    publicip           = var.controller_public_ips[count.index].publicip,
    storageip          = var.controller_storage_ips[count.index].storageip,
    storagerepip       = var.controller_storagerep_ips[count.index].storagerepip,
    dataip             = var.controller_data_ips[count.index].dataip,
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = var.internal_cidr,
    public_cidr        = var.public_cidr,
    storage_cidr       = var.storage_cidr,
    storagerep_cidr    = var.storagerep_cidr,
    data_cidr          = var.data_cidr,
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "true",
    inspace_storage    = "true",
    inspace_storagerep = "true",
    inspace_data       = "true"
    })
}

resource "time_sleep" "controller_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.controller]
}

resource "equinix_metal_device_network_type" "controller" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.controller_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "controller_admin" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}

resource "equinix_metal_port_vlan_attachment" "controller_internal" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}

resource "equinix_metal_port_vlan_attachment" "controller_public" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.public_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}

resource "equinix_metal_port_vlan_attachment" "controller_storage" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.storage_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}

resource "equinix_metal_port_vlan_attachment" "controller_storagerep" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.storagerep_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}

resource "equinix_metal_port_vlan_attachment" "controller_data" {
  count     = length(var.controller_names)
  device_id = equinix_metal_device.controller[count.index].id
  vlan_vnid = equinix_metal_vlan.data_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.controller]
}