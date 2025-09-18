#!/usr/bin/env zsh
# passfzf.plugin.zsh - Main plugin file
# A modern fuzzy finder frontend for the Unix standard password manager (pass)
# Author: Dumidu Wijayasekara <dumidu.github@gmail.com>

# Plugin metadata
PASSFZF_VERSION="1.0.0"

# Get the directory where this plugin is located
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
export PASSFZF_PLUGIN_DIR="${0:A:h}"  # Export so it's available to subprocesses

# Add functions directory to fpath for autoloading
fpath=("${PASSFZF_PLUGIN_DIR}/functions" $fpath)

# Autoload all functions
autoload -Uz passfzf
autoload -Uz _passfzf_add_password
autoload -Uz _passfzf_add_folder_password  
autoload -Uz _passfzf_browse_folder
autoload -Uz _passfzf_open_url

# Optional: Create aliases
alias pf='passfzf'
alias pass-fzf='passfzf'

# Add bin directory to PATH
export PATH="${PASSFZF_PLUGIN_DIR}/bin:$PATH"

# Optional: Add completion
if [[ -d "${PASSFZF_PLUGIN_DIR}/completions" ]]; then
    fpath=("${PASSFZF_PLUGIN_DIR}/completions" $fpath)
fi
