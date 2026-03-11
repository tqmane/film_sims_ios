#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import hmac
import os
import shutil
import subprocess
import sys
from pathlib import Path

MAGIC = b"FSAES01"
MASTER_KEY = os.environ.get("FILMSIMS_MASTER_KEY", "")
if not MASTER_KEY:
    print("error: FILMSIMS_MASTER_KEY environment variable is not set.", file=sys.stderr)
    raise SystemExit(1)
ENCRYPTION_KEY = hashlib.sha256(f"enc:{MASTER_KEY}".encode("utf-8")).hexdigest()
AUTH_KEY = hashlib.sha256(f"mac:{MASTER_KEY}".encode("utf-8")).digest()

ROOT = Path(__file__).resolve().parents[1]
SOURCE_TARGETS = [
    (ROOT / "Sources/FilmSims/Resources/luts", ROOT / "Sources/FilmSims/SecureResources/luts"),
    (ROOT / "Sources/FilmSims/Resources/watermark", ROOT / "Sources/FilmSims/SecureResources/watermark"),
]


def encrypt_bytes(data: bytes, iv: bytes) -> bytes:
    result = subprocess.run(
        [
            "openssl",
            "enc",
            "-aes-256-cbc",
            "-e",
            "-nosalt",
            "-K",
            ENCRYPTION_KEY,
            "-iv",
            iv.hex(),
        ],
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    cipher_text = result.stdout
    header = MAGIC + iv + cipher_text
    mac = hmac.new(AUTH_KEY, header, hashlib.sha256).digest()
    return header + mac


def encrypt_tree(source_root: Path, destination_root: Path) -> int:
    if destination_root.exists():
        shutil.rmtree(destination_root)
    destination_root.mkdir(parents=True, exist_ok=True)

    encrypted_count = 0
    for source_file in sorted(source_root.rglob("*")):
        if not source_file.is_file():
            continue

        relative_path = source_file.relative_to(source_root)
        destination_file = destination_root / relative_path
        destination_file = destination_file.with_name(destination_file.name + ".enc")
        destination_file.parent.mkdir(parents=True, exist_ok=True)

        plain_bytes = source_file.read_bytes()
        encrypted_bytes = encrypt_bytes(plain_bytes, os.urandom(16))
        destination_file.write_bytes(encrypted_bytes)
        encrypted_count += 1

    return encrypted_count


def main() -> int:
    total = 0
    for source_root, destination_root in SOURCE_TARGETS:
        if not source_root.exists():
            print(f"skip: missing {source_root}")
            continue
        count = encrypt_tree(source_root, destination_root)
        print(f"encrypted {count} files -> {destination_root.relative_to(ROOT)}")
        total += count

    if total == 0:
        print("no resources were encrypted", file=sys.stderr)
        return 1

    print(f"done: {total} files encrypted")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
