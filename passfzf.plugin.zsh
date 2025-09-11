#!/usr/bin/env zsh

# passfzf - fzf-powered interface for pass (password-store)
# Author: Dumidu Wijayasekara - github.com/dumidusw
# License: MIT
passfzf() {
    local selection
    local pass_dir="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

    # Command to reload password list
    local reload_cmd="echo '✨ + Add New Password'; find \"$pass_dir\" -name \"*.gpg\" -printf '%P\n' 2>/dev/null | sed 's/\.gpg$//' | sort | sed 's/^/🔐 /'"

    # Build list
    local -a entries
    entries=("✨ + Add New Password")
    for p in $(find "$pass_dir" -name "*.gpg" -printf '%P\n' 2>/dev/null | sed 's/\.gpg$//' | sort); do
        entries+=("🔐 $p")
    done

    # Launch fzf
    selection=$(
        printf '%s\n' "${entries[@]}" | \
        fzf --height 40% \
            --reverse \
            --prompt='🔑 Pass> ' \
            --header='ENTER: copy • Ctrl+Y: copy+stay • Ctrl+E: edit • Ctrl+D: delete • + Add new' \
--preview='if [[ {} == *"Add New Password" ]]; then echo "✨ Create a new password entry"; else pass show {+2} | sed "1s/.*/🔐 [PASSWORD HIDDEN — Press ENTER to copy]/" | head -10; fi' \
            --preview-window='right:50%' \
            --bind 'ctrl-y:execute-silent( ( pass show -c {+2} &>/dev/null && command -v notify-send >/dev/null && notify-send "🔐 Password Copied" "{+2}" -t 1500 -u low ) )+refresh-preview+clear-screen' \
            --bind "ctrl-e:execute(EDITOR=nvim pass edit {+2})+reload($reload_cmd)" \
            --bind "ctrl-n:execute-silent( ( echo '✨ + Add New Password' ) )+accept" \
            --bind "ctrl-d:execute( \
                entry={+2}; \
                exec < /dev/tty; \
                echo '⚠️  DELETE CONFIRMATION'; \
                echo ''; \
                echo 'You are about to DELETE:'; \
                echo \"  \$entry\"; \
                echo ''; \
                echo 'Type YES to confirm deletion, or anything else to cancel:'; \
                read -r confirm; \
                if [[ \"\$confirm\" == 'YES' ]]; then \
                    echo 'Deleting...'; \
                    if pass rm -f \"\$entry\"; then \
                        echo \"✅ DELETED: \$entry\"; \
                        command -v notify-send >/dev/null && notify-send '🗑️ Password Deleted' \"\$entry\" -t 2000 -u low 2>/dev/null &; \
                    else \
                        echo \"❌ Failed to delete: \$entry\"; \
                        echo 'Error details:'; \
                        pass rm -f \"\$entry\" 2>&1 || echo 'Command failed'; \
                    fi; \
                else \
                    echo 'ℹ️  Deletion cancelled.'; \
                fi; \
                read -k1 -s 'key?Press any key to continue...' \
            )+reload($reload_cmd)"
    )

    [[ -z "$selection" ]] && return 0

    # Handle "Add New Password"
    if [[ "$selection" == *"Add New Password"* ]]; then
        echo "📁 Select parent folder for new password:"

        # Get directories
        local -a dirs
        dirs=("")
        # Collect all subdirectories, excluding hidden ones (basename starts with '.')
        local -a dirs
        dirs=("")
        while IFS= read -r -d '' dir; do
            [[ -n "$dir" ]] && dirs+=("$dir")
        done < <(
            find "$pass_dir" -type d -not -path "$pass_dir" -printf '%P\0' 2>/dev/null |
            grep -zv '^[^/]*/\.' |
            grep -zv '^\.'
        )

        # Show picker
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
                --preview='item="{}"; if [[ "$item" == *" (root)" ]]; then echo "Will create at root level (e.g., mysite)"; else clean="${item#📁 }"; clean="${clean%/}"; echo "Will create under: $clean/"; fi' \
                --preview-window='right:50%' \
                --bind 'ctrl-n:execute-silent( ( echo "📁 / (root)" ) )+accept'
        )

        [[ -z "$selected_dir" ]] && { echo "❌ Cancelled."; return 0; }

        # Clean path
        if [[ "$selected_dir" == *" (root)" ]]; then
            selected_dir=""
        else
            selected_dir=$(echo "$selected_dir" | sed 's/📁 //' | sed 's/\/$//')
        fi

        # Reset terminal and get name
        exec < /dev/tty
        echo -n "✏️  Enter new entry name (e.g., twitter): "
        read -r new_name
        [[ -z "$new_name" ]] && { echo "❌ Aborted."; return 1; }

        local new_path="${selected_dir:+$selected_dir/}$new_name"

        # Create temporary file for password input
        local tmpfile=$(mktemp -t passfzf-new-XXXXXX)
        {
            echo "# Enter password on first line. Lines after are optional metadata (notes, username, etc.)"
            echo "# DO NOT LEAVE FIRST LINE EMPTY."
            echo "# Save & quit to continue. Delete all content to cancel."
        } > "$tmpfile"

        # Open in editor
        ${EDITOR:-nvim} "$tmpfile"

        # Read first line as password
        password=$(head -n1 "$tmpfile" | tr -d '\r\n')

        # Clean up
        rm -f "$tmpfile"

        # Validate
        if [[ -z "$password" ]]; then
            echo "❌ Password cannot be empty. Aborted."
            return 1
        fi

        echo "✏️  Optional: adding metadata..."



        # Insert
        if echo -n "$password" | pass insert -e "$new_path"; then
            echo "✅ Created: $new_path"
            command -v notify-send >/dev/null && notify-send "🔐 New Password Created" "$new_path" -t 2000 -u low 2>/dev/null &
            # echo "✏️  Adding metadata (optional)..."
			echo "ℹ️  Metadata (if any) saved with password."
            # pass edit "$new_path"
            echo "🔄 Reloading..."
            passfzf
        else
            echo "❌ Failed to create: $new_path"
        fi

        return 0
    fi

    # Handle normal entry
    local real_path="${selection#* }"
    if pass show -c "$real_path" 2>/dev/null; then
        echo "✅ COPIED: $real_path"
        command -v notify-send >/dev/null && notify-send "🔐 Password Copied" "$real_path" -t 2000 -u low 2>/dev/null &
    else
        echo "❌ Failed to copy: $real_path"
    fi
}
