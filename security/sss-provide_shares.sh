#!/bin/bash

: ${sss_home:=$HOME/sss}
: ${sss_session:=$sss_home/generate}
: ${sss_input:=$sss_home/input}

numbers=(1 2 3 4 5)
shuffled_numbers=$(echo "${numbers[@]}" | tr ' ' '\n' | shuf | tr '\n' ' ')
shuffled_array=()
for number in $shuffled_numbers; do
    shuffled_array+=("$number")
done

for share_pos in ${numbers[@]}; do
    read -p "Provide share, and press Enter: " share
    if [ ! -z "$share" ]; then
        echo -n $share > "$sss_input"/share.tmp
    else
        share_no=${shuffled_array[$(( share_pos - 1))]}
        
        echo "None provided. Taking share no. $share_no from generated ones"
        echo -n $(tail -$share_no $sss_session/shares.txt | head -1) > "$sss_input"/share.tmp
    fi
    share_sha=$(sha256sum "$sss_input"/share.tmp | awk '{print $1}')
    mv "$sss_input"/share.tmp "$sss_input"/$share_sha    
done
