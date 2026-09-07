"""Ensure upstream notices remain in the distributed third-party notice file."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
notices = (root / "THIRD_PARTY_NOTICES.txt").read_text()
for relative in (
    "Vendor/UnRAR/license.txt",
    "Vendor/UnRAR/acknow.txt",
    "DerivedDataRelease/SourcePackages/checkouts/Sparkle/LICENSE",
):
    upstream = (root / relative).read_text().strip()
    if upstream not in notices:
        raise SystemExit(f"Missing or outdated upstream license: {relative}")
header = (root / "Vendor/UnRAR/blake2sp.cpp").read_text().split("*/", 1)[0] + "*/"
if header not in notices or "4. Limitations and Disclaimers." not in notices:
    raise SystemExit("Missing BLAKE2 dedication or CC0 legal text")
print("Third-party notices match upstream license texts.")
