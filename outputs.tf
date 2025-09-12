output "powervs_details" {
    value = <<EOM
    PowerVS instance details:
      IP address: ${ibm_pi_instance.powervs_instance.pi_network[0].ip_address}
      vCPU: ${ibm_pi_instance.powervs_instance.min_virtual_cores}
      Memory: ${ibm_pi_instance.powervs_instance.min_memory}
      PowerVS Workspace: ${ibm_pi_workspace.powervs_workspace.pi_name}
      Location: ${ibm_pi_workspace.powervs_workspace.pi_datacenter}
    EOM
}
