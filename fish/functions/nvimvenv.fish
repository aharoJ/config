function nvimvenv
  if test -e "$VIRTUAL_ENV" -a -f "$VIRTUAL_ENV/bin/activate.fish"
    source "$VIRTUAL_ENV/bin/activate.fish"
    command nvim $argv
    deactivate
  else
    command nvim $argv
  end
end

