#!/usr/bin/env python3
"""Extract passed test names from xcresult test results tree (via stdin).

Reads TEST_TARGET env var for the target prefix (e.g. SendbirdChatTests).
"""
import os, sys, json


def collect_passed(node, target, path=None):
    if path is None:
        path = []
    results = set()
    name = node.get('name', {}).get('_value', '')
    status = node.get('testStatus', {}).get('_value', '')
    subtests = node.get('subtests', {}).get('_values', [])
    if status == 'Success' and not subtests and path:
        class_name = path[-1]
        method_name = name.replace('()', '')
        results.add(f'{target}/{class_name}/{method_name}')
    for sub in subtests:
        results.update(collect_passed(sub, target, path + [name]))
    return results


target = os.environ.get('TEST_TARGET', 'UnknownTarget')
data = json.load(sys.stdin)
passed = set()
for summary in data.get('summaries', {}).get('_values', []):
    for testable in summary.get('testableSummaries', {}).get('_values', []):
        for test in testable.get('tests', {}).get('_values', []):
            passed.update(collect_passed(test, target))
for t in sorted(passed):
    print(t)
