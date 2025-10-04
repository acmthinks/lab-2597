/**
 * @author Andrea C. Crawford
 * @email acm@us.ibm.com
 * @create date 2023-12-22 15:33:00
 * @modify date 2023-04-24 08:02:08
 * @desc [description]
 */


###############################################################################
## Create a Resource Group
##
## Creates a resource group
###############################################################################
data "ibm_resource_group" "resource_group" {
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
  #pi_advertise         = "enable"
}


###############################################################################
## Create a PowerVS instance
##
## This creates a PowerVS instance (or a vm) using the ssh key and subnet above
###############################################################################
resource "ibm_pi_instance" "powervs_instance" {
    pi_memory             = var.powervs_instance_memory
    pi_processors         = var.powervs_instance_cores
    pi_instance_name      = join("-", [var.prefix, "power-vsi"])
    pi_proc_type          = "shared"
    pi_image_id           = "e37d8d58-05fc-4843-b5e9-bddab5af4f0d"
    pi_key_pair_name      = ibm_pi_key.power_vsi_ssh_key.pi_key_name
    pi_sys_type           = var.powervs_system_type
    pi_cloud_instance_id  = ibm_pi_workspace.powervs_workspace.id
    pi_pin_policy         = "none"
    pi_health_status      = "WARNING"
    pi_network {
      network_id = ibm_pi_network.workload-subnet[0].network_id
    }
}



###############################################################################
###############################################################################
##
##  PART 2
##
###############################################################################
###############################################################################

###############################################################################
## Create a VPC on IBM Cloud
## Availability Zones: 1 (no need for failover in Dev)
## Name: edge-vpc
## IP Address Range: 10.10.10.0/24 (256 IP addresses across all subnets)
###############################################################################
resource "ibm_is_vpc" "edge_vpc" {
  name = join("-", [var.prefix, "edge-vpc"])
  resource_group = data.ibm_resource_group.resource_group.id
  address_prefix_management = "manual"
  default_routing_table_name = join("-", [var.prefix, "edge-vpc", "rt", "default"])
  default_security_group_name = join("-", [var.prefix, "edge-vpc", "sg", "default"])
  default_network_acl_name = join("-", [var.prefix, "edge-vpc", "acl", "default"])
}

#set VPC Address prefix (all subnets in this vpc will derive from this range)
resource "ibm_is_vpc_address_prefix" "edge_prefix" {
  name = "edge-address-prefix"
  zone = var.zone
  vpc  = ibm_is_vpc.edge_vpc.id
  cidr = var.edge_vpc_address_prefix
}


###############################################################################
## Create Subnet #1: VPN Server Subnet
## Name: vpn-server-subnet
## CIDR: 10.10.10.0/25 (128 IP addresses in the VPN Server subnet)
## Language: Terraform
###############################################################################
resource "ibm_is_subnet" "vpn_server_subnet" {
  depends_on = [
    ibm_is_vpc_address_prefix.edge_prefix
  ]
  ipv4_cidr_block = var.edge_vpc_vpn_cidr
  name            = "vpn-server-subnet"
  vpc             = ibm_is_vpc.edge_vpc.id
  zone            = var.zone
  resource_group = data.ibm_resource_group.resource_group.id
}

###############################################################################
## Create Subnet #2: Bastion Subnet
## Name: bastion-server-subnet
## CIDR: 10.10.10.128/25 (128 IP addresses in the VPN Destination subnet)
###############################################################################
resource "ibm_is_subnet" "bastion_subnet" {
  depends_on = [
    ibm_is_vpc_address_prefix.edge_prefix
  ]
  ipv4_cidr_block = var.edge_vpc_bastion_cidr
  name            = "bastion-server-subnet"
  vpc             = ibm_is_vpc.edge_vpc.id
  zone            = var.zone
  resource_group = data.ibm_resource_group.resource_group.id
}

