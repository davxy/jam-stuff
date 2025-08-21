#!/bin/bash

set -e

# Target configuration: maps target names to their GitHub repositories and release files
# NOTE: Some targets may require repository cloning if they don't provide release files.
# If repo cloning is required, the TARGET_FILES value is left empty
# Architecture-specific files: use format "arch:filename" for multiple architectures
declare -A TARGET_REPOS
declare -A TARGET_FILES
# NOTE: For Docker-based targets, use TARGET_IMAGES only
declare -A TARGET_IMAGES

# === VINWOLF ===
TARGET_REPOS[vinwolf]="bloppan/conformance_testing"

# === JAMZIG ===
TARGET_REPOS[jamzig]="jamzig/conformance-releases"

# === JAMDUNA ===
TARGET_REPOS[jamduna]="jam-duna/jamtestnet"
TARGET_FILES[jamduna]="linux:duna_target_linux macos:duna_target_mac"

# === JAMIXIR ===
TARGET_REPOS[jamixir]="jamixir/jamixir-releases"
TARGET_FILES[jamixir]="linux:jamixir_linux-x86-64-gp_0.6.7_v0.2.6_tiny.tar.gz"

# === JAVAJAM ===
TARGET_REPOS[javajam]="javajamio/javajam-releases"
TARGET_FILES[javajam]="linux:javajam-linux-x86_64.zip macos:javajam-macos-x86_64.zip"

# === JAMZILLA ===
TARGET_REPOS[jamzilla]="ascrivener/jamzilla-conformance-releases"
TARGET_FILES[jamzilla]="linux:fuzzserver-tiny-amd64-linux macos:fuzzserver-tiny-arm64-darwin"

# === SPACEJAM ===
TARGET_REPOS[spacejam]="spacejamapp/specjam"
TARGET_FILES[spacejam]="linux:spacejam-0.6.7-linux-amd64.tar.gz macos:spacejam-0.6.7-macos-arm64.tar.gz"

# === BOKA ===
TARGET_IMAGES[boka]="acala/boka:latest"

# === TURBOJAM ===
TARGET_IMAGES[turbojam]="r2rationality/turbojam-fuzz:20250821-000"

# Get list of available targets
AVAILABLE_TARGETS=($(printf '%s\n' "${!TARGET_REPOS[@]}" "${!TARGET_IMAGES[@]}" | sort))

# Function to get the correct file for a target and architecture
get_target_file() {
    local target=$1
    local arch=$2
    local files="${TARGET_FILES[$target]}"
    
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

# Function to check if a target supports a specific architecture
target_supports_arch() {
    local target=$1
    local arch=$2
    local files="${TARGET_FILES[$target]}"
    
    # If no files specified, assume it supports all architectures (repo cloning)
    if [ -z "$files" ]; then
        return 0
    fi
    
    # Check if the architecture is available
    for file_spec in $files; do
        if [[ "$file_spec" == "$arch:"* ]]; then
            return 0
        fi
    done
    
    echo "Error: No $arch version available for $target" >&2
    echo "Available architectures for $target:" >&2
    for file_spec in $files; do
        echo "  - ${file_spec%%:*}: ${file_spec#*:}" >&2
    done
    
    return 1
}

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

# Function to pull Docker images
# Usage: pull_docker_image target
pull_docker_image() {
    local target=$1
    local docker_image="${TARGET_IMAGES[$target]}"

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

# Shared function to download GitHub releases
# Usage: download_github_release target architecture
download_github_release() {
    local target=$1
    local arch=$2
    local repo="${TARGET_REPOS[$target]}"
    local file=$(get_target_file "$target" "$arch")

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

# Main entry point

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target> [architecture]"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    echo "Available architectures: linux, macos"
    echo "Default architecture: linux"
    exit 1
fi

TARGET="$1"
ARCH="${2:-linux}"  # Default to linux if no architecture specified

# Validate architecture
if [[ "$ARCH" != "linux" && "$ARCH" != "macos" ]]; then
    echo "Error: Unsupported architecture '$ARCH'"
    echo "Supported architectures: linux, macos"
    exit 1
fi

echo "Target: $TARGET, Architecture: $ARCH"

if [ "$TARGET" = "all" ]; then
    echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
    for target in "${AVAILABLE_TARGETS[@]}"; do
        echo "Downloading $target for $ARCH..."
        if [[ -v TARGET_REPOS[$target] ]]; then
            if target_supports_arch "$target" "$ARCH"; then
                download_github_release "$target" "$ARCH"
            else
                echo "Skipping $target: No $ARCH support available"
            fi
        elif [[ -v TARGET_IMAGES[$target] ]]; then
            pull_docker_image "$target"
        else
            echo "Error: Unknown target type for $target"
        fi
        echo ""
    done
elif [[ -v TARGET_REPOS[$TARGET] ]]; then
    if target_supports_arch "$TARGET" "$ARCH"; then
        download_github_release "$TARGET" "$ARCH"
    else
        exit 1
    fi
elif [[ -v TARGET_IMAGES[$TARGET] ]]; then
    echo "Note: Docker images are architecture-independent"
    pull_docker_image "$TARGET"
else
    echo "Unknown target '$TARGET'"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    exit 1
fi
