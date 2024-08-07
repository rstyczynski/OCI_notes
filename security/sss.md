# Shamir's Secret Sharing scheme

Cloud technology has revolutionized the way businesses and individuals manage and deploy their IT resources, offering flexibility, scalability, and cost efficiency. However, this new model introduces new security challenges, primarily due to the inherent accessibility of cloud systems through APIs.

Imagine cloud tenancy cloud account that can literally do everything with all the resources. Imagine Oracle DRCC owner account that can do all good and bad things with the whole OCI region. That's a huge power and huge responsibility. Owning the master password is like owning the code to the nuclear button; when the password will be grabbed by an enemy, consequences may be unrecoverable. Would you like to be in possession of the master password? I'm sure not. 

As cloud technology continues to evolve, ensuring robust security measures is essential to protect sensitive data and resources. Several techniques can significantly improve security, including the use of strong passwords and the implementation of Multi-Factor Authentication (MFA). Recent achievement is adoption of Fast Identity Online (FIDO) standard, enabling third party trust source device to be used in authentication process. Some systems already replaced passwords with FIDO devices as e.g. fingerprint scanner available in Mac computers. Anyway it does not matter if single person provides the password (sth he knows) or uses FIDO (sth he has). Still it's the single person with power to control whole system.

Cloud providers as Oracle OCI promotes best practices related to notification about power user (break glass) connection to the system, and modification of power user properties. It's good as security team may closely look into audit stream to discover why this individual has connected on the top privileged account.

Having this owner may react on potential improper behavior, however it may be too late, as attacker may destroy a lot in seconds. That's the consequence of having power of API.

To remove the risk power users shall connect under supervisory of several personas under special access procedure. 

To remove the risk, let's split the password and share among two board members. It's called secret sharing. In case of emergency they will give parts of the password, and make the access possible. 

This scheme has obvious security advantage. Distributing the shares reduces the risk of a single point of failure. Unauthorized access becomes harder since multiple individuals are involved. 

What happened when one of them will be not available or will loose his part? Hopefully cloud support will help, but it will take time. On the other hand, ideally support should not be able to help, as it's not their business and not their security scope. When Support may help - it means that any unauthorized party may gain access incl. government agencies, and it's not what you want to be possible.

A more robust solution is to use Shamir's Secret Sharing scheme. This involves dividing the password among few trusted persons, with the requirement that defined subset of them can reconstruct the password. It means that when some of them are unavailable, the remaining ones can still reconstruct the password as long as the threshold (e.g. three out of five) is met.

Shamir's Secret Sharing scheme establishes secure and redundant way of storing highly critical passwords. Adoption of such scheme must be confirmed by the governance and security officers, who should establish appropriate procedures and take care of trainings to build real awareness of secret sharing importance. 

Owning the master password is like owning the code to the nuclear button; when the password will be grabbed by an enemy, consequences may be unrecoverable. 

Implementing proper security procedure eliminates this serious problem. Shamir's Secret Sharing scheme is one of achievable solutions to achieve it.

Take a look at two exemplary model codes. Code was prepared on OSX, but may be used at any regular system; all you potentially need to do - is to adjust packages install for your case.

# sss-cli

Install tools; adjust this part for your system.
``` bash
brew install vitkabele/tap/sss-cli
brew install pwgen
brew install coreutils
```

Generate password
``` bash
pwgen -s -y -B 12 1 > password.txt
```

Split the password and remove in a safe way
``` bash
secret-share-split --count 5 --threshold 2 password.txt >shares.txt
cat password.txt | sha256sum > password.sha
gshred -u -n 3 password.txt 
```

Take two random shares available fragments and reconstruct the password
``` bash
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 >shares_subset.txt

cat shares_subset.txt | secret-share-combine > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha
```

Validate and view the recovered password.
``` bash
diff password.sha password_recombined.sha && echo OK || echo Error
cat password_recombined.txt
```

Complete code is here: [sss-osx-vitkabele.sh](https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-osx-vitkabele.sh)


# secretsharing Python package

