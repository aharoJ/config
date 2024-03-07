function tmux_pwd
    set -l dir (string split -r -m1 '/' $PWD)[2]
    set -l parentdir (string split -r -m2 '/' $PWD)[2]
    echo "$parentdir/$dir"
end
