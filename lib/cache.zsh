#!/usr/bin/env zsh

# Cache entries and categories from password store

_passfzf_cache_entries() {
    local pass_dir="${1:-${PASSWORD_STORE_DIR:-$HOME/.password-store}}"

    # Reset globals
    typeset -g -a _PASSFZF_ALL_ENTRIES=()
    typeset -g -A _PASSFZF_IS_CATEGORY=()
    typeset -g -A _PASSFZF_SEEN_CATEGORIES=()

    # Single find call to get all entries and build category map
    while IFS= read -r -d '' entry; do
        local clean_entry="${entry%.gpg}"
        _PASSFZF_ALL_ENTRIES+=("$clean_entry")

        if [[ "$clean_entry" == */* ]]; then
            local category="${clean_entry%%/*}"
            if [[ -z "${_PASSFZF_SEEN_CATEGORIES[$category]}" ]]; then
                _PASSFZF_IS_CATEGORY[$category]=1
                _PASSFZF_SEEN_CATEGORIES[$category]=1
            fi
        else
            _PASSFZF_IS_CATEGORY[$clean_entry]=0
        fi
    done < <(find "$pass_dir" -name "*.gpg" -type f -printf '%P\0' 2>/dev/null)
}
