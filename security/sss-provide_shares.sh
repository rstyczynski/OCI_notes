#!/bin/bash

: ${sss_session:=$HOME/sss/generate}
: ${sss_input:=$HOME/sss/input}

numbers=(1 2 3 4 5)
shuffled_numbers=$(echo "${numbers[@]}" | tr ' ' '\n' | shuf | tr '\n' ' ')

for share_no in $shuffled_numbers; do
    read -p "Pressn Enter to send secret share no. $share_no."
    echo -n $(tail -$share_no $sss_session/shares.txt | head -1) > "$sss_input"/share.tmp
    share_sha=$(sha256sum "$sss_input"/share.tmp | awk '{print $1}')
    mv "$sss_input"/share.tmp "$sss_input"/$share_sha
done