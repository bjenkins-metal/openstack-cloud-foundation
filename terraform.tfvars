auth_token      = "YOUR AUTH TOKEN"
project_id      = "YOUR PROJECT ID"
safe_ip         = "your.ip.add.ress" #Typically you can google "what is my IP".  You need your public source IP to manage the Edge instance

# Metro for this stack
metro         = "METRO" // example metros "da" "se" "sg"

# use mkpasswd from the whois package to create the password for the ubuntu user. (mkpasswd --method=SHA-512 --rounds=4096)
# make sure to leave both types of quotes and place your password in the center.  ie. "'your-encrypted-password'"
# Sample password (don't use this) "'$6$rounds=4096$gO/W73Ig$SHNVljzgegbTs.rt.Jj0lEsPZehb7.9QYnqprIV7tRgURSsaOwJfSrKph9h760yvFvD7L2.kFVucKF8mR9SJq.'"

ubuntu_user_pw  = "'your password here.  Look at the instructions above.  The tick and quotes are important'"

# Openstack deployment type  
# Compact = "false" will deploy a full private cloud containing 3 controller hosts, 3 database hosts, 3 OVN-Dedicated-Chassis, 3 Storage hosts, 5 compute nodes, the edge and juju controller.
# Compact = "true" will shrink the deployment to 3 controller hosts, 3 compute nodes, the edge and juju controller.
compact = "true"

# VLAN provisioning
admin_vlan = {
  vxlan = "1000"
  name = "Admin"
}
internal_vlan = {
  vxlan = "1001"
  name = "Internal"
}
public_vlan = {
  vxlan = "1002"
  name = "Public"
}
storage_vlan = {
  vxlan = "1003"
  name = "Storage"
}
storagerep_vlan = {
  vxlan = "1004"
  name = "StorageReplication"
}
data_vlan = {
  vxlan = "1005"
  name = "Data"
}
overlay_vlan = {
  vxlan = "1006"
  name = "Overlay"
}
external_vlan = {
  vxlan = "2000"
  name = "External"
}

# Machine Flavors
juju_size       = "m3.small.x86"
controller_size = "m3.large.x86"
db_size         = "m3.large.x86"
storage_size    = "s3.xlarge.x86"
ovnc_size       = "m3.small.x86"
compute_size    = "n3.xlarge.x86"
ubuntu_version  = "ubuntu_22_04"
billing_cycle   = "hourly"

## EDGE PROVISIONING VARS ##
# This is not for Openstack external networking
# This is for the VPN and offers a place to publish the APIs or dashboard if needed using 1:1 NAT
router_public_ips_net = "8" # Number of IPs needed, for instance a /29=8 /28=16 /27=32
router_public_ips_tag = ["Router Subnet"]
edge_hostname    = "edge-gateway"
edge_os          = "ubuntu_22_04"
edge_size        = "m3.small.x86"
pub_ip           = "" # leave blank
# DHCP ranges for each network
admin_dhcp       = "172.22.0.100-172.22.0.249"
internal_dhcp    = "172.22.1.100-172.22.1.249"
public_dhcp      = "172.22.2.100-172.22.2.249"
storage_dhcp     = "172.22.3.100-172.22.3.249"
storagerep_dhcp  = "172.22.4.100-172.22.4.249"
data_dhcp        = "172.22.5.100-172.22.5.249"
# Ip addresses from the admin subnet for the VPN connection
local_vpn        = "172.22.0.250"
remote_vpn       = "172.22.0.251"
# NTP, DNS and safe IP settings
ntp_local        = "172.22.0.1"
ntp_upstream     = "pool.ntp.org"
dns_upstream     = "1.1.1.1"
# CHR Version to deploy.  
# Make sure you have a Mikrotik account so you can get a 60 day trial of unlimited port speed
mikrotik_link    = "https://download.mikrotik.com/routeros/7.14.3/chr-7.14.3.img.zip"
mikrotik_version = "chr-7.14.3.img"

## Openstack external provider network
# External IP block size /29=8 /28=16 /27=32
os_external_subnet_size = "16"
os_external_subnet_tag = ["External Subnet"]

