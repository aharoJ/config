#!/bin/sh
# path: ~/.config/fish/internal/process/bsd-process-guard.sh
# description: Refuse misplaced BSD pkill/pgrep options before invoking either tool.
# patched: Shared guard linked as ~/.local/bin/pkill and ~/.local/bin/pgrep.
# date: 2026-10-17

tool=${0##*/}
case "$tool" in pkill|pgrep) ;; *) exit 2 ;; esac
first=1
options=1
pattern=
value=
for arg do
    if [ -n "$value" ]; then
        value=
        continue
    fi
    if [ -n "$pattern" ]; then
        case "$arg" in
            -*) printf '%s: misplaced option %s after pattern; put all options and their values before patterns\n' "$tool" "$arg" >&2; exit 2 ;;
        esac
        continue
    fi
    if [ -n "$first" ] && [ "$tool" = pkill ]; then
        first=
        signal=$(printf '%s' "$arg" | /usr/bin/tr '[:lower:]' '[:upper:]')
        case "$signal" in
            -[0-9]*|-SIG*|-HUP|-INT|-QUIT|-ILL|-TRAP|-ABRT|-IOT|-EMT|-FPE|-KILL|-BUS|-SEGV|-SYS|-PIPE|-ALRM|-TERM|-URG|-STOP|-TSTP|-CONT|-CHLD|-CLD|-TTIN|-TTOU|-IO|-POLL|-XCPU|-XFSZ|-VTALRM|-PROF|-WINCH|-INFO|-USR1|-USR2) continue ;;
        esac
    fi
    first=
    if [ -n "$options" ]; then
        case "$arg" in
            --) options=; continue ;;
            -?*)
                flags=${arg#-}
                while [ -n "$flags" ]; do
                    flag=${flags%"${flags#?}"}
                    flags=${flags#?}
                    case "$flag" in
                        u|U|g|G|t|P|F|s|d)
                            [ -n "$flags" ] || value=1
                            break ;;
                    esac
                done
                continue ;;
        esac
    fi
    pattern=1
done
exec "/usr/bin/$tool" "$@"
