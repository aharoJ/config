# path: ~/.config/fish/internal/spring-boot/sbt.fish
function sbt --description 'Run Spring Boot tests with profile support'
    # Options:
    #   -t / --test <class>     : specific test class (e.g., StudentServiceImplTest)
    #   -m / --method <name>    : specific test method (requires -t)
    #   -P / --profile <name>   : Spring profile (default: test)
    #   -M / --module <path>    : run only a module (multi-module builds)
    #   -T / --tag <tag>        : JUnit 5 tag filter (e.g., "unit", "integration")
    #   -e / --exclude <tag>    : exclude JUnit 5 tag
    #   -p / --parallel         : run tests in parallel
    #   -f / --fail-fast        : stop on first failure
    #   -q / --quiet            : suppress maven output (default: show test results)
    #   -r / --rerun            : rerun failing tests
    #   -c / --coverage         : generate coverage report (jacoco)
    
    argparse 't/test=' 'm/method=' 'P/profile=' 'M/module=' 'T/tag=' 'e/exclude=' 'p/parallel' 'f/fail-fast' 'q/quiet' 'r/rerun' 'c/coverage' -- $argv
    or return
    
    set -l mvn "./mvnw"
    set -l mvn_flags
    set -l profile "test"  # default profile for tests
    
    # Quiet mode (OFF by default for tests - you need to see results)
    if set -q _flag_quiet
        set -a mvn_flags "-q"
    end
    
    # Profile handling
    if set -q _flag_profile
        set profile $_flag_profile
    end
    set -a mvn_flags "-Dspring.profiles.active=$profile"
    
    # Specific test class
    if set -q _flag_test
        if set -q _flag_method
            # Class#method format
            set -a mvn_flags "-Dtest=$_flag_test#$_flag_method"
        else
            set -a mvn_flags "-Dtest=$_flag_test"
        end
    end
    
    # JUnit 5 tag filtering
    if set -q _flag_tag
        set -a mvn_flags "-Dgroups=$_flag_tag"
    end
    
    if set -q _flag_exclude
        set -a mvn_flags "-DexcludedGroups=$_flag_exclude"
    end
    
    # Module selection
    if set -q _flag_module
        set -a mvn_flags "-pl" $_flag_module "-am"
    end
    
    # Parallel execution
    if set -q _flag_parallel
        set -a mvn_flags "-T" "1C"
        set -a mvn_flags "-Dparallel=methods"
        set -a mvn_flags "-DuseUnlimitedThreads=true"
    end
    
    # Fail fast
    if set -q _flag_fail_fast
        set -a mvn_flags "-Dsurefire.failIfNoSpecifiedTests=false"
        set -a mvn_flags "--fail-fast"
    end
    
    # Rerun failing tests
    if set -q _flag_rerun
        set -a mvn_flags "-Dsurefire.rerunFailingTestsCount=2"
    end
    
    # Coverage report
    set -l goal "test"
    if set -q _flag_coverage
        set goal "verify"
        set -a mvn_flags "-Pcoverage"  # assumes you have a coverage profile
    end
    
    # Display what we're doing
    set_color green
    echo "🧪 Spring Boot Test Runner"
    set_color normal
    echo "   Profile: $profile"
    if set -q _flag_test
        echo "   Test: $_flag_test"
        if set -q _flag_method
            echo "   Method: $_flag_method"
        end
    end
    if set -q _flag_module
        echo "   Module: $_flag_module"
    end
    if set -q _flag_tag
        echo "   Tag: $_flag_tag"
    end
    if set -q _flag_coverage
        echo "   Coverage: Enabled"
    end
    echo ""
    
    # Execute
    echo ">>> $mvn $mvn_flags $goal"
    $mvn $mvn_flags $goal
end
