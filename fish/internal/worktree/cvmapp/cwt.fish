function cwt --description 'cvmapp-wt new + cd in one'
    if test (count $argv) -lt 1
        echo 'usage: cwt <branch> [base]' >&2
        return 2
    end
    set -l p (cvmapp-wt new $argv); or return $status
    cd $p;
end
