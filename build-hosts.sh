#!/bin/bash

# Update and install packages
apt-mark hold cloud-init
apt-mark hold grub*
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

# Find interface names and nic count
# Some Metal hosts with 4 NICS have 2 unconnected onboard 1G NICs that still show up when polling for devices
ncount=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | wc -l)
if [[ "$ncount" -ge "4" ]] && [[ $(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p) == "eno1" ]]; then
nic1=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 3p)
nic2=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 4p)
nic3=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 5p)
nic4=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 6p)
elif [[ "$ncount" -eq "4" ]] && [[ $(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p) != "eno1" ]]; then
nic1=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p)
nic2=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 2p)
nic3=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 3p)
nic4=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 4p)
elif [[ "$ncount" -eq "4" ]] && [[ $(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p) == "eno1" ]]; then
nic1=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 3p)
nic2=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 4p)
else
nic1=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p)
nic2=$(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 2p)
fi

# Build new interfaces file

mv /etc/network/interfaces /etc/network/interfaces."$(date +"%m-%d-%y-%H-%M")"
if [[ "$ncount" -eq "6" ]]; then
cat > /etc/network/interfaces << EOFNET0
auto lo
iface lo inet loopback

auto $nic1
iface $nic1 inet manual
    bond-master bond0
    mtu 9000

auto $nic2
iface $nic2 inet manual
    bond-master bond1
    mtu 9000

auto $nic3
iface $nic3 inet manual
    bond-master bond0
    mtu 9000

auto $nic4
iface $nic4 inet manual
    bond-master bond1
    mtu 9000

auto bond0
iface bond0 inet manual
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves $nic1 $nic3
    mtu 9000

auto bond1
iface bond1 inet manual
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves $nic2 $nic4
    mtu 9000
EOFNET0
elif [[ "$ncount" -eq "4" ]] && [[ $(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p) != "eno1" ]]; then
cat > /etc/network/interfaces << EOFNET0.1
auto lo
iface lo inet loopback

auto $nic1
iface $nic1 inet manual
    bond-master bond0
    mtu 9000

auto $nic2
iface $nic2 inet manual
    bond-master bond1
    mtu 9000

auto $nic3
iface $nic3 inet manual
    bond-master bond0
    mtu 9000

auto $nic4
iface $nic4 inet manual
    bond-master bond1
    mtu 9000

auto bond0
iface bond0 inet manual
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves $nic1 $nic3
    mtu 9000

auto bond1
iface bond1 inet manual
    bond-downdelay 200
    bond-miimon 100
    bond-mode 4
    bond-updelay 200
    bond-xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-slaves $nic2 $nic4
    mtu 9000
EOFNET0.1
else
cat > /etc/network/interfaces << EOFNET1
auto lo
iface lo inet loopback

auto $nic1
iface $nic1 inet manual
    bond-master bond0
    mtu 9000

auto $nic2
iface $nic2 inet manual
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
    bond-slaves $nic1 $nic2
    mtu 9000
EOFNET1
fi
cat >> /etc/network/interfaces << EOFNETAD

auto bond0.${admin_vlan}
iface bond0.${admin_vlan} inet static
    address ${adminip}/$adminsn
    gateway $admingw
    dns-nameservers ${admin_dns}
EOFNETAD

if [ "$inspace_internal" = "true" ]; then
cat >> /etc/network/interfaces << EOFNET2

auto bond0.${internal_vlan}
iface bond0.${internal_vlan} inet static
    address ${internalip}/$internalsn
EOFNET2
fi
if [ "$inspace_public" = "true" ]; then
cat >> /etc/network/interfaces << EOFNET3

auto bond0.${public_vlan}
iface bond0.${public_vlan} inet static
    address ${publicip}/$publicsn
EOFNET3
fi
if [ "$inspace_storage" = "true" ]; then
if [[ "$ncount" -eq "6" ]]; then
cat >> /etc/network/interfaces << EOFNET4.0

auto bond1.${storage_vlan}
iface bond1.${storage_vlan} inet static
    address ${storageip}/$storagesn
EOFNET4.0
elif [[ "$ncount" -eq "4" ]] && [[ $(lshw -class network | grep -A 1 "bus info" | grep name | sed 's/.*:\s*//' | sed -n 1p) != "eno1" ]]; then
cat >> /etc/network/interfaces << EOFNET4.1

auto bond1.${storage_vlan}
iface bond1.${storage_vlan} inet static
    address ${storageip}/$storagesn
EOFNET4.1
else
cat >> /etc/network/interfaces << EOFNET4.2

auto bond0.${storage_vlan}
iface bond0.${storage_vlan} inet static
    address ${storageip}/$storagesn
EOFNET4.2
fi
fi
if [ "$inspace_storagerep" = "true" ]; then
cat >> /etc/network/interfaces << EOFNET5

auto bond0.${storagerep_vlan}
iface bond0.${storagerep_vlan} inet static
    address ${storagerepip}/$storagerepsn
EOFNET5
fi
if [ "$inspace_data" = "true" ]; then
cat >> /etc/network/interfaces << EOFNET6

auto bond0.${data_vlan}
iface bond0.${data_vlan} inet static
    address ${dataip}/$datasn
EOFNET6
fi
if [ "$inspace_overlay" = "true" ]; then
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
#20.04
sed -re 's/^(PasswordAuthentication)([[:space:]]+)no/\1\2yes/' -i.`date -I` /etc/ssh/sshd_config
#22.04
sed -re 's/^(KbdInteractiveAuthentication)([[:space:]]+)no/\1\2yes/' -i.`date -I` /etc/ssh/sshd_config

rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

# clean up and reboot to apply everything
touch /etc/cloud/cloud-init.disabled
reboot
