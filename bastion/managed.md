# Managed SSH session via OCI Bastion

OCI Bastion service provides convenient way to connects to compute instances. Managed mode uses Bastion Plugin running at the target instance, what eliminates need to register own ssh keys in the operating system; you do not even need to use you ssh key, as below script creates one-time use ssh key for each bastion session. Little things that makes our life easier.

## Prerequisites  
Before proceeding make sure all mandatory connection tools and properties are in place. 

You need to:
1. install OCI CLI
2. register API KEY at your OCI profile
3. prepare OCI config profile

At tenancy level below myst be ready:
1. OCI Bastion service must be available with known OCID 
2. The target compute instance must have enabled Bastion Plugin to enable ssh connection in managed mode.
3. you must belong to a group with all required IAM access privileges.

## Helper functions
Copy paste below functions to your shell session ore register them in your bash_profile. Both are used to handle all the bastion mechanics:
1. getBastionSession - initializes the session
2. connectTroughBastion - connects to the target

```
function getBastionSession {

    target_state=ACCEPTED 
    if [ "$1" == sync ]; then target_state=SUCCEEDED; fi

    if [ -z "$oci_profile" ]; then oci_profile=DEFAULT; fi
    if [ -z "$session_name" ]; then session_name="$(whoami)_$(hostname)"; fi
    mkdir -p ~/oci/bastion/bin
    mkdir -p ~/oci/bastion/session

    echo "=== Generating session ssh key for $session_name..."
    private_key=~/oci/bastion/session/${session_name}.rsa
    rm -rf $private_key
    ssh-keygen -t rsa -b 4096 -N "" -f $private_key >/dev/null 2>&1

    echo "=== Creating bastion session..."
    oci bastion session create-managed-ssh \
    --profile $oci_profile \
    --wait-for-state $target_state \
    --bastion-id $bastion_ocid \
    --display-name $session_name \
    --key-type PUB \
    --ssh-public-key-file ${private_key}.pub \
    --target-os-username $target_username \
    --target-resource-id $target_ocid > ~/oci/bastion/session/${session_name}_workrequest.json 

    echo "=== Saving session ocid...."
    cat ~/oci/bastion/session/${session_name}_workrequest.json | jq -r ".data.resources[0].identifier" > ~/oci/bastion/session/$session_name.ocid

}

function connectTroughBastion {

    if [ ! -z "$1" ]; then session_name=$1; fi

    if [ -z "$oci_profile" ]; then oci_profile=DEFAULT; fi
    if [ -z "$session_name" ]; then session_name="$(whoami)_$(hostname)"; fi
    mkdir -p ~/oci/bastion/bin

    echo "=== Getting session details for $session_name..."
    oci bastion session get \
    --profile $oci_profile \
    --session-id $(cat ~/oci/bastion/session/$session_name.ocid) > ~/oci/bastion/session/$session_name.json

    session_state=$(cat ~/oci/bastion/session/$session_name.json | jq -r '.data."lifecycle-state"')
    if [ "$session_state" != ACTIVE ]; then
        echo "Error. Session not active. Invoke getBastionSession to build the new one."
        return 1
    fi

    echo "=== Getting session command line...."
    private_key=~/oci/bastion/session/${session_name}.rsa
    cat ~/oci/bastion/session/$session_name.json | jq -r '.data."ssh-metadata".command' \
    | sed "s|<privateKey>|\$private_key|g" \
    | grep '^ssh -i $private_key -o ProxyCommand' \
    > ~/oci/bastion/bin/${session_name}_connect.sh

    source ~/oci/bastion/bin/${session_name}_connect.sh
}
```

## Prepare Bastion Session
Specify oci profile name and optionally https proxy if your connection needs it. You need to know your OCI Bastion OCID identifier. 

```
https_proxy=your_value
oci_profile=your_value

bastion_ocid=ocid1.bastion.region.id
_EOF
```

Connecting to the target you need to know username and target compute instance OCID. IP is not required here, as is discovered by the Bastion itself. Session name will be used as bastion session name to be visible in e.g. console. This name is used to store data in temporary files used by local functions to handle all the mechanics.

```
session_name=your_value

target_username=your_value

target_ocid=ocid1.instance.region.id
```

Having above you need to request the session. Session may be requested in sync mode, what means that command will be blocked until session is ready. Regular mode works in async mode, jut making sure that the request is accepted, what will be better when you need to establish multiple sessions at once.

```
oci compute instance action --profile $oci_profile \
--instance-id $target_ocid \
--action START \
--wait-for-state Running

getBastionSession sync
```

## Connect to the target
To connect the the target use connectTroughBastion function with optional session name parameter. When parameter is omitted, default one stored in session_name variable is used.

```
connectTroughBastion $session_name
```

## Clean up
Delete the session.

```
oci bastion session delete \
--profile $oci_profile \
--session-id $(cat ~/oci/bastion/session/$session_name.ocid)
```

, and stop the instance if needed.

```
oci compute instance action \
--profile $oci_profile \
--instance-id $target_ocid \
--action STOP
```