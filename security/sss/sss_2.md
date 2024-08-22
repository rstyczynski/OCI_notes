
# Shamir's Secret Sharing scheme - password split

Shamir's Secret Sharing scheme allows to split parts of the secret among number of holders with ability to reconstruct it using defined subset of pieces. [First part](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_1.md) of SSS article introduces the theory. [Second one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_2.md) presents how to create shares using regular tools. [Third one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_3.md) shows how to rebuild the secret from subset of shares, and [the last one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_4.md) - supplies password to web page authentication.

Take a look at two selected SSS tools. Code was prepared on OSX with use of regular utilities and Python code. May be used at any regular system; all you potentially need to do - is to adjust packages install for your case.

### sss-cli

First example uses code developed by vitkabele. Before use this code has to be examined and documented. It may be smart to use own code, as the implementation is not complex thanks to straight forward theory behind. Code handles very long secrets.

Install tools; adjust this part for your system.

``` bash
brew install vitkabele/tap/sss-cli
brew install pwgen
```

Prepare environment

``` bash
sss_home=$HOME/sss
sss_session=$sss_home/generate
mkdir -p $sss_session
cd $sss_session
```

Generate password

``` bash
pwgen -s -y -B 12 1 > password.txt
```

Split the password

``` bash
secret-share-split --count 5 --threshold 2 password.txt >shares.txt
cat password.txt | sha256sum > password.sha
```

Take two random shares available fragments and reconstruct the password

``` bash
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 > shares_subset.txt

cat shares_subset.txt | secret-share-combine > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha
```

Validate the recovered password.

``` bash
diff password.sha password_recombined.sha && echo OK || echo Error
```

### secretsharing Python package

Let's do the same using regular Python library - secretsharing.

Install tools; adjust this code for your system.

``` bash
brew install pwgen
```

Prepare environment

``` bash
sss_home=$HOME/sss
sss_session=$sss_home/generate; mkdir -p $sss_session
cd $sss_session
```

Install Python library and get CLI Python code

``` bash
cd $sss_home/..
python3 -m venv sss
source sss/bin/activate
pip3 install --upgrade pip
pip3 install --upgrade --force-reinstall git+https://github.com/blockstack/secret-sharing

cd $sss_home/bin
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/sss-split.py > sss-split.py
chmod +x sss-split.py
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/sss-combine.py > sss-combine.py
chmod +x sss-combine.py
cd $sss_session
```

Generate password

``` bash
pwgen -s -y -B 12 1 > password.txt
```

Split the password

``` bash
cat password.txt | $sss_home/bin/python $sss_home/bin/sss-split.py 2 5 >shares.txt
cat password.txt | sha256sum > password.sha
```

Take two random shares available fragments and reconstruct the password

``` bash
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 >shares_subset.txt

cat shares_subset.txt | $sss_home/bin/python $sss_home/bin/sss-combine.py > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha
```

Validate the password

``` bash
diff password.sha password_recombined.sha && echo OK || echo Error
```

## Conclusion

This part presented how to split the password into shared using regular available tools. Sample code may be reused for production use adding some extra logic increasing security and usability. Note that libraries does not product standard data, and shares cannot be recombined using different tool than used to make a split.
