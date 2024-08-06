#!/bin/bash

# Update and install packages
apt-mark hold cloud-init
apt-mark hold grub*
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
  --memory=2048 \
  --disk vol=default/${mikrotik_version},bus=sata \
  --network=network:bridge1,model=virtio \
  --network=network:bridge2,model=virtio \
  --os-variant=linux2022 \
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
            endpoint: ubuntu@${jujuadminip}
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
    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
  owner: 'ubuntu:ubuntu'
  permissions: '0644'
  defer: true
- path: /home/ubuntu/openstack/mom/bundle.compact
  encoding: gz+b64
  content: |
    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
    4iTJ2/8AxTJJYwNWAAA=
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
wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -P /root
cp /root/jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/
qemu-img resize /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img 50G
echo "80"
virsh pool-refresh default
wait
virt-install --name=juju-client \
--import \
--vcpus=2 \
--memory=4096 \
--disk vol=default/juju_seed.img,device=cdrom \
--disk vol=default/jammy-server-cloudimg-amd64.img,device=disk,bus=virtio \
--network=network:bridge2,model=virtio \
--os-variant=ubuntu22.04 \
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
