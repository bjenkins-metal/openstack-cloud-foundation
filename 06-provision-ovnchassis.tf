# Provision OVN Chassis Hosts


resource "equinix_metal_device" "ovnc" {
  count             = var.compact == "false" ? length(var.ovnc_names) : 0
  hostname          = var.ovnc_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.ovnc_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-hosts.sh", {
    hostname           = var.ovnc_names[count.index].servername
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    overlay_vlan       = var.overlay_vlan.vxlan,
    adminip            = var.ovnc_admin_ips[count.index].adminip,
    internalip         = var.ovnc_internal_ips[count.index].internalip,
    publicip           = "",
    storageip          = "",
    storagerepip       = "",
    dataip             = var.ovnc_data_ips[count.index].dataip,
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = var.internal_cidr,
    public_cidr        = "",
    storage_cidr       = "",
    storagerep_cidr    = "",
    data_cidr          = var.data_cidr,
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "false",
    inspace_storage    = "false",
    inspace_storagerep = "false",
    inspace_data       = "true",
    inspace_overlay    = "true"
    })
}

resource "time_sleep" "ovnc_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.ovnc]
}

resource "equinix_metal_device_network_type" "ovnc" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.ovnc_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "ovnc_admin" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.ovnc]
}

resource "equinix_metal_port_vlan_attachment" "ovnc_internal" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.ovnc]
}

resource "equinix_metal_port_vlan_attachment" "ovnc_data" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  vlan_vnid = equinix_metal_vlan.data_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.ovnc]
}

resource "equinix_metal_port_vlan_attachment" "ovnc_overlay" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  vlan_vnid = equinix_metal_vlan.overlay_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.ovnc]
}

resource "equinix_metal_port_vlan_attachment" "ovnc_external" {
  count     = var.compact == "false" ? length(var.ovnc_names) : 0
  device_id = equinix_metal_device.ovnc[count.index].id
  vlan_vnid = equinix_metal_vlan.external_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.ovnc]
}
