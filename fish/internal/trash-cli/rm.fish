function rm --description 'Safe delete via trash-cli (interactive shells)'
    # Keep scripts safe: only intercept in interactive shells.
    status is-interactive; or exec command rm $argv

    if type -q trash-put
        trash-put $argv
    else
        command rm -I $argv
    end
end

