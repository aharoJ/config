function swt --description 'stage-wt new + cd + claude in one'
    if test (count $argv) -lt 1
        echo 'usage: swt <branch> [base]' >&2
        return 2
    end
    set -l p (stage-wt new $argv); or return $status
    cd $p;
end
