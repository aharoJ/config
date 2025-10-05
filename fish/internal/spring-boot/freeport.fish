function freeport --description 'Kill whatever is using a TCP port'
    set -l port $argv[1]
    test -n "$port"; or begin
        echo "usage: freeport <port>"; return 2
    end
    set -l pids (lsof -ti tcp:$port)
    if test -n "$pids"
        echo "Killing $pids on :$port"
        kill -9 $pids
    else
        echo "No process on :$port"
    end
end

