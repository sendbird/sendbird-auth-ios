#!/usr/bin/env python3
"""Extract testsRef ID from xcresult top-level JSON (via stdin)."""
import sys, json

data = json.load(sys.stdin)
for a in data.get('actions', {}).get('_values', []):
    ref = a.get('actionResult', {}).get('testsRef', {}).get('id', {}).get('_value', '')
    if ref:
        print(ref)
        break
