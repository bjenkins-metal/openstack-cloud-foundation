#!/bin/bash

# Update and install packages
apt-mark hold cloud-init
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Workaround for some Terrafrom corner cases
inspace_internal=${inspace_internal}
inspace_public=${inspace_public} 
inspace_storage=${inspace_storage} 
inspace_storagerep=${inspace_storagerep} 
inspace_data=${inspace_data}
inspace_overlay=${inspace_overlay}

# Fix hostname for Openstack
sed -i '1 s/./#&/' /etc/hosts
echo "127.0.0.1     ${hostname}     ${hostname}     localhost" >> /etc/hosts

# change gateways to IP only and get subnet
admingw=$(echo ${admin_gateway} | cut -d "/" -f 1)
adminsn=$(echo ${admin_cidr} | cut -d "/" -f2)
internalsn=$(echo ${internal_cidr} | cut -d "/" -f2)
publicsn=$(echo ${public_cidr} | cut -d "/" -f2)
storagesn=$(echo ${storage_cidr} | cut -d "/" -f2)
storagerepsn=$(echo ${storagerep_cidr} | cut -d "/" -f2)
datasn=$(echo ${data_cidr} | cut -d "/" -f2)

# Find interface names
read -r name if1 if2 < <(grep bond-slaves /etc/network/interfaces)

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
iface bond0.${admin_vlan} inet static
    address ${adminip}/$adminsn
    gateway $admingw
    dns-nameservers ${admin_dns}
EOFNET1
if [ "$inspace_internal" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET2

auto bond0.${internal_vlan}
iface bond0.${internal_vlan} inet static
    address ${internalip}/$internalsn
EOFNET2
fi
if [ "$inspace_public" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET3

auto bond0.${public_vlan}
iface bond0.${public_vlan} inet static
    address ${publicip}/$publicsn
EOFNET3
fi
if [ "$inspace_storage" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET4

auto bond0.${storage_vlan}
iface bond0.${storage_vlan} inet static
    address ${storageip}/$storagesn
EOFNET4
fi
if [ "$inspace_storagerep" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET5

auto bond0.${storagerep_vlan}
iface bond0.${storagerep_vlan} inet static
    address ${storagerepip}/$storagerepsn
EOFNET5
fi
if [ "$inspace_data" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET6

auto bond0.${data_vlan}
iface bond0.${data_vlan} inet static
    address ${dataip}/$datasn
EOFNET6
fi
if [ "$inspace_overlay" = "true" ]
then
cat >> /etc/network/interfaces << EOFNET7

auto bond0.${overlay_vlan}
iface bond0.${overlay_vlan} inet manual
EOFNET7
fi

# wait for everything to finish
sleep 30

# add ubuntu user
useradd -m -p ${ubuntu_user_pw} -s /usr/bin/bash ubuntu
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Enable SSH password login
sed -re 's/^(PasswordAuthentication)([[:space:]]+)no/\1\2yes/' -i.`date -I` /etc/ssh/sshd_config

# clean up and reboot to apply everything
touch /etc/cloud/cloud-init.disabled
reboot