#!/usr/bin/env python3
"""Prepare verified manga PDFs outside the checkout. Missing assets fail; no silent skip."""
import argparse, hashlib, json, os, re, tempfile, subprocess
from pathlib import Path
MANIFEST_URL = "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/pdf-manifest.json"
MANIFEST_SHA256 = "4ffcdc152b18fe631b7db4f749907caa1ccf5888511137784d23774abf5d7ed4"
def fetch(url):
    return subprocess.check_output(["curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https", "--proto-redir", "=https", "--max-time", "90", url])
def digest(data): return hashlib.sha256(data).hexdigest()
def resolve(entries, name):
    mt = re.fullmatch(r"tameshibu_episode(\d+)(?:_\d+)?_([a-z_]+)\.pdf", name)
    if not mt: raise ValueError("Unsupported fixture name: " + name)
    lang = {"tl":"fil", "in":"id"}.get(mt[2], mt[2])
    matches = [e for e in entries if e["episode"] == int(mt[1]) and e["language_key"] == lang]
    if len(matches) != 1: raise ValueError("Ambiguous or missing fixture: " + name)
    return matches[0]
def valid(data, entry):
    return len(data) == entry["bytes"] and digest(data) == entry["sha256"] and data.startswith(b"%PDF-")
def atomic(path, data):
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=".verified-")
    try:
        with os.fdopen(fd, "wb") as stream: stream.write(data)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp): os.unlink(temp)
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache-dir", required=True, type=Path)
    ap.add_argument("--input-dir", type=Path, help="Reuse only inputs matching fixed manifest size/SHA")
    ap.add_argument("--manifest", type=Path, help="Offline copy of the pinned fixed manifest")
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--files", nargs="+", default=["tameshibu_episode1_2_"+x+".pdf" for x in ["en","ja","ko","zh_cn"]])
    a = ap.parse_args(); root = a.cache_dir.expanduser().resolve()
    checkout = Path(__file__).resolve().parents[1]
    if root.is_relative_to(checkout): raise ValueError("Cache must be outside the checkout")
    if a.offline and not a.manifest: raise ValueError("Offline preparation requires --manifest")
    data = a.manifest.read_bytes() if a.manifest else fetch(MANIFEST_URL)
    if digest(data) != MANIFEST_SHA256: raise ValueError("Fixed manifest SHA-256 mismatch")
    manifest = json.loads(data); root.mkdir(parents=True, exist_ok=True)
    receipt = {}; old = root / "fixture-index.json"
    if old.exists(): receipt = json.loads(old.read_text())
    for name in a.files:
        entry = resolve(manifest["entries"], name)
        if Path(name).name != name: raise ValueError("Invalid path")
        target = root / name
        content = target.read_bytes() if target.exists() else b""
        if not valid(content, entry) and a.input_dir:
            for candidate in [a.input_dir / name, a.input_dir / entry["filename"]]:
                if candidate.is_file() and valid(candidate.read_bytes(), entry):
                    content = candidate.read_bytes(); break
        if not valid(content, entry):
            if a.offline: raise ValueError("Missing verified offline PDF: " + name)
            url = entry["new_download_url"]
            if not url.startswith("https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/"): raise ValueError("Unexpected download URL")
            content = fetch(url)
        if not valid(content, entry): raise ValueError("PDF size/header/SHA mismatch: " + name)
        if not target.exists() or target.read_bytes() != content: atomic(target, content)
        receipt[name] = {"filename":entry["filename"], "bytes":len(content), "sha256":digest(content)}
    atomic(old, json.dumps(receipt, indent=2, sort_keys=True).encode())
    print("Verified fixtures: " + str(len(a.files)))
    print("MIHIRAKI_SAMPLE_PDF_DIR=" + str(root))
if __name__ == "__main__": main()
