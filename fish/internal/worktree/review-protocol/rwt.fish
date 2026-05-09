function rwt --description 'rp-wt new + cd in one'
    if test (count $argv) -lt 1
        echo 'usage: rwt <branch> [base]' >&2
        return 2
    end
    set -l p (rp-wt new $argv); or return $status
    cd $p;
end
