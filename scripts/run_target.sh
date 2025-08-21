#!/bin/bash

set -e

DEFAULT_SOCK="/tmp/jam_target.sock"

# List of available targets
AVAILABLE_TARGETS=(
    "boka"
    "jamzig"
    "jamduna"
    "jamixir"
    "jamzilla"
    "javajam"
    "spacejam"
    "vinwolf"
    "turbojam"
)

run() {
    local target="$1"
    local command="$2"
    target_dir=$(find targets -name "$target*" -type d | head -1)
    # Find the subdirectory with the most recent modification date
    target_dir=$(find "$target_dir" -maxdepth 1 -type d | tail -n +2 | xargs ls -dt | head -1)
    echo "Run $target on $target_dir"

    # Set up trap to cleanup on exit
    cleanup() {
        # Prevent multiple cleanup calls
        if [ "$CLEANUP_DONE" = "true" ]; then
            return
        fi
        CLEANUP_DONE=true

        echo "Cleaning up $target..."
        if [ ! -z "$TARGET_PID" ]; then
            echo "Killing target $TARGET_PID"
            kill $TARGET_PID 2>/dev/null || true
        fi
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup EXIT INT TERM

    pushd "$target_dir" > /dev/null
    eval "$command" &
    TARGET_PID=$!
    popd > /dev/null

    sleep 3
    echo "Waiting for target termination (pid=$TARGET_PID)"
    wait $TARGET_PID
}

run_docker() {
    local target="$1"
    local image="$2"
    local command="$3"

    echo "Run $target via Docker"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "Error: Docker image '$image' not found locally."
        echo "Please run: ./scripts/get_target.sh $target"
        exit 1
    fi

    cleanup_docker() {
        echo "Cleaning up Docker container $target..."
        docker kill "$target" 2>/dev/null || true
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup_docker EXIT INT TERM

    docker run --rm --pull=never --platform linux/amd64 --name "$target" -v /tmp:/tmp --user "$(id -u):$(id -g)" "$image" $command &
    TARGET_PID=$!

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

run_boka() {
    run_docker "boka" "acala/boka:latest" "fuzz target --socket-path $DEFAULT_SOCK"
}

run_turbojam() {
    run_docker "turbojam" "r2rationality/turbojam-fuzz:20250821-000"
}

case "$1" in
    "jamzig") run_jamzig ;;
    "jamduna") run_jamduna ;;
    "jamixir") run_jamixir ;;
    "jamzilla") run_jamzilla ;;
    "javajam") run_javajam ;;
    "spacejam") run_spacejam ;;
    "vinwolf") run_vinwolf ;;
    "boka") run_boka ;;
    "turbojam") run_turbojam ;;
    *)
        echo "Unknown target '$1'"
        echo "Available targets: ${AVAILABLE_TARGETS[*]}"
        exit 1
        ;;
esac

