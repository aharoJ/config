You don’t actually “source” Starship like a normal script — you initialize it for Fish by running its init function and pointing it to your config file. Since your config lives at `~/.config/starship/starship.toml`, here’s how you set it up:

### 1. Point Starship to Your Config

Add this to your `~/.config/fish/config.fish` (or any file in `~/.config/fish/conf.d/`):

```fish
# Tell starship where to find your config
set -x STARSHIP_CONFIG ~/.config/starship/starship.toml

# Initialize starship for fish
starship init fish | source
```

### 2. Reload Your Shell

Either restart your terminal or just run:

```fish
source ~/.config/fish/config.fish
```
