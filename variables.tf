###############################################################################
## General variables
###############################################################################
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
## PowerVS variables (Part 1)
###############################################################################
variable "powervs_supported_zone" {
  type        = string
  description = "IBM Cloud availability zone within a region to provision the resources."
  default     = "dal10"
}

variable "powervs_subnet_cidr" {
  type        = string
  description = "IP Address CIDR for PowerVS workspace"
  default = "10.80.0.0/24"
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


###############################################################################
## VPC variables  (Part 2)
###############################################################################
variable "edge_vpc_address_prefix" {
  type        = string
  description = "IP Address prefix (CIDR)"
  default     = "10.50.0.0/24"
}

variable "edge_vpc_vpn_cidr" {
  type        = string
  description = "IP Address CIDR for the vpn"
  default     = "10.50.0.0/25"
}

variable "edge_vpc_bastion_cidr" {
  type        = string
  description = "IP Address CIDR for bastion or jump host"
  default     = "10.50.0.128/25"
}

variable "edge_vpc_public_cidr" {
  type = string
  description = "IP Address CIDR for public VPN traffic"
  default = "192.168.0.0/16"
}

variable "vpn_certificate_file" {
  type = string
  description = "VPN certificate file (i.e. vpnserver.pem)"
  default = "certs/lab-2597.vpn-server.ibm.com.pem"
}

variable "vpn_private_key" {
  type = string
  description = "contents of private key (i.e. lab-2596.vpn-server.ibm.com.key)"
  sensitive = true
}

variable "ca_certificate_file" {
  type = string
  description = "Intermediate CA certificate file name (ca.pem)"
  default = "certs/ca.pem"
}

## Reserved Endpoints
#Must also leave open: port 53/UDP/DNS, port 80/TCP/HTTP, port 443/TCP/HTTPS, port 8443/TCP/HTTPS (for linux) for IaaS service endpoints to work
#more info at https://cloud.ibm.com/docs/vpc?topic=vpc-service-endpoints-for-vpc
variable "iaas-service-endpoint-cidr" {
  type = string
  description = "Infrastructure services are available by using certain DNS names from the adn.networklayer.com domain, and they resolve to 161.26.0.0/16 addresses. Services that you can reach include: DNS resolvers, Ubuntu and Debian APT mirrors, NTP, IBM COS."
  default = "161.26.0.0/16"
}
