# Test Neovim startup speed
nvim --startuptime /tmp/startup.log -c "qa"

# View the log
nvim /tmp/startup.log
