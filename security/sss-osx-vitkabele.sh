#!/bin/bash

# install tools; adjust for your system.
brew install vitkabele/tap/sss-cli
brew install pwgen
brew install coreutils

# generate password
pwgen -s -y -B 12 1 > password.txt

# split the password and remove in a safe way
secret-share-split --count 5 --threshold 2 	password.txt >shares.txt
cat password.txt | sha256sum > password.sha
gshred -u -n 3 password.txt 

# take two random shares available fragments
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 >shares_subset.txt

# reconstruct password
cat shares_subset.txt | secret-share-combine > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha

# validate
diff password.sha password_recombined.sha && echo OK || echo Error

# view the password
cat password_recombined.txt
