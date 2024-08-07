#!/bin/bash

# install tools; adjust for your system.
brew install pwgen
brew install coreutils

# install python library
python3 -m venv sss
source sss/bin/activate
pip3 install --upgrade pip
pip3 install --upgrade --force-reinstall git+https://github.com/blockstack/secret-sharing

# get python code
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-split.py > sss/bin/sss-split.py
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-combine.py > sss/bin/sss-combine.py

# generate password
pwgen -s -y -B 12 1 > password.txt

# split the password and remove in a safe way
cat password.txt | sss/bin/python sss/bin/sss-split.py  2 5 >shares.txt
cat password.txt | sha256sum > password.sha
gshred -u -n 3 password.txt 

# take two random shares available fragments
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 >shares_subset.txt

# reconstruct password
cat shares_subset.txt | sss/bin/python sss/bin/sss-combine.py > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha

# validate
diff password.sha password_recombined.sha && echo OK || echo Error

# view the password
cat password_recombined.txt

# remove python environment
deactivate
rm -rf sss/*
rmdir sss