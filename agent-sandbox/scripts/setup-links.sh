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
export CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-"/configs/claude"}

# for codex
create_config_link /configs/codex ~/.codex

# for gemini
create_config_link /configs/gemini ~/.gemini
export GEMINI_CLI_SYSTEM_SETTINGS_PATH=${GEMINI_CLI_SYSTEM_SETTINGS_PATH:-"/configs/gemini-system/settings.json"}

# for copilot
create_config_link /configs/copilot ~/.copilot

# for cursor-agent
create_config_link /configs/cursor ~/.cursor
