Yesss! 🎉 Glad it worked — and yeah, your old notes were solid but a bit too hacky for future you.
Here’s a **clean, future-proof version** of your notes — clear, step-by-step, and works on macOS M-series or Intel.

---

# 📝 eza Theme Setup (macOS)

## 1️⃣ Clone the Theme Repo

```sh
git clone https://github.com/eza-community/eza-themes.git ~/.config/eza/eza-themes
```

> 📌 You can place this anywhere, but `~/.config/eza/eza-themes` keeps it clean and predictable.

---

## 2️⃣ Tell eza Where to Look (macOS Fix)

By default, eza looks in `~/Library/Application Support/eza/` on macOS.
Instead, tell eza to use `~/.config/eza`:

```fish
set -Ux EZA_CONFIG_DIR ~/.config/eza
```

Add that to your `~/.config/fish/config.fish` so it sticks.

---

## 3️⃣ Create or Link Your Theme

Pick a theme and symlink it to `theme.yml`.
Example: **tokyonight** 🌙

```sh
ln -sf ~/.config/eza/eza-themes/themes/tokyonight.yml ~/.config/eza/theme.yml
```

Switch to **catppuccin** 🍬

```sh
ln -sf ~/.config/eza/eza-themes/themes/catppuccin.yml ~/.config/eza/theme.yml
```

---

## 4️⃣ Disable Conflicting Variables

Make sure `LS_COLORS` and `EZA_COLORS` aren’t overriding your theme:

```fish
set -e LS_COLORS
set -e EZA_COLORS
```

Put those in your `config.fish` too.

---

## 5️⃣ Test Your Setup

Check which theme is loading:

```sh
eza --debug
```

You should see:

```sh
Config directory: $HOME/.config/eza
Theme file: $HOME/.config/eza/theme.yml
```

