#!/bin/bash

set -e

DEFAULT_SOCK="/tmp/jam_target.sock"

# Target configuration using associative array with dot notation
# Architecture-specific files: use format "arch:filename" for multiple architectures
declare -A TARGETS

# === VINWOLF ===
TARGETS[vinwolf.repo]="bloppan/conformance_testing"
TARGETS[vinwolf.cmd.linux]="./linux/tiny/x86_64/vinwolf-target --fuzz $DEFAULT_SOCK"

# === JAMZIG ===
TARGETS[jamzig.repo]="jamzig/conformance-releases"
TARGETS[jamzig.cmd.linux]="./tiny/linux/x86_64/jam_conformance_target -vv --socket $DEFAULT_SOCK"
TARGETS[jamzig.cmd.macos]="./tiny/macos/aarch64/jam_conformance_target -vv --socket $DEFAULT_SOCK"

# === JAMDUNA ===
TARGETS[jamduna.repo]="jam-duna/jamtestnet"
TARGETS[jamduna.file]="linux:duna_target_linux macos:duna_target_mac"
TARGETS[jamduna.cmd.linux]="./duna_target_linux -socket $DEFAULT_SOCK"
TARGETS[jamduna.cmd.macos]="./duna_target_mac -socket $DEFAULT_SOCK"

# === JAMIXIR ===
TARGETS[jamixir.repo]="jamixir/jamixir-releases"
TARGETS[jamixir.file]="linux:jamixir_linux-x86-64-gp_0.6.7_v0.2.6_tiny.tar.gz"
TARGETS[jamixir.cmd.linux]="./jamixir fuzzer --socket-path $DEFAULT_SOCK"

# === JAVAJAM ===
TARGETS[javajam.repo]="javajamio/javajam-releases"
TARGETS[javajam.file]="linux:javajam-linux-x86_64.zip macos:javajam-macos-x86_64.zip"
TARGETS[javajam.cmd]="./bin/javajam fuzz $DEFAULT_SOCK"

# === JAMZILLA ===
TARGETS[jamzilla.repo]="ascrivener/jamzilla-conformance-releases"
TARGETS[jamzilla.file]="linux:fuzzserver-tiny-amd64-linux macos:fuzzserver-tiny-arm64-darwin"
TARGETS[jamzilla.cmd.linux]="./fuzzserver-tiny-amd64-linux -socket $DEFAULT_SOCK"
TARGETS[jamzilla.cmd.macos]="./fuzzserver-tiny-arm64-darwin -socket $DEFAULT_SOCK"

# === SPACEJAM ===
TARGETS[spacejam.repo]="spacejamapp/specjam"
TARGETS[spacejam.file]="linux:spacejam-0.6.7-linux-amd64.tar.gz macos:spacejam-0.6.7-macos-arm64.tar.gz"
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
    echo "WARN: cloning $target repo"
    local temp_dir=$(mktemp -d)
    git clone "https://github.com/$repo" --depth 1 "$temp_dir"
    local commit_hash=$(cd "$temp_dir" && git rev-parse --short HEAD)
    local target_dir="targets/$target/$commit_hash"
    mkdir -p "targets/$target"
    mv "$temp_dir" "$target_dir"
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
    local arch=$2
    local repo="${TARGETS[$target.repo]}"
    local file=$(get_target_file "$target.file" "$arch")

    if [ -z "$repo" ]; then
        echo "Error: missing repository information for $target"
        return 1
    fi

    if [ -z "$file" ]; then
        echo "Info: No release file specified for $target on $arch, cloning repository instead"
        clone_github_repo "$target" "$repo"
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

    local download_dir="targets/$target/${latest_tag}"

    mkdir -p "$download_dir"
    echo "Moving to $download_dir..."
    mv "$file" "$download_dir/"

    # Check if file is an archive and extract it, or make it executable
    cd "$download_dir"
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

# Function to get the correct file for a target and architecture
get_target_file() {
    local target=$1
    local arch=$2
    local files="${TARGETS[$target.file]}"
    
    if [ -z "$files" ]; then
        echo ""
        return 0
    fi
    
    # Parse architecture-specific files
    for file_spec in $files; do
        if [[ "$file_spec" == "$arch:"* ]]; then
            echo "${file_spec#*:}"
            return 0
        fi
    done
    
    # If requested arch not found, return empty (let caller handle the error)
    echo ""
    return 1
}

run() {
    local target="$1"
    local command="${TARGETS[$target.cmd]}"

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
            echo "Killing target $TARGET_PID..."
            kill -TERM $TARGET_PID 2>/dev/null || true
            sleep 1
            # Force kill if still running
            kill -KILL $TARGET_PID 2>/dev/null || true
        fi
        rm -f "$DEFAULT_SOCK"
    }

    trap cleanup EXIT INT TERM

    pushd "$target_dir" > /dev/null
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

validate_target() {
    local target=$1
    if [[ "$target" != "all" ]] && ! is_repo_target "$target" && ! is_docker_target "$target"; then
        echo "Unknown target '$target'" >&2
        echo "Available targets: ${AVAILABLE_TARGETS[*]} all" >&2
        return 1
    fi
    return 0
}

validate_architecture() {
    local arch=$1
    if [[ "$arch" != "linux" && "$arch" != "macos" ]]; then
        echo "Error: Unsupported architecture '$arch'" >&2
        echo "Supported architectures: linux, macos" >&2
        return 1
    fi
    return 0
}

is_docker_target() {
    local target=$1
    [[ -v TARGETS[$target.image] ]]
}

is_repo_target() {
    local target=$1
    [[ -v TARGETS[$target.repo] ]]
}

# Main script logic
if [ $# -lt 2 ]; then
    echo "Usage: $0 <get|run> <target>"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    exit 1
fi

ACTION="$1"
TARGET="$2"
ARCH="${3:-linux}"  # Default to linux if no architecture specified

validate_architecture "$ARCH" || exit 1
validate_target "$TARGET" || exit 1

echo "Action: $ACTION, Target: $TARGET, Architecture: $ARCH"


case "$ACTION" in
    "get")
        if [ "$TARGET" = "all" ]; then
            echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
            for target in "${AVAILABLE_TARGETS[@]}"; do
                if is_repo_target "$target"; then
                    if target_supports_arch "$target" "$ARCH"; then
                elif is_docker_target "$target"; then
                    if ! pull_docker_image "$target"; then
                else
                    echo "Error: Unknown target type for $target"
                fi
                echo ""
            done
        elif is_repo_target "$TARGET"; then
            if target_supports_arch "$TARGET" "$ARCH"; then
        elif is_docker_target "$TARGET"; then
            pull_docker_image "$TARGET"
        else
            echo "Unknown target '$TARGET'"
            echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
            exit 1
        fi
        ;;
    "run")
        if is_docker_target "$target"; then
            run_docker_image $TARGET
        elif is_repo_target "$target"; then
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
