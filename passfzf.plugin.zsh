# passfzf.plugin.zsh
# Modern zsh plugin for password store frontend

# Get plugin directory
0=${(%):-%N}
PASSFZF_PLUGIN_DIR=${0:A:h}

# Add functions directory to fpath for autoloading
if [[ -d "$PASSFZF_PLUGIN_DIR/functions" ]]; then
    fpath=("$PASSFZF_PLUGIN_DIR/functions" $fpath)
fi

# Autoload all functions
autoload -Uz passfzf _passfzf_add_password _passfzf_browse_folder _passfzf_add_folder_password

# Optional: Set up completions
if [[ -d "$PASSFZF_PLUGIN_DIR/completions" ]]; then
    fpath=("$PASSFZF_PLUGIN_DIR/completions" $fpath)
    autoload -Uz compinit && compinit
fi

# Plugin metadata (optional but good practice)
PASSFZF_VERSION="1.0.0"
