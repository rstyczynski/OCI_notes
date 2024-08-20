#!/bin/bash

while read -r line; do
  sha256=$(echo -n "$line" | sha256sum | awk '{print $1}')
  echo "$sha256"
done
