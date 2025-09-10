# Part 2: Add a “jump” server to the PowerVS environment

Terraform is a declarative framework for provisioning. In this part, you will simulate a change in the Terraform that reflects additional IBM Cloud resources being added to the cloud account. Because of it’s declarative nature, Terraform is aware of the resources that currently exist and any changes (including updates, deletions and additions) to the code. Existing resources that are unchanged (i.e. the PowerVS AIX machine) will remain unchanged, while Terraform will add new resources.

1. Update and run the Schematics Workspace
2. Run Schematics workspace
3. Examine the Schematics Workspace
4. Validate the provisioned environment
