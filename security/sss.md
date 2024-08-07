# Shamir' scheme secret sharing 

Cloud technology has revolutionized the way businesses and individuals manage and deploy their IT resources, offering flexibility, scalability, and cost efficiency. However, this new model introduces new security challenges, primarily due to the inherent accessibility of cloud systems through APIs.

Imagine cloud tenancy cloud account that can literally do everything with all the resources. Imagine Oracle DRCC owner account that can do all good and bad things with the whole OCI region. That's a huge power and huge responsibility. Owning the master password is like owning the code to the nuclear button; when the password will be grabbed by an enemy, consequences may be unrecoverable. Would you like to be in possession of the master password? I'm sure not. 

As cloud technology continues to evolve, ensuring robust security measures is essential to protect sensitive data and resources. Several techniques can significantly improve security, including the use of strong passwords and the implementation of Multi-Factor Authentication (MFA). Recent achievement is adoption of Fast Identity Online (FIDO) standard, enabling third party trust source device to be used in authentication process. Some systems already replaced passwords with FIDO devices as e.g. fingerprint scanner available in Mac computers. Anyway it does not matter if single person provides the password (sth he knows) or uses FIDO (sth he has). Still it's the single person with power to control whole system.

Cloud providers as Oracle OCI promotes best practices related to notification about power user (break glass) connection to the system, and modification of power user properties. It's good as security team may closely look into audit stream to discover why this individual has connected on the top privileged account.

Having this owner may react on potential improper behavior, however it may be too late, as attacker may destroy a lot in seconds. That's the consequence of having power of API.

To remove the risk power users shall connect under supervisory of several personas under special access procedure. 

To remove the risk, let's split the password and share among two board members. It's called secret sharing. In case of emergency they will give parts of the password, and make the access possible. 

This scheme has obvious security advantage. Distributing the shares reduces the risk of a single point of failure. Unauthorized access becomes harder since multiple individuals are involved. 

What happened when one of them will be not available or will loose his part? Hopefully cloud support will help, but it will take time. On the other hand, ideally support should not be able to help, as it's not their business and not their security scope. When Support may help - it means that any unauthorized party may gain access incl. government agencies, and it's not what you want to be possible.

A more robust solution is to use Shamir's secret sharing scheme. This involves dividing the password among few trusted persons, with the requirement that defined subset of them can reconstruct the password. It means that when some of them are unavailable, the remaining ones can still reconstruct the password as long as the threshold (e.g. three out of five) is met.

Shamir's secret sharing scheme establishes secure and redundant way of storing highly critical passwords. Adoption of such scheme must be confirmed by the governance and security officers, who should establish appropriate procedures and take care of trainings to build real awareness of secret sharing importance. 

Owning the master password is like owning the code to the nuclear button; when the password will be grabbed by an enemy, consequences may be unrecoverable. 

Implementing proper security procedure eliminates this serious problem. Shamir's secret sharing scheme is one of achievable solutions to achieve it.

Take a look at below exemplary model code for OSX. Code may be used at any  regular system; adjust packages install for your case.

``` bash
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
```

Let's do the same using 10 years old python library, which looks stable.

``` bash
# install tools; adjust for your system.
brew install pwgen
brew install coreutils

# install python library
python3 -m venv sss
source sss/bin/activate
pip3 install --upgrade pip
pip3 install --upgrade --force-reinstall  git+https://github.com/blockstack/secret-sharing

# prepare code
cat > sss/bin/sss-split.py  <<_EOF
from secretsharing import PlaintextToHexSecretSharer
import argparse
import sys

def main():

    parser = argparse.ArgumentParser(description="Shamir's Secret Sharing CLI")
    parser.add_argument('minimum', type=int, help='Minimum number of shares needed to reconstruct the secret')
    parser.add_argument('shares', type=int, help='Total number of shares to create')

    args = parser.parse_args()

    secret = secret = sys.stdin.readline().strip()
    threshold = args.minimum
    num_shares = args.shares
    
    # Create shares
    shares = PlaintextToHexSecretSharer.split_secret(
                secret,                                          
                share_threshold = threshold, 
                num_shares = num_shares)
    
    for share in shares:
        print(share)
    
if __name__ == '__main__':
    main()
_EOF

cat > sss/bin/sss-combine.py << _EOF
from secretsharing import PlaintextToHexSecretSharer
import sys

# Read shares from stdin
shares = sys.stdin.read().splitlines()

# Recover the secret from the shares
recovered_secret = PlaintextToHexSecretSharer.recover_secret(shares)
print(recovered_secret)
_EOF

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
```

# Implementation notes
1. Operation should be performed on encrypted ramdisk, created before use and destroyed after
2. Shares may be stored in encrypted form on USB stick with backup on a paper in ASCII and QR Code for easy retrieval. Encryption password is remembered by share's owner, who enters it to decrypt his share when needed. 
3. To improve safety each share owner holds set of fingerprints of all other shares; it protect against providing wrong share by one of corrupted share holders.
4. First example uses code developed by vitkabele. Before use this code has to be examined and documented. It may be smart to use own code, as the implementation is not complex thanks to straight forward theory behind.
5. Another python based example uses library available in packages repository
6. Wiki page describing sss conveys low level python code that works for shares up to 15 characters. This one may be used as well, after slight adoption.

# References
* https://medium.com/@goldengrisha/shamirs-secret-sharing-a-step-by-step-guide-with-python-implementation-da25ae241c5d
* https://evervault.com/blog/shamir-secret-sharing
* https://github.com/dsprenkels/sss-cli
* https://github.com/blockstack/secret-sharing
* https://dl.acm.org/doi/pdf/10.1145/359168.359176


