#!/bin/bash

# Update and install packages
apt-mark hold cloud-init
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
apt-get -y install virt-manager bridge-utils ufw moreutils cloud-image-utils unzip expect gettext dialog jq

# Collect network info for the management interface
ipaddr=$(ifdata -pa bond0)
netmask=$(ifdata -pn bond0)
gateway=$(route -n | awk '/^0.0.0.0/ { print $2 }')
elascidr=${pub_ip}

# Get first usable IP from elastic CIDR
cidr=$(echo $elascidr | cut -d "/" -f2)
first3oc=$(echo $elascidr | cut -d. -f1-3)
lastoc=$(echo $elascidr | cut -d. -f4 | rev | cut -c 4- | rev)
nextip=$((lastoc+1))
elasip=$first3oc.$nextip"/"$cidr

# change gateways to IP only and get subnet
admingw=$(echo ${admin_gateway} | cut -d "/" -f 1)
internalgw=$(echo ${internal_gateway} | cut -d "/" -f 1)
publicgw=$(echo ${public_gateway} | cut -d "/" -f 1)
storagegw=$(echo ${storage_gateway} | cut -d "/" -f 1)
storagerepgw=$(echo ${storagerep_gateway} | cut -d "/" -f 1)
datagw=$(echo ${data_gateway} | cut -d "/" -f 1)

# work around Terraform corner cases
passwd=${passwd}

# Get IP for router external internface
routerip=$((nextip+1))
routercidr=$first3oc.$routerip"/"$cidr

# Find interface names
read -r name if1 if2 < <(grep bond-slaves /etc/network/interfaces)

# Disable netfilter on bridges
echo net.bridge.bridge-nf-call-ip6tables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-iptables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-arptables=0 >> /etc/sysctl.d/bridge.conf
echo ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/bridge.conf" >> /etc/udev/rules.d/99-bridge.rules

# Remove default bridges for KVM
virsh net-destroy default
virsh net-undefine default

# Build new interfaces file
mv /etc/network/interfaces /etc/network/interfaces."$(date +"%m-%d-%y-%H-%M")"
cat > /etc/network/interfaces << EOFNET
auto lo
iface lo inet loopback

auto $if1
iface $if1 inet manual
mtu 9000

auto $if2
iface $if2 inet manual
mtu 9000

auto bridge1 
iface bridge1 inet static
    address $ipaddr
    netmask $netmask
    gateway $gateway
    dns-nameservers ${dns_upstream}
    bridge_ports $if1
    bridge_stp off
    bridge_maxwait 0
    bridge_fd 0
    mtu 9000

auto bridge1:0
iface bridge1:0 inet static
    address $elasip

auto bridge2
iface bridge2 inet manual
    bridge_ports $if2
    bridge_stp off
    bridge_maxwait 0
    bridge_fd 0
    mtu 9000
EOFNET

# Create and apply bridge files for KVM
cat > /tmp/bridge1.xml << EOB1
<network>
  <name>bridge1</name>
  <forward mode="bridge"/>
  <bridge name="bridge1"/>
</network>
EOB1
cat > /tmp/bridge2.xml << EOB2
<network>
  <name>bridge2</name>
  <forward mode="bridge"/>
  <bridge name="bridge2"/>
</network>
EOB2

virsh net-define /tmp/bridge1.xml
virsh net-autostart bridge1
virsh net-define /tmp/bridge2.xml
virsh net-autostart bridge2

# Configure UFW to allow SSH on management IP
ufw logging on
ufw default deny incoming
ufw default allow outgoing
ufw allow from any to $ipaddr port 22
ufw --force enable

# Configure forwarding for elastic SUBNET
sed -i "s/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/g" /etc/default/ufw
echo "net/ipv4/ip_forward=1" >> /etc/ufw/sysctl.conf
echo "net/ipv4/conf/all/forwarding=1" >> /etc/ufw/sysctl.conf

