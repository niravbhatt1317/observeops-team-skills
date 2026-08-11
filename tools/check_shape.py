#!/usr/bin/env python3
"""Strict shape check for a Claude Code settings.json.

Exists because PowerShell's array handling can silently turn a one-element JSON
array into a bare object, and the PowerShell-side assertions in CI could not see
it: member access like $h.Stop.hooks.command works whether hooks is an array or a
single object, so a corrupt file looked healthy. Parse with something that cares
about the difference.
"""
import json, sys

cfg = json.load(open(sys.argv[1]))
bad = []

def want_list(path, v):
    if not isinstance(v, list):
        bad.append("%s is %s, expected array" % (path, type(v).__name__))
        return False
    return True

hooks = cfg.get("hooks")
if hooks is not None:
    if isinstance(hooks, dict):
        for ev, entries in hooks.items():
            if not want_list("hooks.%s" % ev, entries):
                continue
            for i, e in enumerate(entries):
                want_list("hooks.%s[%d].hooks" % (ev, i), (e or {}).get("hooks"))
    else:
        bad.append("hooks is %s, expected object" % type(hooks).__name__)

perms = cfg.get("permissions")
if isinstance(perms, dict):
    for k in ("allow", "deny", "ask", "additionalDirectories"):
        if k in perms:
            want_list("permissions.%s" % k, perms[k])

for key in ("enabledPlugins", "enableAllProjectMcpServers"):
    pass  # shape varies by version; not asserted

if bad:
    print("SHAPE BROKEN:")
    for b in bad:
        print("  -", b)
    print("\n--- file ---")
    print(json.dumps(cfg, indent=2)[:2000])
    sys.exit(1)
print("shape OK: every array is still an array")
