# Provide password to the target system

Shamir's Secret Sharing scheme allow to split parts of the secret among number of holders with ability to reconstruct it using defined subset of pieces. First part of SSS article introduces the theory, and presented how to create shares. Second one rebuilds the secret from subset of shares. The last one - third supplies password to web page authentication. Let's focus on password supply now.

## Password supply

On this stage you are able to split your secreted among five shareholders, and reconstruct the password from any two shares of of available five. In real life it means that two of board members can open access to critical resource as DRCC or OCI Tenancy.

Tha final step is to provide password into login dialog box in such way that operator will not know the password. Having such procedure password mey be reused in the future, and it's not mandatory to change it to eliminate risk that operator will remember the secret and used it in unauthorized way.

## Target system interaction

This exemplary procedure assumes that OSX Safari is used to reach OCI console. With both it's possible to script Safari interaction using AppleScript plus OSX System Events. All the code is contained in a bash script, which writes AppleScript to temporary directory and executes it to:

1. validate current webpage name
2. validate current URL
3. validate current URL's parameter value
4. validate that active field is the one to get password.

Once all the above conditions are met, script uses remote JavaScript invocation to set password field value to actual password taken from SSS recovery step.

## Target system description

To make this demo a little more realistic, target system is described using data structure, specifying webpage, url, parameter with expected value, and target password field name. Demo comes with script to create below structure, to make it easier to adjust code to other purposes. We will capture data for OCI login page

``` yaml
--
name: oci
webpage: Oracle Cloud Infrastructure | Sign In
url: https://login.eu-frankfurt-1.oraclecloud.com
arg: tenant
arg_value: tenant1
field: password
```

## OCI login password supply

Let's try now to configure connection to Safari browser with web page discovery and creation of password destination descriptor. With this we will supply password the the OCI login process. Note that this process works only on OSX as it uses OS level features.

Prepare environment

``` bash
export sss_home=$HOME/sss
export sss_session=$sss_home/generate; mkdir -p $sss_session
export sss_input=$HOME/sss/input; mkdir -p $sss_input
export sss_shares=$HOME/sss/shares; mkdir -p $sss_shares
cd $sss_session
```

Get Safari interaction code.

``` bash
cd $sss_home/bin
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/safari_capture_password_descriptor.sh > safari_capture_password_descriptor.sh
chmod +x safari_capture_password_descriptor.sh
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/safari_interaction.sh > safari_interaction.sh
chmod +x safari_interaction.sh
cd -
```

## Build password target descriptor

We will create password field descriptor for a fake tenancy1, which does exist in the OCI, however we have no access to it. It does not matter, as the success of this exercise is to pass SSS password to OCI login field.

OCI login URL is complex, but we are interested only in the address and the value of 'tenant' parameter.

``` bash
$sss_home/bin/safari_capture_password_descriptor.sh oci_tenant1 address_only tenant
```

You will be requested by the script to open target tenant1 login web page at Safari, and place cursor on destination password field. Once ready, press enter to get oci_tenant1.yaml file ready. The file should look like the following.

``` yaml
--
name: oci_tenant1
webpage: Oracle Cloud Infrastructure | Sign In
url: https://login.eu-frankfurt-1.oraclecloud.com
arg: tenant
arg_value: tenant1
field: password
```

Now you are ready to supply the password to OCI login. Close OCI login page, and close Safari. Switch to terminal and run below script, It's assumed that both previous steps were executed and password file is in place.

``` bash
$sss_home/bin/safari_interaction.sh oci_tenant1.yaml
```

Once executed script with switch to Safari, which will be started if not running, and will listen to active web page. You have to open OCI login form for tenant1 tenancy. Once ready script will place password in the proper input field.

## Conclusion

This article presented how to supply password in secure way to the login web page. It's a demo, however presented model is quite close to potential production use. An honest operator will not see the password in any point of the process. Real implementation should use encrypted ramdisk to store session and temporary files. Good idea is to store password in additionally encrypted form to prevent from potential temptation to see it. Real production procedure should change the password as the consequence of password recovery and use process.


