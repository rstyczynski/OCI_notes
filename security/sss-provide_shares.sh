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
    echo $share_pos
    read -p "Provide share, and press Enter" share
    if [ ! -z "$share" ]; then
        echo -n $share > "$sss_input"/share.tmp
    else
        echo "None provided. Taking share from generated ones"
        share_no=${shuffled_array[$(( share_pos - 1))]}
        echo -n $(tail -$share_no $sss_session/shares.txt | head -1) > "$sss_input"/share.tmp
    fi
    share_sha=$(sha256sum "$sss_input"/share.tmp | awk '{print $1}')
    mv "$sss_input"/share.tmp "$sss_input"/$share_sha    
done


for share_no in $shuffled_numbers; do
    read -p "Provide share, and press Enter to send secret share no. $share_no."
    echo -n $(tail -$share_no $sss_session/shares.txt | head -1) > "$sss_input"/share.tmp
    share_sha=$(sha256sum "$sss_input"/share.tmp | awk '{print $1}')
    mv "$sss_input"/share.tmp "$sss_input"/$share_sha
done