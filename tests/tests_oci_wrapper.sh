#!/bin/bash
export OCI_CLI_PROFILE=gc3

# discover tenancy
rm -rf ~/.oci/objects/tenancy
discover_tenancy

# discover single compartment
get_compartment_id /
get_compartment_id /GC3IsolatedLabs
get_compartment_id /GC3IsolatedLabs/ECCC
get_compartment_id /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI

# discover compartment with auto tenency discovery
rm -rf ~/.oci/objects/tenancy
get_compartment_id /GC3IsolatedLabs

# working compartment
set_working_compartment /
get_compartment_id .

oc iam compartment set /GC3IsolatedLabs/ECCC
get_compartment_id .

# discover all compartment
discover_compartments / 10
discover_compartments /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI

discover_compartments / 10 0
# shellcheck disable=SC2154
tree "$tenancy_home/iam/compartment"
find "$tenancy_home/iam/compartment" -type d | sed "s|^$tenancy_home/iam/compartment||g"

# bastion
get_bastion_id /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI/Bastion202405271103
get_bastion_id /Bastion202405271103

# locate compartment by ocid
get_compartment_path ocid1.compartment.oc1..aaaaaaaactqfav25mrxxun27vgca5skxndcpbinco7wbwr25q5ltznkoghpa

# oci wrapper
oci iam compartment set /GC3IsolatedLabs/ECCC
get_compartment_id .

oci iam compartment get --compartment-id /GC3IsolatedLabs/ECCC
oci compute instance list --compartment-id /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI

oci iam compartment set /GC3IsolatedLabs
oci iam compartment get --compartment-id .
oci compute instance list --compartment-id ./ECCC/RYSZARD_STYCZYNSKI  | jq -r '.data[]' | jq -r  '[."display-name", .id] | @tsv' 

oci iam compartment set /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI
oci compute instance list --compartment-id . | jq -r '.data[]' | jq -r  '[."display-name", .id] | @tsv' 

# oci autocomplete
# it's interactive - press SPACE/TAB/ENTER where requested
oci TAB ENTER
oci os TAB TAB ENTER
oci os n TAB TAB TAB ENTER
oci os ns ge TAB ENTER

oci TAB
oci comp TAB
oci compute instance SPACE TAB TAB ENTER
oci compute instance list SPACE TAB ENTER
oci compute instance list --compartment-id / TAB TAB ENTER
oci compute instance list --compartment-id /GC3IsolatedLabs TAB TAB ENTER
oci compute instance list --compartment-id /GC3IsolatedLabs/ECCC TAB TAB ENTER
oci compute instance list --compartment-id /GC3IsolatedLabs/ECCC/RY TAB ENTER
oci compute instance list --compartment-id /GC3IsolatedLabs/ECCC/RYSZARD_STYCZYNSKI ENTER

