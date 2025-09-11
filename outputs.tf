output "vpn_server_url" {
    value = ibm_is_vpn_server.vpn_server.hostname
}

output "bastion_server_vsi_ip" {
    value = ibm_is_instance.bastion_server_vsi.primary_network_attachment[0].primary_ip
    #value = ibm_is_instance.bastion_server_vsi.primary_network_attachment[0].virtual_network_interface[0].
}

output "vpc_name" {
    value = ibm_is_vpc.edge_vpc.name
}

output "vpc_crn" {
    value = ibm_is_vpc.edge_vpc.crn
}

output "message" {
    value = <<EOM
    1. Connect with OpenVPN. Be sure to download the client profile template (locally).
    2. Obtain a one time only passcode: https://iam.cloud.ibm.com/identity/passcode
    3. Connect using the client VPN template with your IBM Cloud username and the passcode as the password
    4. On local terminal type the following to access the bastion server:
    ssh root@${ibm_is_instance.bastion_server_vsi.primary_network_attachment[0].primary_ip[0].address}
EOM
}
