# Provision compute Hosts


resource "equinix_metal_device" "compute" {
  count             = var.compact == "false" ? length(var.compute_names) : 3
  hostname          = var.compute_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.compute_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-hosts.sh", {
    hostname           = var.compute_names[count.index].servername
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    overlay_vlan       = var.overlay_vlan.vxlan,
    adminip            = var.compute_admin_ips[count.index].adminip,
    internalip         = var.compute_internal_ips[count.index].internalip,
    publicip           = "",
    storageip          = var.compute_storage_ips[count.index].storageip,
    storagerepip       = "",
    dataip             = var.compute_data_ips[count.index].dataip,
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = var.internal_cidr,
    public_cidr        = "",
    storage_cidr       = var.storage_cidr,
    storagerep_cidr    = "",
    data_cidr          = var.data_cidr,
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "false",
    inspace_storage    = "true",
    inspace_storagerep = "false",
    inspace_data       = "true",
    inspace_overlay    = "true"
    })
}

resource "time_sleep" "compute_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.compute]
}

resource "equinix_metal_device_network_type" "compute" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.compute_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "compute_admin" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}

resource "equinix_metal_port_vlan_attachment" "compute_internal" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}

resource "equinix_metal_port_vlan_attachment" "compute_storage" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.storage_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}

resource "equinix_metal_port_vlan_attachment" "compute_data" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.data_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}

resource "equinix_metal_port_vlan_attachment" "compute_overlay" {
  count     = var.compact == "false" ? length(var.compute_names) : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.overlay_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}

resource "equinix_metal_port_vlan_attachment" "compute_external" {
  count     = var.compact == "false" ? 0 : 3
  device_id = equinix_metal_device.compute[count.index].id
  vlan_vnid = equinix_metal_vlan.external_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.compute]
}
