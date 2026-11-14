#!/usr/bin/env python3
"""Compare on-chain runtime code vs forge-compiled deployedBytecode.

Usage: compare-bytecode.py <artifact.json> <onchain.txt> [ADDR ...]
- artifact.json: forge artifact (out/<Contract>.sol/<Contract>.json)
- onchain.txt: file whose content is the eth_getCode hex string (0x-prefixed ok)
- ADDR: candidate 20-byte addresses for immutable patch attempts (e.g. router, permit2)

Prints lengths, keccak256 (eth_hash/pycryptodome if available, else NONE),
diff ranges, immutable-slot analysis, masked comparison, and patch-match attempts.
Keccak values in deliverables are produced with `cast keccak` (authoritative);
this script's keccak is a cross-check when a keccak library is present.
"""
import json, sys, itertools

def keccak(b):
    try:
        from eth_hash.auto import keccak as k
        return k(b).hex()
    except Exception:
        pass
    try:
        from Crypto.Hash import keccak as ck
        return ck.new(digest_bits=256, data=b).hexdigest()
    except Exception:
        return None

def load_hex(path):
    s = open(path).read().strip()
    if s.startswith("0x") or s.startswith("0X"):
        s = s[2:]
    return bytes.fromhex(s)

def main():
    art = json.load(open(sys.argv[1]))
    onchain = load_hex(sys.argv[2])
    db = art["deployedBytecode"]
    obj = db["object"]
    compiled = bytes.fromhex(obj[2:] if obj.startswith("0x") else obj)
    refs = db.get("immutableReferences", {})
    print(f"compiled_len={len(compiled)} onchain_len={len(onchain)}")
    print(f"compiled_keccak={keccak(compiled)}")
    print(f"onchain_keccak={keccak(onchain)}")
    print(f"immutable_ref_groups={len(refs)}")
    for astid, occs in refs.items():
        print(f"  astId={astid} occurrences={occs}")
    if compiled == onchain:
        print("VERDICT=EXACT_MATCH")
        return
    if len(compiled) != len(onchain):
        print(f"VERDICT=LENGTH_MISMATCH compiled={len(compiled)} onchain={len(onchain)}")
        n = min(len(compiled), len(onchain))
        i = 0
        while i < n and compiled[i] == onchain[i]:
            i += 1
        print(f"common_prefix_bytes={i}")
        return
    diffs = [i for i in range(len(compiled)) if compiled[i] != onchain[i]]
    print(f"diff_byte_count={len(diffs)} first={diffs[0] if diffs else None} last={diffs[-1] if diffs else None}")
    ranges = []
    for i in diffs:
        if ranges and i == ranges[-1][1] + 1:
            ranges[-1][1] = i
        else:
            ranges.append([i, i])
    print(f"diff_ranges={ranges}")
    slots = []
    for astid, occs in refs.items():
        for o in occs:
            slots.append((o["start"], o["start"] + o["length"] - 1, astid))
    print(f"immutable_slots={slots}")
    covered = all(any(s <= i <= e for s, e, _ in slots) for i in diffs)
    print(f"all_diffs_inside_immutable_slots={covered}")
    for s, e, astid in slots:
        print(f"  slot astId={astid} [{s}..{e}]: compiled={compiled[s:e+1].hex()} onchain={onchain[s:e+1].hex()}")
    def masked(b):
        ba = bytearray(b)
        for s, e, _ in slots:
            for i in range(s, e + 1):
                ba[i] = 0
        return bytes(ba)
    print(f"masked_equal={masked(compiled) == masked(onchain)} masked_keccak={keccak(masked(compiled))}")
    addrs = [bytes.fromhex(a[2:] if a.startswith("0x") else a) for a in sys.argv[3:]]
    if refs and addrs:
        groups = list(refs.keys())
        for combo in itertools.product(addrs, repeat=len(groups)):
            patched = bytearray(compiled)
            for astid, val in zip(groups, combo):
                for o in refs[astid]:
                    slot = b"\x00" * (o["length"] - len(val)) + val if o["length"] >= len(val) else val[-o["length"]:]
                    patched[o["start"]:o["start"] + o["length"]] = slot
            if bytes(patched) == onchain:
                print(f"PATCH_MATCH assignment={dict(zip(groups, [c.hex() for c in combo]))}")
                return
        print("PATCH_MATCH=none (tried all assignments of given addresses)")

if __name__ == "__main__":
    main()
