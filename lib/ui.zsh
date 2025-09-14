#!/usr/bin/env zsh

# UI rendering, fzf bindings, headers, previews

_passfzf_dynamic_header_cmd() {
    local pass_dir="$1"
    cat <<EOF
total_entries=\$(find "$pass_dir" -name "*.gpg" -type f 2>/dev/null | wc -l)
category_count=\$(find "$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null | sed "s/\.gpg\$//" | sed "s|/.*||" | sort -u | wc -l)
echo "\$category_count categories • \$total_entries total entries
ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • + Add new"
EOF
}

_passfzf_smart_reload_cmd() {
    local pass_dir="$1"
    cat <<EOF
if [[ -n "\$FZF_QUERY" ]]; then
    find "$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null \\
      | sed "s/\.gpg\$//" \\
      | sort \\
      | sed "s/^/🔐 /"
else
    echo "✨ + Add New Password"
    find "$pass_dir" -name "*.gpg" -printf "%P\n" 2>/dev/null \\
      | sed "s/\.gpg\$//" \\
      | sed "s|/.*||" \\
      | sort -u \\
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

_passfzf_render_main_ui() {
    local pass_dir="$1"
    shift
    local -a entries=("$@")

    local total_entries=${#_PASSFZF_ALL_ENTRIES[@]}
    local category_count=${#_PASSFZF_SEEN_CATEGORIES[@]}
    local min_height=15
    local max_height=25
    local calculated_height=$((category_count + 5))
    [[ $calculated_height -lt $min_height ]] && calculated_height=$min_height
    [[ $calculated_height -gt $max_height ]] && calculated_height=$max_height

    local dynamic_header="$(_passfzf_dynamic_header_cmd "$pass_dir")"
    local smart_reload="$(_passfzf_smart_reload_cmd "$pass_dir")"

    local delete_script="$(_passfzf_create_delete_script)"

    local selection=$(
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
						folder=\$(echo {} | sed "s/📁 //" | sed "s|/\$||")
						echo "📂 Contents of \$folder/:" 
						echo ""
						find "$pass_dir/\$folder" -name "*.gpg" -printf "%P\\\\n" 2>/dev/null | \\
						sed "s/\\\\.gpg\\\$//" | sort | head -20 | sed "s/^/  🔐 /"
						count=\$(find "$pass_dir/\$folder" -maxdepth 1 -name "*.gpg" -type f 2>/dev/null | wc -l)
						if [ "\$count" -gt 20 ]; then
							echo "  ... and \$((count - 20)) more entries"
						fi
						;;
                        entry=$(echo {} | cut -d" " -f2-)
                        pass show "\$entry" 2>/dev/null | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                        ;;
                esac' \
            --preview-window='right:50%' \
            --bind "change:reload($smart_reload)" \
            --bind 'ctrl-y:execute-silent(
                entry=$(echo {} | cut -d" " -f2-)
                pass show -c "$entry" &>/dev/null && command -v notify-send >/dev/null 2>&1 && notify-send "🔐 Password Copied" "$entry" -t 1500 -u low &>/dev/null
            )+refresh-preview+clear-screen' \
            --bind 'ctrl-e:execute(
                if [[ {} == 📁* || {} == *"Add New Password"* ]]; then
                    echo "⚠️  Edit operation not available for folders"
                    read -k1 -s "key?Press any key to continue..."
                else
                    entry=$(echo {} | cut -d" " -f2-)
                    EDITOR=${EDITOR:-nvim} pass edit "$entry"
                fi
            )+reload('"$smart_reload"')+transform-header('"$dynamic_header"')' \
            --bind "ctrl-n:execute-silent(echo '✨ + Add New Password')+accept" \
            --bind 'ctrl-d:execute(
                if [[ {} == 📁* || {} == *"Add New Password"* ]]; then
                    echo "⚠️  Delete operation not available for folders"
                    read -k1 -s "key?Press any key to continue..."
                else
                    entry=$(echo {} | cut -d" " -f2-)
                    '"$delete_script"' "$entry"
                fi
            )+reload('"$smart_reload"')+transform-header('"$dynamic_header"')'
    )

    rm -f "$delete_script"
    echo "$selection"
}

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

    local folder_delete_script="$(_passfzf_create_delete_script)"

    local folder_reload_cmd=$(cat <<EOF
if [[ -n "\$FZF_QUERY" ]]; then
    find "$pass_dir/$folder" -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null \\
      | sed "s/\.gpg\$//" \\
      | sort \\
      | sed "s|^|🔐 $folder/|"
else
    echo "✨ + Add New Password"
    echo "📁 ← Back to categories"
    find "$pass_dir/$folder" -maxdepth 1 -name "*.gpg" -printf "%P\n" 2>/dev/null \\
      | sed "s/\.gpg\$//" \\
      | sort \\
      | sed "s|^|🔐 $folder/|"
fi
EOF
)

    local dynamic_folder_header_cmd=$(cat <<EOF
folder_count=\$(find "$pass_dir/$folder" -maxdepth 1 -name "*.gpg" -type f 2>/dev/null | wc -l)
echo "📊 Folder: $folder — \$folder_count entries
ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • ← Back"
EOF
)

    local folder_selection=$(
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
                        pass show "\$entry" 2>/dev/null | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                        ;;
                esac' \
            --preview-window='right:50%' \
            --bind "change:reload($folder_reload_cmd)" \
            --bind 'ctrl-y:execute-silent(
                entry=$(echo {} | cut -d" " -f2-)
                pass show -c "$entry" &>/dev/null && command -v notify-send >/dev/null 2>&1 && notify-send "🔐 Password Copied" "$entry" -t 1500 -u low &>/dev/null
            )+refresh-preview+clear-screen' \
            --bind 'ctrl-e:execute(
                if [[ {} == 📁* || {} == *"Add New Password"* || {} == *"← Back"* ]]; then
                    echo "⚠️  Edit operation not available for this item"
                    read -k1 -s "key?Press any key to continue..."
                else
                    entry=$(echo {} | cut -d" " -f2-)
                    EDITOR=${EDITOR:-nvim} pass edit "$entry"
                fi
            )+reload('"$folder_reload_cmd"')+transform-header('"$dynamic_folder_header_cmd"')' \
            --bind 'ctrl-d:execute(
                if [[ {} == 📁* || {} == *"Add New Password"* || {} == *"← Back"* ]]; then
                    echo "⚠️  Delete operation not available for this item"
                    read -k1 -s "key?Press any key to continue..."
                else
                    entry=$(echo {} | cut -d" " -f2-)
                    '"$folder_delete_script"' "$entry"
                fi
            )+reload('"$folder_reload_cmd"')+transform-header('"$dynamic_folder_header_cmd"')' \
            --bind 'ctrl-n:execute-silent(echo "📁 ← Back to categories")+accept'
    )

    rm -f "$folder_delete_script"
    echo "$folder_selection"
}
