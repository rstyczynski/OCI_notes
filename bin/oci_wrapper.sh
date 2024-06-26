#!/bin/bash

# shellcheck disable=SC2002
# (style): Useless cat. 

# shellcheck disable=SC2236
# (style): Use -n instead of ! -z.

# shellcheck disable=SC2001 
# (style): See if you can use ${variable//search/replace} instead.

# shellcheck disable=SC2155 
# (warning): Declare and assign separately to avoid masking return values.

#
# discover tenancy
#
function discover_tenancy {
: <<'_function_info'
Discovers parameters is the tenancy and sets tenancy cache home directory.

Input:
* exported variable OCI_CLI_PROFILE with oci profile

Output:
* variable tenancy_home
* variable tenancy_id
* variable tenancy_realm
* variable tenancy_name
* variable tenancy_region_key
_function_info

    test -z "$OCI_CLI_PROFILE" && OCI_CLI_PROFILE=DEFAULT

    tenancy_dir=~/.oci/objects/tenancy
    mkdir -p $tenancy_dir

    tenancy_id=$(cat ~/.oci/config | sed -n "/\[${OCI_CLI_PROFILE}\]/,/\[/p" | grep tenancy | cut -d= -f2)
    tenancy_realm=$(echo "$tenancy_id" | cut -d. -f3)

    if [ -z "$tenancy_id" ]; then
        echo "General error. OCI profile at ~/.oci/config not available for $OCI_CLI_PROFILE."  
        unset tenancy_id tenancy_realm tenancy_name tenancy_region_key 
        return 1
    fi

    oci iam tenancy get --tenancy-id "$tenancy_id" > ${tenancy_dir}/details
    read -r tenancy_name tenancy_region_key < <(jq -r '.data | "\(.name) \(.["home-region-key"])"' ${tenancy_dir}/details)

    tenancy_home=~/.oci/objects/tenancy/$tenancy_realm/$tenancy_name
    mkdir -p "$tenancy_home"

    if [ -z "$tenancy_id" ] \
    || [ -z "$tenancy_realm" ] \
    || [ -z "$tenancy_name" ] \
    || [ -z "$tenancy_region_key" ]; then
        echo "General error. OCI profile at ~/.oci/config not available for $OCI_CLI_PROFILE."  
        unset tenancy_id tenancy_realm tenancy_name tenancy_region_key 
        return 1
    else
        echo "Tenency context prepared." >&2
        echo "\- id:    $tenancy_id" >&2
        echo "\- realm: $tenancy_realm" >&2
        echo "\- name:  $tenancy_name" >&2
        echo "\- region key: $tenancy_region_key" >&2
        echo "\- cache home: $tenancy_home" >&2
    fi
}

