#!/usr/bin/env zsh

# Get plugin directory
0=${(%):-%N}
plugin_dir=${0:A:h}

# Source all modules in order
for module in utils cache ui actions folder core; do
    source "$plugin_dir/lib/$module.zsh"
done

# Load completion if available
if [[ -f "$plugin_dir/completions/_passfzf" ]]; then
    fpath=("$plugin_dir/completions" $fpath)
    autoload -Uz compinit && compinit
fi
