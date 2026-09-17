# OrangeFox patch pack

Patch set for OrangeFox 12.1. Patches are grouped by **type of change**, not by recommended/optional profiles. All patches are applied by default.

## Use

From the Android source root:

```bash
chmod +x ofox_patches/apply.sh
./ofox_patches/apply.sh --check
./ofox_patches/apply.sh
```

Apply only one category if needed:

```bash
./ofox_patches/apply.sh --category adb-sideload
```

Use `--list` to view all patches.
