output "message" {
    value = <<EOM
###############################################################################
###############################################################################
##
##  PART 2
##
###############################################################################
###############################################################################

    Bastion (jump server) virtual server instance details:
      IP address: ${ibm_is_instance.bastion_server_vsi.primary_network_attachment[0].primary_ip}
      vCPU: ${ibm_is_instance.bastion_server_vsi.vcpu}
      Memory: ${ibm_is_instance.bastion_server_vsi.memory}
      Virtual Private Cloud: ${ibm_is_instance.bastion_server_vsi.vcpu}
      Location: ${var.region}
      Zone: ${ibm_is_instance.bastion_server_vsi.zone}
      URL: https://cloud.ibm.com/power/servers

    A client VPN server has been provisioned. Here is how to connect to the bastion (jump server).
        1. Go to this link https://cloud.ibm.com/infrastructure/network/vpnServers and click on the VPN server name.
        2. From the "clients" tab, download the Client Profile Template (.ovpn file) from the VPN Server to your local machine.
        3. Double click on the .ovpn file. Connect with OpenVPN client.
        4. Use the IBM Cloud id as the 'username".
        5. For the password, obtain a one time only passcode: https://iam.cloud.ibm.com/identity/passcode (and copy/paste in the vpn client)
        6. Use the ssh private key provided (id_lab2597.txt, it is only available to lab participants in TechZone and not in git)
        7. Be sure the private key file is at the proper permisison level (chmod 600 id_lab2597)
        8. On local terminal type the following to access the bastion (jump server):
            ssh -i /path/id_lab2597 root@${ibm_is_instance.bastion_server_vsi.primary_network_attachment[0].primary_ip}

    EOM
}