# Create router config file with correct external IP and gateway
cat > /root/mikrotik_config.cfg << EOFM
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no mtu=9000
/interface vlan
add interface=ether2 mtu=9000 name=${admin_vlan_name} vlan-id=${admin_vlan}
add interface=ether2 mtu=9000 name=${internal_vlan_name} vlan-id=${internal_vlan}
add interface=ether2 mtu=9000 name=${public_vlan_name} vlan-id=${public_vlan}
add interface=ether2 mtu=9000 name=${storage_vlan_name} vlan-id=${storage_vlan}
add interface=ether2 mtu=9000 name=${storagerep_vlan_name} vlan-id=${storagerep_vlan}
add interface=ether2 mtu=9000 name=${data_vlan_name} vlan-id=${data_vlan}
/ip pool
add name=${admin_vlan_name} ranges=${admin_dhcp}
add name=${internal_vlan_name} ranges=${internal_dhcp}
add name=${public_vlan_name} ranges=${public_dhcp}
add name=${storage_vlan_name} ranges=${storage_dhcp}
add name=${storagerep_vlan_name} ranges=${storagerep_dhcp}
add name=${data_vlan_name} ranges=${data_dhcp}
/ip dhcp-server
add address-pool=${data_vlan_name} interface=${data_vlan_name} name=${data_vlan_name}
add address-pool=${internal_vlan_name} interface=${internal_vlan_name} name=${internal_vlan_name}
add address-pool=${public_vlan_name} interface=${public_vlan_name} name=${public_vlan_name}
add address-pool=${storage_vlan_name} interface=${storage_vlan_name} name=${storage_vlan_name}
add address-pool=${storagerep_vlan_name} interface=${storagerep_vlan_name} name=${storagerep_vlan_name}
add address-pool=${admin_vlan_name} interface=${admin_vlan_name} name=${admin_vlan_name}
/interface l2tp-server server set enabled=yes use-ipsec=required ipsec-secret=\$vpnss
/ip address
add address=$routercidr interface=ether1
add address=${admin_gateway} interface=${admin_vlan_name}
add address=${internal_gateway} interface=${internal_vlan_name}
add address=${public_gateway} interface=${public_vlan_name}
add address=${storage_gateway} interface=${storage_vlan_name}
add address=${storagerep_gateway} interface=${storagerep_vlan_name}
add address=${data_gateway} interface=${data_vlan_name}
/ip dhcp-server network
add address=${admin_cidr} dns-server=${admin_dns} gateway=$admingw ntp-server=${ntp_local}
add address=${internal_cidr} dns-server=${admin_dns} gateway=$internalgw ntp-server=${ntp_local}
add address=${public_cidr} dns-server=${admin_dns} gateway=$publicgw ntp-server=${ntp_local}
add address=${storage_cidr} dns-server=${admin_dns} gateway=$storagegw ntp-server=${ntp_local}
add address=${storagerep_cidr} dns-server=${admin_dns} gateway=$storagerepgw ntp-server=${ntp_local}
add address=${data_cidr} dns-server=${admin_dns} gateway=$datagw ntp-server=${ntp_local}
/ip dns set allow-remote-requests=yes servers=${dns_upstream}
/ip firewall address-list
add address=0.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=172.16.0.0/12 comment=RFC6890 list=not_in_internet
add address=192.168.0.0/16 comment=RFC6890 list=not_in_internet
add address=10.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=169.254.0.0/16 comment=RFC6890 list=not_in_internet
add address=127.0.0.0/8 comment=RFC6890 list=not_in_internet
add address=224.0.0.0/4 comment=Multicast list=not_in_internet
add address=198.18.0.0/15 comment=RFC6890 list=not_in_internet
add address=192.0.0.0/24 comment=RFC6890 list=not_in_internet
add address=192.0.2.0/24 comment=RFC6890 list=not_in_internet
add address=198.51.100.0/24 comment=RFC6890 list=not_in_internet
add address=203.0.113.0/24 comment=RFC6890 list=not_in_internet
add address=100.64.0.0/10 comment=RFC6890 list=not_in_internet
add address=240.0.0.0/4 comment=RFC6890 list=not_in_internet
add address=192.88.99.0/24 comment="6to4 relay Anycast [RFC 3068]" list=not_in_internet
add address=${admin_cidr} list=safe
add address=${internal_cidr} list=safe
add address=${public_cidr} list=safe
add address=${storage_cidr} list=safe
add address=${storagerep_cidr} list=safe
add address=${data_cidr} list=safe
add address=${safe_ip} list=safe
/ip firewall filter
add action=accept chain=input comment="accept established connection packets" connection-state=established in-interface=ether1
add action=accept chain=input comment="accept related connection packets" connection-state=related in-interface=ether1
add action=drop chain=input comment="drop invalid packets" connection-state=invalid
add action=accept chain=input comment="Allow access to router from known network" src-address-list=safe
add action=drop chain=input comment="detect and drop port scan connections" protocol=tcp psd=21,3s,3,1
add action=tarpit chain=input comment="suppress DoS attack" connection-limit=3,32 protocol=tcp src-address-list=black_list
add action=add-src-to-address-list address-list=black_list address-list-timeout=1d chain=input comment="detect DoS attack" connection-limit=10,32 protocol=tcp
add action=jump chain=input comment="jump to chain ICMP" jump-target=ICMP protocol=icmp
add action=jump chain=input comment="jump to chain services" jump-target=services
add action=accept chain=input comment="Allow Broadcast Traffic" dst-address-type=broadcast
add action=log chain=input log-prefix=Filter:
add action=drop chain=input comment="drop everything else"
add action=accept chain=ICMP comment="0:0 and limit for 5pac/s" icmp-options=0:0-255 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="3:3 and limit for 5pac/s" icmp-options=3:3 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="3:4 and limit for 5pac/s" icmp-options=3:4 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="8:0 and limit for 5pac/s" icmp-options=8:0-255 limit=5,5:packet protocol=icmp
add action=accept chain=ICMP comment="11:0 and limit for 5pac/s" icmp-options=11:0-255 limit=5,5:packet protocol=icmp
add action=drop chain=ICMP comment="Drop everything else" protocol=icmp
add action=accept chain=services comment="accept localhost" dst-address=127.0.0.1 src-address=127.0.0.1
add action=accept chain=services comment="allow IPSec connections" dst-port=500 protocol=udp
add action=accept chain=services comment="allow IPSec" protocol=ipsec-esp
add action=accept chain=services comment="allow IPSec" protocol=ipsec-ah
add action=return chain=services
add action=fasttrack-connection chain=forward comment=FastTrack connection-state=established,related hw-offload=yes
add action=accept chain=forward comment="Established, Related" connection-state=established,related
add action=drop chain=forward comment="Drop invalid" connection-state=invalid log=yes log-prefix=invalid in-interface=ether1
add action=drop chain=forward comment="Drop incoming packets that are not NATted" connection-nat-state=!dstnat connection-state=new in-interface=ether1 log=yes log-prefix=!NAT
add action=drop chain=forward comment="Drop incoming from internet which is not public IP" in-interface=ether1 log=yes log-prefix=!public src-address-list=not_in_internet
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether1 src-address=${internal_cidr}
add action=masquerade chain=srcnat out-interface=ether1 src-address=${public_cidr}
add action=masquerade chain=srcnat out-interface=ether1 src-address=${storage_cidr}
add action=masquerade chain=srcnat out-interface=ether1 src-address=${storagerep_cidr}
add action=masquerade chain=srcnat out-interface=ether1 src-address=${data_cidr}
add action=masquerade chain=srcnat out-interface=ether1 src-address=${admin_cidr}
add action=masquerade chain=srcnat src-address=${remote_vpn}
/ip route add gateway=$first3oc.$nextip
/ipv6 firewall filter
add action=accept chain=input comment="Allow established connections" connection-state=established
add action=accept chain=input comment="Allow related connections" connection-state=related
add action=accept chain=input comment="Allow limited ICMP" limit=50/5s,5 protocol=icmpv6
add action=drop chain=input
add action=accept chain=forward comment="Allow any to internet" out-interface=ether1
add action=accept chain=forward comment="Allow established connections" connection-state=established
add action=accept chain=forward comment="Allow related connections" connection-state=related
add action=drop chain=forward
/ppp secret add local-address=${local_vpn} name=\$vuser remote-address=${remote_vpn} password=\$vpnpw
/system ntp client set enabled=yes
/system ntp server set enabled=yes
/system ntp client servers add address=${ntp_upstream}
/system/license/renew level=p-unlimited  account=\$mt_user password=\$mt_pass
/quit
EOFM

