#!/usr/bin/env python3
"""Inspect a local Archive or manually exported IPA; never export or contact Apple.

Signature/profile metadata inspection is NOT cryptographic trust validation.
Use a new output directory on every run. Original artifacts are read-only.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import zipfile


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def plist(path):
    data = path.read_bytes()
    try:
        return plistlib.loads(data)
    except plistlib.InvalidFileException:
        result = subprocess.run(
            ["/usr/bin/plutil", "-convert", "xml1", "-o", "-", str(path)],
            capture_output=True, check=True, timeout=30
        )
        return plistlib.loads(result.stdout)


def signature_metadata(executable):
    data = executable.read_bytes()
    if data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("Expected a thin little-endian 64-bit Mach-O")
    count = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(count):
        command, size = struct.unpack_from("<II", data, offset)
        if command == 0x1D:  # LC_CODE_SIGNATURE
            start, length = struct.unpack_from("<II", data, offset + 8)
            blob = data[start:start + length]
            magic, total, slots = struct.unpack_from(">III", blob)
            if magic != 0xFADE0CC0 or total > len(blob):
                raise ValueError("Unexpected signature container")
            entitlements = None
            directories = []
            for slot in range(slots):
                kind, location = struct.unpack_from(">II", blob, 12 + slot * 8)
                blob_magic, blob_length = struct.unpack_from(">II", blob, location)
                payload = blob[location:location + blob_length]
                if blob_magic == 0xFADE7171:  # XML entitlements
                    entitlements = plistlib.loads(payload[8:])
                if blob_magic == 0xFADE0C02:  # CodeDirectory
                    directories.append({"slot": kind, "sha256": hashlib.sha256(payload).hexdigest()})
            return {"entitlements": entitlements, "codeDirectories": directories,
                    "cryptographic_signature_verified": False, "trust_verified": False}
        if size < 8:
            raise ValueError("Invalid Mach-O load command")
        offset += size
    raise ValueError("No embedded signature")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--archive", type=Path, help="Matching Archive (required for IPA comparison)")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", default="12")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    source = args.artifact.resolve()
    summary = {"artifact": str(source), "expected_version": "1.0.4", "expected_build": args.build,
               "online_validation_performed": False, "export_performed": False}
    if source.suffix == ".ipa":
        if args.archive is None:
            parser.error("--archive is required for a new IPA")
        summary["ipa_sha256"] = sha(source)
        with zipfile.ZipFile(source) as archive:
            if any(n.startswith("/") or ".." in Path(n).parts for n in archive.namelist()):
                raise ValueError("Unsafe ZIP path")
        extracted = args.output / "Extracted"
        subprocess.run(["/usr/bin/ditto", "-x", "-k", str(source), str(extracted)], check=True, timeout=60)
        apps = list((extracted / "Payload").glob("*.app"))
    elif source.suffix == ".xcarchive":
        apps = list((source / "Products/Applications").glob("*.app"))
        summary["archive_info"] = plist(source / "Info.plist")
    else:
        parser.error("Expected .xcarchive or .ipa")
    if len(apps) != 1:
        raise ValueError("Expected exactly one app")
    app = apps[0]
    info = plist(app / "Info.plist")
    summary["info"] = info
    checks = {}
    for key, expected in {"CFBundleShortVersionString": "1.0.4", "CFBundleVersion": args.build,
                          "CFBundleIdentifier": "com.takumayamada22.PDFViewer",
                          "CFBundleName": "MihirakiPDF", "CFBundleExecutable": "MihirakiPDFViewer",
                          "CFBundleDisplayName": "MihirakiPDFViewer", "CFBundleDevelopmentRegion": "en"}.items():
        checks[key] = info.get(key) == expected
    executable = app / info["CFBundleExecutable"]
    summary["executable_sha256"] = sha(executable)
    summary["signature_metadata"] = signature_metadata(executable)
    raw = (app / "embedded.mobileprovision").read_bytes()
    start = raw.find(b"<?xml")
    end = raw.find(b"</plist>", start)
    if start < 0 or end < 0:
        raise ValueError("Cannot inspect profile XML")
    profile = plistlib.loads(raw[start:end + 8])
    summary["profile"] = {k: profile.get(k) for k in ["UUID", "Name", "CreationDate", "ExpirationDate", "TeamIdentifier", "Entitlements", "ProvisionsAllDevices"]}
    summary["profile"]["registered_device_count"] = len(profile.get("ProvisionedDevices", []))
    summary["profile"]["CMS_trust_verified"] = False
    entitlements = summary["signature_metadata"]["entitlements"] or {}
    checks["entitlements_match_profile"] = bool(entitlements) and all(profile["Entitlements"].get(k) == v for k, v in entitlements.items())
    checks["team"] = entitlements.get("com.apple.developer.team-identifier") == "B2E5F3M8V5"
    checks["application_identifier"] = entitlements.get("application-identifier") == "B2E5F3M8V5.com.takumayamada22.PDFViewer"
    summary["privacy_manifest"] = plist(app / "PrivacyInfo.xcprivacy")
    root = Path(__file__).resolve().parent.parent
    checks["manifest_matches_source"] = (app / "PrivacyInfo.xcprivacy").read_bytes() == (root / "MihirakiPDFViewer/PrivacyInfo.xcprivacy").read_bytes()
    checks["no_storekit_configuration"] = not any(app.rglob("*.storekit"))
    summary["embedded_frameworks"] = [str(p.relative_to(app)) for p in app.rglob("*.framework")]
    summary["embedded_dylibs"] = [str(p.relative_to(app)) for p in app.rglob("*.dylib")]
    summary["localizations"] = {}
    for locale in ["de", "en", "es", "fil", "fr", "id", "ja", "ko", "ne", "pt-BR", "vi", "zh-Hans", "zh-Hant"]:
        localized_info = plist(app / (locale + ".lproj/InfoPlist.strings"))
        strings = plist(app / (locale + ".lproj/Localizable.strings"))
        name = "見開きPDFビューア" if locale == "ja" else "MihirakiPDFViewer"
        badge = strings.get("koyomi_v2_badge_name", "")
        checks["names_" + locale] = localized_info.get("CFBundleDisplayName") == name and localized_info.get("CFBundleName") == "MihirakiPDF" and strings.get("app_name") == name
        checks["badge_" + locale] = bool(badge) and "2.0" not in badge
        if locale in ["en", "ja"]:
            checks["badge_" + locale] = badge == ("リリース記念こよみバッジ" if locale == "ja" else "Release Commemorative Koyomi Badge")
        summary["localizations"][locale] = {"displayName": localized_info.get("CFBundleDisplayName"), "bundleName": localized_info.get("CFBundleName"), "badge": badge, "logHeader": strings.get("MihirakiPDFViewer App Logs")}
    for name, command in {
        "linked-libraries": ["/usr/bin/otool", "-L", str(executable)],
        "binary-uuid": ["/usr/bin/dwarfdump", "--uuid", str(executable)],
        "assets": ["/usr/bin/xcrun", "--no-cache", "assetutil", "--info", str(app / "Assets.car")],
    }.items():
        result = subprocess.run(command, capture_output=True, timeout=60)
        (args.output / (name + ".txt")).write_bytes(result.stdout + result.stderr)
        checks[name + "_read"] = result.returncode == 0
        if name == "assets":
            for asset in ["KoyomiV2Badge", "TipIconBronze", "TipIconSilver", "TipIconGold"]:
                checks["asset_" + asset] = asset.encode() in result.stdout
    if args.archive:
        archive_app = args.archive / "Products/Applications/MihirakiPDFViewer.app"
        resources = ["PrivacyInfo.xcprivacy", "Assets.car"]
        resources += [str(p.relative_to(app)) for p in app.glob("*.lproj/*.strings")]
        checks["archive_resources_match"] = all((app / p).read_bytes() == (archive_app / p).read_bytes() for p in resources)
        summary["matching_archive"] = str(args.archive.resolve())
    files = {str(p.relative_to(app)): sha(p) for p in sorted(app.rglob("*")) if p.is_file()}
    (args.output / "app-files-sha256.json").write_text(json.dumps(files, indent=2))
    if source.suffix == ".ipa":
        checks["original_ipa_unchanged"] = sha(source) == summary["ipa_sha256"]
    summary["checks"] = checks
    summary["static_checks_passed"] = all(checks.values())
    (args.output / "inspection.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2, default=str))
    print(json.dumps({"output": str(args.output), "static_checks_passed": all(checks.values()), "failed": [k for k, v in checks.items() if not v]}, ensure_ascii=False))
    raise SystemExit(0 if all(checks.values()) else 1)


if __name__ == "__main__":
    main()
