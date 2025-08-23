#!/bin/bash

set -e

DEFAULT_SOCK="/tmp/jam_target.sock"

# Target configuration using associative array with dot notation
declare -A TARGETS

# === VINWOLF ===
TARGETS[vinwolf.repo]="bloppan/conformance_testing"
TARGETS[vinwolf.cmd]="./linux/tiny/x86_64/vinwolf-target --fuzz $DEFAULT_SOCK"

# === JAMZIG ===
TARGETS[jamzig.repo]="jamzig/conformance-releases"
TARGETS[jamzig.cmd]="./tiny/linux/x86_64/jam_conformance_target -vv --socket $DEFAULT_SOCK"

# === JAMDUNA ===
TARGETS[jamduna.repo]="jam-duna/jamtestnet"
TARGETS[jamduna.file]="duna_target_linux"
TARGETS[jamduna.cmd]="./duna_target_linux -socket $DEFAULT_SOCK"

# === JAMIXIR ===
TARGETS[jamixir.repo]="jamixir/jamixir-releases"
TARGETS[jamixir.file]="jamixir_linux-x86-64-gp_0.6.7_v0.2.6_tiny.tar.gz"
TARGETS[jamixir.cmd]="./jamixir fuzzer --socket-path $DEFAULT_SOCK"

# === JAVAJAM ===
TARGETS[javajam.repo]="javajamio/javajam-releases"
TARGETS[javajam.file]="javajam-linux-x86_64.zip"
TARGETS[javajam.cmd]="./bin/javajam fuzz $DEFAULT_SOCK"

# === JAMZILLA ===
TARGETS[jamzilla.repo]="ascrivener/jamzilla-conformance-releases"
TARGETS[jamzilla.file]="fuzzserver-tiny-amd64-linux"
TARGETS[jamzilla.cmd]="./fuzzserver-tiny-amd64-linux -socket $DEFAULT_SOCK"

# === SPACEJAM ===
TARGETS[spacejam.repo]="spacejamapp/specjam"
TARGETS[spacejam.file]="spacejam-0.6.7-linux-amd64.tar.gz"
TARGETS[spacejam.cmd]="./spacejam -vv fuzz target $DEFAULT_SOCK"

# === BOKA ===
TARGETS[boka.image]="acala/boka:latest"
TARGETS[boka.cmd]="fuzz target --socket-path $DEFAULT_SOCK"

# === TURBOJAM ===
TARGETS[turbojam.image]="r2rationality/turbojam-fuzz:latest"
TARGETS[turbojam.cmd]="fuzzer-api $DEFAULT_SOCK"


# Get list of available targets
get_available_targets() {
    local targets=()
    for key in "${!TARGETS[@]}"; do
        local target_name="${key%%.*}"
        if [[ ! " ${targets[@]} " =~ " ${target_name} " ]]; then
            targets+=("$target_name")
        fi
    done
    printf '%s\n' "${targets[@]}" | sort
}

AVAILABLE_TARGETS=($(get_available_targets))

clone_github_repo() {
    target=$1
    repo=$2
    local temp_dir=$(mktemp -d)
    git clone "https://github.com/$repo" --depth 1 "$temp_dir"
    local commit_hash=$(cd "$temp_dir" && git rev-parse --short HEAD)
    local target_dir=$(realpath "targets/$target")
    mkdir -p "$target_dir"
    local target_dir_rev="$target_dir/$commit_hash"
    mv "$temp_dir" "$target_dir_rev"
    rm -f "$target_dir/latest"
    ln -s "$target_dir_rev" "$target_dir/latest"
    echo "Cloned to $target_dir"
    return 0
}

pull_docker_image() {
    local target=$1
    local docker_image="${TARGETS[$target.image]}"

    if [ -z "$docker_image" ]; then
        echo "Error: No Docker image specified for $target"
        return 1
    fi

    echo "Pulling Docker image: $docker_image"

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        return 1
    fi

    docker pull "$docker_image"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to pull Docker image $docker_image"
        return 1
    fi

    echo "Successfully pulled Docker image: $docker_image"

    return 0
}

