#!/usr/bin/env zsh

# passfzf - fzf-powered interface for pass (password-store)
# Author: Dumidu Wijayasekara - github.com/dumidusw
# License: MIT
passfzf() {
    clear
    exec < /dev/tty  
    local selection
    local pass_dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

    build_categories() {
        echo "✨ + Add New Password"
        
        # Get all entries and extract top-level items
        find "$pass_dir" -name "*.gpg" -printf '%P\n' 2>/dev/null | sed 's/\.gpg$//' | while IFS= read -r entry; do
            if [[ "$entry" == */* ]]; then
                # Extract top-level directory
                echo "${entry%%/*}"
            else
                # Root level entry
                echo "$entry"
            fi
        done | sort -u | while IFS= read -r item; do
            if [[ -d "$pass_dir/$item" ]]; then
                echo "📁 $item/"
            else
                echo "🔐 $item"
            fi
        done
    }

    build_all_entries() {
        echo "✨ + Add New Password"
        find "$pass_dir" -name "*.gpg" -printf '%P\n' 2>/dev/null | sed 's/\.gpg$//' | sort | sed 's/^/🔐 /'
    }

    local categories_file=$(mktemp)
    local all_entries_file=$(mktemp)
    
    build_categories > "$categories_file"
    build_all_entries > "$all_entries_file"

    local reload_cmd="if [[ -n \"\$FZF_QUERY\" ]]; then cat '$all_entries_file'; else cat '$categories_file'; fi"

    selection=$(
        cat "$categories_file" | \
        fzf --height 40% \
            --reverse \
            --prompt='🔑 Pass> ' \
            --header='Start typing to search all • ENTER: select • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete' \
            --preview='
                if [[ {} == *"Add New Password" ]]; then
                    echo "✨ Create a new password entry"
                elif [[ {} == 📁* ]]; then
                    # Show contents of folder
                    folder=$(echo {} | sed "s/📁 //" | sed "s|/\$||")
                    echo "📂 Contents of $folder/:"
                    echo ""
                    find "'"$pass_dir"'/$folder" -name "*.gpg" -printf "%P\n" 2>/dev/null | sed "s/\.gpg\$//" | head -20 | sed "s/^/  🔐 /"
                    count=$(find "'"$pass_dir"'/$folder" -name "*.gpg" 2>/dev/null | wc -l)
                    if [[ $count -gt 20 ]]; then
                        remaining=$((count - 20))
                        echo "  ... and $remaining more entries"
                    fi
                else
                    # Show password entry
                    entry=$(echo {} | sed "s/🔐 //")
                    if [[ -f "'"$pass_dir"'/$entry.gpg" ]]; then
                        pass show "$entry" | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                    fi
                fi
            ' \
            --preview-window='right:50%' \
            --bind "change:reload($reload_cmd)" \
            --bind 'ctrl-y:execute-silent(
                entry=$(echo {} | sed "s/^[📁🔐✨] *//" | sed "s|/\$||")
                if [[ {} != *"Add New Password"* ]] && [[ {} != 📁* ]]; then
                    pass show -c "$entry" &>/dev/null && command -v notify-send >/dev/null && notify-send "🔐 Password Copied" "$entry" -t 1500 -u low
                fi
            )+refresh-preview+clear-screen' \
            --bind "ctrl-e:execute(
                entry=\$(echo {} | sed 's/^[📁🔐✨] *//' | sed 's|/\$||')
                if [[ {} != *'Add New Password'* ]] && [[ {} != 📁* ]]; then
                    EDITOR=nvim pass edit \"\$entry\"
                fi
            )+reload($reload_cmd)" \
            --bind "ctrl-n:execute-silent( ( echo '✨ + Add New Password' ) )+accept" \
            --bind "ctrl-d:execute(
                entry=\$(echo {} | sed 's/^[📁🔐✨] *//' | sed 's|/\$||')
                if [[ {} != *'Add New Password'* ]] && [[ {} != 📁* ]]; then
                    exec < /dev/tty
                    echo '⚠️  DELETE CONFIRMATION'
                    echo ''
                    echo 'You are about to DELETE:'
                    echo \"  \$entry\"
                    echo ''
                    echo 'Type YES to confirm deletion, or anything else to cancel:'
                    read -r confirm
                    if [[ \"\$confirm\" == 'YES' ]]; then
                        echo 'Deleting...'
                        if pass rm -f \"\$entry\"; then
                            echo \"✅ DELETED: \$entry\"
                            command -v notify-send >/dev/null && notify-send '🗑️ Password Deleted' \"\$entry\" -t 2000 -u low 2>/dev/null &
                        else
                            echo \"❌ Failed to delete: \$entry\"
                        fi
                    else
                        echo 'ℹ️  Deletion cancelled.'
                    fi
                    read -k1 -s 'key?Press any key to continue...'
                fi
            )+reload($reload_cmd)"
    )

    rm -f "$categories_file" "$all_entries_file"

    [[ -z "$selection" ]] && return 0

    if [[ "$selection" == *"Add New Password"* ]]; then
        echo "📁 Select parent folder for new password:"

        local -a dirs
        dirs=("")
        while IFS= read -r -d '' dir; do
            [[ -n "$dir" ]] && dirs+=("$dir")
        done < <(
            find "$pass_dir" -type d -not -path "$pass_dir" -printf '%P\0' 2>/dev/null |
            grep -zv '^[^/]*/\.' |
            grep -zv '^\.'
        )

        local selected_dir
        selected_dir=$(
            for d in "${dirs[@]}"; do
                if [[ -z "$d" ]]; then
                    echo "📁 / (root)"
                else
                    echo "📁 $d/"
                fi
            done | \
            fzf --height 40% \
                --reverse \
                --prompt='📁 Folder> ' \
                --header='Select parent folder • ESC to cancel • Ctrl+N = root' \
                --preview='
                    item="{}"
                    if [[ "$item" == *" (root)" ]]; then
                        echo "Will create at root level (e.g., mysite)"
                    else
                        clean="${item#📁 }"
                        clean="${clean%/}"
                        echo "Will create under: $clean/"
                    fi
                ' \
                --preview-window='right:50%' \
                --bind 'ctrl-n:execute-silent( ( echo "📁 / (root)" ) )+accept'
        )

        [[ -z "$selected_dir" ]] && { echo "❌ Cancelled."; return 0; }

        if [[ "$selected_dir" == *" (root)" ]]; then
            selected_dir=""
        else
            selected_dir=$(echo "$selected_dir" | sed 's/📁 //' | sed 's/\/$//')
        fi

        exec < /dev/tty
        echo -n "✏️  Enter new entry name (e.g., twitter): "
        read -r new_name
        [[ -z "$new_name" ]] && { echo "❌ Aborted."; return 1; }

        local new_path="${selected_dir:+$selected_dir/}$new_name"

        local tmpfile=$(mktemp -t passfzf-new-XXXXXX)
        {
            echo "# Enter password on first line. Lines after are optional metadata (notes, username, etc.)"
            echo "# DO NOT LEAVE FIRST LINE EMPTY."
            echo "# Save & quit to continue. Delete all content to cancel."
        } > "$tmpfile"

        ${EDITOR:-nvim} "$tmpfile"

        password=$(head -n1 "$tmpfile" | tr -d '\r\n')

        rm -f "$tmpfile"

        if [[ -z "$password" ]]; then
            echo "❌ Password cannot be empty. Aborted."
            return 1
        fi

        echo "✏️  Optional: adding metadata..."

        if echo -n "$password" | pass insert -e "$new_path"; then
            echo "✅ Created: $new_path"
            command -v notify-send >/dev/null && notify-send "🔐 New Password Created" "$new_path" -t 2000 -u low 2>/dev/null &
            echo "ℹ️  Metadata (if any) saved with password."
            echo "🔄 Reloading..."
            passfzf
        else
            echo "❌ Failed to create: $new_path"
        fi

        return 0
    fi

    if [[ "$selection" == 📁* ]]; then
        local folder=$(echo "$selection" | sed 's/📁 //' | sed 's|/$||')
        echo "📂 Expanding folder: $folder"
        
        local folder_selection
        folder_selection=$(
            {
                echo "✨ + Add New Password"
                echo "📁 ← Back to categories"
                find "$pass_dir/$folder" -name "*.gpg" -printf '%P\n' 2>/dev/null | sed 's/\.gpg$//' | sort | sed 's/^/🔐 /'
            } | \
            fzf --height 40% \
                --reverse \
                --prompt="🔑 $folder/> " \
                --header='ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • ← Back' \
                --preview='
                    if [[ {} == *"Add New Password" ]]; then
                        echo "✨ Create a new password entry in '"$folder"'/"
                    elif [[ {} == *"← Back"* ]]; then
                        echo "🔙 Return to category view"
                    else
                        entry=$(echo {} | sed "s/🔐 //")
                        pass show "'"$folder"'/$entry" | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10
                    fi
                ' \
                --preview-window='right:50%'
        )
        
        if [[ "$folder_selection" == *"← Back"* ]]; then
            passfzf  
            return 0
        elif [[ "$folder_selection" == *"Add New Password"* ]]; then
            exec < /dev/tty
            echo -n "✏️  Enter new entry name for $folder/: "
            read -r new_name
            [[ -z "$new_name" ]] && { echo "❌ Aborted."; return 1; }
            
            local new_path="$folder/$new_name"
            echo -n "🔑 Enter password: "
            read -rs password
            echo
            
            if echo -n "$password" | pass insert -e "$new_path"; then
                echo "✅ Created: $new_path"
                command -v notify-send >/dev/null && notify-send "🔐 New Password Created" "$new_path" -t 2000 -u low 2>/dev/null &
            fi
            return 0
        elif [[ -n "$folder_selection" ]]; then
            local real_path="$folder/${folder_selection#* }"
            if pass show -c "$real_path" 2>/dev/null; then
                echo "✅ COPIED: $real_path"
                command -v notify-send >/dev/null && notify-send "🔐 Password Copied" "$real_path" -t 2000 -u low 2>/dev/null &
            fi
        fi
        return 0
    fi

    local real_path="${selection#* }"
    if pass show -c "$real_path" 2>/dev/null; then
        echo "✅ COPIED: $real_path"
        command -v notify-send >/dev/null && notify-send "🔐 Password Copied" "$real_path" -t 2000 -u low 2>/dev/null &
    else
        echo "❌ Failed to copy: $real_path"
    fi
}
