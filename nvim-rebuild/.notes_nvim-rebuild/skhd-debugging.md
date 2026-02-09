# skhd.zig Debugging Playbook

## The Input Stack (bottom → top)

```
Physical key → Karabiner-Elements → macOS → skhd → yabai
```

When bindings stop working, isolate WHICH layer broke.

---

## Step 1: Is It Karabiner or skhd?

**Test Karabiner directly:** Press `Hyper+[` (desktop switch left). This is Karabiner-only — skhd is not involved.

- Works → Karabiner is fine, problem is skhd
- Fails → Karabiner is the problem (check permissions below)

**Confirm with EventViewer:** Open Karabiner-EventViewer, press CapsLock+key. You should see `left_command + left_control + left_option + left_shift` flags. If you see raw `caps_lock`, Karabiner lost the device grab.

## Step 2: Is skhd Running?

```bash
pgrep -fl skhd
brew services list | grep skhd
```

## Step 3: Does the Config Parse?

```bash
skhd -V
```

- Sits silently → config is clean
- `error: ParseErrorOccurred` → config has a syntax error

## Step 4: Isolate the Broken Module

Comment out ALL `.load` lines in `skhdrc`. Uncomment one at a time, running `skhd -V` after each. The one that triggers `ParseErrorOccurred` is the culprit.

```
# .load "modules/navigation.skhdrc"     ← uncomment, test, re-comment if clean
# .load "modules/manipulation.skhdrc"
# .load "modules/layout.skhdrc"
# .load "modules/resize.skhdrc"
# .load "modules/services.skhdrc"
# .load "modules/apps.skhdrc"
# .load "modules/scripts.skhdrc"
```

---

## Known skhd.zig Parser Traps

### 1. Missing Space Around Colon

```
rshift - a: /path/to/app     ← ❌ BREAKS (no space before colon)
rshift - a : /path/to/app    ← ✅ WORKS  (space-colon-space)
```

### 2. No Variable or Tilde Expansion

```
hyper - g : python3 "$HOME/.scripts/foo.py"         ← ❌ BREAKS
hyper - g : python3 ~/.scripts/foo.py               ← ❌ BREAKS
hyper - g : python3 /Users/aharoj/.scripts/foo.py   ← ✅ WORKS
```

Always use absolute paths. No `$HOME`, no `~`.

### 3. Duplicate Keybindings Across Modules

```
# layout.skhdrc
hyper - b : yabai -m space --balance

# scripts.skhdrc
hyper - b : python3 /some/script.py    ← ❌ BREAKS (duplicate key)
```

Original skhd did last-write-wins. skhd.zig errors on duplicate bindings across `.load` modules. One key = one module, no exceptions.

---

## Karabiner Debugging (When It IS Karabiner)

### Permissions

System Settings → Privacy & Security → Input Monitoring:
- `Karabiner-Core-Service` ✓
- `Karabiner-EventViewer` ✓

### HHKB Bluetooth Re-grab Failure

After HHKB sleeps and reconnects, Karabiner may fail to re-grab the device. Fix:

```bash
launchctl kickstart -k gui/$(id -u)/org.pqrs.karabiner.karabiner_grabber
launchctl kickstart -k gui/$(id -u)/org.pqrs.karabiner.karabiner_observer
```

### Grabber Logs

```bash
tail -f /var/log/karabiner/grabber.log
```

Look for fresh entries with today's date and your HHKB (vendor 1278, product 33). Stale logs = daemon not running.

### Virtual HID Driver

```bash
systemextensionsctl list | grep karabiner
```

If missing, reinstall: `brew reinstall --cask karabiner-elements`

---

## Quick Reference

| Symptom | Likely Cause | Fix |
|---|---|---|
| ALL bindings dead | skhd crashed or parse error | `skhd -V` to check |
| Hyper bindings dead, rshift works | Karabiner lost grab | Kickstart grabber |
| Parse error | Syntax issue in module | Isolate with comment-out method |
| Works after restart, fails later | HHKB Bluetooth re-grab | Automate grabber kickstart on wake |
