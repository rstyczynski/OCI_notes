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