function get_compartment_id {
: <<'_function_info'
Returns compartment if for given compartment path.

Input:
* compartment path e.g. /abc/xyz or ./xyz

Output:
* ocid
_function_info

    local cmp_path_URI=$1
    # remove forbidden characters
    local cmp_path=$(echo "$cmp_path_URI" | tr ' #%&{}\\<>' '_')

    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi

    local base_dir=$tenancy_home/iam/compartment
    
    local compartment_id=""

    # handle relative compartment
    if [[ "$cmp_path" == .* ]]; then
        cmp_path=$(echo "$cmp_path" | sed "s|^\.|$(get_working_compartment)|")
    fi

    if [ "$cmp_path" == '/' ]; then
        compartment_id=$tenancy_id
    else
        # replace path delimiters with bash delimiters (not to touch IFS)
        cmp_path=$(echo "$cmp_path" | tr '/' '\t')

        local cmp_dynamic_path=""
        mkdir -p "${base_dir}${cmp_dynamic_path}"

        # get root compartment id
        compartment_id=$tenancy_id
        if [ ! -s "${base_dir}${cmp_dynamic_path}/ocid" ]; then
            echo  "$compartment_id"  > "${base_dir}${cmp_dynamic_path}/ocid"
        fi
 
        if [ ! -s "${base_dir}${cmp_dynamic_path}"/list ]; then
            oci iam compartment list > "${base_dir}${cmp_dynamic_path}"/list || rm "${base_dir}${cmp_dynamic_path}"/list
        fi
 
        local cmp
        echo "Processing $cmp_path_URI..." >&2
        for cmp in $cmp_path; do
            echo "\- $cmp" >&2
            cmp_dynamic_path=$cmp_dynamic_path/$cmp
            mkdir -p "${base_dir}${cmp_dynamic_path}"

            if [ -s "${base_dir}${cmp_dynamic_path}/ocid" ]; then
                compartment_id=$(<"${base_dir}${cmp_dynamic_path}/ocid")
            else
                if [ ! -s "${base_dir}${cmp_dynamic_path}/../list" ]; then
                    oci iam compartment list \
                    --compartment-id "$compartment_id" > "${base_dir}${cmp_dynamic_path}/../list" || rm "${base_dir}${cmp_dynamic_path}/../list"
                fi

                if [ -s "${base_dir}${cmp_dynamic_path}/../list" ]; then
                    compartment_id=$(jq --arg name "$cmp" -r '.data[] | select(.name == $name).id' "${base_dir}${cmp_dynamic_path}/../list")
                    
                    if [ ! -z  "$compartment_id"  ]; then
                        echo -n  "$compartment_id" > "${base_dir}${cmp_dynamic_path}/ocid"
                    else
                        echo "Error retrieving compartment id for ${cmp_dynamic_path}." >&2
                        rm -rf "${base_dir}${cmp_dynamic_path}"
                    fi
                else
                    echo "Error retrieving list of compartments for $compartment_id" >&2
                    compartment_id=""
                fi
            fi
        done
    fi
    echo  "$compartment_id" 
}

# by ocid
function get_compartment_path {
: <<'_function_info'
Converts ocid to compartment path operating in a cache data. Will not perform conversion for not discovered ocid.

Input:
* ocid

Output:
* compartment path w.g. /abc/xyz
_function_info

    local ocid=$1

    if [[ "$ocid" == ocid1.compartment* ]]; then
        grep -rl -x "$ocid" --include="ocid" "$tenancy_home"/iam/compartment | \
        sed "s|$tenancy_home/iam/compartment||" |
        sed 's|/ocid||'
    else
        echo "Error. Provide ocid as a parameter." >&2
        return 1
    fi
}

# discover compartments
function discover_compartments {
: <<'_function_info'
Discovers all subcompartments for given compartment root.

Input:
* compartment path to start the discovery
* number of worker processes
* maximum age of data in cache

Output:
* files \$tenancy_home/iam/compartment with ocid and json describing compartments
_function_info

    local cmp_path=$1
    local background_count_max=$2
    local ttl=$3

    # shellcheck disable=SC2223
    : ${cmp_path:=/}
    # shellcheck disable=SC2223
    : ${background_count_max:=10}
    # shellcheck disable=SC2223
    : ${ttl:=43200}

    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi

    local cmp_id=""
    if [ -z "$cmp_path" ] || [ "$cmp_path" == "/" ]; then
        cmp_path=""
        cmp_id=$tenancy_id
    else
        cmp_path=$1
        cmp_id=$(get_compartment_id "$cmp_path")
    fi

    local compartment_base="$tenancy_home/iam/compartment${cmp_path}"
    echo "============================================="
    echo "Getting compartments for $cmp_path..."
    echo "\- $compartment_base"

    echo "Preparing for data refresh..."
    mkdir -p "$compartment_base"
    find "$compartment_base" -maxdepth 1 -name "list" -mmin +"$ttl" -exec sh -c 'echo "|- deleting: $1" && rm "$1"' _ {} \;
    echo "\- OK"

    if [ -s "$compartment_base/list" ]; then
        echo "Compartment list for ${cmp_path} is available..."
        echo "\- ocid: $cmp_id"
    else
        echo "Getting compartment list for ${cmp_path}..."
        echo "\- ocid: $cmp_id"
        mkdir -p "$compartment_base"
        oci iam compartment list --compartment-id "$cmp_id" > "$compartment_base/list" || rm "$compartment_base/list"
    fi

    if [ -s "$compartment_base/list" ]; then
        local background_count=0
        for cmp_name in $(jq -r '.data[].name' "$compartment_base/list"); do
            if [ ! -z "$background_count_max" ] && [ "$background_count_max" -gt 0 ]; then
                discover_compartments "${cmp_path}/$cmp_name" "$background_count_max" &
                
                background_count=$((background_count + 1))
                if [ $background_count -eq "$background_count_max" ]; then
                    echo "Waiting for worker processes to finish..."
                    wait
                    background_count=0
                fi
            else
                discover_compartments "${cmp_path}/$cmp_name"
            fi 
        done
    fi
    echo "Waiting for worker processes $cmp_path to finish..."
    wait
}