###############################################################################
## Create NACL for Subnet #1
## Name: vpn-server-subnet-acl
## Rules:
##  #   | Direction | Action    | Protocol  | Source        | Destination
##  1   | inbound   | Allow     | UDP       | 0.0.0.0/0 any | 10.50.0.0/25 443
##  2   | inbound   | Allow     | ALL       | 10.50.0.0/24  | 192.168.0.0/16
##  3   | inbound   | Deny      | ALL       | 0.0.0.0/0 any | 0.0.0.0/0 any
##
##  1   | outbound  | Allow     | UDP       | 10.50.0.0/25 443 | 0.0.0.0/0 any
##  2   | outbound  | Allow     | ALL       | 192.168.0.0/16 | 10.50.0.0/24
##  3   | outbound  | Deny      | ALL       | 0.0.0.0/0 any | 0.0.0.0/0 any
###############################################################################
resource "ibm_is_network_acl" "vpn_server_subnet_acl" {
  name = "vpn-server-subnet-acl"
  vpc  = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  rules {
    name        = "inbound-allow-same-subnet-ssh"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = var.edge_vpc_vpn_cidr
    direction   = "inbound"
    udp {
      port_max = 443
      port_min = 443
    }
  }
  rules {
    name        = "inbound-allow-vpc-to-public-all"
    action      = "allow"
    source      = var.edge_vpc_address_prefix
    destination = var.edge_vpc_public_cidr
    direction   = "inbound"
  }
    rules {
    name        = "inbound-deny-all"
    action      = "deny"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
  rules {
    name        = "oubbound-allow-same-subnet-ssh"
    action      = "allow"
    source      = var.edge_vpc_vpn_cidr
    destination = "0.0.0.0/0"
    direction   = "outbound"
    udp {
      source_port_max = 443
      source_port_min = 443
    }
  }
  rules {
    name        = "outbound-allow-public-to-vpc"
    action      = "allow"
    source      = var.edge_vpc_public_cidr
    destination = var.edge_vpc_address_prefix
    direction   = "outbound"
  }
  rules {
    name        = "outbound-deny-all"
    action      = "deny"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "outbound"
  }
}

###############################################################################
## Attach the NACL to the VPN Server subnet
###############################################################################
resource "ibm_is_subnet_network_acl_attachment" "vpn_server_subnet_acl_attachment" {
  subnet      = ibm_is_subnet.vpn_server_subnet.id
  network_acl = ibm_is_network_acl.vpn_server_subnet_acl.id
}


###############################################################################
## Create NACL for Subnet #2
## Name: bastion-server-subnet-acl
## Rules:
##  #   | Direction | Action    | Protocol  | Source        | Destination
##  1   | inbound   | Allow     | ALL       | 192.168.0.0/16| 10.50.0.128/25 Internet traffic through Client VPN Server
##  2   | inbound   | Allow     | ALL       | 10.50.0.0/25  | 10.50.0.128/25
##  (3) | inbound   | Allow     | ALL       | 10.60.0.128/25| 10.50.0.128/25 for connecting to another VPC or PowerVS workspace
##  (4) | inbound   | Allow     | ALL       | 161.26.0.0/16 | 0.0.0.0/0 IaaS service endpoints (RHN, NTP, DNS, et al)
##  (5) | inbound   | Allow     | TCP       | 166.9.0.0/16  | 10.50.0.128/25  VPE service endpoints (use for VPE gateways)
##  12  | inbound   | Deny      | ALL       | 0.0.0.0/0     | 10.50.0.128/25
##
##  1   | outbound  | Allow     | ALL       | 10.50.0.128/25 | 192.168.0.0/16 Internet traffic through Client VPN Server
##  2   | outbound  | Allow     | ALL       | 10.50.0.128/25 | 10.50.0.0/25
##  3   | outbound  | Allow     | TCP       | 10.50.0.128/25 443 | 0.0.0.0/0
##  (4) | outbound  | Allow     | ALL       | 10.50.0.128/25 | 10.60.0.128/25 for connecting to another VPC or PowerVS workspace
##  (5) | outbound  | Allow     | ALL       | 10.50.0.128/25 | 161.26.0.0/16 IaaS service endpoints (RHN, NTP, DNS, et al)
##  (6) | outbound  | Allow     | TCP       | 10.50.0.128/25 | 166.9.0.0/16 VPE service endpoints (use for VPE gateways)
##  12  | outbound  | Deny      | ALL       | 10.50.0.128/25     | 0.0.0.0/0
###############################################################################
resource "ibm_is_network_acl" "bastion_server_subnet_acl" {
  name = "bastion-server-subnet-acl"
  vpc  = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  rules {
    name        = "inbound-allow-vpn-traffic"
    action      = "allow"
    source      = var.edge_vpc_public_cidr
    destination = var.edge_vpc_bastion_cidr
    direction   = "inbound"
  }
  rules {
    name        = "inbound-allow-same-subnet-to-vpn"
    action      = "allow"
    source      = var.edge_vpc_vpn_cidr
    destination = var.edge_vpc_bastion_cidr
    direction   = "inbound"
  }
  # add rule to allow traffic from PowerVS workspace
  rules {
    name        = "inbound-allow-powervs-workspace"
    action      = "allow"
    source      = var.powervs_subnet_cidr
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
  rules {
    name        = "inbound-iaas-service-endpoints"
    action      = "allow"
    source      = var.iaas-service-endpoint-cidr
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
  rules {
    name        = "inbound-deny-all"
    action      = "deny"
    source      = "0.0.0.0/0"
    destination = var.edge_vpc_bastion_cidr
    direction   = "inbound"
  }
  rules {
    name        = "oubbound-allow-all-vpn-traffic"
    action      = "allow"
    source      = var.edge_vpc_bastion_cidr
    destination = var.edge_vpc_public_cidr
    direction   = "outbound"
  }
  rules {
    name        = "outbound-allow-bastion-to-vpn"
    action      = "allow"
    source      = var.edge_vpc_bastion_cidr
    destination = var.edge_vpc_vpn_cidr
    direction   = "outbound"
  }
  rules {
    name        = "outbound-allow-bastion-to-any"
    action      = "allow"
    source      = var.edge_vpc_bastion_cidr
    destination = "0.0.0.0/0"
    direction   = "outbound"
      tcp {
        source_port_min = 443
        source_port_max = 443
      }
  }
  # add rule to allow traffic from PowerVS workspace
  rules {
    name        = "outbound-allow-powervs-workspace"
    action      = "allow"
    source      = var.edge_vpc_bastion_cidr
    destination =  var.powervs_subnet_cidr
    direction   = "outbound"
  }
  rules {
    name        = "outbound-allow-iaas-service-endpoints"
    action      = "allow"
    source      = var.edge_vpc_bastion_cidr
    destination = var.iaas-service-endpoint-cidr
    direction   = "outbound"
  }
  rules {
    name        = "outbound-deny-all"
    action      = "deny"
    source      = var.edge_vpc_bastion_cidr
    destination = "0.0.0.0/0"
    direction   = "outbound"
  }
}



###############################################################################
## Attach the NACL to the Bastion Server subnet
###############################################################################
resource "ibm_is_subnet_network_acl_attachment" "bastion_server_subnet_acl_attachment" {
  subnet      = ibm_is_subnet.bastion_subnet.id
  network_acl = ibm_is_network_acl.bastion_server_subnet_acl.id
}

###############################################################################
## Create Security Group for VPN Server
## Name: vpn-server-sg
## Rules:
##  Direction | Protocol  | Source Type | Source        | Destination
##  inbound   | UDP       | Any         | 0.0.0.0/0     | 0.0.0.0/0 443
##  inbound   | ALL       | CIDR block  | 10.50.0.0/24  | 0.0.0.0/0
##
##  Direction | Protocol  | Source Type | Source        | Destination
##  egress    | UDP       | Any         | 0.0.0.0/0     | 0.0.0.0/0 443
##  egress    | ALL       | CIDR block  | 0.0.0.0/0     | 10.50.0.0/24
###############################################################################
resource "ibm_is_security_group" "vpn_server_sg" {
  name = "vpn-server-sg"
  vpc = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_security_group_rule" "vpn_server_rule_1" {
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "inbound"
  remote = "0.0.0.0/0"
  udp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "vpn_server_rule_2" {
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_address_prefix
}

resource "ibm_is_security_group_rule" "vpn_server_rule_3" {
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "outbound"
  remote = "0.0.0.0/0"
  udp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "vpn_server_rule_4" {
  group = ibm_is_security_group.vpn_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_address_prefix
}


###############################################################################
## Create Security Group for Bastion Server
## Name: bastion-sg
## Rules:
##  Direction | Protocol  | Source          | Destination
##  inbound   | ALL       | 192.168.0.0/16  | 0.0.0.0/0
##  inbound   | TCP       | 10.50.0.0/24    | 0.0.0.0/0 [Ports 22-22]
##  inbound   | ICMP      | 10.10.10.0/24   | 0.0.0.0/0 [Type:8, Code:Any]
##  inbound   | ALL       | 10.50.0.0/25    | 0.0.0.0/0
##  inbound   | ALL       | 161.26.0.0/16    | 0.0.0.0/0
##  (inbound) | ALL       | 10.60.0.128/25  | 0.0.0.0/0 for connecting to another VPC or PowerVS workspace

##
##  Direction | Protocol  | Source          | Destination
##  egress    | ALL       | 0.0.0.0/0       | 192.168.0.0/16
##  egress    | TCP       | 0.0.0.0/0       | 10.50.0.0/24   [Ports 22-22]
##  egress    | ICMP      | 0.0.0.0/0       | 10.50.0.0/24 [Type:8, Code:Any]
##  egress    | ALL       | 0.0.0.0/0       | 10.50.0.0/25
##  egress    | ALL       | 0.0.0.0/0       | 161.26.0.0/16
##  (egress)  | ALL       | 0.0.0.0/0       | 10.60.0.128/25  for connecting to another VPC or PowerVS workspace
###############################################################################
resource "ibm_is_security_group" "bastion_server_sg" {
  name = "bastion-server-sg"
  vpc = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_security_group_rule" "bastion_server_rule_1" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_vpn_cidr
}

resource "ibm_is_security_group_rule" "bastion_server_rule_2" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_address_prefix
  icmp {
    type = 8
  }
}

resource "ibm_is_security_group_rule" "bastion_server_rule_3" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_address_prefix
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "bastion_server_rule_4" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.edge_vpc_public_cidr
}

resource "ibm_is_security_group_rule" "bastion_server_rule_inbound_iaas_endpoints" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.iaas-service-endpoint-cidr
}
# add security group ingress for PowerVS traffic
resource "ibm_is_security_group_rule" "bastion_server_rule_inbound_powervs" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "inbound"
  remote = var.powervs_subnet_cidr
}

resource "ibm_is_security_group_rule" "bastion_server_rule_5" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_vpn_cidr
}

