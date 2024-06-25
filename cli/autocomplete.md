# OCI CLI autocomplete

Oracle ships OCI CLI with fabulous interactive mode. It's really great interface, but may be little disappointing for Linux users, as in the history of execution you'l always find just "oci -i", instead of actual command that you recently executed. It's little unknown how to proceed in case of executing

```
oci compute instance list --compartment-id  
```

as the autocomplete will not help in ocid lookup.

## o
Great extension for OCI CLI comes with o command, which adds very interesting features extending OCI CLI to a powerful swiss-army-knife class tool with output formatting and ocid handling. o command comes with a great tool to deal with ocid by using resource names. It's a killer feature, as you do not need to copy/paste long identifiers anymore. o is impressive and but still does not support auto complete. 

o has a power to influence user showing by example how to be creative around OCI SDK. 

## OCI resource path
OCI resource model is strictly related to compartments. This great virtualization of server rooms' access control adds breaking trough flexibility for resource distribution in the OCI tenancy, for the price of dealing with long and boring OCI identifiers - ocids. 

During my tool developments I discovered that it's an interesting idea to apply URI concept to address OCI resources. Each resource must exist in one and only one compartment, so URI may be applied; to make it simpler I'll decide to use regular Linux directory path.

Here is example of bastion service located in meet-me-room compartment under prod compartment. 

```
/prod/meet-me-room/bastion
```

Now the only trick is to provide tool to convert path style into ocid.

## Simple auto-complete

Let' play with simple OCI CLI autocomplete. Load the source code and source it. It's assumed you are using bash. I do not know how and if this autocomplete works with other shells.

```bash
mkdir -p ~/.oci/bin
wget https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/bin/oci_wrapper.sh -q -O - > ~/.oci/bin/oci_wrapper.sh
source ~/.oci/bin/oci_wrapper.sh
```

Now you can play with oci and TAB button. Enter below command 

```
oci os ns g
```

.. and press TAB.

```
oci os ns get
```

Now try with something more complex.

```
oci comp
```

... press TAB

```
oci compute inst
```

... press TAB

```
oci compute instance list
```

... press TAB

```
oci compute instance list --compartment-id
```

You reached the limit of foundation level auto complete. When you'll press TAB in this context you will be notified that:

```
Error. Compartment cache not ready. Discover compartments first.
```

## Compartment discovery

```
discover_compartments / 
```


## Tenancy discovery
Most probably it's possible and convenient to use OCI search service, but such technique requires API calls each time conversion is needed. To eliminate it some kind of cache mechanism must be in place, and it's the direction I decided to follow. I made such decision inspired by similar technique used by Kevin Colwell - o command's inventor.

Tenancy discovery is started with reading OCI CLI connection descriptor located at ~/.oci/profile. 


Once sourced you can discover your tenancy.

```bash
discover_tenancy
```

, after a while you will see the data, where critical information is cache_home, as this location will be used to keep all tenancy cached data. 

```
Tenancy context prepared.
\- id:    ocid1.tenancy.oc1.....
\- realm: oc1
\- name:  my_cloud
\- region key: FRA
\- cache home: /Users/rstyczynski/.oci/objects/tenancy/oc1/my_cloud
```
Notice that cache directory has OCI realm in the structure, what makes it possible to work with tenancies in different realm, even when tenancy names are the same. Quite unlikely situation indeed, but it's better not to be surprised in the future.

## OCI connection
OCI CLI works with OCI connection specified in ~/.oci/profile; by default DEFAULT profile is used, but you may speci


