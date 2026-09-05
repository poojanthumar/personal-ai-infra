#!/bin/zsh
set -euo pipefail

umask 077

backup_dir="$HOME/Backups/oracle"
ssh_key="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Code/secrets/ssh-keys-oracle-vm.key"
vm_host="ubuntu@100.105.56.99"
stamp="$(date +%F)"

mkdir -p "$backup_dir"

for database in aihub website; do
	target="$backup_dir/${database}-${stamp}.dump"
	temporary="$(mktemp "$backup_dir/.${database}-${stamp}.XXXXXX.dump")"
	trap 'rm -f "$temporary"' EXIT

	ssh -i "$ssh_key" -o BatchMode=yes "$vm_host" \
		"sudo -u postgres pg_dump --format=custom --no-owner --no-acl --dbname=${database}" \
		> "$temporary"

	pg_restore --list "$temporary" >/dev/null
	test "$(stat -f %z "$temporary")" -gt 512
	mv -f "$temporary" "$target"
	chmod 600 "$target"
	trap - EXIT
	print "verified backup: $target"
done

find "$backup_dir" -type f \( -name 'aihub-*.dump' -o -name 'website-*.dump' \) -mtime +14 -delete
