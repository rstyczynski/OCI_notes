#!/bin/bash

function get_arguments {
    tf_provider_object_type=$1
    resource=$2

    tf_provider_doc_base_url=${tf_provider_doc_base_url:-'https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci'}
    tf_provider_version=${tf_provider_version:-6.23.0}

    export tmp=~/tmp; mkdir -p $tmp

    case $tf_provider_object_type in
    resource)
        tf_provider_object_type_code=r
        ;;
    datasource)
        tf_provider_object_type_code=d
        ;;
    esac

    curl -s $tf_provider_doc_base_url/$tf_provider_version/docs/$tf_provider_object_type_code/$resource.html | 
    sed -n '/Argument Reference/,/Attributes Reference/p' | 
    grep '<li><p><code>' > $tmp/arguments

    arguments=$(cat $tmp/arguments | 
    cut -d '>' -f4-6 | 
    cut -d'<' -f1 |
    grep -v '^ ')

    # look for Optional | Required | Updatable
    # <li><p><code>ocpu_count</code> - (Optional) (Updatable)
    # <li><p><code>ssh_public_keys</code> - (Required) (Updatable) 
    rm -rf $tmp/required_args
    rm -rf $tmp/optional_args
    rm -rf $tmp/updateable_args

    cat $tmp/arguments | while read -r line; do
        argument=$(echo "$line" | cut -d '>' -f4-6 | 
                    cut -d'<' -f1 |
                    grep -v '^ ')

        echo "$line" | grep -q '(Required)'  && required=yes  || required=no
        echo "$line" | grep -q '(Optional)'  && optional=yes  || optional=no
        echo "$line" | grep -q '(Updatable)' && updatable=yes || updatable=no

        if [ "$required" = yes ]; then
            echo "$argument" >> $tmp/required_args
        fi

        if [ "$optional" = yes ]; then
            echo "$argument" >> $tmp/optional_args
        fi

        if [ "$updatable" = yes ]; then
            echo "$argument" >> $tmp/updateable_args
        fi

        echo "$argument $required $optional $updatable"
    done

    echo
    echo "Required"
    echo "--------"
    cat $tmp/required_args #| tr '\n' ' '

    echo 
    echo "Optional"
    echo "--------"
    cat $tmp/optional_args #| tr '\n' ' '

    echo
    echo "Updateable"
    echo "----------"
    cat $tmp/updateable_args #| tr '\n' ' '
}

function get_attributes {
    tf_provider_object_type=$1
    resource=$2
    output=$3

    output=${output:-'${attribute}'}

    tf_provider_doc_base_url=${tf_provider_doc_base_url:-'https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci'}
    tf_provider_version=${tf_provider_version:-6.23.0}

    export tmp=~/tmp; mkdir -p $tmp

    case $tf_provider_object_type in
    resource)
        tf_provider_object_type_code=r
        ;;
    datasource)
        tf_provider_object_type_code=d
        ;;
    esac

    curl -s $tf_provider_doc_base_url/$tf_provider_version/docs/$tf_provider_object_type_code/$resource.html | 
    sed -n '/Argument Reference/,/Attributes Reference/p' | 
    grep '<li><p><code>' > $tmp/attributes

    attributes=$(cat $tmp/attributes | 
    cut -d '>' -f4-6 | 
    cut -d'<' -f1 |
    grep -v '^ ')

    # look for Optional | Required | Updatable
    # <li><p><code>ocpu_count</code> - (Optional) (Updatable)
    # <li><p><code>ssh_public_keys</code> - (Required) (Updatable) 

    cat $tmp/attributes | while read -r line; do
        attribute=$(echo "$line" | cut -d '>' -f4-6 | 
                    cut -d'<' -f1 |
                    grep -v '^ ')

        eval "echo \"$output\""
    done
}



function tf_update_argument_mapping {
  tf_file=$1

  info="
Update tf files with currnet list of arguments existing for given version of terraform provider. 

      # attributes assigment <provisioned_clusters>
      # object:   database_cloud_vm_cluster
      # type:     resource
      # version:  6.3.0
      # template: \${attribute} = v.\${attribute}
      # start of attributes assigment <provisioned_clusters>
      availability_domain = v.availability_domain
      # (...)
      zone_id = v.zone_id
      # end of attributes assigment <provisioned_clusters>
"
  # discover code injection section codes
  section_codes=$(grep '# attributes assigment <' $tf_file | sed 's/.*<\(.*\)>.*/\1/')

  for code in $section_codes; do
    # discover code injection paramters per each section
    section_args=$tmp/section_args
    sed -n '/# attributes assigment <'"$code"'>/,/# start of attributes assigment <'"$code"'>/p' $tf_file > $section_args

    indent=$(grep '# attributes assigment <'"$code"'>' $section_args | cut -f1 -d'#')
    object=$(grep '# object:' $section_args | cut -f2 -d':' | sed 's/^[ \t]*//')
    type=$(grep '# type:' $section_args | cut -f2 -d':' | sed 's/^[ \t]*//')
    base_url=$(grep '# base_url:' $section_args | cut -f2 -d':' | sed 's/^[ \t]*//')
    version=$(grep '# version:' $section_args | cut -f2 -d':' | sed 's/^[ \t]*//')
    template=$(grep '# template:' $section_args | cut -f2-990 -d':' | sed 's/^[ \t]*//')

    # perform code injection for each section
    code_injection_file=$tmp/${object}.attr
    tf_provider_version=${version}
    tf_provider_doc_base_url=${base_url}
    get_attributes ${type} ${object} "${indent}${template}" > $code_injection_file

    tf_file_progress=$tmp/$(basename $tf_file).inprogress

    if [ -s "$code_injection_file" ]; then
      sed -i .bak '/# start of attributes assigment <'"$code"'>/,/# end of attributes assigment <'"$code"'>/ {
        /# start of attributes assigment <'"$code"'>/ {
          p
          r '"$code_injection_file"'
          d
        }
        /# end of attributes assigment <'"$code"'>/ p
        d
      }' $tf_file

      status_desc="${indent}# $(date) Attributes injected."
    else
      status_desc="${indent}# $(date) Error loading attributes. Data not injected."
    fi

    # update status
    sed -i .bak '/# start of attributes assigment <'"$code"'>/i\
'"$status_desc"'
      ' $tf_file
  done
}

function tf_update_argument_mapping_bulk {
  dir=$1

  # discover files
  tf_files=$(find $dir -name *.tf)

  for tf_file in $tf_files; do
    echo "Processing $tf_file..."
    tf_update_argument_mapping "$tf_file"
  done
}

tf_update_argument_mapping_bulk ./