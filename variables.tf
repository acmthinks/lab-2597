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
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9WtH8MgfX434Pxt8jBDR8ILUWLeyIR8ajSuZdr7wVq4vpj7sal6M1Bri8n/jCBIO3LsllkjuRzf0X3xAH6S5BNpoalaH5yjZMXV8ieonslhpqcKzj2+vWcteuKIGgGOGit3qrdEwXQNJRk5w8TxEVIBs7YfzomoaYBMzx+10pFZ6VvbP8B+Vf+Xld4wGFKDST+ou5M4cHn93p2Jk4Gz4djumsJMPp9cIsC2aub8h8KC4/pgG/guQI99aUPqrA/pmoCERZx80BoN0TNBO7VE5XNE+QTQ80JMPC4qucGffGgK8Q/6oGWyho5w9Ujxky0SF6dnZUhcCACFeItpQJiebqhCdb75y0KaL7tkIBn/aaHyeLf2PpOu7aHchvi78azdNcGmIolH2JnXAnZ4mWeuX1CGtsDqJGkbHGEvADno/u1zyM2ZuUCnSzMzlkwWoSvtgPbkD9YxxzsE4/1yVz7w+QGUxbet5CQN4rGYS3yEavyF0o2qdkBTTXYpE450I+Xos="
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
  default = "10.60.0.0/24"
}

variable "powervs_instance_cores" {
  type        = string
  description =  "number of physical cores (can be fractional to .25)"
  default = ".5"
}

variable "powervs_instance_memory" {
  type        = number
  description =  "amount of memory (GiB)"
  default = 4
}

variable "powervs_system_type" {
  type = string
  description = "Power System type: 922, 980, 1080. Check data centers for availability. Defaults to Power9 scale-out (922)"
  default = "s922"
}
