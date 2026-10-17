"""Select an available iPad on iOS 26.5 or newer; never silently skip tests."""

import json
import subprocess


def select_simulator(devices):
    candidates = []
    for runtime, entries in devices.items():
        if not runtime.startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
            continue
        version = tuple(int(part) for part in runtime.split("iOS-")[1].split("-"))
        if version < (26, 5):
            continue
        for device in entries:
            if device.get("isAvailable") and device["name"].startswith("iPad"):
                candidates.append((version, device["name"], device["udid"]))
    if not candidates:
        raise SystemExit("No available iPad simulator with iOS >= 26.5. Check the runner image.")
    return max(candidates)[2]


if __name__ == "__main__":
    result = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"])
    print(f"SIMULATOR_ID={select_simulator(json.loads(result)['devices'])}")