function get_subcompartments {
: <<'_function_info'
Returns sub compartments for given compartment path. 

Does not traverse path, which must exist in compartment cache, however gets fresh list of subcompartments if existing data is older then 1 minute.

Input:
* compartment path

Output:
* list of compartments
_function_info

    local cmp_path=$1

    # handle relative compartment
    if [[ "$cmp_path" == .* ]]; then
        # shellcheck disable=SC2001
        cmp_path=$(echo "$cmp_path" | sed "s|^\.|$(get_working_compartment)|")
    fi

    # validate path
    path_regex="^/(\.?[^/ ]*)+(/[^/ ]+)*$"
    if [[ ! $cmp_path =~ $path_regex ]] \
    || [[ "$cmp_path" == *..* ]] ; then
        echo "Error. Provide valid compartment path." >&2
        return 1
    fi

    #TTL
    if [ -s "$tenancy_home/iam/compartment${cmp_path}/list" ]; then
        local ttl=1
        echo "Preparing for data refresh..." >&2
        find "$tenancy_home/iam/compartment${cmp_path}" -maxdepth 1 -name "list" -mmin +"$ttl" -exec sh -c 'echo "|- deleting: $1" && rm "$1"' _ {} \; >&2
        echo "\- OK" >&2
    fi

    # get data if not available
    if [ ! -s "$tenancy_home/iam/compartment${cmp_path}/list" ]; then
        # shellcheck disable=SC2154
        mkdir -p "$tenancy_home/iam/compartment${cmp_path}"
        if ! oci iam compartment list --compartment-id "$cmp_path" > "$tenancy_home/iam/compartment${cmp_path}/list"; then
            rm -rf "$tenancy_home/iam/compartment${cmp_path}"
        fi
    fi

    if [ -s "$tenancy_home/iam/compartment${cmp_path}/list" ]; then
        # shellcheck disable=SC2002
        cat "$tenancy_home/iam/compartment${cmp_path}/list" | jq -r '.data[] | [.name, .id] | @tsv' | \
        while read -r cmp_name ocid; do
            echo "$cmp_name"
            mkdir -p "$tenancy_home/iam/compartment${cmp_path}/${cmp_name}"
            echo -n "$ocid" > "$tenancy_home/iam/compartment${cmp_path}/${cmp_name}/ocid"
        done
    fi
}

function get_compartments {
: <<'_function_info'
Returns sub compartments for given compartment path. Traverses full path from root, and rebuilds cache.

Input:
* compartment path

Output:
* list of compartments
_function_info

    local cmp_path=$1

    local cmp_path_partial=''
    get_subcompartments / >/dev/null 2>&1
    for cmp in $(echo "$cmp_path" | tr '/' '\t'); do
        cmp_path_partial=$cmp_path_partial/$cmp
        get_subcompartments "$cmp_path_partial" >/dev/null 2>&1
    done

    get_subcompartments "$cmp_path"
}

