#!/usr/bin/env zsh

# Main orchestrator — passfzf()

passfzf() {
    clear
    exec < /dev/tty

    local pass_dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

    # Cache entries
    _passfzf_cache_entries "$pass_dir"

    # Build initial display list
    local -a entries=("✨ + Add New Password")
    {
        for entry in "${_PASSFZF_ALL_ENTRIES[@]}"; do
            if [[ "$entry" == */* ]]; then
                echo "${entry%%/*}"
            else
                echo "$entry"
            fi
        done | sort -u
    } | while IFS= read -r item; do
        if [[ "${_PASSFZF_IS_CATEGORY[$item]}" == "1" ]]; then
            entries+=("📁 $item/")
        else
            entries+=("🔐 $item")
        fi
    done

    # Render main UI
    local selection="$(_passfzf_render_main_ui "$pass_dir" "${entries[@]}")"

    # Handle empty selection
    [[ -z "$selection" ]] && { echo "👋 Goodbye!"; return 0; }

    # Route selection
    case "$selection" in
        *"Add New Password"*)
            _passfzf_add_password "$pass_dir"
            ;;
        📁*)
            local folder=$(echo "$selection" | sed 's/📁 //' | sed 's|/$||')
            _passfzf_browse_folder "$pass_dir" "$folder"
            ;;
        *)
            _passfzf_copy_password "${selection#* }"
            ;;
    esac
}
