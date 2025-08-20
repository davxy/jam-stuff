#!/bin/bash

set -e

# Target configuration: maps target names to their GitHub repositories and release files
# NOTE: Some targets may require repository cloning if they don't provide release files.
# If repo cloning is required, the TARGET_FILES value is left empty
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
TARGET_FILES[jamduna]="duna_target_linux"
# === JAMIXIR ===
TARGET_REPOS[jamixir]="jamixir/jamixir-releases"
TARGET_FILES[jamixir]="jamixir_linux-x86-64-gp_0.6.7_v0.2.6_tiny.tar.gz"
# === JAVAJAM ===
TARGET_REPOS[javajam]="javajamio/javajam-releases"
TARGET_FILES[javajam]="javajam-linux-x86_64.zip"
# === JAMZILLA ===
TARGET_REPOS[jamzilla]="ascrivener/jamzilla-conformance-releases"
TARGET_FILES[jamzilla]="fuzzserver-tiny-amd64-linux"
# === SPACEJAM ===
TARGET_REPOS[spacejam]="spacejamapp/specjam"
TARGET_FILES[spacejam]="spacejam-0.6.7-linux-amd64.tar.gz"
# === BOKA ===
TARGET_IMAGES[boka]="acala/boka:latest"

# Get list of available targets
AVAILABLE_TARGETS=($(printf '%s\n' "${!TARGET_REPOS[@]}" "${!TARGET_IMAGES[@]}" | sort))

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
# Usage: download_github_release target
download_github_release() {
    local target=$1
    local repo="${TARGET_REPOS[$target]}"
    local file="${TARGET_FILES[$target]}"

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


if [ $# -eq 0 ]; then
    echo "Usage: $0 <target>"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    exit 1
fi

TARGET="$1"

if [ "$TARGET" = "all" ]; then
    echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
    for target in "${AVAILABLE_TARGETS[@]}"; do
        echo "Downloading $target..."
        if [[ -v TARGET_REPOS[$target] ]]; then
            download_github_release "$target"
        elif [[ -v TARGET_IMAGES[$target] ]]; then
            pull_docker_image "$target"
        else
            echo "Error: Unknown target type for $target"
        fi
        echo ""
    done
elif [[ -v TARGET_REPOS[$TARGET] ]]; then
    download_github_release "$TARGET"
elif [[ -v TARGET_IMAGES[$TARGET] ]]; then
    pull_docker_image "$TARGET"
else
    echo "Unknown target '$TARGET'"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    exit 1
fi