## Controller PROVISIONING VARS ##
controller_names = [
 {servername = "controller01"}, #controller 1
 {servername = "controller02"}, #controller 2
 {servername = "controller03"}  #controller 3
]
controller_admin_ips = [
 {adminip = "172.22.0.11"}, #controller 1
 {adminip = "172.22.0.12"}, #controller 2
 {adminip = "172.22.0.13"}  #controller 3
]
controller_internal_ips = [
 {internalip = "172.22.1.11"}, #controller 1
 {internalip = "172.22.1.12"}, #controller 2
 {internalip = "172.22.1.13"}  #controller 3
]
controller_public_ips = [
 {publicip = "172.22.2.11"}, #controller 1
 {publicip = "172.22.2.12"}, #controller 2
 {publicip = "172.22.2.13"}  #controller 3
]
controller_storage_ips = [
 {storageip = "172.22.3.11"}, #controller 1
 {storageip = "172.22.3.12"}, #controller 2
 {storageip = "172.22.3.13"}  #controller 3
]
controller_storagerep_ips = [
 {storagerepip = "172.22.4.11"}, #controller 1
 {storagerepip = "172.22.4.12"}, #controller 2
 {storagerepip = "172.22.4.13"}  #controller 3
]
controller_data_ips = [
 {dataip = "172.22.5.11"}, #controller 1
 {dataip = "172.22.5.12"}, #controller 2
 {dataip = "172.22.5.13"}  #controller 3
]

## DB PROVISIONING VARS ##
db_names = [
 {servername = "db01"}, #db 1
 {servername = "db02"}, #db 2
 {servername = "db03"}  #db 3
]
db_admin_ips = [
 {adminip = "172.22.0.14"}, #db 1
 {adminip = "172.22.0.15"}, #db 2
 {adminip = "172.22.0.16"}  #db 3
]
db_internal_ips = [
 {internalip = "172.22.1.14"}, #db 1
 {internalip = "172.22.1.15"}, #db 2
 {internalip = "172.22.1.16"}  #db 3
]

## OVN Chassis PROVISIONING VARS ##
ovnc_names = [
 {servername = "ovn-chassis01"}, #gateway 1
 {servername = "ovn-chassis02"}, #gateway 2
 {servername = "ovn-chassis03"}  #gateway 3
]
ovnc_admin_ips = [
 {adminip = "172.22.0.17"}, #gateway 1
 {adminip = "172.22.0.18"}, #gateway 2
 {adminip = "172.22.0.19"}  #gateway 3
]
ovnc_internal_ips = [
 {internalip = "172.22.1.17"}, #gateway 1
 {internalip = "172.22.1.18"}, #gateway 2
 {internalip = "172.22.1.19"}  #gateway 3
]
ovnc_data_ips = [
 {dataip = "172.22.5.17"}, #gateway 1
 {dataip = "172.22.5.18"}, #gateway 2
 {dataip = "172.22.5.19"}  #gateway 3
]

## Storage PROVISIONING VARS ##
storage_names = [
 {servername = "storage01"}, #ceph-osd 1
 {servername = "storage02"}, #ceph-osd 2
 {servername = "storage03"}  #ceph-osd 3
]
storage_admin_ips = [
 {adminip = "172.22.0.20"}, #ceph-osd 1
 {adminip = "172.22.0.21"}, #ceph-osd 2
 {adminip = "172.22.0.22"}  #ceph-osd 3
]
storage_internal_ips = [
 {internalip = "172.22.1.20"}, #ceph-osd 1
 {internalip = "172.22.1.21"}, #ceph-osd 2
 {internalip = "172.22.1.22"}  #ceph-osd 3
]
storage_storage_ips = [
 {storageip = "172.22.3.20"}, #ceph-osd 1
 {storageip = "172.22.3.21"}, #ceph-osd 2
 {storageip = "172.22.3.22"}  #ceph-osd 3
]
storage_storagerep_ips = [
 {storagerepip = "172.22.4.20"}, #ceph-osd 1
 {storagerepip = "172.22.4.21"}, #ceph-osd 2
 {storagerepip = "172.22.4.22"}  #ceph-osd 3
]

