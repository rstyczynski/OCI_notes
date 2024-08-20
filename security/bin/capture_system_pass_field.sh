#!/bin/bash

system_name=$1

if [ -z "$system_name" ]; then
    echo "Error. Provide system name."
    exit 1
fi

address_only=no
if [ "$2" = "address_only" ]; then
    address_only=yes
fi

expected_arg=$3

set -e

read -p "In Safari blowser open target ${system_name} web page, and place cursor on destination password field. Press Enter once ready."

session_tmp=$(mktemp -d)

# check name of webpage
cat > $session_tmp/get_webpage_from_safari.applescript  <<EOF
tell application "Safari"
    set frontWindow to front window
    set activeTab to current tab of frontWindow
    set pageTitle to name of activeTab
    return pageTitle
end tell
EOF

# check current URL
cat > $session_tmp/get_URL_from_safari.applescript  <<EOF
tell application "Safari"
    set frontWindow to front window
    set activeTab to current tab of frontWindow
    set currentURL to URL of activeTab
    return currentURL
end tell
EOF

# get input name
cat > $session_tmp/get_input_name_from_safari.applescript  <<EOF
tell application "Safari"
    tell front window
        tell current tab
            set jsScript to "var activeElement = document.activeElement; activeElement ? activeElement.name : 'No active element';"
            try
                set elementName to do JavaScript jsScript
                return elementName
            on error errMsg
                error "Error: " & errMsg
            end try
        end tell
    end tell
end tell
EOF

current_webpage=$(osascript $session_tmp/get_webpage_from_safari.applescript)
current_URL=$(osascript $session_tmp/get_URL_from_safari.applescript)

expected_URL=$current_URL
if [ "$address_only" = "yes" ]; then
    expected_URL=$(echo $current_URL | cut -f1 -d'?' | cut -f1-3 -d'/')
fi

expected_arg_value=$(echo $expected_URL | tr '[?&]' '\n' | grep "^$expected_arg" | cut -f2 -d=)
echo $expected_URL | tr '[?&]' '\n' | grep "^$expected_arg"

current_password_input=$(osascript $session_tmp/get_input_name_from_safari.applescript)

cat > ${system_name}.yaml <<_EOF
--
name: ${system_name}
webpage: ${current_webpage}
url: ${expected_URL}
arg: ${expected_arg}
arg_value: ${expected_arg_value}
field: ${current_password_input}
_EOF

echo Data written to 
cat ${system_name}.yaml 

rm -rf "$session_tmp"