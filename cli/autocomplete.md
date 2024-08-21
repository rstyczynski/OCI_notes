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

> [!Note]
> During my tool developments I discovered that it's an interesting idea to apply URI concept to address OCI resources. Each resource must exist in one and only one compartment, so URI may be applied; to make it simpler I'll decide to use regular Linux directory path.

Here is example of bastion service located in meet-me-room compartment under prod compartment.

```text
/prod/meet-me-room/bastion
```

Now the only trick is to provide a tool to convert OCI path into ocid.

## OCI CLI auto-complete

Let' play with simple OCI CLI autocomplete. Load the source code and source it. It's assumed you are using bash. I do not know how and if this autocomplete works with other shells.

```bash
mkdir -p ~/.oci/bin
wget --no-cache https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/bin/oci_wrapper.sh -q -O ~/.oci/bin/oci_wrapper.sh
source ~/.oci/bin/oci_wrapper.sh
```

Now you can play with oci and TAB button. Enter below command:

```bash
oci os ns g
```

.. and press TAB.

```bash
oci os ns get
```

Now try with something more complex.

```bash
oci comp
```

... press TAB

```bash
oci compute inst
```

... press TAB

```bash
oci compute instance list
```

... press TAB, TAB

```bash
oci compute instance list --compartment-id
```

Now you see added slash.

```bash
oci compute instance list --compartment-id /
```

... press TAB, TAB to see list of your root level compartments.

```bash
oci compute instance list --compartment-id /
/prod            /ManagedCompartmentForPaaS  
```

Now you can work with autocomplete in the same way you used to work with directories. Compartment autocomplete has exactly the same mechanics as autocomplete of regular file system path and files, as it's implemented using local compartment cache, which is organized using file system.

```bash
oci compute instance list --compartment-id /prod/meet-me-room
```

Notice here little of magic, as oci command in place of expected ocid accepts resource path. It's handled by oci wrapper replacing path into required ocid. This function is described later in this document. if you are interested in details keep reading, if not enjoy OCI CLI autocomplete.

Compartment information is collected from oci each time you press TAB, so you may see tiny delay. Once the data is in the cache - it will be reused. Data is reloaded after 1 minute to always see current compartments.
