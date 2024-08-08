#!/bin/bash

: ${shares_working_dir:=$HOME/sss/generate}
: ${shares_input_dir:=$HOME/sss/input}

numbers=(1 2 3 4 5)
shuffled_numbers=$(echo "${numbers[@]}" | tr ' ' '\n' | shuf | tr '\n' ' ')

for share_no in $shuffled_numbers; do
    read -p "Pressn Enter to send secret share no. $share_no."
    echo -n $(tail -$share_no $shares_working_dir/shares.txt | head -1) > "$shares_input_dir"/share.tmp
    share_sha=$(sha256sum "$shares_input_dir"/share.tmp | awk '{print $1}')
    mv "$shares_input_dir"/share.tmp "$shares_input_dir"/$share_sha
done