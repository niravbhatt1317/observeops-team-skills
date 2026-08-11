import json, sys
cfg = json.load(open(sys.argv[1]))
h = cfg.get("hooks")
print("hooks type:", type(h).__name__)
bad = []
for ev, v in (h or {}).items():
    print("  %-22s -> %s" % (ev, type(v).__name__))
    if not isinstance(v, list):
        bad.append("hooks.%s is %s, expected list" % (ev, type(v).__name__))
        v = [v]
    for i, e in enumerate(v):
        inner = e.get("hooks") if isinstance(e, dict) else None
        print("      [%d].hooks -> %s" % (i, type(inner).__name__))
        if not isinstance(inner, list):
            bad.append("hooks.%s[%d].hooks is %s, expected list" % (ev, i, type(inner).__name__))
print()
print("VERDICT:", ("BROKEN -> " + "; ".join(bad)) if bad else "all arrays correct")
