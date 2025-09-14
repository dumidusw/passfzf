#!/usr/bin/env zsh

# passfzf.plugin.zsh - plugin bootstrap for zsh (sourced)
# Only run once
[[ -n ${_PASSFZF_LOADED:-} ]] && return
_PASSFZF_LOADED=1

# Get plugin directory robustly
_pf_this_file=${(%):-%N}
plugin_dir=${_pf_this_file:A:h}

# Source all modules in order (lib should be in plugin_dir)
for module in utils cache ui actions folder core; do
    if [[ -r "$plugin_dir/lib/$module.zsh" ]]; then
        source "$plugin_dir/lib/$module.zsh"
    fi
done

# Load completion if available
if [[ -f "$plugin_dir/completions/_passfzf" ]]; then
    fpath=("$plugin_dir/completions" $fpath)
    autoload -Uz compinit && compinit >/dev/null 2>&1
    # Register completion
    if (( $+commands[compdef] )); then
        compdef _passfzf passfzf 2>/dev/null || true
    fi
fi