cat > /root/mtconfig << RTRC
#!/usr/bin/expect -f
log_user 0
spawn virsh console CloudRouter
sleep 5
send "\r"
expect "Login: "
send "admin+t\r"
expect "*word? "
send "\r"
expect "*?Y?n?: "
send "n\r"
expect "*word? "
send $::env(adminpa)\r
expect "*word? "
send $::env(adminpa)\r
expect "*> "
set cfg [open /root/mikrotik_config_complete.cfg r]
set cmd_list [split [read \$cfg] "\n"]
close \$cfg
foreach cmd \$cmd_list {
    expect "*> "
    send "\$cmd\r"
}
RTRC

cat > /root/start << EOSTART
#!/usr/bin/env bash
export DIALOGRC=/root/dialogrc
BACKTITLE="Metal Edge Manager"
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

MAININSTRUCTIONS=\$(cat << 'EOM'
\n***************************************************************************************************
\n*                                                                                                 *
\n*                 The Metal Edge Manager will help you with the following tasks                   *
\n*                                                                                                 *
\n*  1. Create an edge Mikrotik router VM using the settings from the Terraform tfvars file         *
\n*      A. You will need 6 pieces of information to launch the edge                                *
\n*        1. Your username for mikrotik.com                                                        *
\n*        2. Your password for mikrotik.com                                                        *
\n*        3. Admin password for the router.  You can use any password you like                     *
\n*        4. L2TP VPN username. Can be any name you like                                           *
\n*        5. L2TP VPN password. Use any password you like                                          *
\n*        6. L2TP shared secret. Use any password you like                                         *
\n*                                                                                                 *
\n*  2. Create a JUJU client VM with all the tools needed to bootstrap JUJU and launch Openstack    *
\n*                                                                                                 *
\n*      *************************************************************************************      *
\n*      *              Please visit https://mikrotik.com/client and register                *      *
\n*      *                for a free account if you do not have one already                  *      *
\n*      *   **If you do not have an account the interfaces will run at a combined 1Mbps**   *      *
\n*      *         The launch system will auto register the device for a 60 day trial        *      *
\n*      *************************************************************************************      *
\n*                                                                                                 *
\n***************************************************************************************************
EOM
)

