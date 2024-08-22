# Shamir's Secret Sharing scheme - share collection model

using Secret Sharing scheme

Shamir's Secret Sharing scheme allow to split parts of the secret among number of holders with ability to reconstruct it using defined subset of pieces. [First part](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_1.md) of SSS article introduces the theory. [Second one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_2.md) presents how to create shares using regular tools. [Third one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_3.md) rebuilds the secret from subset of shares, and [the last one](https://github.com/rstyczynski/OCI_notes/blob/main/security/sss/sss_4.md) - supplies password to web page authentication.

Let's focus now on rebuilding the password from subset of shares.

## Share collection

Share collection process collects shares from shareholders, who copy their pieces into specified input directory. The collection process stops when required number of shares is received.

Before proceeding, it's required that you executed share generation process from first part of this blog, using secretsharing Python package (second exemplary code).

Prepare environment

``` bash
export sss_home=$HOME/sss
export sss_session=$sss_home/generate; mkdir -p $sss_session
export sss_input=$HOME/sss/input; mkdir -p $sss_input
export sss_shares=$HOME/sss/shares; mkdir -p $sss_shares
cd $sss_session
```

Get share collection code.

``` bash
cd $sss_home/bin
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/sss-collect_shares.sh > sss-collect_shares.sh
chmod +x sss-collect_shares.sh
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/sss-share-fingerprints.sh > sss-share-fingerprints.sh
chmod +x sss-share-fingerprints.sh
curl -S https://raw.githubusercontent.com/rstyczynski/OCI_notes/main/security/sss/bin/sss-provide_shares.sh > sss-provide_shares.sh
chmod +x sss-provide_shares.sh
cd -
```

On this stage, share eneration process is extened by preparation of sha set. Having a list of sha fingeprints make it easy to detect if provided data is one of shares or it's a fake data. In target solution such list shuld be distributed to each shareholder as each of them may need to initiate password recovery process.

``` bash
cat shares.txt | $sss_home/bin/sss-share-fingerprints.sh > shares_sha.txt
```

Execute share collection procedure. This procedure will finish after reception of two shares identified by sha fingerprint, as this exemplary process expects at least two shares.

``` bash
$sss_home/bin/sss-collect_shares.sh 2
```

Now systems awaits for shares.

In *another terminal* simulate share providing process. You can provide shares manualy, or press enter to randomy select shares from generated ones in previous step. We still are in a lab environment, having access to all the data, so we can play with shares.

``` bash
export sss_home=$HOME/sss
export sss_session=$sss_home/generate
export sss_input=$HOME/sss/input
$sss_home/bin/sss-provide_shares.sh
```

Build secret from collected shares.

``` bash
cat shares_received.txt | $sss_home/bin/python $sss_home/bin/sss-combine.py | tr -d '\n' > password_recovered.txt
cat password_recovered.txt | sha256sum > password_recovered.sha
```

Validate the password

``` bash
diff password.sha password_recovered.sha && echo OK || echo Error
```

The password is recovered form just any two parts of five generated shares.

## Conclusion

This article presented how to reconstruct secret password from minimal set of shares using Shamir's Secret Sharing. Provided code may be theoretically used in real life as sss-provide_shares.sh accepts user input. It makes possible data retrieval from paper, QR code. Support for other mediums as e.g. USB stick should be developed.
