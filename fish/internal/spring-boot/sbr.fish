# path: ~/.config/fish/internal/spring-boot/sbr.fish
function sbr --description 'Clean, (re)boot, and run Spring Boot (mvn wrapper)'
    # Options:
    #   -p / --port <n>         : server port (also frees it first)
    #   -P / --profile <name>   : Spring profile (default: dev)
    #   -S / --skip-tests       : skip tests
    #   -U / --update-snapshots : mvn -U (refresh snapshots)
    #   -f / --fork             : run in forked mode (default false)
    #   -j / --jvm "<args>"     : JVM args (e.g., "-Xmx2g -XX:+UseZGC")
    #   -m / --module <path>    : run only a module (multi-module builds)
    #   -c / --clean-install    : run clean install instead of clean run
    #   -D / --debug            : enable remote debugging on port 5005
    #   -v / --verbose          : show full maven output (disable -q)
    
    argparse 'p/port=' 'P/profile=' 'S/skip-tests' 'U/update-snapshots' 'f/fork' 'j/jvm=' 'm/module=' 'c/clean-install' 'D/debug' 'v/verbose' -- $argv
    or return
    
    set -l mvn "./mvnw"
    set -l mvn_flags
    set -l run_flags
    set -l profile "dev"  # default profile
    
    # Quiet mode (disable with -v/--verbose)
    if not set -q _flag_verbose
        set -a mvn_flags "-q"
    end
    
    # Profile handling
    if set -q _flag_profile
        set profile $_flag_profile
    end
    set -a run_flags "-Dspring-boot.run.profiles=$profile"
    
    # Test skipping
    if set -q _flag_skip_tests
        set -a mvn_flags "-DskipTests"
    end
    
    # Update snapshots
    if set -q _flag_update_snapshots
        set -a mvn_flags "-U"
    end
    
    # Fork mode (default: false for faster hot reload)
    if not set -q _flag_fork
        set -a run_flags "-Dspring-boot.run.fork=false"
    end
    
    # JVM arguments
    if set -q _flag_jvm
        set -a run_flags "-Dspring-boot.run.jvmArguments=$_flag_jvm"
    end
    
    # Debug mode
    if set -q _flag_debug
        set -l debug_args "-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"
        if set -q _flag_jvm
            # Append to existing JVM args
            set run_flags[-1] "-Dspring-boot.run.jvmArguments=$_flag_jvm $debug_args"
        else
            set -a run_flags "-Dspring-boot.run.jvmArguments=$debug_args"
        end
        echo "🐛 Debug mode enabled on port 5005"
    end
    
    # Module selection (for multi-module projects)
    if set -q _flag_module
        set -a mvn_flags "-pl" $_flag_module "-am"
    end
    
    # Port management
    if set -q _flag_port
        if command -q freeport
            freeport $_flag_port
        else
            echo "⚠️  freeport command not found, skipping port cleanup"
        end
        set -a run_flags "-Dserver.port=$_flag_port"
    end
    
    # Parallel builds (use all CPU cores)
    set -a mvn_flags "-T" "1C"
    
    # Display what we're doing
    set_color green
    echo "🚀 Spring Boot Runner"
    set_color normal
    echo "   Profile: $profile"
    if set -q _flag_port
        echo "   Port: $_flag_port"
    end
    if set -q _flag_module
        echo "   Module: $_flag_module"
    end
    if set -q _flag_debug
        echo "   Debug: Enabled (port 5005)"
    end
    echo ""
    
    # Execute Maven
    if set -q _flag_clean_install
        echo ">>> $mvn $mvn_flags clean install"
        $mvn $mvn_flags clean install
    else
        echo ">>> $mvn $mvn_flags clean spring-boot:run $run_flags"
        $mvn $mvn_flags clean spring-boot:run $run_flags
    end
end