function createDialogRC() {
[ ! -f \$DIALOGRC ] && cat << 'EORC' > \$DIALOGRC
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = OFF
use_shadow = OFF
use_colors = ON
screen_color = (BLUE,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,ON)
title_color = (BLUE,BLACK,ON)
border_color = (WHITE,BLACK,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = dialog_color
button_key_active_color = button_active_color
button_key_inactive_color = (WHITE,BLACK,OFF)
button_label_active_color = (YELLOW,BLUE,ON)
button_label_inactive_color = (BLACK,BLACK,ON)
inputbox_color = dialog_color
inputbox_border_color = dialog_color
searchbox_color = dialog_color
searchbox_title_color = title_color
searchbox_border_color = border_color
position_indicator_color = title_color
menubox_color = dialog_color
menubox_border_color = border_color
item_color = dialog_color
item_selected_color = button_active_color
tag_color = title_color
tag_selected_color = button_label_active_color
tag_key_color = button_key_inactive_color
tag_key_selected_color = (WHITE,BLUE,ON)
check_color = dialog_color
check_selected_color = button_active_color
uarrow_color = (GREEN,WHITE,ON)
darrow_color = uarrow_color
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = button_active_color
form_text_color = (WHITE,BLACK,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
gauge_color = title_color
border2_color = dialog_color
inputbox_border2_color = dialog_color
searchbox_border2_color = dialog_color
menubox_border2_color = dialog_color
EORC
}

# Results dialog
function displayResult() {
  dialog --title "\$1" \
    --backtitle "\$BACKTITLE" \
    --no-collapse \
    --colors \
    --msgbox "\$result" \$HEIGHT \$WIDTH
}

function progressBar() {
  dialog --backtitle "\$BACKTITLE" --gauge "\$PROGMESSAGE" 10 50 0
}

function edgeMenu() {
  form=\$(dialog --backtitle "Prepare the Edge and Client VMs" \
  --nocancel \
  --title "Passwords and User Info" \
  --form "" 13 55 6 \
  "Mikrotik.com USER:" 1 1 "" 1 20 35 30 \
  "Mikrotik.com PASS:" 2 1 "" 2 20 35 30 \
  "Router admin PASS:" 3 1 "" 3 20 35 30 \
  "Router VPN USER  :" 4 1 "" 4 20 35 30 \
  "Router VPN PASS  :" 5 1 "" 5 20 35 30 \
  "Router VPN Secret:" 6 1 "" 6 20 35 30 3>&1 1>&2 2>&3 3>&-)
  export mt_user=\$(echo "\$form" | sed -n 1p)
  export mt_pass=\$(echo "\$form" | sed -n 2p)
  export adminpa=\$(echo "\$form" | sed -n 3p)
  export vuser=\$(echo "\$form" | sed -n 4p)
  export vpnpw=\$(echo "\$form" | sed -n 5p)
  export vpnss=\$(echo "\$form" | sed -n 6p)
  envsubst < /root/mikrotik_config.cfg > /root/mikrotik_config_complete.cfg
  PROGMESSAGE="Launching Edge, this will take a moment"
  launchEdge | progressBar
  /root/mtconfig
  sleep 5
  rm /root/mikrotik_config_complete.cfg
}

function launchEdge() {
  echo "10"
  wget -q ${mikrotik_link} -P /root
  echo "30"
  unzip /root/${mikrotik_version}.zip -d /root
  mv /root/${mikrotik_version} /var/lib/libvirt/images/
  echo "50"
  virt-install --name=CloudRouter \
  --import \
  --vcpus=2 \
  --memory=1024 \
  --disk vol=default/${mikrotik_version},bus=sata \
  --network=network:bridge1,model=virtio \
  --network=network:bridge2,model=virtio \
  --os-type=generic \
  --os-variant=generic \
  --noautoconsole
  echo "70"
  virsh autostart CloudRouter
  echo "90"
}

function launchClient() {
  echo "10"
  cat > /root/juju_cloud_init.cfg << 'EOFC'
#cloud-config
hostname: juju-client
manage_etc_hosts: true
users:
- name: ubuntu
  hashed_passwd: "$passwd"
  shell: /bin/bash
  lock_passwd: false
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups: users, admin

ssh_pwauth: true

disable_root: false

package_update: true

package_upgrade: true

packages:
- python3-gi
- gobject-introspection
- gir1.2-gtk-3.0
- python3-openstackclient
- expect
- jq
- nmap
- dialog

growpart:
  mode: auto
  devices: ['/']

write_files:
- path: /home/ubuntu/.bashrc
  content: |
    export PATH=$PATH:/home/ubuntu/openstack/mom/
  append: true
  defer: true
- path: /home/ubuntu/openstack/mom/metal.yaml
  content: |
    clouds:
      metal:
        type: manual
        auth-types: []
        regions:
          ${metro}:
            endpoint: ${jujuadminip}
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
- path: /home/ubuntu/openstack/mom/osenv
  content: |
    {"hosts": {
      "controller": [
        {
          "name": "${cont1name}",
          "adminip": "${cont1adminip}"
        },
        {
          "name": "${cont2name}",
          "adminip": "${cont2adminip}"
        },
        {
          "name": "${cont3name}",
          "adminip": "${cont3adminip}"
        }
      ],
      "db": [
        {
          "name": "${db1name}",
          "adminip": "${db1adminip}"
        },
        {
          "name": "${db2name}",
          "adminip": "${db2adminip}"
        },
        {
          "name": "${db3name}",
          "adminip": "${db3adminip}"
        }
      ],
      "ovnc": [
        {
          "name": "${ovnc1name}",
          "adminip": "${ovnc1adminip}"
        },
        {
          "name": "${ovnc2name}",
          "adminip": "${ovnc2adminip}"
        },
        {
          "name": "${ovnc3name}",
          "adminip": "${ovnc3adminip}"
        }
      ],
      "storage": [
        {
          "name": "${stor1name}",
          "adminip": "${stor1adminip}"
        },
        {
          "name": "${stor2name}",
          "adminip": "${stor2adminip}"
        },
        {
          "name": "${stor3name}",
          "adminip": "${stor3adminip}"
        }
      ],
      "compute": [
        {
          "name": "${comp1name}",
          "adminip": "${comp1adminip}"
        },
        {
          "name": "${comp2name}",
          "adminip": "${comp2adminip}"
        },
        {
          "name": "${comp3name}",
          "adminip": "${comp3adminip}"
        },
        {
          "name": "${comp4name}",
          "adminip": "${comp4adminip}"
        },
        {
          "name": "${comp5name}",
          "adminip": "${comp5adminip}"
        }
      ],
      "juju": [
        {
          "name": "${jujuname}",
          "adminip": "${jujuadminip}"
        }
      ]
    },
    "cidrs": {
        "admin_cidr": "${admin_cidr}",
        "internal_cidr": "${internal_cidr}",
        "public_cidr": "${public_cidr}",
        "storage_cidr": "${storage_cidr}",
        "storagerep_cidr": "${storagerep_cidr}",
        "data_cidr": "${data_cidr}"
    },
    "ips": {
        "keystone": {
          "pubip": "${keystone_pubip}",
          "intip": "${keystone_intip}",
          "adminip": "${keystone_adminip}"
        },
        "ncc": {
          "pubip": "${ncc_pubip}",
          "intip": "${ncc_intip}",
          "adminip": "${ncc_adminip}"
        },
        "placement": {
          "pubip": "${placement_pubip}",
          "intip": "${placement_intip}",
          "adminip": "${placement_adminip}"
        },
        "glance": {
          "pubip": "${glance_pubip}",
          "intip": "${glance_intip}",
          "adminip": "${glance_adminip}"
        },
        "cinder": {
          "pubip": "${cinder_pubip}",
          "intip": "${cinder_intip}",
          "adminip": "${cinder_adminip}"
        },
        "rados": {
          "pubip": "${rados_pubip}",
          "intip": "${rados_intip}",
          "adminip": "${rados_adminip}"
        },
        "neutron": {
          "pubip": "${neutron_pubip}",
          "intip": "${neutron_intip}",
          "adminip": "${neutron_adminip}"
        },
        "heat": {
          "pubip": "${heat_pubip}",
          "intip": "${heat_intip}",
          "adminip": "${heat_adminip}"
        },
        "dashboard": {
          "pubip": "${dash_pubip}"
        },
        "vault": {
          "adminip": "${vault_adminip}"
        },
        "barbican": {
          "pubip": "${barb_pubip}",
          "intip": "${barb_intip}",
          "adminip": "${barb_adminip}"
        },
        "magnum": {
          "pubip": "${magnum_pubip}",
          "intip": "${magnum_intip}",
          "adminip": "${magnum_adminip}"         
        },
        "vip_cidr": {
          "cidr": "${vip_cidr}"
        }
    },
    "type": {
        "compact": "${compact}"
    },
    "overlay": {
        "vlan": "${overlay_vlan}"
    },
    "source": {
        "release": "${ossource}"
    },
    "externalnet": {
        "cidr": "${externalcidr}"
    }
    }
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
- path: /home/ubuntu/openstack/mom/mom
  encoding: gz+b64
  content: |
    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
    CREJvUIu9QTJ+BcB07yvRZkAAA==
  owner: 'ubuntu:ubuntu'
  permissions: '0755'
  defer: true
- path: /home/ubuntu/openstack/mom/dialogrc
  encoding: gz+b64
  content: |
    H4sIAAAAAAAAA42UwW6DMAyG7zxF1VMn9TDtvkNb0W0aotK0qeoJheBB1JSgxLTd2w/CWkJC0I74
    /2L/sR2IqoDi7Hn2GCioiCQIyYVlObSx+TxAkiYcSg2cmWKYMISTar53221QK0hUQTJxMQJUcCE1
    EQeKSoCyCzWRxTr6CpfraLV5X+7ih6A7a8qt0usZI1zkvb5/ffs0zyNDDt7sqZAZSP/ptEYUZUIo
    sjO4WJPLoFhpcaa3G3SEHzvdSBGTdtIOXW63dwOcpMAds4cwinZ7x20Hu8ntBrOyqjEV1/Fb3VWr
    kwNIAZG08Obo5eGwjC+DsQqZn0ElmvVjehQZowSFHE12grL2urmJU3XaBff0o1UU8ObFQDY5YST5
    qLk27kvgDljj7ZZYpLs4d9JJbq8zLYAex6/XSf+6X02kNB/uy0cYxsuulH64Q93EdRcL4NXEyn8L
    eboVRLjipBcND6i/hJvDKtZuNKGHJ6H54ZS87+hCQ73xnNT5+JJ2O/L0r5fioew992DDJfVAvyaY
    0KC5BQAA
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
- path: /home/ubuntu/openstack/mom/bundle.full
  encoding: gz+b64
  content: |
    H4sIAAAAAAAAA+0c247bNva9QP/BGBQoUCwTe26dGOhDdhpsi3bTIN0U6NOAkmhbGUpUdPHM7GL/
    fQ+voihKpuzxoAs4A0Q0eXhInisvh6xImZJqOVuxGNOvv8JFQdMY1ynLq+XXX81mMSk2iFUJqoo0
    FzmQt8FltjRFJjPPCV3OqhpHlMjMkmzTCnAtZ1eLC5mVN9ldk6c1tKlyaqbwotnZmzOTXMyt9EKl
    WdF2jf+LaEOqmpVkOavLhujsuIHMLP03QSuc0qYkKGEZhgHMVphWBoyPK4EuxpwCryH1ukoinYh1
    ItEJohMrnVjrxEajnOmcVCc+68S9TlCdyHQit3v0mTVljimqoP/L2eX8zbUuraAkhrxvfv/t08fb
    dzq7qWB8aUniGqXMJkSU5kmar1tynZ0tZ2leE47f0IoCsUjJGcdKvCYlKXRRxjnnwudlQRB5lJko
    w7KyC1U0EQiSQWpGQOKS1BVS2d16QqBKnLBq/TAkb6o4SOYu37wJkDn6mCzn9o+F/ePcL3dGLYBa
    WmFQzJq8Nk1AT2AYNF1v6gfC/0cFYxQVawTdWc7QYgdXt2kBeR/f/vj2x3+K78/v/yW+Hz79fQJ7
    cZJxuReftvdlna54t7ngd4u0NLh41gD8gJ/6BRvcz0sTktdp/YQqUnL18kCo3/2SIYk6QBhZ9Jkr
    hzIUQ6Iqv4Z5Sg5BuTwYK4q3HumFPg4JLhQFCe33IXZyL5nFTb1BVVMUrKxJIrv1ONFikscCKEkS
    IftK3ucWh1IgcU8PvAK+t/BGjNVVXeICabx9i5YS3oEJli7B1SZiuEw8cpdUzyuMlaeRomQZqTek
    8bQ1YEqVgPbhyyhBWVqWzGk8BooT4A6XRo+QtqVhxvXmYm/TGOaXAI8/F+EYPLaHUtJDWM1K594H
    /Nx8blCar5hHsyWVUYTje5InXhIOUS9sJnQxP5aGR5TF92bQ71lOJjAFTDzFeUwQLlK0JaXs7bkR
    24LkMCDAz8p0zbXSMwvRtEJAuYLBr6o7L5M+7fbn98KnwVf4NPganyZg7uI0AeE9vzzQVODsS9GH
    5JxtCj+DW8FztG3MZUqh2DLaZGTY4w161j0daMaldA//Om3+1nWKFUg7GP8kCtAbi4CW2qAN1oTo
    KJDJDtKhmymGxEdfQM+SaYYhkG44Jhm+h9GWJGO1b7pBoBBvwcviKKXA4y6I8UQnSu2gFKnjpEsa
    nhM2yVosnssGB/qy6RNun5KtS7zCuYdLgSQfm2WU7NEhsPQHXRLLvDBHt7g+lqMLcmfP6LH+8etb
    4bHgKzwWfF/SY5080my/Rdye/kpNhE4GeNwAbwiuHdJAThBVLm+ujmUbdqq9VOmf3kmVhq9Qafi+
    rEpP9whe6QCKo4I2MFBY20eshE5iHy8P2ZI5wpRR9PukYOMKdk+ewCrljgvWuWFO+OJoe6A7Fa0o
    yYqUnPudJaVx0FIRf3n3p1BE+ApFhO9xFHGvSZjYBBteK456StWJwfIYSMOTmHrmYwYqZ6rXgvjP
    qtdaktAqTXR9BBPBLSD1EMOAZ2mSUPKAfY74SMvLBxJVFUMwNav49uPAfp3p4cmyjFuWjGQxjjfE
    WUCZ7CD6XNwEmpYL+8el/ePKb1owpewBNasHlBbXqGKrmu9KTz/a4mOZMO+l/BAUqW1s/67vUAmM
    f68d4eyp+kJBFkBQIuSVWR+Ew56bV/PXAyya6xy5Wd7SS6KtNoTS9jDq+TmpOoxynBE1FtMD/Ahr
    NhhBrEzb+XxuzhL2PzPYx8zHTE2c3D1z/g/IrhjvLStZ48U5YMwk3WUlJBdqPn5LgHA+D5AfaHz3
    sjQeocjYrnsAsVqbf6JXCL182zcnYg0Qq7+WPZFqgFT+VcmJXAPkyuP4RKkwSpGmLlkOi8UTwYII
    VlC+DuCxDid6hdBrixv60rT6/yEVGKrTunnHulmZKNSzUVZBEI2u5s92AulfPOOmZhmu0xjRC7wG
    GyECu9iWk8U+4CI57x5KtqUb6iULVg8YV/4iesGZ50GW0XPEo8xQReKmFET0QAmIFSsfMF97rbsw
    K4prcAj1AyvvzZYU9KPYPFWQbcJS1pRFwHCVjbK6Wc7eWBZK9KRoqNg+6zaR4ZwfAGnOqU10StY4
    foIVHxfAzqgzXnqBBDErVHAhUrpneqNxGUFUIzD9XriQstXljG0rt0gTD62hncI5l3zGw8337z6J
    DVj4ig1Y+I5uwEIerCxQifM1qdyR/QWOSXgUAPIcZ4syzZjEt5e6byjrikWUPWpJmrIDm6UJzKQ9
    sYq2oRkspAwnCMSfr/M8hHAkexRVCzN+jHSk7d2tOMuv6n4nLUKcvFO4d9IMZdt80FFZMEGUW8z9
    Dgd0SWiHMNCLV+LveeY3MJmqcZrvFu5+ORhUvl+aOWqesy1GMWUND1/OAQOlrjh5QcKc+vXxIl5Y
    vkrXCNwiUFMGet7JQM877u858e5KUvPLPD9czOd/G4W4ExTZYvrDYm4zkUt7x+XpM6F1I45aOlds
    oHcMvLiMxeX2tmYxo4J8uVH5uGiQap2H6JT8s5xdtkyUDl66YuDye8nV6f50pz/80rAayxgh1FTc
    8a9KlllLqM7oJnjP21vpPW9vpfe8vX3JOAKei2KxiT9Fr0IDhKQSZEXjs0Y9NQo/aXnhCCN9rjXV
    zwpLAMQdKd5mB52DtuIX5kO/NDivm8xMjQeJMRb6pIs8giOHrDjuMYuyJMwaXvUD3a961vBscW7d
    87uw0pdW+spKXw/cBQwKCjy6HdVro3TLz8nXpWfhoUBgviNu+NlFaS6C3ApcVcBex+TSNNqmsGaS
    amBiEsooaaeTqkEkLvvUTwXgrypzOzFraA3TKFYBSc5ydhZsPfmdEnmtBilFkoNIbAB+v03Kickl
    FTcwa35Jk1/6A9oh6BzvAOL3ePYxukAAOa77bTbFpE6JrLTumLhlQSZxLLBD1UV8LrecJbg21IJm
    wRaUMPjBeJO9LWAKRi6N/XaMTzs8KxMju3Yfd027lMlMKY809s7bguzi6D3RvC4c01QXYRZpYAKr
    9+a4AL8CZK9YuZ4gWiMT/6HxhVEBuiLExCNFUOSr1SrywGmpByCMdIvLY01tExI16649SsiKb9Wi
    mivEUv80pWklN5CUlQRLuiVc6J1NKmlAlLXQVPr08dcWYsWA76iqaNfIaCHXTlZsjo0BrNKSPGC6
    A01/v6wHEY2XbwvHlbDVisL6SBgkMLaSV2d/kirctEtVg+wf3/7+0+/vbo01jsBzNpoFNnfkxBfA
    d2wTPZCoFEb+9QRl2itKz9yZGTJL+803jxjLlvq8hwpyC4vGC4uIg8UYmGOYoYN+dA1BWxBkAIIv
    c0wOETrKyUjgnQK+SRC8d9AWSd/tL5M7IR4ubMBcpZWHC7IgiAvnCz8NozJN1mr2tIIlBYy4KAT9
    oKgVoojlyZznAKD88eqb3/549/HXt3+2g8iRwtbi0KvtpYXMbMUvJT6jDiLqV48K4QrxS8qWaT5o
    ujZ8FAaTlO5UZWw/zl7l7Kn2o7IzuIfKyZuQRAwhGZaJHkiYjoYEZJ5dt2up79vkzdALK391ybLd
    4QEvDRwub3uLzcAxvskO4v3F+bHmZ8941PRB3aP7oO7RfXjpe3TPc+nmkJj7yTs+AxMJg+d0KrLj
    VKTEUZTW2RftmTtUcgrDzOx56Bste4dLFxgkVWzkQFcSKo7H+Yn+hlhnmXIbiWeLszOo4igdP7HW
    GOVe00VbxB8IAbzoS0MaUgXYUX5nEtfVXQwrkruK3xJoKMB8+93rq9l38u/bY1rcSSq6W7b0Az9G
    TzzPepx0SIF4Iqe27ZJ8197B0bYOhOyvSU5KvrPIF5so5ttPZe3zPn+85YEOU0RU7QEefo3MM1EU
    zxcMBiiECQyNRhaIk3bagg8QBNtPPmdUXzIcb9JcXbY5m8No/vNfkVy0yfM2edEmL9vkVZu8bpPf
    t8mbNvnGasJuzmpvYTW4sFpcWE0urDYXutGSUPMeJAJ1NOHfGzHzRb5Ld7yoA2uESVbxx5NbQGgQ
    yIQ82pic+1MWDEckjZd+HARJzfO2IiH3aMKDxRlyL7PtmSakq1qaihLKtjvWOLrZY+CGhP0qnbfr
    1JOeyHn7Uzxg1+JXdsMH6Wzey1r+wAs99G7sqR54L47+UM5wHA5f/P1y+OQHcpcBDpn7xcOo+GRI
    Vndnq7JkuKY+2lYUMfc6VeaYQPgR9qWjXbJodvkWH16mtVUPZV2LyWGgt6Db7b0Y1VbvLMSHyGYB
    jdG8xdqns7qwpYnce4XES2FV6VDyKjQObfu5Vj87Z5FjpHEAbRT7MEbVDVEZBaofNXQMnTzQHueX
    wdAzmdZTgJpj/nfONNvsGs7rM53q7QONPSgXzV70sxF4A4FGrYO/gos3hDmdgfRlyS9lEwagWTfc
    Y99d3EMVSaFxFKnD+6429bh+gLR2KOP18t33lbXgDqyFjeT2KqrXbJ0umseZ0bgUzrw4/dI6ONRe
    /f6AO9v8nciNURHvAvYQhftqVWGScHf7vFsUevAqcmXApHQgBmZzHZTeydzQtb2D52ctKneaZsXp
    uZMzq8jMJ71R41qe7RpB3LTg95v0WQicm0JDUtgBG53FWbjDFwP2ubBHcfyB5N3gn37z45cJRlGb
    I9d+96yiQDrYiPuDsw9jBe6BJvvQbgikoyoueXbSX6H1d7F/Sri7s2Ot9fF5+F4XS7N5MlbVAhqo
    16GMAz7wrMOh1qPF5BgPX1SUY0R8INqY+J5k1abEV28vEzHIOk8Dfcb13zI4lJgCiUNHNw/pPE0p
    51U3TSQBE2JoBeCzkk9g7Gb/D2DPgDXzZAAA
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
- path: /home/ubuntu/openstack/mom/bundle.compact
  encoding: gz+b64
  content: |
    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
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
EOFC
echo "40"
cat > /root/network_config_static.cfg << EOFN
version: 2
ethernets:
  enp1s0:
     dhcp4: false
vlans:
    vlan${admin_vlan}:
        id: ${admin_vlan}
        link: enp1s0
        addresses: [ ${jujuclient_ip} ]
        gateway4: $admingw
        nameservers:
            addresses: [ ${admin_dns} ]
EOFN
echo "50"
cloud-localds --network-config=/root/network_config_static.cfg /var/lib/libvirt/images/juju_seed.img /root/juju_cloud_init.cfg &> /dev/null
rm /root/network_config_static.cfg
rm /root/juju_cloud_init.cfg
echo "70"
wget -q https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -P /root
cp /root/focal-server-cloudimg-amd64.img /var/lib/libvirt/images/
qemu-img resize /var/lib/libvirt/images/focal-server-cloudimg-amd64.img 50G
echo "80"
virsh pool-refresh default
wait
virt-install --name=juju-client \
--import \
--vcpus=2 \
--memory=4096 \
--disk vol=default/juju_seed.img,device=cdrom \
--disk vol=default/focal-server-cloudimg-amd64.img,device=disk,bus=virtio \
--network=network:bridge2,model=virtio \
--os-type=linux \
--os-variant=ubuntu20.04 \
--virt-type=kvm \
--graphics=none \
--console=pty,target_type=serial \
--noautoconsole
virsh autostart juju-client
echo "100"
}

## START HERE ##
createDialogRC

# Menu
while true; do
  exec 3>&1
  selection=\$(dialog \
    --backtitle "\$BACKTITLE" \
    --title "Edge Menu" \
    --clear \
    --cancel-label "Exit" \
    --help-button \
    --help-label "Instructions" \
    --menu "" 0 0 2 \
    "1" "Launch the Mikrotik Edge Router (check instructions)" \
    "2" "Launch the JUJU client VM" \
    2>&1 1>&3)
  exit_status=\$?
  exec 3>&-
  case \$exit_status in
    \$DIALOG_CANCEL)
      clear
      exit
      ;;
    \$DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
    \$DIALOG_HELP)
      clear
      HEIGHT=30
      WIDTH=103
      result=\$(echo "\$MAININSTRUCTIONS")
      displayResult "Instructions and Info"
      HEIGHT=0
      WIDTH=0
      ;;
  esac
  case \$selection in
    1 )
      if [ -f "/var/run/libvirt/qemu/CloudRouter.pid" ]; then
        HEIGHT=6
        WIDTH=50
        result="  It seems that the Edge VM already exists\nPlease delete the VM before deploying again!"
        displayResult "VM Detected"
        HEIGHT=0
        WIDTH=0
      else
        HEIGHT=6
        WIDTH=75
        edgeMenu
        result="The router has been deployed, connect to the VPN using $first3oc.$routerip\nIf you entered a safe IP you can manage the router with winbox or http"
        displayResult "Edge Deployed"
        HEIGHT=0
        WIDTH=0
      fi
      ;;
    2 )
      if [ -f "/var/run/libvirt/qemu/juju-client.pid" ]; then
        HEIGHT=6
        WIDTH=52
        result="It seems that the JUJU client VM already exists\n  Please delete the VM before deploying again!"
        displayResult "VM Detected"
        HEIGHT=0
        WIDTH=0
      else
        HEIGHT=8
        WIDTH=75
        PROGMESSAGE="Deploying Client VM"
        launchClient | progressBar
        result="            Connect to the VPN using $first3oc.$routerip\n             ssh to the JUJU client at ${jujuclient_ip}\n   Use the JUJU client to bootstrap amd maintain JUJU and Openstack\nThe VM is currently updating and will be available in a minute or two"
        displayResult "Client VM Installed"
        HEIGHT=0
        WIDTH=0
      fi
      ;;
  esac
done
EOSTART

# Reboot to apply everything
chmod +x /root/start
chmod +x /root/mtconfig
touch /etc/cloud/cloud-init.disabled
reboot