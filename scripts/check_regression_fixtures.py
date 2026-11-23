"""Fail before simulator startup if required synthetic PDF inputs are absent or changed."""
import hashlib
import json
import re
from pathlib import Path

def check(root):
    folder = root / "testdata"
    manifest = json.loads((folder / "Regression8-fixtures.json").read_text())
    for entry in manifest["fixtures"]:
        path = folder / entry["name"]
        data = path.read_bytes()
        if len(data) != entry["bytes"] or hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"Regression fixture differs: {entry['name']}")
        if len(re.findall(rb"/Type /Page\b", data)) != 8:
            raise ValueError(f"Expected eight pages: {entry['name']}")
    return len(manifest["fixtures"])

if __name__ == "__main__":
    print(f"Verified {check(Path(__file__).resolve().parents[1])} synthetic regression PDFs.")
