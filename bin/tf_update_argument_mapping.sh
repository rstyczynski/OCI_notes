#!/bin/bash

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
    template=$(grep '# template:' $section_args | cut -f2 -d':' | sed 's/^[ \t]*//')

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

tf_update_argument_mapping_bulk /Users/rstyczynski/Documents/avaloq/terraform/oci-module-common-exacs
