output "powervs_details" {
    value = <<EOM
###############################################################################
###############################################################################
##
##  PART 1
##
###############################################################################
###############################################################################

    PowerVS instance details:
      IP address: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}
      CPU: ${ibm_pi_instance.powervs_instance.pi_processors}
      Memory: ${ibm_pi_instance.powervs_instance.pi_memory}
      PowerVS Workspace: ${ibm_pi_workspace.powervs_workspace.pi_name}
      Location: ${ibm_pi_workspace.powervs_workspace.pi_datacenter}
      URL: https://cloud.ibm.com/power/servers
    EOM
}