resource "ibm_is_security_group_rule" "bastion_server_rule_6" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_address_prefix
  icmp {
    type = 8
  }
}

resource "ibm_is_security_group_rule" "bastion_server_rule_7" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_address_prefix
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "bastion_server_rule_8" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.edge_vpc_public_cidr
}

resource "ibm_is_security_group_rule" "bastion_server_rule_outbound_iaas_endpoints" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.iaas-service-endpoint-cidr
}
# add security group egress rule to allow trafific outbound to powervs
resource "ibm_is_security_group_rule" "bastion_server_rule_outbound_powervs" {
  group = ibm_is_security_group.bastion_server_sg.id
  direction = "outbound"
  remote = var.powervs_subnet_cidr
}

## Secrets Manager instance
resource "ibm_resource_instance" "secrets_manager" {
  name = "${var.prefix}-secrets-manager"
  service = "secrets-manager"
  plan = "standard"
  location = "us-south"
  resource_group_id = data.ibm_resource_group.resource_group.id

  parameters = {
    "allowed_network" = "public-and-private"
  }
}

resource "ibm_sm_secret_group" "vpn_server_secret_group" {
  instance_id = ibm_resource_instance.secrets_manager.guid
  region        = "us-south"
  name          = "vpn-server-secret-group"
  description = "VPN and CA certificates"
}

