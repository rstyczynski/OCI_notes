#!/bin/bash

yaml_file=$1

session_tmp=$(mktemp -d)

#
# prepare scripts
#

# check name of webpage
cat > $session_tmp/get_webpage_from_safari.applescript  <<EOF
tell application "Safari"
    set frontWindow to front window
    set activeTab to current tab of frontWindow
    set pageTitle to name of activeTab
    return pageTitle
end tell
return
EOF

# check current URL
cat > $session_tmp/get_URL_from_safari.applescript  <<EOF
tell application "Safari"
    set frontWindow to front window
    set activeTab to current tab of frontWindow
    set currentURL to URL of activeTab
    return currentURL
end tell
return
EOF

# focus in Safari on input
cat > $session_tmp/focus_in_safari.applescript  <<EOF
on run {inputName}
    tell application "Safari"
        activate
        delay 1
        do JavaScript "document.querySelector('input[name=\"" & inputName & "\"]').focus();" in current tab of window 1
    end tell
end run
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
return
EOF

cat > $session_tmp/send_to_safari.applescript  <<EOF
on run {fileName}
    tell application "Safari"
        activate
    end tell

    set pass_posix_path to fileName
    set pass_path to POSIX file pass_posix_path as alias

    set keystrokeToSend to read pass_path as «class utf8»

    tell application "System Events"
        keystroke keystrokeToSend
    end tell
    return
end run
EOF

cat > $session_tmp/send_to_input_safari.applescript  <<EOF
on run {field_name, file_name}
    set field_value to read POSIX file file_name
    tell application "Safari"
        do JavaScript "document.getElementsByName('" & field_name & "')[0].value = '" & field_value & "';" in front document
    end tell
    return
end run
EOF

# Read the values from the YAML file

get_yaml_field() {
    local key="$1"
    grep "^$key:" "$yaml_file" | sed "s/^$key: *//"
}

system_name=$(get_yaml_field name)
expected_webpage=$(get_yaml_field webpage)
expected_URL=$(get_yaml_field url)
expected_arg=$(get_yaml_field arg)
expected_arg_value=$(get_yaml_field arg_value)
expected_password_input=$(get_yaml_field field)

cd $sss_session

while [ ! -f "password_recovered.txt" ]; do
    echo "Waiting for the password..."
    sleep 1
done
echo "Ready."

echo "Navigate to ${system_name} desired web page."
cat <<_EOF
Expected destination:
- ${expected_webpage}
- ${expected_URL}
_EOF

if [ ! -z "$expected_arg" ]; then
    echo "- ${expected_arg}=${expected_arg_value}"
fi
echo "- ${expected_password_input}"

#
# wait for proper web page with expected password input field
#
state=initialising
while [ "$state" != "ready_for_password" ]; do
    echo "waiting for proper web page. State: $state"

    current_webpage=$(osascript $session_tmp/get_webpage_from_safari.applescript 2>/dev/null)
    current_URL=$(osascript $session_tmp/get_URL_from_safari.applescript 2>/dev/null)


    current_arg=$(echo "$current_URL" | grep -o "${expected_arg}=[^&]*" | head -n 1)
    current_arg_value=${current_arg#${expected_arg}=}
    
    osascript $session_tmp/focus_in_safari.applescript $expected_password_input 2>/dev/null
    current_password_input=$(osascript $session_tmp/get_input_name_from_safari.applescript 2>/dev/null)

    # echo "- $current_webpage vs. $expected_webpage"
    # echo "- $current_URL vs. $expected_URL"
    # echo "- $current_password_input vs. $expected_password_input"

    state_error=
    state=ready_for_password
    [ "$current_webpage" == "$expected_webpage" ] || state_error="$state_error wrong Web"
    [[ "$current_URL" == "$expected_URL"* ]] || state_error="$state_error wrong URL"
    [ "$current_arg_value" == "$expected_arg_value" ] || state_error="$state_error wrong argument"
    [ "$current_password_input" == "$expected_password_input" ] || state="$state_error wrong field"

    if [ ! -z "$state_error" ]; then
        state=$state_error
    fi
    sleep 0.2
done
echo "Web page ready."

echo "Sending password."
# password paste
osascript $session_tmp/send_to_input_safari.applescript "$expected_password_input" "$PWD/password_recovered.txt"

echo "Done."
rm -rf "$session_tmp"
