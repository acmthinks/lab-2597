/**
 * @author Andrea C. Crawford
 * @email acm@us.ibm.com
 * @create date 2023-12-22 15:33:00
 * @modify date 2023-04-24 08:02:08
 * @desc Terraform to provision a PowerVS workspace and a single instance
 */


###############################################################################
## Create a Resource Group
##
## Creates a resource group
###############################################################################
resource "ibm_resource_group" "resource_group" {
   name   = var.resource_group
}


###############################################################################
###############################################################################
##
##  PART 1
##
###############################################################################
###############################################################################


###############################################################################
## Create a Power VS Workspace
###############################################################################
resource ibm_pi_workspace "powervs_workspace" {
  pi_name          = join("-", [var.prefix, "power-workspace"])

  pi_datacenter    = var.region
  pi_resource_group_id  = data.ibm_resource_group.resource_group.id
}

# Create SSH Key object in PowerVS workspace, based on the ssh public key
# payload from Secrets Manager
resource "ibm_pi_key" "power_vsi_ssh_key" {
  pi_key_name       = join("-", [var.prefix, "ssh-key"])
  pi_ssh_key = var.public_ssh_key
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
  pi_visibility = "workspace"
}

###############################################################################
## Create a subnet in the PowerVS workspace
##
## This creates a PRIVATE vlan (or subnet) in the PowerVS workspace
###############################################################################
resource "ibm_pi_network" "workload-subnet" {
  count                = 1
  pi_network_name      = "workload-subnet"
  pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
  pi_network_type      = "vlan"
  pi_cidr              = var.powervs_subnet_cidr
  #pi_advertise = "enable"
}


###############################################################################
## Create a PowerVS instance
##
## This creates a PowerVS instance (or a vm) using the ssh key and subnet above
###############################################################################
resource "ibm_pi_instance" "powervs-instance" {
    pi_memory             = var.powervs_instance_memory
    pi_processors         = var.powervs_instance_cores
    pi_instance_name      = join("-", [var.prefix, "power-vsi"])
    pi_proc_type          = "shared"
    #pi_image_id           = data.ibm_pi_image.aix72_5_10_image.id
    pi_image_id = "52f2891b-6e4b-4765-bc0e-43cdc036305a"
    pi_key_pair_name      = ibm_pi_key.power_vsi_ssh_key.pi_key_name
    pi_sys_type           = var.powervs_system_type
    pi_cloud_instance_id  = ibm_pi_workspace.powervs_workspace.id
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_network {
      network_id = ibm_pi_network.workload-subnet[0].network_id
    }
}

#data "ibm_pi_image" "aix72_5_10_image" {
#    pi_image_name = "52f2891b-6e4b-4765-bc0e-43cdc036305a"
#    #pi_image_name = "7200-05-10"
#    pi_cloud_instance_id = ibm_pi_workspace.powervs_workspace.id
#}
