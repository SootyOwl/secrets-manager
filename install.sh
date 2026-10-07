#!/bin/sh
# Symlink the launchers into ~/.local/bin and add the menu entry.
# Re-run after moving the repo.
set -e
repo=$(cd "$(dirname "$0")" && pwd -P)
bin=$HOME/.local/bin
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications

mkdir -p "$bin" "$apps"
ln -sfn "$repo/bin/secrets-manager" "$bin/secrets-manager"
ln -sfn "$repo/bin/with-secrets" "$bin/with-secrets"
sed "s|@BIN@|$bin|" "$repo/secrets-manager.desktop.in" >"$apps/secrets-manager.desktop"
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo "Installed. Open \"Secrets\" from the app menu."
if ! grep -q 'secret-links' "$HOME/.bashrc" 2>/dev/null; then
    echo "To make linked programs pick up their secrets, add this to ~/.bashrc:"
    echo "    . \"$repo/shell/secret-links.bash\""
fi
