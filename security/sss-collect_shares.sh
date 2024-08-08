#!/bin/bash

threshold=$1

#
# collect password pieces
#
: ${sss_session:=$HOME/sss/generate}
: ${sss_input:=$HOME/sss/input}
: ${sss_shares:=$HOME/sss/shares}

function collect_shares {
    threshold=$1

    ready_cnt=0
    while [ "$ready_cnt" -lt "$threshold" ]; do
        read -p "Put share files in input directory and press enter. One share per file. Input directory: $sss_input"
        cat $sss_session/shares_sha.txt | while read -r expected_sha; do
            if [ -f "$sss_input"/$expected_sha ]; then
                if [ -f "$sss_shares"/$expected_sha ]; then
                    echo $expected_sha - ready
                else
                    echo $expected_sha - provided
                    cp "$sss_input"/$expected_sha "$sss_shares"
                fi
            else
                echo $expected_sha - expected
            fi
        done
        ready_cnt=$(ls "$sss_shares" | wc -l)
    done
    echo "Required shares ready."
}
collect_shares $threshold

# combine input
function reconstruct_secrets {
    : > $sss_session/shares_received.txt
    for file in "$sss_shares"/*; do
            cat "$file" >> $sss_session/shares_received.txt
            echo >> $sss_session/shares_received.txt
    done
}
reconstruct_secrets