## Compute PROVISIONING VARS ##
compute_names = [
 {servername = "compute01"}, #compute 1
 {servername = "compute02"}, #compute 2
 {servername = "compute03"}, #compute 3
 {servername = "compute04"}, #compute 4
 {servername = "compute05"}  #compute 5
]
compute_admin_ips = [
 {adminip = "172.22.0.23"}, #compute 1
 {adminip = "172.22.0.24"}, #compute 2
 {adminip = "172.22.0.25"}, #compute 3
 {adminip = "172.22.0.26"}, #compute 4
 {adminip = "172.22.0.27"}  #compute 5
]
compute_internal_ips = [
 {internalip = "172.22.1.23"}, #compute 1
 {internalip = "172.22.1.24"}, #compute 2
 {internalip = "172.22.1.25"}, #compute 3
 {internalip = "172.22.1.26"}, #compute 4
 {internalip = "172.22.1.27"}  #compute 5
]
compute_storage_ips = [
 {storageip = "172.22.3.23"}, #compute 1
 {storageip = "172.22.3.24"}, #compute 2
 {storageip = "172.22.3.25"}, #compute 3
 {storageip = "172.22.3.26"}, #compute 4
 {storageip = "172.22.3.27"}  #compute 5
]
compute_data_ips = [
 {dataip = "172.22.5.23"}, #compute 1
 {dataip = "172.22.5.24"}, #compute 2
 {dataip = "172.22.5.25"}, #compute 3
 {dataip = "172.22.5.26"}, #compute 4
 {dataip = "172.22.5.27"}  #compute 5
]

## JUJU Controller ##
juju_names = [
 {servername = "jujucontrol"}
]
# IP for physical JUJU controller
juju_admin_ips = [
 {adminip = "172.22.0.2"}
]
#IP for the juju client VM (make sure the subnet matches ie. 255.255.255.0 = /24)
jujuclient_ip     = "172.22.0.3/24"

# Subnet settings for openstack spaces
admin_cidr         = "172.22.0.0/24"
admin_dns          = "172.22.0.1"
admin_gateway      = "172.22.0.1/24"
internal_cidr      = "172.22.1.0/24"
internal_gateway   = "172.22.1.1/24"
public_cidr        = "172.22.2.0/24"
public_gateway     = "172.22.2.1/24"
storage_cidr       = "172.22.3.0/24"
storage_gateway    = "172.22.3.1/24"
storagerep_cidr    = "172.22.4.0/24"
storagerep_gateway = "172.22.4.1/24"
data_cidr          = "172.22.5.0/24"
data_gateway       = "172.22.5.1/24"

## Openstack source
ossource = "cloud:jammy-antelope"
#ossource = "cloud:focal-xena"

## Openstack service Virtual IP Settings ##
# Subnet mask for vitual IPs assigned to the various services. For this project stick to a single subnet size for all networks i.e. /24 or /16
vip_cidr = "24"
# Keystone
keystone_pubip   = "172.22.2.50"
keystone_intip  = "172.22.1.50"
keystone_adminip = "172.22.0.50"
# Nova Cloud Controller
ncc_pubip   = "172.22.2.49"
ncc_intip  = "172.22.1.49"
ncc_adminip = "172.22.0.49"
# Placement
placement_pubip   = "172.22.2.48"
placement_intip  = "172.22.1.48"
placement_adminip = "172.22.0.48"
# Glance
glance_pubip   = "172.22.2.47"
glance_intip  = "172.22.1.47"
glance_adminip = "172.22.0.47"
# Cinder
cinder_pubip   = "172.22.2.46"
cinder_intip  = "172.22.1.46"
cinder_adminip = "172.22.0.46"
# Ceph-RADOS
rados_pubip   = "172.22.2.45"
rados_intip  = "172.22.1.45"
rados_adminip = "172.22.0.45"
# Neutron-API
neutron_pubip   = "172.22.2.44"
neutron_intip  = "172.22.1.44"
neutron_adminip = "172.22.0.44"
# Heat
heat_pubip   = "172.22.2.43"
heat_intip  = "172.22.1.43"
heat_adminip = "172.22.0.43"
# Openstack Dashboard
dash_pubip   = "172.22.2.10"
# Vault
vault_adminip  = "172.22.0.42"
# Barbican
barb_pubip   = "172.22.2.41"
barb_intip  = "172.22.1.41"
barb_adminip = "172.22.0.41"
# Magnum
magnum_pubip   = "172.22.2.41"
magnum_intip  = "172.22.1.41"
magnum_adminip = "172.22.0.41"