# Get vpn server cert (stored in Secrets Manager)
resource "ibm_sm_imported_certificate" "imported_vpn_certificate" {
  instance_id   = ibm_resource_instance.secrets_manager.guid
  region        = var.region
  name          = "vpn-server-certificate"
  secret_group_id = ibm_sm_secret_group.vpn_server_secret_group.secret_group_id
  certificate = file("${var.vpn_certificate_file}")
  intermediate = file("${var.ca_certificate_file}")
  private_key = "${var.vpn_private_key}"
}

resource "ibm_sm_secret_group" "ssh_keys_secret_group" {
  instance_id   = ibm_resource_instance.secrets_manager.guid
  region        = var.region
  name          = "ssh-keys-secret-group"
  description = "ssh keys"
}

## get public ssh key (stored in Secrets Manager)
resource "ibm_sm_arbitrary_secret" "ssh_key_secret" {
  instance_id   = ibm_resource_instance.secrets_manager.guid
  region        = var.region
  name          = join("-", [var.prefix, "ssh-key"])
  secret_group_id = ibm_sm_secret_group.ssh_keys_secret_group.secret_group_id
  payload       = "${var.public_ssh_key}"
}

#create VSI

#service authorization to allow Client VPN service connect to Secrets Manager
resource "ibm_iam_authorization_policy" "client_vpn_to_secrets_manager_auth" {
  source_service_name = "is"
  source_resource_type = "vpn-server"

  target_service_name = "secrets-manager"
  target_resource_instance_id = ibm_resource_instance.secrets_manager.guid
  roles               = ["SecretsReader"]
  description         = "Client VPN to Secrets Manager service authorization policy"
}

