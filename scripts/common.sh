#!/bin/bash

# Common functions shared between get_target.sh and run_target.sh

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

# Function to validate architecture
validate_architecture() {
    local arch=$1
    if [[ "$arch" != "linux" && "$arch" != "macos" ]]; then
        echo "Error: Unsupported architecture '$arch'" >&2
        echo "Supported architectures: linux, macos" >&2
        return 1
    fi
    return 0
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

# Function to check if target is a Docker target
is_docker_target() {
    local target=$1
    [[ -v TARGET_IMAGES[$target] ]]
}

# Function to check if target is a repository target
is_repo_target() {
    local target=$1
    [[ -v TARGET_REPOS[$target] ]]
}

# Function to show usage information
show_usage() {
    local script_name=$1
    echo "Usage: $script_name <target> [architecture]"
    echo "Available targets: ${AVAILABLE_TARGETS[*]} all"
    echo "Available architectures: linux, macos"
    echo "Default architecture: linux"
}

# Function to validate target exists
validate_target() {
    local target=$1
    if [[ "$target" != "all" ]] && ! is_repo_target "$target" && ! is_docker_target "$target"; then
        echo "Unknown target '$target'" >&2
        echo "Available targets: ${AVAILABLE_TARGETS[*]} all" >&2
        return 1
    fi
    return 0
}
