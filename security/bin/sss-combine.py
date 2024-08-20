from secretsharing import PlaintextToHexSecretSharer
import sys

# Read shares from stdin
shares = sys.stdin.read().splitlines()

# Recover the secret from the shares
recovered_secret = PlaintextToHexSecretSharer.recover_secret(shares)
print(recovered_secret)
