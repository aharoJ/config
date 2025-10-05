# TOML
brew install taplo

# YAML
brew install yamlfmt
npm  -g install yaml-language-server
pipx install yamllint   # or: pip install --user yamllint

# Shell
npm  -g install bash-language-server
brew install shellcheck shfmt

# Fish (formatter is built in; linter is built in to nvim-lint)
brew install fish

# Optional Fish LSP (nice, but not required)
# Requires Rust toolchain: https://rustup.rs
cargo install fish-lsp


# daemons & formatters
npm -g i @fsouza/prettierd prettier eslint_d
# optional: install the tailwind plugin globally too (project-local is preferred)
# npm -g i prettier-plugin-tailwindcss

brew install yamlfmt shfmt taplo stylua


