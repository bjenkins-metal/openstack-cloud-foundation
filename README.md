# Openstack Cloud Foundation
Deploy a highly available, private cloud on Equinix Metal in the worlds most desirable places.  

## Summary
This project simplifies Openstack deployment and management by using the Canonnical JUJU charm framework to deploy on Equinix Metal.  JUJU allows you to manage and monitor the entire deployment from a single host.  This includes lifecycling and stack upgrades.  This deployment project will allow you to choose form mini or full stacks.  The mini stack is similar to classic vSphere where you need a minimal control plane and a few HCI compute hosts that will contain both compute and storage.  The full stack is a fully featured private cloud that is designed to scale up significanly and offer a self service private cloud experience to your users or consumers.  The full stack includes resilient storage and an object storage system.  You can alter the storage layout and add discreet storage arrays from name brand vendors to suppliment or replace the storage used in this project.

## Current versions deployed with this project
* ### Ubuntu 22.04 LTS - Jammy
* ### Openstack Antelope - 2023.1

## Platform Features
* 3 failure domains so you can absorb failures, manage, update and upgrade the stack without impacting production
* TLS encrypted endpoints on the control plane with easy key management through the Vault
* Connect to complex networks like layer 2 extensions in a secure and private way
* Offer self service cloud features to your consumers in a mluti tenant framework to allow managers to administer sub groups in your organization
* You decide on how the external network will work.  Bring your own network or use other options available on Fabric and Metal.


## What the OCF project does
* ### Deploy and configure all the hardware needed for the stack
    * Create edge router 
        * VPN access to manage the project
        * Allow 1:1 NAT to expose APIs if needed
        * Handle DHCP, NAT, VPN, NTP and DNS forwarding for the control plane
    * Create management VMs with tools needed for Opentstack management
    * Create JUJU controllers for logsink and control plane
    * Create controller nodes
        * Configure the NVMe drives for mirrored ZFS pools
        * Create the bridge configurations for LXD services
    * Create dedicated database hosts
        * (Full deployment only)
        * Configure the NVMe drives for mirrored ZFS pools
        * Create the bridge configurations for LXD services
    * Create Ceph storage pool
        * (Full deployment only)
        * Highly available
        * Highly redundant data
        * about 65TB of usable space
        * Expand horizontally, just add more nodes
    * Create highly available OVN edge
        * (full deployment only)
        * Simplify public IP management
        * Scale the compute infrastructure easily
        * Manage layer 2 sprawl for provider networks
    * Create compute nodes
        * Scale horizontally by adding more nodes
        * Compact stack will add HCI storage to the compute nodes
* ### Create domain for management
    * Deploy VM with management tools needed to launch and monitor Openstack
    * Bootstrap JUJU
        * Prepares the hosts for centralized management by JUJU
        * Prepare the logsink and control plane server
    * Metal Openstack Manager (MOM) deployed to simplify tasks
        * Deploy a reference HA Openstack region with storage and networking
        * Populate the stack with a reference layout
            * External network automatically connected
            * Ubuntu image added to the image store
            * Add flavors for VMs
            * Create internal network 
            * Create router
        * Manage the Vault
            * Automatically distribute certificates to secure the API endpoints

---

### OCF should be treated as a reference deployment to get you started down the path of Openstack. The key takeaway is the freedom that will allow you to customize the platform to your own needs.  Openstack is well documented, well understood and made up of an ever evolving set of projects.  Almost everything in this project is modular from the routing edge to the modules that make up Openstack.
---
### This project is EXPERIMENTAL and there is no official support for this project.  This project can change and the reference design may shift over time.
---

