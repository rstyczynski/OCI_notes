"""
The following Python implementation of Shamir's secret sharing is
released into the Public Domain under the terms of CC0 and OWFa:
https://creativecommons.org/publicdomain/zero/1.0/
http://www.openwebfoundation.org/legal/the-owf-1-0-agreements/owfa-1-0

See the bottom few lines for usage. Tested on Python 2 and 3.

Code originates from https://en.wikipedia.org/wiki/Shamir%27s_secret_sharing#Usage and is augmented with slight changes.
"""

from __future__ import division
from __future__ import print_function

import random
import functools
import argparse
import sys

# 12th Mersenne Prime
_PRIME = 2 ** 127 - 1

_RINT = functools.partial(random.SystemRandom().randint, 0)

def ascii_to_int_bytes(ascii_string):
    byte_representation = ascii_string.encode('ascii')
    return int.from_bytes(byte_representation, byteorder='big')

def int_to_ascii_bytes(integer_value):
    length = (integer_value.bit_length() + 7) // 8
    byte_representation = integer_value.to_bytes(length, byteorder='big')
    return byte_representation.decode('ascii')

def _eval_at(poly, x, prime):
    """Evaluates polynomial (coefficient tuple) at x, used to generate a
    shamir pool in make_random_shares below.
    """
    accum = 0
    for coeff in reversed(poly):
        accum *= x
        accum += coeff
        accum %= prime
    return accum

def make_random_shares(secret, minimum, shares, prime=_PRIME):
    """
    Generates a random shamir pool for a given secret, returns share points.
    """
    if minimum > shares:
        raise ValueError("Pool secret would be irrecoverable.")
    poly = [secret] + [_RINT(prime - 1) for i in range(minimum - 1)]
    points = [(i, _eval_at(poly, i, prime))
              for i in range(1, shares + 1)]
    return points

def _extended_gcd(a, b):
    """
    Division in integers modulus p means finding the inverse of the
    denominator modulo p and then multiplying the numerator by this
    inverse (Note: inverse of A is B such that A*B % p == 1). This can
    be computed via the extended Euclidean algorithm
    http://en.wikipedia.org/wiki/Modular_multiplicative_inverse#Computation
    """
    x = 0
    last_x = 1
    y = 1
    last_y = 0
    while b != 0:
        quot = a // b
        a, b = b, a % b
        x, last_x = last_x - quot * x, x
        y, last_y = last_y - quot * y, y
    return last_x, last_y

def _divmod(num, den, p):
    """Compute num / den modulo prime p

    To explain this, the result will be such that:
    den * _divmod(num, den, p) % p == num
    """
    inv, _ = _extended_gcd(den, p)
    return num * inv

def _lagrange_interpolate(x, x_s, y_s, p):
    """
    Find the y-value for the given x, given n (x, y) points;
    k points will define a polynomial of up to kth order.
    """
    k = len(x_s)
    assert k == len(set(x_s)), "points must be distinct"
    def PI(vals):  # upper-case PI -- product of inputs
        accum = 1
        for v in vals:
            accum *= v
        return accum
    nums = []  # avoid inexact division
    dens = []
    for i in range(k):
        others = list(x_s)
        cur = others.pop(i)
        nums.append(PI(x - o for o in others))
        dens.append(PI(cur - o for o in others))
    den = PI(dens)
    num = sum([_divmod(nums[i] * den * y_s[i] % p, dens[i], p)
               for i in range(k)])
    return (_divmod(num, den, p) + p) % p

def recover_secret(shares, prime=_PRIME):
    """
    Recover the secret from share points
    (points (x,y) on the polynomial).
    """
    if len(shares) < 2:
        raise ValueError("need at least two shares")
    x_s, y_s = zip(*shares)
    return _lagrange_interpolate(0, x_s, y_s, prime)

def main():
    """Main function"""
    
    parser = argparse.ArgumentParser(description="Shamir's Secret Sharing CLI")
    parser.add_argument('secret', type=str, help='The secret to share')
    parser.add_argument('minimum', type=int, help='Minimum number of shares needed to reconstruct the secret')
    parser.add_argument('shares', type=int, help='Total number of shares to create')

    args = parser.parse_args()

    secret = args.secret
    minimum = args.minimum
    shares = args.shares

    # Check if secret length is within the allowed limit
    if len(secret) > 15:
        print("Error: secret length must be 15 characters or fewer.")
        sys.exit(1)

    secret = ascii_to_int_bytes(secret)
    shares = make_random_shares(secret, minimum = minimum, shares = shares)

    print('Secret:                                                     ',
          secret, secret)
    print('Shares:')
    if shares:
        for share in shares:
            print('  ', share)

    print('Secret recovered from minimum subset of shares:             ',
          recover_secret(shares[:minimum]), int_to_ascii_bytes(recover_secret(shares[:minimum])))
    print('Secret recovered from a different minimum subset of shares: ',
          recover_secret(shares[-minimum:]), int_to_ascii_bytes(recover_secret(shares[-minimum:])))

if __name__ == '__main__':
    main()
