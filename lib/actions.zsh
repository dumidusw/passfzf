#!/usr/bin/env zsh

# Add, Edit, Delete, Copy actions

_passfzf_add_password() {
    local pass_dir="$1"
    echo "📁 Select parent folder for new password:"

    local -a dirs=()
    while IFS=$'\n' read -r dir; do
        [[ -z "$dir" ]] && continue
        [[ "$dir" == .* || "$dir" == */.* ]] && continue
        dirs+=("$dir")
    done < <(find "$pass_dir" -mindepth 1 -type d -printf '%P\n' 2>/dev/null)

    local dir_count=${#dirs[@]}
    local picker_height=$((dir_count + 10))
    [[ $picker_height -lt 15 ]] && picker_height=15
    [[ $picker_height -gt 30 ]] && picker_height=30

    local selected_dir
    selected_dir=$(
        {
            echo "📁 / (top level)"
            printf '%s\n' "${dirs[@]}" | sort -u | sed 's|^|📁 |; s|$|/|'
        } | fzf --height ${picker_height} \
                --reverse \
                --prompt='📁 Folder> ' \
                --header='Select parent folder • ESC to cancel • Ctrl+N = top level' \
                --preview='
                    case {} in
                        *"(top level)"*)
                            echo "⚠️  You are about to add a password at the top level."
                            echo ""
                            echo "Existing entries in root:"
                            find "'"$pass_dir"'" -mindepth 1 -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null | sed "s/\.gpg$//" | sort | head -10 | sed "s/^/  🔐 /"
                            ;;
                        *)
                            clean=$(echo {} | sed "s/📁 //" | sed "s|/$||")
                            echo "Will create under: \$clean/"
                            echo ""
                            echo "Existing entries in this folder:"
                            find "'"$pass_dir"'" -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null | sed "s/\.gpg$//" | sort | head -10 | sed "s/^/  🔐 /"
                            ;;
                    esac' \
                --preview-window='right:50%' \
                --bind 'ctrl-n:execute-silent(echo "📁 / (top level)")+accept'
    )

    [[ -z "$selected_dir" ]] && { echo "👋 Goodbye!"; return 0; }

    if [[ "$selected_dir" == *"(top level)"* ]]; then
        selected_dir=""
    else
        selected_dir="${selected_dir#📁 }"
        selected_dir="${selected_dir%/}"
    fi

    exec < /dev/tty
    echo -n "✏️  Enter new entry name (e.g., twitter): "
    read -r new_name

    _passfzf_validate_name "$new_name" || return 1

    local new_path="${selected_dir:+$selected_dir/}$new_name"
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
        echo "✅ Password created successfully: $new_name"
        _passfzf_notify "🔐 New Password Created" "$new_name"
        echo "🔄 Reloading..."
        _passfzf_cleanup_tmpfiles "$tmpfile" "$clean_tmpfile"
        passfzf
    else
        echo "❌ Failed to create: $new_path"
        _passfzf_cleanup_tmpfiles "$tmpfile" "$clean_tmpfile"
        return 1
    fi
}

_passfzf_copy_password() {
    local real_path="$1"
    if pass show -c "$real_path" &>/dev/null; then
        local display_name="${real_path##*/}"
        local category="${real_path%/*}"
        if [[ "$category" != "$real_path" ]]; then
            echo "🔐 Password copied: $display_name (from $category)"
        else
            echo "🔐 Password copied: $display_name"
        fi
        _passfzf_notify "🔐 Password Copied" "$display_name"
        echo "⏳ Will clear from clipboard in 45 seconds"
    else
        echo "❌ Failed to copy password: $real_path"
    fi
}
