# Provision storage Hosts


resource "equinix_metal_device" "storage" {
  count             = length(var.storage_names)
  hostname          = var.storage_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.storage_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-hosts.sh", {
    hostname           = var.storage_names[count.index].servername
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    overlay_vlan       = var.overlay_vlan.vxlan,
    adminip            = var.storage_admin_ips[count.index].adminip,
    internalip         = var.storage_internal_ips[count.index].internalip,
    publicip           = "",
    storageip          = var.storage_storage_ips[count.index].storageip,
    storagerepip       = var.storage_storagerep_ips[count.index].storagerepip,
    dataip             = "",
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = var.internal_cidr,
    public_cidr        = "",
    storage_cidr       = var.storage_cidr,
    storagerep_cidr    = var.storagerep_cidr,
    data_cidr          = "",
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "false",
    inspace_storage    = "true",
    inspace_storagerep = "true",
    inspace_data       = "false",
    inspace_overlay    = "false"
    })
}

resource "time_sleep" "storage_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.storage]
}

resource "equinix_metal_device_network_type" "storage" {
  count     = length(var.storage_names)
  device_id = equinix_metal_device.storage[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.storage_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "storage_admin" {
  count     = length(var.storage_names)
  device_id = equinix_metal_device.storage[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.storage]
}

resource "equinix_metal_port_vlan_attachment" "storage_internal" {
  count     = length(var.storage_names)
  device_id = equinix_metal_device.storage[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.storage]
}

resource "equinix_metal_port_vlan_attachment" "storage_storage" {
  count     = length(var.storage_names)
  device_id = equinix_metal_device.storage[count.index].id
  vlan_vnid = equinix_metal_vlan.storage_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.storage]
}

resource "equinix_metal_port_vlan_attachment" "storage_storagerep" {
  count     = length(var.storage_names)
  device_id = equinix_metal_device.storage[count.index].id
  vlan_vnid = equinix_metal_vlan.storagerep_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.storage]
}