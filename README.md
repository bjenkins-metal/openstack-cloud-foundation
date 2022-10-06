# Openstack Cloud Foundation
Deploy a self-managed, highly available private cloud on Equinix Metal

## Summary
If you are looking for something new to WARE then you have come to the right place!  The Equinix Metal Openstack Cloud Foundation project is an open and freely available reference deployment system for Openstack on Metal.  Openstack has traditionally been complex to design and deploy due to the very open nature of the projects that make up the Openstack ecosystem.  Without an opinionated deployment system like Metal and JUJU, it can be difficult to evaluate and use Openstack for the first time or deploy at scale. Using the power of Equinix Fabric and interconnection services makes it possible to design and deploy a truly private, self-service cloud to your users.

## What the OCF project does
* ### Deploy and configure all the hardware needed for the stack
    * Create edge router 
        * VPN access to manage the project
        * Allow one to one NAT to expose APIs if needed
        * Handle DHCP, NAT, VPN, NTP and DNS forwarding
    * Create management VM with tools needed for Opentstack management
    * Create JUJU controller for logsink and control plane
    * Create controller nodes
        * Configure the NVMe drives for mirrored ZFS pools
        * Create the bridge configurations for LXD services
    * Create dedicated database hosts
        * (Full deployment only)
        * Configure the NVMe drives for mirrored ZFS pools
        * Create the bridge configurations for LXD services
    * Create Ceph storage pool
        * Highly available
        * Highly redundant data
        * about 65TB of usable space
        * Expand horizontally, just add more nodes
    * Create highly available OVN edge
        * (full deployment only)
        * Simplify public IP management
        * Connect to a remote private network
        * Scale the compute infrastructure easily
        * No layer 2 sprawl for provider networks
    * Create compute nodes
        * Scale horizontally by adding more nodes
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

* ## What the OCF project does not do
    * Does not manage all aspects of the stack
    * Does not Harden the stack against security threats
    * Does not deliver a production ready environment

---

### OCF should be treated as a reference deployment to get you started down the path of Openstack. The key takeaway is the freedom that will allow you to customize the platform to your own needs.  Openstack is well documented, well understood and is an ever evolving set of projects.  Almost everything in this project is modular from the routing edge to the modules that make up Openstack.  You can bolt on new features like Magnum for containers or Designate for DNS using JUJU charms or dig deep and create your own charms to extend Openstack. Even the edge can be replaced by using an existing gateway in colocation, Equinix Network Edge or another NFV.
---
### This project is EXPERIMENTAL and is not suitable for any use outside of learning JUJU and Openstack.  There is no support for the project and you will need to be patient with the process if you have not tried Openstack before.  This project can change rapidly and the reference design may shift over time. The components of this project can help with understanding JUJU and Openstack while giving you a good foundation to create your own stack. Have fun, good luck!
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
    * You know how to manage Linux
    * You know how to use Terraform
    * You know how to SSH with keys and passwords
    * You understand how to setup a VPN (L2TP specifically) on your OS
    * You know how to launch a VM in general on any platform, that skill translates
    * You are somewhat familiar with Equinix Metal and have an account

# Lets get started!
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
    * SSH to the edge host and type "./start" then hit enter
    * You will be presented with the Edge Manager.  Click on Launch edge
        * Enter your Mikrotik.com username
        * Enter your Mikrotik.com password (this is to auto register the edge into your account)
        * Choose a password for the edge router
        * Choose a username for the VPN
        * Choose a password for the VPN user
        * Choose a shared secret for the L2TP setup
        * SAVE ALL THIS INFO FOR LATER!
5. Once the edge is launched you will be presented with the IP that you will use as the VPN target, save that IP
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
    * at the shell type "watch -c juju status --color" and hit enter
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

That is it, you can now go to the management machine and visit /home/ubuntu/openstack where you will type "source admin.rc". Now you can use the Openstack CLI to operate the stack.  You can also go back to mom and click bootstrap and then click show admin info where you can see the randomly generated admin password.  It will tell you the location of the Openstack Dashboard and your admin info.  If nothing was altered in terraform.tfvars then the dashboard should be located at https://172.22.2.10. The dashboard will be loaded with a self signed certificate so just accept it when you see it pop up.  The username is admin, the domain is admin_domain and the password you retrieved in the last step.

## Troubleshooting
* If juju status never shows the nova cloud controller is ready you can use mom to restart the nova cloud controllers
* If after terraform apply you get any errors during launch just type terraform apply again and it should complete the build
* If anything looks odd or out of sorts just start over, don't spend too much time troubleshooting.  Most of the time it works every time :)
* If you must or accidentally reboot a controller host you will need to unseal the vault.  There is a utility in mom to help under the vault menu

JUJU is a powerful tool to aid in troubleshooting.  From the management VM you can get to any of the service containers using an easy syntax.  juju ssh application/#.  For example if one of the neutron-api nodes shows error or blocked or just needs some attention then you can type juju ssh nautron-api/0 or /1 or /2 or whatever unit you need to access and it will drop you into the container.  Just type exit and you will be back in the management machine.  No need to keep an extensive list of IPs and keys, juju helps centralize it all.  Check out all the docs online for JUJU and JUJU charms.  The Xena release of Openstack is the default for this project so make sure when researching Openstack that you stick to the Xena documentation.
