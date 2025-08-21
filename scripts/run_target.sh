#!/bin/bash

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

DEFAULT_SOCK="/tmp/jam_target.sock"

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
    show_usage "$0"
    exit 1
fi

TARGET="$1"
ARCH="${2:-linux}"  # Default to linux if no architecture specified

# Validate architecture and target
validate_architecture "$ARCH" || exit 1
validate_target "$TARGET" || exit 1

echo "Running target: $TARGET, Architecture: $ARCH"

run_jamzig() {
    if [ "$ARCH" = "linux" ]; then
        run "jamzig" "./tiny/linux/x86_64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
    elif [ "$ARCH" = "macos" ]; then
        run "jamzig" "./tiny/macos/aarch64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
    fi
}

run_jamduna() {
    if [ "$ARCH" = "linux" ]; then
        run "jamduna" "./duna_target_linux -socket $DEFAULT_SOCK"
    elif [ "$ARCH" = "macos" ]; then
        run "jamduna" "./duna_target_mac -socket $DEFAULT_SOCK"
    fi
}

run_jamixir() {
    if [ "$ARCH" = "linux" ]; then
        run "jamixir" "./jamixir fuzzer --socket-path $DEFAULT_SOCK"
    elif [ "$ARCH" = "macos" ]; then
        echo "Error: jamixir does not support macOS architecture"
        exit 1
    fi
}

run_jamzilla() {
    if [ "$ARCH" = "linux" ]; then
        run "jamzilla" "./fuzzserver-tiny-amd64-linux -socket $DEFAULT_SOCK"
    elif [ "$ARCH" = "macos" ]; then
        run "jamzilla" "./fuzzserver-tiny-arm64-darwin -socket $DEFAULT_SOCK"
    fi
}

run_javajam() {
    run "javajam" "./bin/javajam fuzz $DEFAULT_SOCK"
}

run_spacejam() {
    run "spacejam" "./spacejam -vv fuzz target $DEFAULT_SOCK"
}

run_vinwolf() {
    if [ "$ARCH" = "linux" ]; then
        run "vinwolf" "./linux/tiny/x86_64/vinwolf-target --fuzz $DEFAULT_SOCK"
    elif [ "$ARCH" = "macos" ]; then
        echo "Error: vinwolf does not support macOS architecture"
        exit 1
    fi
}

run_boka() {
    run_docker "boka" "acala/boka:latest" "fuzz target --socket-path $DEFAULT_SOCK"
}

run_turbojam() {
    run_docker "turbojam" "r2rationality/turbojam-fuzz:20250821-000"
}

case "$TARGET" in
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
        echo "Unknown target '$TARGET'"
        echo "Available targets: ${AVAILABLE_TARGETS[*]}"
        exit 1
        ;;
esac