#
# bastion path2id
#
function get_bastion_id {
: <<'_function_info'
Returns bastion ocid for given bastion path

Input:
* bastion path

Output:
* ocid
_function_info

    local bastion_URL=$1

    # parameter test
    if [ -z "$bastion_URL" ] \
    || [ "$bastion_URL" != "$(dirname "$bastion_URL")/$(basename "$bastion_URL")" ] \
    && [ ! "$bastion_URL" == "$(basename "$bastion_URL")" ]; then
        echo "Error. Provide valid bastion path - the name prefixed by compartment path."
        return 1
    fi

    # return value
    local bastion_id

    # prepare tenency cache directory etc.
    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi

    local base_dir=$tenancy_home/bastion

    local bastion_name=$(basename "$bastion_URL")
    local bastion_location=$(dirname "$bastion_URL")
    
    local bastion_dir=${base_dir}${bastion_location}/${bastion_name}
    mkdir -p "$bastion_dir"
    
    local compartment_id=$(get_compartment_id "$bastion_location")

    if [ -s "${bastion_dir}"/ocid ]; then
        bastion_id=$(< "${bastion_dir}"/ocid)
    else
        oci bastion bastion list \
        --all \
        --compartment-id "$compartment_id" > "${bastion_dir}"/../bastion_list \
        || rm "${bastion_dir}"/../bastion_list 

        if [ -s "${bastion_dir}/../bastion_list" ]; then
            bastion_id=$(jq --arg name "$bastion_name" -r '.data[] | select(.name == $name).id' "${bastion_dir}"/../bastion_list)
            echo -n "$bastion_id" > "${bastion_dir}"/ocid
        else
            echo "Error getting bastion id." >&2
            return 1
        fi
    fi

    echo "$bastion_id"
}

#
# set/get working compartment
#
function set_working_compartment {
: <<'_function_info'
Sets working compartment. Once stored you can use dot notation to refere to working compartment.

Input:
* compartment path

Output:
* compartment path
_function_info

    local working_compartment=$1

    local ocid=$(get_compartment_id "$working_compartment")
    
    mkdir -p "$session_home/${tenancy_realm}_${tenancy_name}"
    if [[ "$ocid" == ocid* ]]; then
        echo "$working_compartment" > "$session_home/${tenancy_realm}_${tenancy_name}/compartment"
    else
        echo / > "$session_home/${tenancy_realm}_${tenancy_name}/compartment"
    fi

    cat "$session_home/${tenancy_realm}_${tenancy_name}/compartment"
}

function get_working_compartment {
: <<'_function_info'
Returns working compartment. 

Input:
* (none)

Output:
* compartment path
_function_info

    local compartment

    local session_home=~/.oci/oc/session

    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi
 
    if [ -f "$session_home/${tenancy_realm}_${tenancy_name}/compartment" ]; then
        compartment=$(cat "$session_home/${tenancy_realm}_${tenancy_name}/compartment")
    else
        compartment=/
    fi
    #echo "Compartment: $compartment" >&2
    echo "$compartment"
}
alias pwc=get_working_compartment

function get_working_compartment_id {
: <<'_function_info'
Returns working compartment's ocid.

Input:
* (none)

Output:
* ocid
_function_info

    local ocid

    ocid=$(get_compartment_id "$(get_working_compartment)")
    #echo "Compartment ocid: $ocid" >&2
    echo "$ocid"
}
alias pwc_id=get_working_compartment_id

