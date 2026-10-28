#!/usr/bin/env python3
"""Reject tracked Android signing secrets without reading or printing contents."""
import argparse
from pathlib import PurePosixPath
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.')
    args = parser.parse_args()
    tracked = subprocess.check_output(['git', '-C', args.repo, 'ls-files', '-z'])
    forbidden = []
    for raw in tracked.decode('utf-8', errors='surrogateescape').split('\0'):
        if not raw:
            continue
        path = PurePosixPath(raw)
        if path.name == 'key.properties' or path.suffix.lower() in {'.jks', '.keystore'}:
            forbidden.append(raw)
    if forbidden:
        print('Signing material must stay outside Git:', file=sys.stderr)
        for name in forbidden:
            print(f'  {name}', file=sys.stderr)
        return 1
    print('No tracked Android signing material.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