resource "ibm_is_vpn_server" "vpn_server" {
  certificate_crn = ibm_sm_imported_certificate.imported_vpn_certificate.crn
  client_authentication {
    method    = "username"
    identity_provider = "iam"
  }
  client_ip_pool         = var.edge_vpc_public_cidr
  client_idle_timeout    = 600
  enable_split_tunneling = true
  name                   = join("-", [var.prefix, "vpn-server"])
  port                   = 443
  protocol               = "udp"
  subnets                = [ibm_is_subnet.vpn_server_subnet.id]
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.vpn_server_sg.id]
}

## VPN Server route -- deliver all traffic to Bastion vsi
resource "ibm_is_vpn_server_route" "vpn_server_route" {
  vpn_server    = ibm_is_vpn_server.vpn_server.vpn_server
  destination   = var.edge_vpc_bastion_cidr
  action        = "deliver"
  name          = "deliver-bastion-host"
  depends_on = [ibm_iam_authorization_policy.client_vpn_to_secrets_manager_auth]
}


### Create Bastion
resource "ibm_is_ssh_key" "bastion_ssh_key" {
  name       = "andrea-ssh-public-key"
  public_key = "${var.public_ssh_key}"
  type = "rsa"
  resource_group = data.ibm_resource_group.resource_group.id
}

# get catalog image
data "ibm_is_image" "centos" {
  name = "ibm-centos-stream-9-amd64-11"
}

data "ibm_is_image" "debian" {
  name = "ibm-debian-13-minimal-amd64-1"
}

