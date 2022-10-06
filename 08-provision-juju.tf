# Provision juju Hosts


resource "equinix_metal_device" "juju" {
  count             = length(var.juju_names)
  hostname          = var.juju_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.juju_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-hosts.sh", {
    hostname           = var.juju_names[count.index].servername
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    overlay_vlan       = var.overlay_vlan.vxlan,
    adminip            = var.juju_admin_ips[count.index].adminip,
    internalip         = "",
    publicip           = "",
    storageip          = "",
    storagerepip       = "",
    dataip             = "",
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = "",
    public_cidr        = "",
    storage_cidr       = "",
    storagerep_cidr    = "",
    data_cidr          = "",
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "false",
    inspace_storage    = "false",
    inspace_storagerep = "false",
    inspace_data       = "false",
    inspace_overlay    = "false"
    })
}

resource "time_sleep" "juju_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.juju]
}

resource "equinix_metal_device_network_type" "juju" {
  count     = length(var.juju_names)
  device_id = equinix_metal_device.juju[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.juju_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "juju_admin" {
  count     = length(var.juju_names)
  device_id = equinix_metal_device.juju[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.juju]
}

resource "equinix_metal_port_vlan_attachment" "juju_internal" {
  count     = length(var.juju_names)
  device_id = equinix_metal_device.juju[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.juju]
}