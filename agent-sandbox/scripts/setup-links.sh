#!/bin/bash
set -euo pipefail

# ensure correct ownership of persistent directory
sudo chown -vR "$(whoami)":"$(whoami)" /configs
sudo chown -vR "$(whoami)":"$(whoami)" /commandhistory

# Function to create directory and symbolic link
create_config_link() {
    local source_dir=$1
    local target_link=$2

    mkdir -p "$source_dir"
    
    ln -sf "$source_dir" "$target_link"
}

# for claude
create_config_link /configs/claude ~/.claude

# for codex
create_config_link /configs/codex ~/.codex

# for gemini
create_config_link /configs/gemini ~/.gemini

# for copilot
create_config_link /configs/copilot ~/.copilot

# for cursor-agent
create_config_link /configs/cursor ~/.cursor
