#!/bin/bash

threshold=$1

#
# collect password pieces
#

shares_working_dir=./sss/generate
shares_input_dir=./sss/shares_input
shares_dir=./sss/shares

mkdir -p $shares_dir; rm -rf $shares_dir/*
mkdir -p $shares_input_dir; rm -rf $shares_input_dir/*

function collect_shares {
    threshold=$1

    ready_cnt=0
    while [ "$ready_cnt" -lt "$threshold" ]; do
        read -p "Put share files in input directory and press enter. One share per file. Input directory: $shares_input_dir"
        cat $shares_working_dir/shares_sha.txt | while read -r expected_sha; do
            if [ -f "$shares_input_dir"/$expected_sha ]; then
                if [ -f "$shares_dir"/$expected_sha ]; then
                    echo $expected_sha - ready
                else
                    echo $expected_sha - provided
                    cp "$shares_input_dir"/$expected_sha "$shares_dir"
                fi
            else
                echo $expected_sha - expected
            fi
        done
        ready_cnt=$(ls "$shares_dir" | wc -l)
    done
    echo "Required shares ready."
}
collect_shares $threshold

# combine input
function reconstruct_secrets {
    : > $shares_working_dir/shares_received.txt
    for file in "$shares_input_dir"/*; do
            cat "$file" >> $shares_working_dir/shares_received.txt
            echo >> $shares_working_dir/shares_received.txt
    done
}
reconstruct_secrets
