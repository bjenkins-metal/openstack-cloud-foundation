# Provision Edge Host

# Provision elastic public IPs for the KVM public network
resource "equinix_metal_reserved_ip_block" "routed" {
  project_id  = var.project_id
  metro       = var.metro
  type        = "public_ipv4"
  quantity    = var.router_public_ips_net
  tags        = var.router_public_ips_tag
}

# Create and configure the edge instance.
resource "equinix_metal_device" "edge" {
  hostname         = var.edge_hostname
  plan             = var.edge_size
  metro            = var.metro
  operating_system = var.edge_os
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  user_data        = templatefile("build-edge.sh", {
    overlay_vlan = var.overlay_vlan.vxlan,
    pub_ip = equinix_metal_reserved_ip_block.routed.cidr_notation,
    passwd = var.ubuntu_user_pw,
    metro = var.metro,
    admin_gateway = var.admin_gateway,
    safe_ip = var.safe_ip,
    admin_cidr = var.admin_cidr,
    internal_cidr = var.internal_cidr,
    public_cidr = var.public_cidr,
    storage_cidr = var.storage_cidr,
    storagerep_cidr = var.storagerep_cidr,
    data_cidr = var.data_cidr,
    cont1name = var.controller_names[0].servername,
    cont1adminip = var.controller_admin_ips[0].adminip,
    cont2name = var.controller_names[1].servername,
    cont2adminip = var.controller_admin_ips[1].adminip,
    cont3name = var.controller_names[2].servername,
    cont3adminip = var.controller_admin_ips[2].adminip,
    db1name = var.db_names[0].servername,
    db1adminip = var.db_admin_ips[0].adminip,
    db2name = var.db_names[1].servername,
    db2adminip = var.db_admin_ips[1].adminip,
    db3name = var.db_names[2].servername,
    db3adminip = var.db_admin_ips[2].adminip,
    ovnc1name = var.ovnc_names[0].servername,
    ovnc1adminip = var.ovnc_admin_ips[0].adminip,
    ovnc2name = var.ovnc_names[1].servername,
    ovnc2adminip = var.ovnc_admin_ips[1].adminip,
    ovnc3name = var.ovnc_names[2].servername,
    ovnc3adminip = var.ovnc_admin_ips[2].adminip,
    stor1name = var.storage_names[0].servername,
    stor1adminip = var.storage_admin_ips[0].adminip,
    stor2name = var.storage_names[1].servername,
    stor2adminip = var.storage_admin_ips[1].adminip,
    stor3name = var.storage_names[2].servername,
    stor3adminip = var.storage_admin_ips[2].adminip,
    comp1name = var.compute_names[0].servername,
    comp1adminip = var.compute_admin_ips[0].adminip,
    comp2name = var.compute_names[1].servername,
    comp2adminip = var.compute_admin_ips[1].adminip,
    comp3name = var.compute_names[2].servername,
    comp3adminip = var.compute_admin_ips[2].adminip,
    comp4name = var.compute_names[3].servername,
    comp4adminip = var.compute_admin_ips[3].adminip,
    comp5name = var.compute_names[4].servername,
    comp5adminip = var.compute_admin_ips[4].adminip,
    jujuname = var.juju_names[0].servername,
    jujuadminip = var.juju_admin_ips[0].adminip,
    compact = var.compact,
    keystone_pubip = var.keystone_pubip,
    keystone_intip = var.keystone_intip,
    keystone_adminip = var.keystone_adminip,
    ncc_pubip = var.ncc_pubip,
    ncc_intip = var.ncc_intip,
    ncc_adminip = var.ncc_adminip,
    placement_pubip = var.placement_pubip,
    placement_intip = var.placement_intip,
    placement_adminip = var.placement_adminip,
    glance_pubip = var.glance_pubip,
    glance_intip = var.glance_intip,
    glance_adminip = var.glance_adminip,
    cinder_pubip = var.cinder_pubip,
    cinder_intip = var.cinder_intip,
    cinder_adminip = var.cinder_adminip,
    rados_pubip = var.rados_pubip,
    rados_intip = var.rados_intip,
    rados_adminip = var.rados_adminip,
    neutron_pubip = var.neutron_pubip,
    neutron_intip = var.neutron_intip,
    neutron_adminip = var.neutron_adminip,
    heat_pubip = var.heat_pubip,
    heat_intip = var.heat_intip,
    heat_adminip = var.heat_adminip,
    dash_pubip = var.dash_pubip,
    vault_adminip = var.vault_adminip,
    barb_pubip = var.barb_pubip,
    barb_intip = var.barb_intip,
    barb_adminip = var.barb_adminip,
    jujuclient_ip = var.jujuclient_ip,
    admin_dhcp = var.admin_dhcp,
    internal_dhcp = var.internal_dhcp,
    public_dhcp = var.public_dhcp,
    storage_dhcp = var.storage_dhcp,
    storagerep_dhcp = var.storagerep_dhcp,
    data_dhcp = var.data_dhcp,
    admin_cidr = var.admin_cidr,
    admin_dns = var.admin_dns,
    admin_gateway = var.admin_gateway,
    internal_cidr = var.internal_cidr,
    internal_gateway = var.internal_gateway,
    public_cidr = var.public_cidr,
    public_gateway = var.public_gateway,
    storage_cidr = var.storage_cidr,
    storage_gateway = var.storage_gateway,
    storagerep_cidr = var.storagerep_cidr,
    storagerep_gateway = var.storagerep_gateway,
    data_cidr = var.data_cidr,
    data_gateway = var.data_gateway,
    ntp_local = var.ntp_local,
    ntp_upstream = var.ntp_upstream,
    dns_upstream = var.dns_upstream,
    mikrotik_link = var.mikrotik_link,
    mikrotik_version = var.mikrotik_version,
    admin_vlan = var.admin_vlan.vxlan,
    internal_vlan = var.internal_vlan.vxlan,
    public_vlan = var.public_vlan.vxlan,
    storage_vlan = var.storage_vlan.vxlan,
    storagerep_vlan = var.storagerep_vlan.vxlan,
    data_vlan = var.data_vlan.vxlan,
    admin_vlan_name = var.admin_vlan.name,
    internal_vlan_name = var.internal_vlan.name,
    public_vlan_name = var.public_vlan.name,
    storage_vlan_name = var.storage_vlan.name,
    storagerep_vlan_name = var.storagerep_vlan.name,
    data_vlan_name = var.data_vlan.name,
    local_vpn = var.local_vpn,
    remote_vpn = var.remote_vpn,
    magnum_pubip   = var.magnum_pubip,
    magnum_intip  =  var.magnum_intip,
    magnum_adminip = var.magnum_adminip,
    vip_cidr = var.vip_cidr,
    ossource = var.ossource,
    externalcidr = equinix_metal_reserved_ip_block.external.cidr_notation
    })
}

# Change network mode to hybrid-unbonded
resource "equinix_metal_device_network_type" "edge" {
  device_id  = equinix_metal_device.edge.id
  type       = "hybrid"
  depends_on = [equinix_metal_device.edge]
}

# Assign elastic block to the edge instance
resource "equinix_metal_ip_attachment" "block_assignment" {
  device_id     = equinix_metal_device.edge.id
  cidr_notation = equinix_metal_reserved_ip_block.routed.cidr_notation
}

# Assign VLANs to the internal interface
resource "equinix_metal_port_vlan_attachment" "edge_admin" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.admin_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}
resource "equinix_metal_port_vlan_attachment" "edge_internal" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.internal_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}
resource "equinix_metal_port_vlan_attachment" "edge_public" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.public_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}
resource "equinix_metal_port_vlan_attachment" "edge_storage" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.storage_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}
resource "equinix_metal_port_vlan_attachment" "edge_storagerep" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.storagerep_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}
resource "equinix_metal_port_vlan_attachment" "edge_data" {
  device_id = equinix_metal_device.edge.id
  vlan_vnid = equinix_metal_vlan.data_vlan.vxlan
  port_name = "eth1"
  depends_on = [equinix_metal_device_network_type.edge]
}