download_github_release() {
    local target=$1
    local repo="${TARGETS[$target.repo]}"
    local file="${TARGETS[$target.file]}"

    if [ -z "$repo" ]; then
        echo "Error: missing repository information for $target"
        return 1
    fi

    if [ -z $file ]; then
        clone_github_repo $target $repo
        return 0
    fi

    echo "Fetching latest release information..."

    # Get the latest release tag from GitHub API
    local latest_tag=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_tag" ]; then
        echo "Error: Could not fetch latest release tag"
        return 1
    fi

    echo "Latest version: $latest_tag"

    # Construct download URL
    local download_url="https://github.com/$repo/releases/download/$latest_tag/$file"

    echo "Downloading from: $download_url"

    # Download the file
    curl -L -o "$file" "$download_url"

    if [ $? -ne 0 ]; then
        echo "Error: Download failed"
        return 1
    fi

    echo "Successfully downloaded $file"
    echo "File size: $(ls -lh $file | awk '{print $5}')"

    local target_dir=$(realpath "targets/$target")
    local target_dir_rev="$target_dir/${latest_tag}"

    rm -f "$target_dir/latest"
    ln -s "$target_dir_rev" "$target_dir/latest"

    mkdir -p "$target_dir_rev"
    mv "$file" "$target_dir_rev/"

    # Check if file is an archive and extract it, or make it executable
    cd "$target_dir_rev"
    if [[ "$file" == *.zip ]]; then
        echo "Extracting zip archive: $file"
        unzip "$file"
        rm "$file"
    elif [[ "$file" == *.tar.gz ]] || [[ "$file" == *.tgz ]]; then
        echo "Extracting tar.gz archive: $file"
        tar -xzf "$file"
        rm "$file"
    elif [[ "$file" == *.tar ]]; then
        echo "Extracting tar archive: $file"
        tar -xf "$file"
        rm "$file"
    else
        echo "Making file executable: $file"
        chmod +x "$file"
    fi
    cd - > /dev/null
}

run() {
    local target="$1"
    local command="${TARGETS[$target.cmd]}"

    target_dir=$(find targets -name "$target*" -type d | head -1)
    target_rev=$(realpath "$target_dir/latest")
    echo "Run $target on $target_rev"

    # Set up trap to cleanup on exit
    cleanup() {
        # Prevent multiple cleanup calls
        if [ "$CLEANUP_DONE" = "true" ]; then
            return
        fi
        CLEANUP_DONE=true

        echo "Cleaning up $target..."
        if [ ! -z "$TARGET_PID" ]; then
            echo "Killing target $TARGET_PID..."
            kill -TERM $TARGET_PID 2>/dev/null || true
            sleep 1
            # Force kill if still running
            kill -KILL $TARGET_PID 2>/dev/null || true
        fi
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup EXIT INT TERM

    pushd "$target_rev" > /dev/null
    bash -c "$command" &
    TARGET_PID=$!
    popd > /dev/null

    echo "Waiting for target termination (pid=$TARGET_PID)"
    wait $TARGET_PID
}

run_docker_image() {
    local target="$1"
    local image="${TARGETS[$target.image]}"
    local command="${TARGETS[$target.cmd]}"

    echo "Run $target via Docker"

    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "Error: Docker image '$image' not found locally."
        echo "Please run: $0 get $target"
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

# Main script logic
if [ $# -lt 2 ]; then
    echo "Usage: $0 <get|run> <target>"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    exit 1
fi

ACTION="$1"
TARGET="$2"

case "$ACTION" in
    "get")
        if [ "$TARGET" = "all" ]; then
            echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
            for target in "${AVAILABLE_TARGETS[@]}"; do
                echo "Downloading $target..."
                if [ -n "${TARGETS[$target.repo]}" ]; then
                    download_github_release "$target"
                elif [ -n "${TARGETS[$target.image]}" ]; then
                    pull_docker_image "$target"
                else
                    echo "Error: Unknown target type for $target"
                fi
                echo ""
            done
        elif [ -n "${TARGETS[$TARGET.repo]}" ]; then
            download_github_release "$TARGET"
        elif [ -n "${TARGETS[$TARGET.image]}" ]; then
            pull_docker_image "$TARGET"
        else
            echo "Unknown target '$TARGET'"
            echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
            exit 1
        fi
        ;;
    "run")
        if [ -n "${TARGETS[$TARGET.image]}" ]; then
            run_docker_image $TARGET
        elif [ -n "${TARGETS[$TARGET.cmd]}" ]; then
            run $TARGET
        else
            echo "Unknown target '$TARGET'"
            echo "Available targets: ${AVAILABLE_TARGETS[*]}"
            exit 1
        fi
        ;;
    *)
        echo "Unknown action '$ACTION'"
        echo "Usage: $0 <get|run> <target>"
        exit 1
        ;;
esac
