Totally—here’s a clean “brew-style” way to **clean ➜ reboot ➜ run** a Spring Boot app from fish, with nice shortcuts.

## Quick one-liners (no setup)

* **Clean + run (dev), skip tests, don’t fork (Ctrl-C stops it):**

```fish
./mvnw -q clean spring-boot:run -DskipTests -Dspring-boot.run.profiles=dev -Dspring-boot.run.fork=false
```

* **Force-reboot the app by freeing the port first (replace 8080 if needed):**

```fish
set -l p (lsof -ti tcp:8080); test -n "$p"; and kill -9 $p
./mvnw -q clean spring-boot:run -DskipTests -Dspring-boot.run.fork=false -Dspring-boot.run.profiles=dev -Dserver.port=8080
```

---

## Nice fish helpers (drop-in functions)

Paste these into `~/.config/fish/functions/` as files, or just source them in your shell. They give you a single command that behaves like `brew update && upgrade && cleanup`.

### 1) `freeport.fish`

```fish
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
```

### 2) `sbr.fish` (Spring Boot Run)

```fish
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
```

### Optional: tiny aliases/abbr (if you like)

```fish
abbr -a mclean './mvnw -q clean'
abbr -a mrun './mvnw -q -T 1C -DskipTests spring-boot:run -Dspring-boot.run.profiles=dev -Dspring-boot.run.fork=false'
abbr -a mjar './mvnw -q -T 1C clean package -DskipTests && java -jar (ls -t target/*.jar | head -n1)'
```

---

## Common flows

* **“Clean → reboot → run dev on 8080”**

```fish
sbr -S -P dev -p 8080
```

* **Run with fresh snapshots + custom JVM heap**

```fish
sbr -S -U -j "-Xms512m -Xmx2g"
```

* **Multi-module: run only `cvmapp-backend`**

```fish
sbr -S -m cvmapp-backend
```

* **Build a JAR and run it (closer to prod)**

```fish
./mvnw -q clean package -DskipTests && java -jar (ls -t target/*.jar | head -n1)
```

---

## Speed/quality tips

* Add **DevTools** for hot restart:

  ```xml
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
  </dependency>
  ```
* Use `-T 1C` (already in `sbr`) to parallelize Maven.
* Keep `-DskipTests` while iterating; drop it before commits/CI.
* Use profiles (`-P dev`, `-P local`) instead of editing `application.yml`.

If you want, I can tailor `sbr` to your repo layout (e.g., auto-detect module, default port, etc.).