Let's do the same using regular Python library - secretsharing.

Install tools; adjust this code for your system.
``` bash
brew install pwgen
brew install coreutils
```

Install Python library and get CLI Python code
``` bash
Python3 -m venv sss
source sss/bin/activate
pip3 install --upgrade pip
pip3 install --upgrade --force-reinstall git+https://github.com/blockstack/secret-sharing

curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-split.py > sss/bin/sss-split.py
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-combine.py > sss/bin/sss-combine.py
```

Generate password
``` bash
pwgen -s -y -B 12 1 > password.txt
```

Split the password and remove in a safe way
``` bash
cat password.txt | sss/bin/Python sss/bin/sss-split.py 2 5 >shares.txt
cat password.txt | sha256sum > password.sha
gshred -u -n 3 password.txt 
```

Take two random shares available fragments and reconstruct the password
``` bash
cat shares.txt | perl -MList::Util=shuffle -wne 'print shuffle <>;' | head -2 >shares_subset.txt

cat shares_subset.txt | sss/bin/Python sss/bin/sss-combine.py > password_recombined.txt
cat password_recombined.txt | sha256sum > password_recombined.sha
```

Validate and view the password
``` bash
diff password.sha password_recombined.sha && echo OK || echo Error

cat password_recombined.txt
```

Remove Python environment
``` bash
deactivate
rm -rf sss/*
rmdir sss
```

Complete code is here: [sss-osx-secretshare.sh](https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss-osx-secretshare.sh)

# Wikipedia
The Wikipedia article explaining Shamir’s Secret Sharing presents Python code with low-level mathematical operations using core Python features without any external libraries. The code works for short secrets up to 15 characters but can be adapted to handle longer secrets by splitting them into 15-character fragments and processing each fragment separately. This simple code can effectively manage longer secrets if needed. The advantage of this code is its simplicity, which allows it to be easily controlled by maintainers with the appropriate knowledge.

The code with slight improvements is here: [sss_wikipedia-demo.py](https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss_wikipedia-demo.py)

# Conclusion
Shamir’s Secret Sharing scheme offers a robust solution for managing highly privileged passwords in cloud environments, where security is paramount. The accessibility of cloud systems through APIs introduces significant security challenges, making strong passwords and Multi-Factor Authentication (MFA) essential. However, single-person control remains a risk, similar to having a nuclear button’s code. Shamir’s scheme mitigates this by splitting a master password among multiple trusted individuals, ensuring that a subset can reconstruct it, thereby reducing the risk of unauthorized access and single points of failure.

This approach enhances security by distributing the responsibility and making unauthorized access significantly more challenging. Adoption of this scheme should be endorsed by governance and security officers, emphasizing proper procedures and training to build awareness of its importance.

# Implementation notes
1. Computer should air gapped i.e. physically disconnected from internet and any other network.
2. Operation should be performed on encrypted ramdisk, created before use and destroyed after
3. Shares may be stored in encrypted form on USB stick with backup on a paper in ASCII and QR Code for easy retrieval. Encryption password is remembered by share's owner, who enters it to decrypt his share when needed. 
4. To improve safety each share owner holds set of fingerprints of all other shares; it protect against providing wrong share by one of corrupted share holders.
5. First example uses code developed by vitkabele. Before use this code has to be examined and documented. It may be smart to use own code, as the implementation is not complex thanks to straight forward theory behind.
6. Another Python based example uses library available in packages repository
7. Wiki page describing sss conveys low level Python code that works for shares up to 15 characters. This one may be used as well, after slight adoption.

# References
* https://en.wikipedia.org/wiki/Shamir%27s_secret_sharing
* https://medium.com/@goldengrisha/shamirs-secret-sharing-a-step-by-step-guide-with-Python-implementation-da25ae241c5d
* https://evervault.com/blog/shamir-secret-sharing
* https://github.com/dsprenkels/sss-cli
* https://github.com/blockstack/secret-sharing
* https://dl.acm.org/doi/pdf/10.1145/359168.359176


