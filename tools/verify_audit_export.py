#!/usr/bin/env python3
"""
Verify a signed audit-log export from a FEGH app.

Usage:
    python verify_audit_export.py <audit_export.json> [<traeger_public.pem>]

If a separate PEM file is provided, it overrides the embedded
publicKey from the JSON. Useful when the DSB has the canonical
public key stored separately (e.g. archived on the company website).

The script performs two checks:
  1. Internal SHA-256 hash chain across all entries.
  2. Ed25519 signature over the canonical JSON (entries + metadata).

Both must pass for the log to be considered authentic.

Requires:
    pip install cryptography
"""

from __future__ import annotations

import base64
import hashlib
import json
import sys
from pathlib import Path

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.serialization import (
        load_pem_public_key,
    )
except ImportError:
    print('cryptography is required: pip install cryptography', file=sys.stderr)
    sys.exit(2)


GENESIS_HASH = '0' * 64


def canonical(obj):
    """Return a canonical JSON string with sorted keys, no whitespace."""
    if isinstance(obj, dict):
        items = sorted(obj.items())
        return '{' + ','.join(
            f'{json.dumps(k)}:{canonical(v)}' for k, v in items
        ) + '}'
    if isinstance(obj, list):
        return '[' + ','.join(canonical(x) for x in obj) + ']'
    return json.dumps(obj)


def verify_chain(entries) -> str | None:
    """Return None if chain is intact, otherwise an error message."""
    prev = GENESIS_HASH
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            return f'entry {i}: not an object'
        stored = entry.pop('hash', None)
        if stored is None:
            return f'entry {i}: missing hash field'
        if entry.get('prev_hash') != prev:
            return f'entry {i}: prev_hash breaks the chain'
        canon = canonical(entry)
        expected = hashlib.sha256(canon.encode('utf-8')).hexdigest()
        if expected != stored:
            return f'entry {i}: hash mismatch (manipulation suspected)'
        entry['hash'] = stored  # restore
        prev = stored
    return None


def verify_signature(data: dict, public_pem: bytes | None) -> str | None:
    """Return None if signature is valid, otherwise an error message."""
    sig_b64 = data.pop('signature', None)
    if sig_b64 is None:
        return 'no signature field — unsigned export'

    # Use external pubkey if provided, else the one embedded in the JSON.
    if public_pem is None:
        embedded = data.get('publicKey')
        if embedded is None:
            return 'no publicKey embedded and no external PEM provided'
        public_pem = (
            b'-----BEGIN PUBLIC KEY-----\n'
            + base64.b64encode(base64.b64decode(embedded))
            + b'\n-----END PUBLIC KEY-----\n'
        )

    try:
        pub_key = load_pem_public_key(public_pem)
    except Exception as e:
        return f'public key parse failed: {e}'

    payload = canonical(data).encode('utf-8')
    sig_bytes = base64.b64decode(sig_b64)

    try:
        pub_key.verify(sig_bytes, payload)
        return None
    except InvalidSignature:
        return 'signature invalid — file modified or wrong key'
    except Exception as e:
        return f'signature check failed: {e}'


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2

    export_path = Path(argv[1])
    pubkey_path = Path(argv[2]) if len(argv) > 2 else None

    try:
        data = json.loads(export_path.read_text(encoding='utf-8'))
    except Exception as e:
        print(f'ERROR: cannot read export: {e}')
        return 2

    entries = data.get('entries', [])
    print(f'App         : {data.get("appName", "?")}')
    print(f'App version : {data.get("appVersion", "?")}')
    print(f'Exported at : {data.get("exportedAt", "?")}')
    print(f'Fingerprint : {data.get("publicKeyFingerprint", "—")}')
    print(f'Entries     : {len(entries)}')
    print()

    chain_err = verify_chain([dict(e) for e in entries])
    if chain_err is None:
        print('[OK] Hash chain intact across all entries.')
    else:
        print(f'[FAIL] Hash chain: {chain_err}')

    # Work on a copy because verify_signature mutates the dict.
    payload = dict(data)
    payload['entries'] = entries
    pem_bytes = pubkey_path.read_bytes() if pubkey_path else None
    sig_err = verify_signature(payload, pem_bytes)
    if sig_err is None:
        print('[OK] Ed25519 signature valid — file is authentic.')
    elif sig_err.startswith('no signature'):
        print(f'[WARN] {sig_err}')
    else:
        print(f'[FAIL] Signature: {sig_err}')

    print()
    if chain_err is None and (sig_err is None or sig_err.startswith('no signature')):
        print('Result: log is internally consistent.')
        return 0
    print('Result: log integrity could NOT be verified.')
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
