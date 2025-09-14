#!/usr/bin/env zsh

# Folder browsing logic

_passfzf_browse_folder() {
    local pass_dir="$1"
    local folder="$2"

    echo "📂 Expanding folder: $folder"

    local -a folder_entries=("✨ + Add New Password" "📁 ← Back to categories")
    while IFS= read -r -d '' entry; do
        local clean_entry="${entry%.gpg}"
        folder_entries+=("🔐 $folder/$clean_entry")
    done < <(find "$pass_dir/$folder" -maxdepth 1 -name "*.gpg" -type f -printf '%P\0' 2>/dev/null | sort -z)

    local folder_selection="$(_passfzf_render_folder_ui "$pass_dir" "$folder" "${folder_entries[@]}")"

    case "$folder_selection" in
        *"← Back"*)
            passfzf
            ;;
        *"Add New Password"*)
            _passfzf_add_folder_password "$pass_dir" "$folder"
            ;;
        *)
            if [[ -n "$folder_selection" ]]; then
                local real_path="${folder_selection#* }"
                _passfzf_copy_password "$real_path"
            fi
            ;;
    esac
}

_passfzf_add_folder_password() {
    local pass_dir="$1"
    local folder="$2"

    exec < /dev/tty
    echo -n "✏️  Enter new entry name for $folder/: "
    read -r new_name

    _passfzf_validate_name "$new_name" || return 1

    local new_path="$folder/$new_name"

    if [[ -f "$pass_dir/$new_path.gpg" ]]; then
        echo "❌ Entry '$new_path' already exists!"
        return 1
    fi

    local tmpfile="$(_passfzf_create_editor_tmpfile)"
    ${EDITOR:-nvim} "$tmpfile"

    if [[ ! -s "$tmpfile" ]] || [[ -z "$(sed '/^#/d; /^$/d; q' "$tmpfile")" ]]; then
        echo "❌ Password cannot be empty. Aborted."
        _passfzf_cleanup_tmpfiles "$tmpfile"
        return 1
    fi

    local clean_tmpfile=$(mktemp -t passfzf-clean-XXXXXX)
    grep -v '^#' "$tmpfile" > "$clean_tmpfile"

    if pass insert -m "$new_path" < "$clean_tmpfile" &>/dev/null; then
        echo "✅ Password created successfully: $new_name (in $folder)"
        _passfzf_notify "🔐 New Password Created" "$new_name"
        echo "🔄 Returning to folder view..."
        _passfzf_cleanup_tmpfiles "$tmpfile" "$clean_tmpfile"
        passfzf
    else
        echo "❌ Failed to create: $new_path"
        _passfzf_cleanup_tmpfiles "$tmpfile" "$clean_tmpfile"
        return 1
    fi
}
