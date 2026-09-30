#!/usr/bin/env bash

set -u
shopt -s nullglob

usage() {
    cat <<'EOF'
Usage: tools/profile-anush.sh [OPTIONS]

Sample an Anush/Quickshell process tree and write CSV metrics.

Options:
  --pid PID           Quickshell PID (auto-detected when exactly one exists)
  --interval SECONDS  Delay between samples (default: 1)
  --count COUNT       Number of samples; 0 runs until interrupted (default: 60)
  --output PATH       Write CSV to PATH instead of stdout
  -h, --help          Show this help
EOF
}

root_pid=""
interval=1
count=60
output=/dev/stdout

while (($#)); do
    case "$1" in
        --pid)
            (($# >= 2)) || { printf 'profile-anush: --pid needs a value\n' >&2; exit 2; }
            root_pid=$2
            shift 2
            ;;
        --interval)
            (($# >= 2)) || { printf 'profile-anush: --interval needs a value\n' >&2; exit 2; }
            interval=$2
            shift 2
            ;;
        --count)
            (($# >= 2)) || { printf 'profile-anush: --count needs a value\n' >&2; exit 2; }
            count=$2
            shift 2
            ;;
        --output)
            (($# >= 2)) || { printf 'profile-anush: --output needs a value\n' >&2; exit 2; }
            output=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'profile-anush: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ $interval =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] || {
    printf 'profile-anush: interval must be a non-negative number\n' >&2
    exit 2
}
[[ $count =~ ^[0-9]+$ ]] || {
    printf 'profile-anush: count must be a non-negative integer\n' >&2
    exit 2
}

if [[ -z $root_pid ]]; then
    mapfile -t candidates < <(pgrep -x quickshell 2>/dev/null || true)
    if ((${#candidates[@]} != 1)); then
        printf 'profile-anush: expected one quickshell process, found %d; pass --pid\n' \
            "${#candidates[@]}" >&2
        exit 1
    fi
    root_pid=${candidates[0]}
fi

[[ $root_pid =~ ^[0-9]+$ && -r /proc/$root_pid/status ]] || {
    printf 'profile-anush: PID %s is not readable\n' "$root_pid" >&2
    exit 1
}

output_dir=$(dirname -- "$output")
[[ -d $output_dir ]] || {
    printf 'profile-anush: output directory does not exist: %s\n' "$output_dir" >&2
    exit 1
}

clock_ticks=$(getconf CLK_TCK 2>/dev/null || printf '100\n')
start_ns=$(date +%s%N)
previous_ns=$start_ns
previous_ticks=""

process_tree() {
    local -a queue=("$root_pid") result=()
    local cursor=0 pid child parent
    declare -A seen=()
    declare -A children=()

    # Snapshot the process table once. The previous implementation rescanned
    # every /proc status file once per discovered descendant, which made a
    # nominal one-second sample take roughly seven seconds on a busy desktop.
    while read -r child parent; do
        [[ -n $child && -n $parent ]] && children[$parent]+=" $child"
    done < <(ps -eo pid=,ppid=)

    while ((cursor < ${#queue[@]})); do
        pid=${queue[$cursor]}
        ((cursor += 1))
        [[ -r /proc/$pid/status && -z ${seen[$pid]+present} ]] || continue
        seen[$pid]=1
        result+=("$pid")

        for child in ${children[$pid]-}; do
            [[ -z ${seen[$child]+present} ]] && queue+=("$child")
        done
    done

    printf '%s\n' "${result[@]}"
}

printf 'timestamp,elapsed_s,root_pid,processes,children,rss_kib,pss_kib,private_dirty_kib,threads,fds,cpu_pct,voluntary_cs,nonvoluntary_cs\n' >"$output"

sample=0
while ((count == 0 || sample < count)); do
    [[ -r /proc/$root_pid/status ]] || {
        printf 'profile-anush: PID %s exited after %d samples\n' "$root_pid" "$sample" >&2
        exit 1
    }

    mapfile -t pids < <(process_tree)
    rss=0
    pss=0
    private_dirty=0
    threads=0
    fds=0
    ticks=0
    voluntary=0
    nonvoluntary=0

    for pid in "${pids[@]}"; do
        status=/proc/$pid/status
        [[ -r $status ]] || continue
        read -r process_rss process_threads process_voluntary process_nonvoluntary \
            < <(awk '
                /^VmRSS:/ { rss=$2 }
                /^Threads:/ { threads=$2 }
                /^voluntary_ctxt_switches:/ { voluntary=$2 }
                /^nonvoluntary_ctxt_switches:/ { nonvoluntary=$2 }
                END { print rss+0, threads+0, voluntary+0, nonvoluntary+0 }
            ' "$status" 2>/dev/null)
        rss=$((rss + process_rss))
        threads=$((threads + process_threads))
        voluntary=$((voluntary + process_voluntary))
        nonvoluntary=$((nonvoluntary + process_nonvoluntary))

        if [[ -r /proc/$pid/smaps_rollup ]]; then
            read -r process_pss process_private_dirty < <(awk '
                /^Pss:/ { pss=$2 }
                /^Private_Dirty:/ { dirty=$2 }
                END { print pss+0, dirty+0 }
            ' "/proc/$pid/smaps_rollup" 2>/dev/null)
            pss=$((pss + process_pss))
            private_dirty=$((private_dirty + process_private_dirty))
        fi

        if [[ -d /proc/$pid/fd ]]; then
            fd_entries=(/proc/"$pid"/fd/*)
            fds=$((fds + ${#fd_entries[@]}))
        fi

        if [[ -r /proc/$pid/stat ]]; then
            value=$(awk '{ line=$0; sub(/^.*\) /, "", line); split(line, field, " "); print field[12] + field[13] + field[14] + field[15] }' "/proc/$pid/stat" 2>/dev/null)
            ticks=$((ticks + ${value:-0}))
        fi
    done

    now_ns=$(date +%s%N)
    elapsed=$(awk -v now="$now_ns" -v start="$start_ns" 'BEGIN { printf "%.3f", (now-start)/1000000000 }')
    cpu=0.000
    if [[ -n $previous_ticks ]]; then
        cpu=$(awk -v current="$ticks" -v previous="$previous_ticks" \
            -v now="$now_ns" -v before="$previous_ns" -v hz="$clock_ticks" \
            'BEGIN { dt=(now-before)/1000000000; if (dt > 0) printf "%.3f", 100*(current-previous)/hz/dt; else print "0.000" }')
    fi

    timestamp=$(date --iso-8601=seconds)
    printf '%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d\n' \
        "$timestamp" "$elapsed" "$root_pid" "${#pids[@]}" "$(( ${#pids[@]} - 1 ))" \
        "$rss" "$pss" "$private_dirty" "$threads" "$fds" "$cpu" \
        "$voluntary" "$nonvoluntary" >>"$output"

    previous_ticks=$ticks
    previous_ns=$now_ns
    ((sample += 1))
    ((count == 0 || sample < count)) && sleep "$interval"
done
