#!/bin/bash

set -e

DEFAULT_SOCK="/tmp/jam_target.sock"

# List of available targets
AVAILABLE_TARGETS=(
    "jamzig"
    "jamduna"
    "jamixir"
    "jamzilla"
    "javajam"
    "spacejam"
    "vinwolf"
)

cleanup() {
    # Prevent multiple cleanup calls
    if [ "$CLEANUP_DONE" = "true" ]; then
        return
    fi
    CLEANUP_DONE=true
    
    echo "Cleaning up..."
    if [ ! -z "$TARGET_PID" ]; then
        echo "Killing target $TARGET_PID"
        kill $TARGET_PID 2>/dev/null || true
    fi
    rm -f "$DEFAULT_SOCK"
}

run() {
    local target="$1"
    local command="$2"
    target_dir=$(find targets -name "$target*" -type d | head -1)
    # Find the subdirectory with the most recent modification date
    target_dir=$(find "$target_dir" -maxdepth 1 -type d | tail -n +2 | xargs ls -dt | head -1)
    echo "Run $target on $target_dir"
    # Set up trap to cleanup on exit
    trap cleanup EXIT INT TERM
    pushd "$target_dir" > /dev/null
    eval "$command" &
    TARGET_PID=$!
    popd > /dev/null
    sleep 3
    echo "Waiting for target termination (pid=$TARGET_PID)"
    wait $TARGET_PID
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target>"
    echo "Available targets: ${AVAILABLE_TARGETS[*]}"
    exit 1
fi

run_jamzig() {
    run "jamzig" "./tiny/linux/x86_64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
}

run_jamduna() {
    run "jamduna" "./duna_target_linux -socket $DEFAULT_SOCK"
}

run_jamixir() {
    run "jamixir" "./jamixir fuzzer --socket-path $DEFAULT_SOCK"
}

run_jamzilla() {
    run "jamzilla" "./fuzzserver-tiny-amd64-linux -socket $DEFAULT_SOCK"
}

run_javajam() {
    run "javajam" "./bin/javajam fuzz $DEFAULT_SOCK"
}

run_spacejam() {
    run "spacejam" "./spacejam -vv fuzz target $DEFAULT_SOCK"
}

run_vinwolf() {
    run "vinwolf" "./linux/tiny/x86_64/vinwolf-target --fuzz $DEFAULT_SOCK"
}

case "$1" in
    "jamzig") run_jamzig ;;
    "jamduna") run_jamduna ;;        
    "jamixir") run_jamixir ;;        
    "jamzilla") run_jamzilla ;;        
    "javajam") run_javajam ;;        
    "spacejam") run_spacejam ;;
    "vinwolf") run_vinwolf ;;
    *)
        echo "Unknown target '$1'"
        echo "Available targets: ${AVAILABLE_TARGETS[*]}"
        exit 1
        ;;
esac

