#variable "ibmcloud_api_key" {
#  type        = string
#  description = "IBM Cloud API key"
#}

variable "prefix" {
  type        = string
  default = "lab-2597"
  description = "The string that needs to be attached to every resource created"
}

variable "resource_group" {
  type        = string
  default     = "lab-2597"
  description = "Name of the resource group"
}

variable "region" {
  type        = string
  description = "IBM Cloud region to provision the resources."
  default     = "us-south"
}

variable "zone" {
  type        = string
  description = "IBM Cloud availability zone within a region to provision the resources."
  default     = "us-south-1"
}

variable "public_ssh_key" {
  type = string
  description = "public key"
}

###############################################################################
## PowerVS variables
###############################################################################

variable "powervs_supported_zone" {
  type        = string
  description = "IBM Cloud availability zone within a region to provision the resources."
  default     = "dal10"
}

variable "powervs_subnet_cidr" {
  type        = string
  description = "IP Address CIDR for PowerVS workspace"
}

variable "powervs_instance_cores" {
  type        = string
  description =  "number of physical cores (can be fractional to .25)"
  default = ".25"
}

variable "powervs_instance_memory" {
  type        = number
  description =  "amount of memory (GiB)"
  default = 2
}

variable "powervs_system_type" {
  type = string
  description = "Power System type: 922, 980, 1080. Check data centers for availability. Defaults to Power9 scale-out (922)"
  default = "s922"
}
