function sbr --description 'Clean, (re)boot, and run Spring Boot (mvn wrapper)'
    # Options:
    #   -p / --port <n>         : server port (also frees it first)
    #   -P / --profile <name>   : Spring profile (default: dev)
    #   -S / --skip-tests       : skip tests
    #   -U / --update-snapshots : mvn -U (refresh snapshots)
    #   -f / --fork             : run in forked mode (default false)
    #   -j / --jvm "<args>"     : JVM args (e.g., "-Xmx2g -XX:+UseZGC")
    #   -m / --module <path>    : run only a module (multi-module builds)
    argparse 'p/port=' 'P/profile=' 'S/skip-tests' 'U/update-snapshots' 'f/fork' 'j/jvm=' 'm/module=' -- $argv
    or return

    set -l mvn "./mvnw"
    set -l mvn_flags -q
    set -l run_flags

    # Profiles & tests
    if set -q _flag_profile
        set -a run_flags "-Dspring-boot.run.profiles=$_flag_profile"
    else
        set -a run_flags "-Dspring-boot.run.profiles=dev"
    end
    if set -q _flag_skip_tests
        set -a mvn_flags "-DskipTests"
    end
    if set -q _flag_update_snapshots
        set -a mvn_flags "-U"
    end
    if not set -q _flag_fork
        set -a run_flags "-Dspring-boot.run.fork=false"
    end
    if set -q _flag_jvm
        set -a run_flags "-Dspring-boot.run.jvmArguments=$_flag_jvm"
    end
    if set -q _flag_module
        set -a mvn_flags "-pl" $_flag_module "-am"
    end

    # Free the port if provided, then use it
    if set -q _flag_port
        freeport $_flag_port
        set -a run_flags "-Dserver.port=$_flag_port"
    end

    # Use all cores for Maven (faster dependency resolution/compiles)
    set -a mvn_flags "-T" "1C"

    # Clean -> run
    echo ">>> mvn $mvn_flags clean spring-boot:run $run_flags"
    $mvn $mvn_flags clean spring-boot:run $run_flags
end

