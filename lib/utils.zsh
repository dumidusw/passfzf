#!/usr/bin/env zsh

# Shared utilities for notifications, confirmations, validations, temp scripts

_passfzf_notify() {
    local title="$1" msg="$2" duration="${3:-2000}"
    command -v notify-send >/dev/null 2>&1 && {
        notify-send "$title" "$msg" -t "$duration" -u low &>/dev/null &
        disown 2>/dev/null || true
    }
}

_passfzf_confirm_delete() {
    local entry="$1"
    exec < /dev/tty
    echo "⚠️  DELETE CONFIRMATION"
    echo ""
    echo "You are about to DELETE:"
    echo "  $entry"
    echo ""
    echo "Type YES to confirm deletion, or anything else to cancel:"
    read -r confirm
    [[ "$confirm" == "YES" ]]
}

_passfzf_validate_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "❌ Aborted."
        return 1
    fi
    if [[ "$name" =~ [[:space:]] ]]; then
        echo "❌ Entry name cannot contain spaces. Use underscores or hyphens instead."
        return 2
    fi
    return 0
}

_passfzf_create_delete_script() {
    local delete_script=$(mktemp -t passfzf-delete-XXXXXX.sh)
    cat > "$delete_script" <<'DELEOF'
#!/bin/bash
entry="$1"
exec < /dev/tty
echo "⚠️  DELETE CONFIRMATION"
echo ""
echo "You are about to DELETE:"
echo "  $entry"
echo ""
echo "Type YES to confirm deletion, or anything else to cancel:"
read -r confirm
if [[ "$confirm" == "YES" ]]; then
    echo "Deleting..."
    if pass rm -f "$entry" &>/dev/null; then
        echo "✅ Password deleted successfully"
        command -v notify-send >/dev/null 2>&1 && notify-send "🗑️ Password Deleted" "$entry" -t 2000 -u low &>/dev/null &
    else
        echo "❌ Failed to delete: $entry"
    fi
else
    echo "ℹ️ Deletion cancelled."
fi
read -k1 -s "key?Press any key to continue..."
DELEOF
    chmod +x "$delete_script"
    echo "$delete_script"
}

_passfzf_create_editor_tmpfile() {
    local tmpfile=$(mktemp -t passfzf-new-XXXXXX)
    cat > "$tmpfile" <<'EOF'
# Enter password on first line. Lines after are optional metadata (notes, username, etc.)
# DO NOT LEAVE FIRST LINE EMPTY.
# Save & quit to continue. Delete all content to cancel.
EOF
    echo "$tmpfile"
}

_passfzf_cleanup_tmpfiles() {
    local files=("$@")
    for f in "${files[@]}"; do
        [[ -f "$f" ]] && rm -f "$f"
    done
}
