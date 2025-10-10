# Enhanced Fish Function with Profile Switching! 🐟# Usage Examples! 🎯

## Development (Default)
```fish
# Basic dev run (uses dev profile automatically)
sbr

# Dev with custom port
sbr -p 8081

# Dev with tests skipped (faster startup)
sbr -S

# Dev with debugging enabled
sbr -D

# Dev with verbose output
sbr -v
```

## Production Profile (Testing Locally)
```fish
# Run with production profile
sbr -P prod

# Production profile on different port
sbr -P prod -p 9090

# Production profile, skip tests, verbose output
sbr -P prod -S -v
```

## Other Profiles
```fish
# Staging profile
sbr -P staging

# Test profile
sbr -P test

# Multiple profiles (comma-separated in Spring)
sbr -P "prod,azure,monitoring"
```

## Advanced Usage
```fish
# Custom JVM settings
sbr -P prod -j "-Xmx4g -XX:+UseG1GC"

# Debug mode with production profile
sbr -P prod -D

# Just build the JAR (clean install)
sbr -P prod -c -S

# Multi-module project (specific module)
sbr -m backend-api -P dev
```

---

# Production JAR Deployment 📦

## 1. Build Production JAR
```fish
# From your dev machine
sbr -P prod -c -S

# Or directly with Maven
./mvnw clean package -DskipTests -Pprod
```

## 2. Production Server CLI Commands

### Basic Run
```bash
# Set profile via environment variable (RECOMMENDED)
export SPRING_PROFILES_ACTIVE=prod
java -jar cvmapp-backend-0.0.1-SNAPSHOT.jar

# Or via command line flag
java -jar cvmapp-backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod
```

### Production-Ready Command (Full)
```bash
java \
  -Xms512m \
  -Xmx2g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -Dspring.profiles.active=prod \
  -Dserver.port=8080 \
  -jar cvmapp-backend-0.0.1-SNAPSHOT.jar \
  > /var/log/cvmapp/app.log 2>&1 &
```

### With Systemd Service (Best Practice)
Create `/etc/systemd/system/cvmapp.service`:
```ini
[Unit]
Description=CVM App Backend
After=network.target mariadb.service

[Service]
Type=simple
User=cvmapp
WorkingDirectory=/opt/cvmapp
Environment="SPRING_PROFILES_ACTIVE=prod"
Environment="JAVA_OPTS=-Xms512m -Xmx2g -XX:+UseG1GC"
ExecStart=/usr/bin/java $JAVA_OPTS -jar /opt/cvmapp/cvmapp-backend.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl enable cvmapp
sudo systemctl start cvmapp
sudo systemctl status cvmapp
```

### Docker Deployment
```dockerfile
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy JAR
COPY target/cvmapp-backend-*.jar app.jar

# Environment
ENV SPRING_PROFILES_ACTIVE=prod
ENV JAVA_OPTS="-Xms512m -Xmx2g"

# Expose port
EXPOSE 8080

# Run
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

Run it:
```bash
docker build -t cvmapp-backend .
docker run -d \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DB_HOST=mariadb \
  -e DB_NAME=cvmapp \
  -e DB_USER=cvmapp_user \
  -e DB_PASS=secure_password \
  --name cvmapp-backend \
  cvmapp-backend
```

---

# Additional Script Improvements Made ✨

## What I Added:

1. **Profile Display** - Shows which profile you're using (visual feedback)
2. **Debug Mode Flag** (`-D`) - Quick remote debugging setup
3. **Verbose Flag** (`-v`) - See full Maven output when needed
4. **Clean Install Flag** (`-c`) - Build JAR without running
5. **Better Visual Feedback** - Colors and emojis for clarity
6. **Safety Checks** - Handles missing `freeport` command gracefully
7. **Port Display** - Shows what port you're running on
8. **Module Display** - Shows which module in multi-module projects

## Quick Reference Card:
```fish
sbr                    # Dev mode (default)
sbr -P prod            # Production mode
sbr -P staging         # Staging mode
sbr -p 8081            # Custom port
sbr -S                 # Skip tests
sbr -D                 # Debug mode
sbr -v                 # Verbose output
sbr -c                 # Build JAR only
sbr -P prod -S -c      # Build production JAR fast
```

The script is now more robust, informative, and production-ready! 🎉


# CODE 

```
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
```
