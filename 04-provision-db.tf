# Provision Database Hosts

# Deploy controller hosts for LXD use
resource "equinix_metal_device" "db" {
  count             = var.compact == "false" ? length(var.db_names) : 0
  hostname          = var.db_names[count.index].servername
  project_id        = var.project_id
  metro             = var.metro
  plan              = var.db_size
  operating_system  = var.ubuntu_version
  billing_cycle     = var.billing_cycle
  user_data         = templatefile("build-control.sh", {
    admin_vlan         = var.admin_vlan.vxlan,
    internal_vlan      = var.internal_vlan.vxlan,
    public_vlan        = var.public_vlan.vxlan,
    storage_vlan       = var.storage_vlan.vxlan,
    storagerep_vlan    = var.storagerep_vlan.vxlan,
    data_vlan          = var.data_vlan.vxlan,
    adminip            = var.db_admin_ips[count.index].adminip,
    internalip         = var.db_internal_ips[count.index].internalip,
    publicip           = "",
    storageip          = "",
    storagerepip       = "",
    dataip             = "",
    admin_cidr         = var.admin_cidr,
    admin_gateway      = var.admin_gateway,
    admin_dns          = var.admin_dns,
    internal_cidr      = var.internal_cidr,
    public_cidr        = "",
    storage_cidr       = "",
    storagerep_cidr    = "",
    data_cidr          = "",
    ubuntu_user_pw     = var.ubuntu_user_pw,
    inspace_internal   = "true",
    inspace_public     = "false",
    inspace_storage    = "false",
    inspace_storagerep = "false",
    inspace_data       = "false"
    })
}

resource "time_sleep" "db_allow_update" {
  create_duration = "5m"
  depends_on = [equinix_metal_device.db]
}

resource "equinix_metal_device_network_type" "db" {
  count     = var.compact == "false" ? length(var.db_names) : 0
  device_id = equinix_metal_device.db[count.index].id
  type      = "layer2-bonded"
  depends_on = [time_sleep.db_allow_update]
}

resource "equinix_metal_port_vlan_attachment" "db_admin" {
  count     = var.compact == "false" ? length(var.db_names) : 0
  device_id = equinix_metal_device.db[count.index].id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.db]
}

resource "equinix_metal_port_vlan_attachment" "db_internal" {
  count     = var.compact == "false" ? length(var.db_names) : 0
  device_id = equinix_metal_device.db[count.index].id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "bond0"
  depends_on = [equinix_metal_device_network_type.db]
}