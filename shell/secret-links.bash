# Source from ~/.bashrc. Defines a shell function for each program linked in
# secret-links.conf, so typing its name runs it through with-secrets.
_secret_links="${XDG_CONFIG_HOME:-$HOME/.config}/secret-links.conf"
if [ -f "$_secret_links" ]; then
    for _prog in $(awk '!/^#/ && NF == 3 { print $1 }' "$_secret_links" | sort -u); do
        eval "$_prog() { \"\$HOME/.local/bin/with-secrets\" $_prog \"\$@\"; }"
    done
    unset _prog
fi
unset _secret_links
