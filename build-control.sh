#!/bin/bash

# Update and install packages
apt-mark hold cloud-init
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
apt-get -y install bridge-utils zfsutils-linux

# Find interface names
read -r name if1 if2 < <(grep bond-slaves /etc/network/interfaces)

# Disable netfilter on bridges
echo net.bridge.bridge-nf-call-ip6tables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-iptables=0 >> /etc/sysctl.d/bridge.conf
echo net.bridge.bridge-nf-call-arptables=0 >> /etc/sysctl.d/bridge.conf
echo ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/bridge.conf" >> /etc/udev/rules.d/99-bridge.rules

# Workaround for some Terrafrom corner cases
inspace_internal=${inspace_internal}
inspace_public=${inspace_public} 
inspace_storage=${inspace_storage} 
inspace_storagerep=${inspace_storagerep} 
inspace_data=${inspace_data} 

# change gateways to IP only and get subnet
admingw=$(echo ${admin_gateway} | cut -d "/" -f 1)
adminsn=$(echo ${admin_cidr} | cut -d "/" -f2)
internalsn=$(echo ${internal_cidr} | cut -d "/" -f2)
publicsn=$(echo ${public_cidr} | cut -d "/" -f2)
storagesn=$(echo ${storage_cidr} | cut -d "/" -f2)
storagerepsn=$(echo ${storagerep_cidr} | cut -d "/" -f2)
datasn=$(echo ${data_cidr} | cut -d "/" -f2)

# Build new interfaces file
mv /etc/network/interfaces /etc/network/interfaces."$(date +"%m-%d-%y-%H-%M")"
cat > /etc/network/interfaces << EOFNET1
auto lo
iface lo inet loopback

auto $if1
iface $if1 inet manual
    bond-master bond0
    mtu 9000

auto $if2
iface $if2 inet manual
    pre-up sleep 4
    bond-master bond0
    mtu 9000

auto bond0
iface bond0 inet manual
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves $if1 $if2
    mtu 9000

auto bond0.${admin_vlan}
iface bond0.${admin_vlan} inet manual

auto br1000
iface br1000 inet static
    address ${adminip}/$adminsn
    gateway $admingw
    dns-nameservers ${admin_dns}
    bridge_ports bond0.1000
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET1
if [ "$inspace_internal" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET2

auto bond0.${internal_vlan}
iface bond0.${internal_vlan} inet manual

auto br${internal_vlan}
iface br${internal_vlan} inet static
    address ${internalip}/$internalsn
    bridge_ports bond0.${internal_vlan}
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET2
fi
if [ "$inspace_public" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET3

auto bond0.${public_vlan}
iface bond0.${public_vlan} inet manual

auto br${public_vlan}
iface br${public_vlan} inet static
    address ${publicip}/$publicsn
    bridge_ports bond0.${public_vlan}
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET3
fi
if [ "$inspace_storage" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET4

auto bond0.${storage_vlan}
iface bond0.${storage_vlan} inet manual

auto br${storage_vlan}
iface br${storage_vlan} inet static
    address ${storageip}/$storagesn
    bridge_ports bond0.${storage_vlan}
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET4
fi
if [ "$inspace_storagerep" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET5

auto bond0.${storagerep_vlan}
iface bond0.${storagerep_vlan} inet manual

auto br${storagerep_vlan}
iface br${storagerep_vlan} inet static
    address ${storagerepip}/$storagerepsn
    bridge_ports bond0.${storagerep_vlan}
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET5
fi
if [ "$inspace_data" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET6

auto bond0.${data_vlan}
iface bond0.${data_vlan} inet manual

auto br${data_vlan}
iface br${data_vlan} inet static
    address ${dataip}/$datasn
    bridge_ports bond0.${data_vlan}
    bridge_stp off
    bridge_fd 9
    bridge_hello 2
    bridge_maxage 12
EOFNET6
fi

# wait for everything to finish
sleep 30

# add ubuntu user
useradd -m -p ${ubuntu_user_pw} -s /usr/bin/bash ubuntu
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Enable SSH password login
sed -re 's/^(PasswordAuthentication)([[:space:]]+)no/\1\2yes/' -i.`date -I` /etc/ssh/sshd_config
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

# build one time startup service to create ZFS mirror pool on NVMe for LXD
cat > /etc/systemd/system/zfs-build.service << 'EOFB'
[Unit]
Description=Create ZFS pool, this should only run once
After=network.target

[Service]
ExecStart=/root/zfs-build.sh start

[Install]
WantedBy=multi-user.target
EOFB

cat > /root/zfs-build.sh << 'EOFZ'
#!/bin/bash
zpool create default mirror /dev/nvme0n1 /dev/nvme1n1
lxd init --auto --storage-backend=zfs --storage-pool=default
lxc network set lxdbr0 ipv6.address none
systemctl disable zfs-build.service
rm /root/zfs-build.sh
rm /etc/systemd/system/zfs-build.service
EOFZ

chmod 664 /etc/systemd/system/zfs-build.service
chmod 744 /root/zfs-build.sh
systemctl daemon-reload
systemctl enable zfs-build.service
sleep 60

# clean up and reboot to apply everything
touch /etc/cloud/cloud-init.disabled
reboot