resource "ibm_is_virtual_network_interface" "bastion_server_vni" {
  name = "bastion-server-vni"
  resource_group = data.ibm_resource_group.resource_group.id
  allow_ip_spoofing = false
  enable_infrastructure_nat = true
  auto_delete = false
  subnet = ibm_is_subnet.bastion_subnet.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

resource "ibm_is_instance" "bastion_server_vsi" {
  name    = "bastion-server-vsi"
  image   = data.ibm_is_image.debian.id
  profile = "bx2-2x8"

  boot_volume {
    name = "bastion-server-boot"
    auto_delete_volume = true
  }

  primary_network_attachment {
    name = "eth0"
    virtual_network_interface {
      id = ibm_is_virtual_network_interface.bastion_server_vni.id
    }
  }

  vpc  = ibm_is_vpc.edge_vpc.id
  zone = var.zone
  resource_group = data.ibm_resource_group.resource_group.id
  keys = [ibm_is_ssh_key.bastion_ssh_key.id]
}

###############################################################################
## Create a Transit Gateway
##
## This creates a TGW to connect VPC to PowerVS workspace
###############################################################################
resource "ibm_tg_gateway" "vpc_powervs_tg_gw"{
  name = "transit-gateway"
  location = var.region
  global = false
  resource_group = data.ibm_resource_group.resource_group.id
}

#create Transit Gateway connections to the VPC and to the PowerVS workspace
resource "ibm_tg_connection" "vpc_connection" {
  gateway = ibm_tg_gateway.vpc_powervs_tg_gw.id
  network_type = "vpc"
  name = "vpc-connection"
  network_id = ibm_is_vpc.edge_vpc.resource_crn
}

resource "ibm_tg_connection" "powervs_connection" {
  gateway = ibm_tg_gateway.vpc_powervs_tg_gw.id
  network_type = "power_virtual_server"
  name = "powervs-connection"
  network_id = ibm_pi_workspace.powervs_workspace.crn
}


###############################################################################
###############################################################################
##
##  PART 3
##
###############################################################################
###############################################################################

###############################################################################
## Create Cloud Object Storage (and bucket)
##
###############################################################################
resource "ibm_resource_instance" "cos" {
  name              = "cos"
  resource_group_id = data.ibm_resource_group.resource_group.id
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

resource "ibm_cos_bucket" "cos_bucket" {
  bucket_name          = join("-", ["lil-bucket",var.student_id])
  resource_instance_id = ibm_resource_instance.cos.id
  region_location = var.region
  storage_class        = "smart"
}

resource "ibm_cos_bucket_object" "plaintext" {
  bucket_crn      = ibm_cos_bucket.cos_bucket.crn
  bucket_location = ibm_cos_bucket.cos_bucket.region_location
  content         = "IBM is a hybrid cloud and AI company."
  key             = "plaintext.txt"
}

###############################################################################
## Create Security Group for Cloud Object Storage
## Name: cos-sg
## Rules:
##  Direction | Protocol  | Source          | Destination
##  inbound   | ALL       | 10.60.0.128/25  | 0.0.0.0/0 for connecting to another VPC or PowerVS workspace
##
##  Direction | Protocol  | Source          | Destination
##  egress    | ALL       | 0.0.0.0/0       | 10.60.0.128/25  for connecting to another VPC or PowerVS workspace
###############################################################################
resource "ibm_is_security_group" "cos_sg" {
  name = "cos-sg"
  vpc = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "ibm_is_security_group_rule" "cos_ingress_powervs_allow" {
  group = ibm_is_security_group.cos_sg.id
  direction = "inbound"
  remote = var.powervs_subnet_cidr
}

resource "ibm_is_security_group_rule" "cos_egress_powervs_allow" {
  group = ibm_is_security_group.cos_sg.id
  direction = "outbound"
  remote = var.powervs_subnet_cidr
}

###############################################################################
## Create a Virtual Private Endpoint Gateways
##
## https://cloud.ibm.com/docs/cli?topic=cli-service-connection#cli-private-vpc
##
## This creates a VPE GW to connect VPC to COS
## https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-vpes
###############################################################################

resource "ibm_is_virtual_endpoint_gateway" "vpe_cos" {
  depends_on = [ ibm_resource_instance.cos ]
  name = "cos-vpe"
  target {
    crn           = "crn:v1:bluemix:public:cloud-object-storage:global:::endpoint:s3.direct.${var.region}.cloud-object-storage.appdomain.cloud"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "cos-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.cos_sg.id,ibm_is_security_group.bastion_server_sg.id]
}

#Account Management: Endpoint URL (https://private.accounts.cloud.ibm.com)
resource "ibm_is_virtual_endpoint_gateway" "vpe_account_management" {
  name = "account-managememt-vpe"
  target {
    crn           = "crn:v1:bluemix:public:account-management:global:::endpoint:private.accounts.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "account-managememt-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Identity and Access Management: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_iam" {
  name = "iam-vpe"
  target {
    crn           = "crn:v1:bluemix:public:iam-svcs:global:::endpoint:private.iam.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "iam-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Global Catalog: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_global_catalog" {
  name = "global-catalog-vpe"
  target {
    crn           = "crn:v1:bluemix:public:globalcatalog:global:::endpoint:private.globalcatalog.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "global-catalog-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Global Search: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_global_search" {
  name = "global-search-vpe"
  target {
    crn           = "crn:v1:bluemix:public:global-search-tagging:global:::endpoint:api.private.global-search-tagging.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "global-search-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Global Tagging: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_tagging" {
  name = "tagging-vpe"
  target {
    crn           = "crn:v1:bluemix:public:ghost-tags:global:::endpoint:tags.private.global-search-tagging.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "tagging-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Usage Metering/Billing: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_billing" {
  name = "billing-vpe"
  target {
    crn           = "crn:v1:bluemix:public:billing:global:::endpoint:private.billing.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "billing-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}

#Enterprise Management: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_enterprise_mgmt" {
  name = "enterprise-management-vpe"
  target {
    crn           = "crn:v1:bluemix:public:enterprise:global:::endpoint:private.enterprise.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "enterprise-mgmt-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}
#Resource Controller: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_resource_controller" {
  name = "resource-controller-vpe"
  target {
    crn           = "crn:v1:bluemix:public:resource-controller:global:::endpoint:private.resource-controller.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "resource-controller-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}
#User Management: Endpoint URL
resource "ibm_is_virtual_endpoint_gateway" "vpe_user_mgmt" {
  name = "user-management-vpe"
  target {
    crn           = "crn:v1:bluemix:public:user-management:global:::endpoint:private.user-management.cloud.ibm.com"
    resource_type = "provider_cloud_service"
  }
  ips {
    subnet        = ibm_is_subnet.bastion_subnet.id
    name          = "user-management-vpe-ip"
  }
  vpc            = ibm_is_vpc.edge_vpc.id
  resource_group = data.ibm_resource_group.resource_group.id
  security_groups = [ibm_is_security_group.bastion_server_sg.id]
}
