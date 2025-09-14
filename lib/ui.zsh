#!/usr/bin/env zsh

# UI rendering, fzf bindings, headers, previews

# Produce a script body that, when executed, prints the dynamic header.
# This returns a multi-line string (script) — caller should write it to a file.
_passfzf_dynamic_header_cmd() {
    local pass_dir="$1"
    cat <<EOF
#!/usr/bin/env bash
pass_dir='${pass_dir}'
total_entries=\$(find "\$pass_dir" -name "*.gpg" -type f 2>/dev/null | wc -l)
category_count=\$(find "\$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null | sed "s/\.gpg\$//" | sed "s|/.*||" | sort -u | wc -l)
echo "\$category_count categories • \$total_entries total entries
ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • + Add new"
EOF
}

# Produce a script body that prints the reload list (depends on FZF_QUERY)
_passfzf_smart_reload_cmd() {
    local pass_dir="$1"
    cat <<'EOF'
#!/usr/bin/env bash
pass_dir=''"$pass_dir"''
# fzf supplies FZF_QUERY in the environment
if [[ -n "${FZF_QUERY:-}" ]]; then
    find "$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null \
      | sed "s/\.gpg$//" \
      | sort \
      | sed "s/^/🔐 /"
else
    echo "✨ + Add New Password"
    find "$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null \
      | sed "s/\.gpg$//" \
      | sed "s|/.*||" \
      | sort -u \
      | while read -r cat; do
          if [[ -d "$pass_dir/\$cat" ]]; then
              echo "📁 \$cat/"
          else
              echo "🔐 \$cat"
          fi
      done
fi
EOF
}

# Render the main UI using fzf; writes small helper scripts to temp files to avoid quoting issues.
_passfzf_render_main_ui() {
    local pass_dir="$1"
    shift
    local -a entries=("$@")

    local total_entries=${#_PASSFZF_ALL_ENTRIES[@]:-0}
    local category_count=${#_PASSFZF_SEEN_CATEGORIES[@]:-0}
    local min_height=15
    local max_height=25
    local calculated_height=$((category_count + 5))
    [[ $calculated_height -lt $min_height ]] && calculated_height=$min_height
    [[ $calculated_height -gt $max_height ]] && calculated_height=$max_height

    # Create temp script files for reload and header
    local smart_reload_body
    smart_reload_body="$(_passfzf_smart_reload_cmd "$pass_dir")"
    local dynamic_header_body
    dynamic_header_body="$(_passfzf_dynamic_header_cmd "$pass_dir")"

    local smart_reload_file="$(_passfzf_write_cmd_file "$smart_reload_body")"
    local dynamic_header_file="$(_passfzf_write_cmd_file "$dynamic_header_body")"

    local delete_script="$(_passfzf_create_delete_script)"

    local selection
    selection=$(
        printf '%s\n' "${entries[@]}" | \
        fzf --height ${calculated_height} \
            --reverse \
            --prompt='🔑 Pass> ' \
            --header="$category_count categories • $total_entries total entries
ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • + Add new" \
            --preview='
                case {} in
                    *"Total:"*|*"categories • "*)
                        echo "📊 Password Store Statistics"
                        echo ""
                        echo "This shows your complete password store overview."
                        echo "You have organized your passwords into categories"
                        echo "for better management and security."
                        ;;
                    *"Add New Password"*)
                        echo "✨ Create a new password entry"
                        ;;
                    📁*)
                        folder=$(echo {} | sed "s/📁 //" | sed "s|/$||")
                        echo "📂 Contents of $folder/:"
                        echo ""
                        find "'"$pass_dir"'/$folder" -name "*.gpg" -printf "%P\n" 2>/dev/null | \
                            sed "s/\.gpg$//" | sort | head -20 | sed "s/^/  🔐 /"
                        count=$(find "'"$pass_dir"'/$folder" -maxdepth 1 -name "*.gpg" -type f 2>/dev/null | wc -l)
                        if [ "$count" -gt 20 ]; then
                            remaining=$((count - 20))
                            echo "  ... and $remaining more entries"
                        fi
                        ;;
                    *)
                        entry=$(echo {} | cut -d" " -f2-)
                        pass show "$entry" 2>/dev/null | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                        ;;
                esac' \
            --preview-window='right:50%' \
            --bind "change:reload(bash '$smart_reload_file')" \
            --bind 'ctrl-y:execute-silent(
                entry=$(echo {} | cut -d" " -f2-)
                pass show -c "$entry" &>/dev/null && command -v notify-send >/dev/null 2>&1 && notify-send "🔐 Password Copied" "$entry" -t 1500 -u low &>/dev/null
            )+refresh-preview+clear-screen' \
            --bind "ctrl-e:execute(
                if [[ {} == 📁* || {} == *\"Add New Password\"* ]]; then
                    echo \"⚠️  Edit operation not available for folders\"
                    read -n1 -s -r -p \"Press any key to continue...\"
                    echo
                else
                    entry=\$(echo {} | cut -d\" \" -f2-)
                    EDITOR=\${EDITOR:-nvim} pass edit \"\$entry\"
                fi
            )+reload(bash '$smart_reload_file')+transform-header(bash '$dynamic_header_file')" \
            --bind "ctrl-n:execute-silent(echo '✨ + Add New Password')+accept" \
            --bind "ctrl-d:execute(
                if [[ {} == 📁* || {} == *\"Add New Password\"* ]]; then
                    echo \"⚠️  Delete operation not available for folders\"
                    read -n1 -s -r -p \"Press any key to continue...\"
                    echo
                else
                    entry=\$(echo {} | cut -d\" \" -f2-)
                    '$delete_script' \"\$entry\"
                fi
            )+reload(bash '$smart_reload_file')+transform-header(bash '$dynamic_header_file')"
    )

    # Cleanup temp files
    rm -f "$delete_script" "$smart_reload_file" "$dynamic_header_file" 2>/dev/null || true

    printf '%s' "$selection"
}

# Folder UI: same pattern (writes folder-specific reload/header scripts)
_passfzf_render_folder_ui() {
    local pass_dir="$1"
    local folder="$2"
    shift 2
    local -a entries=("$@")

    local folder_entry_count_actual=$((${#entries[@]} - 2))  # subtract "Add" and "Back"
    local folder_height=$((folder_entry_count_actual + 7))
    local terminal_height=$(tput lines)
    local max_usable_height=$((terminal_height - 5))
    [[ $folder_height -lt 15 ]] && folder_height=15
    [[ $folder_height -gt $max_usable_height ]] && folder_height=$max_usable_height

    # Build folder-specific scripts
    local folder_reload_body
    folder_reload_body=$(cat <<EOF
#!/usr/bin/env bash
pass_dir='${pass_dir}'
folder='${folder}'
if [[ -n "\${FZF_QUERY:-}" ]]; then
    find "\$pass_dir/\$folder" -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null \
      | sed "s/\.gpg\$//" \
      | sort \
      | sed "s|^|🔐 ${folder}/|"
else
    echo "✨ + Add New Password"
    echo "📁 ← Back to categories"
    find "\$pass_dir/\$folder" -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null \
      | sed "s/\.gpg\$//" \
      | sort \
      | sed "s|^|🔐 ${folder}/|"
fi
EOF
)

    local dynamic_folder_header_body
    dynamic_folder_header_body=$(cat <<EOF
#!/usr/bin/env bash
pass_dir='${pass_dir}'
folder='${folder}'
folder_count=\$(find "\$pass_dir/\$folder" -maxdepth 1 -name "*.gpg" -type f 2>/dev/null | wc -l)
echo "📊 Folder: $folder — \$folder_count entries
ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • ← Back"
EOF
)

    local folder_reload_file="$(_passfzf_write_cmd_file "$folder_reload_body")"
    local dynamic_folder_header_file="$(_passfzf_write_cmd_file "$dynamic_folder_header_body")"

    local folder_delete_script="$(_passfzf_create_delete_script)"

    local folder_selection
    folder_selection=$(
        printf '%s\n' "${entries[@]}" | \
        fzf --height ${folder_height} \
            --reverse \
            --prompt="🔑 $folder/ ($folder_entry_count_actual)> " \
            --header='ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • ← Back' \
            --preview='
                case {} in
                    *"Add New Password"*)
                        echo "✨ Create a new password entry in '"$folder"'/"
                        ;;
                    *"← Back"*)
                        echo "🔙 Return to category view"
                        ;;
                    *)
                        entry=$(echo {} | cut -d" " -f2-)
                        pass show "$entry" 2>/dev/null | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                        ;;
                esac' \
            --preview-window='right:50%' \
            --bind "change:reload(bash '$folder_reload_file')" \
            --bind 'ctrl-y:execute-silent(
                entry=$(echo {} | cut -d" " -f2-)
                pass show -c "$entry" &>/dev/null && command -v notify-send >/dev/null 2>&1 && notify-send "🔐 Password Copied" "$entry" -t 1500 -u low &>/dev/null
            )+refresh-preview+clear-screen' \
            --bind "ctrl-e:execute(
                if [[ {} == 📁* || {} == *\"Add New Password\"* || {} == *\"← Back\"* ]]; then
                    echo \"⚠️  Edit operation not available for this item\"
                    read -n1 -s -r -p \"Press any key to continue...\"
                    echo
                else
                    entry=\$(echo {} | cut -d\" \" -f2-)
                    EDITOR=\${EDITOR:-nvim} pass edit \"\$entry\"
                fi
            )+reload(bash '$folder_reload_file')+transform-header(bash '$dynamic_folder_header_file')" \
            --bind "ctrl-d:execute(
                if [[ {} == 📁* || {} == *\"Add New Password\"* || {} == *\"← Back\"* ]]; then
                    echo \"⚠️  Delete operation not available for this item\"
                    read -n1 -s -r -p \"Press any key to continue...\"
                    echo
                else
                    entry=\$(echo {} | cut -d\" \" -f2-)
                    '$folder_delete_script' \"\$entry\"
                fi
            )+reload(bash '$folder_reload_file')+transform-header(bash '$dynamic_folder_header_file')" \
            --bind 'ctrl-n:execute-silent(echo "📁 ← Back to categories")+accept'
    )

    # cleanup
    rm -f "$folder_delete_script" "$folder_reload_file" "$dynamic_folder_header_file" 2>/dev/null || true

    printf '%s' "$folder_selection"
}