#
# OCI autocomplete with compartment support
#
function oci_autocomplete {
: <<'_function_info'
Autocomplete support of oci CLI. Supports path autocomplete for --compartment-id paramter.

_function_info

    local _cmd=$1
    local _this=$2
    local _last=$3

    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi

    if [ "$_last" == oci ]; then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$(oci | grep '^    ' | sed 's/^    //g' | cut -d' ' -f1)" -- "$_this") )
    else
        _clean_COMP_LINE=$(echo "$COMP_LINE" | sed "s| $_this$||")
        _words_cnt=$(echo "$_clean_COMP_LINE" | wc -w)

        if [ "$_words_cnt" -lt 4 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$($_clean_COMP_LINE | sed -n '/Commands:/,/xxx/p' | sed 's/^  //g' | cut -d' ' -f1)" -- "$_this") )   
        else
            if [ "$_clean_COMP_LINE" == "oci iam compartment set" ]; then
                # set current compartment must be always absolute! Relative not allowed.
                #if [[ "$_this" == .* ]]; then
                #    session_pwc=$(get_working_compartment)
                #    COMPREPLY=( ./$(cd ~/.oci/objects/tenancy/$tenancy_realm/$tenancy_name/iam/compartment$session_pwc; compgen -d -- $(echo $_this | sed 's|^\.||') ) )
                #else
                    get_compartments "/$_this" >/dev/null 2>/dev/null 
                    if [ ! -d "$tenancy_home"/iam/compartment ]; then
                        echo "Error. Compartment cache not ready. Discover compartments first." >&2
                        return 1
                    fi
                    # shellcheck disable=SC2207
                    # shellcheck disable=SC2164
                    # shellcheck disable=SC2046
                    COMPREPLY=( $(for word in $(cd "$tenancy_home/iam/compartment"; compgen -d -- $(echo "$_this" | sed 's|^/||') ); do echo "/$word"; done) )
                #fi
            else
                # shellcheck disable=SC2207
                # shellcheck disable=SC2021
                COMPREPLY=( $(compgen -W "$($_clean_COMP_LINE 2>&1 | grep "Error: Missing option(s)" | tr ' ' '\n' | grep "\-\-" | tr -d '[,.]')" -- "$_this") )               
            fi

            if [ "$_last" == '--compartment-id' ]; then
                get_compartments "/$_this" >/dev/null 2>/dev/null 
                if [ ! -d "$tenancy_home"/iam/compartment ]; then
                    echo "Error. Compartment cache not ready. Discover compartments first." >&2
                    return 1
                fi
                # shellcheck disable=SC2207
                # shellcheck disable=SC2164
                # shellcheck disable=SC2046
                # shellcheck disable=SC2086
                COMPREPLY=( $(for word in $(cd "$tenancy_home/iam/compartment"; compgen -d -- $(echo "$_this" | sed 's|^/||') ); do echo /$word; done) )
            fi

        fi
    fi
}
complete -F oci_autocomplete oci

#
# skeleton for oci wrapper with:
# 1. set working compartment support
#
function oc {
: <<'_function_info'
oci CLI extension to be used by oci CLI wrapper.

_function_info

    local family=$1 
    local resource=$2
    local operation=$3
    local value=$4

    if [ -z "$tenancy_home" ]; then
        discover_tenancy
    fi
    
    case "$family $resource $operation" in
    "iam compartment set")
        set_working_compartment "$value"
    ;;
    esac
}
#
# OCI wrapper to handle compartment URL
#
function oci { 
: <<'_function_info'
Wraper of oci CLI with support for:
1. iam compartment set - to set working compartment.
2. replace compartment path into ocid
_function_info

    if [ "$1 $2 $3" == "iam compartment set" ]; then
        oc iam compartment set "$4"
    else
        # tip: replace --compartment-id URL with wrapper function
        # shellcheck disable=SC2016
        wrapped_CLI=$(echo "$@" | sed -E 's|--compartment-id ([/\.][A-Za-z0-9_\./]*)|--compartment-id $(get_compartment_id \1)|')
        eval "$(which oci) $wrapped_CLI"
    fi
}
alias oci=oci
