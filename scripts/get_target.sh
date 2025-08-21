#!/bin/bash

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

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
    show_usage "$0"
    exit 1
fi

TARGET="$1"
ARCH="${2:-linux}"  # Default to linux if no architecture specified

# Validate architecture and target
validate_architecture "$ARCH" || exit 1
validate_target "$TARGET" || exit 1

echo "Target: $TARGET, Architecture: $ARCH"

if [ "$TARGET" = "all" ]; then
    echo "Downloading all targets: ${AVAILABLE_TARGETS[*]}"
    for target in "${AVAILABLE_TARGETS[@]}"; do
        echo "Downloading $target for $ARCH..."
        if is_repo_target "$target"; then
            if target_supports_arch "$target" "$ARCH"; then
                download_github_release "$target" "$ARCH"
            else
                echo "Skipping $target: No $ARCH support available"
            fi
        elif is_docker_target "$target"; then
            pull_docker_image "$target"
        else
            echo "Error: Unknown target type for $target"
        fi
        echo ""
    done
elif is_repo_target "$TARGET"; then
    if target_supports_arch "$TARGET" "$ARCH"; then
        download_github_release "$TARGET" "$ARCH"
    else
        exit 1
    fi
elif is_docker_target "$TARGET"; then
    echo "Note: Docker images are architecture-independent"
    pull_docker_image "$TARGET"
fi