## Things you should do before starting this project
    * Visit the Mikrotik website and setup a free account (https://mikrotik.com/client)
        * Creating an account will allow you to auto register the edge for a 60 unlimited trial at full port speed
        * Permanent licenses are affordable and easy to procure through the Mikrotik site
    * Gather your source IP so it can be added to the safe list for remote access.  Typically you can Google "What is my IP"
    * Make sure you have an Equinix Metal account (https://console.equinix.com)
        * Create a new and empty project
        * Gather your API key and your project ID
    * Download the correct Terraform binary for your OS (https://www.terraform.io/downloads)
    * Set aside about 2 hours for the project
    * You will need to generate an encrypted password using the mkpasswd utility so having access to a Linux or Mac machine is important
    * You will need to provide a user/pass plus shared secret for the VPN configuration, any password generator will do
## Assumptions
    * You have an Equinix Metal account
    * You know how to use Terraform
    * You know how to SSH with keys and passwords
    * You understand how to setup a VPN (L2TP specifically) on your OS

# Lets get started!
![OCF High Level Diagram](https://user-images.githubusercontent.com/74058939/194336372-943914f2-b9e0-4c47-a27e-b31aa25a6e4a.png)
## Deployment steps
1. Clone this project locally
2. Modify the terraform.tfvars file to fit your needs.  
    * API token
    * Project ID
    * Source IP (The IP address where you are right now so it can get added to the "safe_list")
    * Encrypted password for the hosts (mkpasswd --method=SHA-512 --rounds=4096)
    * Metro where you will launch (da by default)
    * Decide if you want a full reference stack or a compact stack
        * Full stack is 3 controller hosts, 3 database hosts, 3 OVN Edge hosts, 3 Storage hosts, 5 compute hosts, the edge and juju
        * Compact stack is 3 controller hosts, 3 storage hosts, 3 compute nodes, the edge and juju
3. Use Terraform to launch the stack
    * terraform init
    * terraform plan
    * terraform apply
4. You will be presented with the IP address for the edge host when Terraform completes.
    * SSH to the edge host using the ip from the Terraform output
        * type "./start" then hit enter to launch the Edge Manager
    * From the Edge Manager.
        * Click on Launch edge
        * Enter your Mikrotik.com username
        * Enter your Mikrotik.com password (this is to auto register the edge into your account)
        * Choose a password for the edge router
        * Choose a username for the VPN
        * Choose a password for the VPN user
        * Choose a shared secret for the L2TP setup
        * SAVE ALL THIS INFO FOR LATER!
5. Once the edge is launched you will be presented with the IP that you will use as your VPN target, save that IP!
6. Click Launch the management VM using the edge manager
    * Wait about 2-3 minutes before remoting into the manager.  It has to install and update many packages.
7. Setup the VPN on your OS using the user/pass/secret you entered earlier
8. SSH into the management VM (172.22.0.3 if you did not change the IPs in terraform.tfvars)
    * username is ubuntu, the password will be the UNENCRYPTED version of what you used in the tfvars file
9. type mom and hit enter.  You should now be in the Metal Openstack Manager
    * Go to the Bootstrap Menu
        * Click Bootstrap JUJU and enter the UNENCRYPTED password that you encrypted earlier for the terraform.tfvars file
        * be patient, it will take a few minutes to ingest all the hosts
    * Once bootstrapped click on Deploy Openstack and let it complete
    * Exit the MOM
    * at the shell type "juju status --watch 1s" and hit enter
    * Watch as the stack auto builds itself.  Wait for the install to settle after 20-30 minutes
        * Wait for the majority of the applications to change to ready
        * you will notice the Vault is sealed and some others are waiting on certificates
        * exit the watch screen (ctrl+c) and type mom again.
    * Go to the Vault Menu and click Initialize and Authorize Vault.  Wait about 5 minutes for it to settle
    * Optional but recommended is go back to the bootstrap menu and click Populate Openstack
        * The external provider network will be auto created
        * Ubuntu Jammy image will be downloaded and added to Glance
        * VM Flavors will be created
        * An internal network and router will be created in the admin project
    * Get your admin password
        * go back to mom and click bootstrap and then click show admin info where you can see the randomly generated admin password
    * If nothing was altered in terraform.tfvars then the dashboard should be located at https://172.22.2.10
        * The dashboard will be loaded with a self signed certificate so just accept it when you see it pop up
        * The username is admin, the domain is admin_domain and the password you retrieved in the last step
    * To access the Openstack CLI
        * visit /home/ubuntu/openstack where you will type "source admin.rc" and you can use the Openstack CLI to operate the stack.

## Troubleshooting
* If terraform apply shows an error during launch just type terraform apply again and it should complete the build
* If anything looks odd or out of sorts just start over, don't spend too much time troubleshooting.  Most of the time it works every time :)
* If you ever reboot a controller host you will need to unseal the vault.  There is a utility in mom to help under the vault menu

JUJU is a powerful tool to aid in troubleshooting.  From the management VM you can directly access the console of any service container using an easy syntax.  juju ssh application/leader.  For example if one of the neutron-api nodes shows error or blocked or just needs some attention then you can type juju ssh nautron-api/0 or /1 or /2 or whatever unit you need to access and it will give you access to the terminal of the container.  Just type exit and you will be back in the management machine.  No need to keep an extensive list of IPs and keys, juju helps centralize it all.  Check out all the docs online for JUJU and JUJU charms.
