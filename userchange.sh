#!/usr/bin/env bash
set -euo pipefail

OLDUSER="sonore"
NEWUSER="sorone"
OLDHOME="/home/$OLDUSER"
NEWHOME="/home/$NEWUSER"

# 1) sanity checks
if [[ $EUID -ne 0 ]]; then
  echo "❌ Must be run as root."
  exit 1
fi

if ! id "$OLDUSER" &>/dev/null; then
  echo "❌ User '$OLDUSER' does not exist."
  exit 1
fi

if [[ "${SUDO_USER:-root}" == "$OLDUSER" ]]; then
  echo "⚠️  You're running as '$OLDUSER'. Please switch to another admin account."
  exit 1
fi

echo "🔄 Renaming user and home directory..."

# 2) rename the login and home
usermod -l "$NEWUSER" "$OLDUSER"
usermod -d "$NEWHOME" -m "$NEWUSER"

# 3) rename the primary group if it exists
if getent group "$OLDUSER" >/dev/null; then
  groupmod -n "$NEWUSER" "$OLDUSER"
fi

# 4) fix ownership on the moved home
chown -R "$NEWUSER":"$NEWUSER" "$NEWHOME"

# 5) patch Hyprland configs: update any hard-coded paths
if [[ -d "$NEWHOME/.config/hypr" ]]; then
  echo "🔧 Updating Hyprland configs..."
  find "$NEWHOME/.config/hypr" -type f \
    -exec sed -i "s|/home/$OLDUSER|/home/$NEWUSER|g" {} +
  chown -R "$NEWUSER":"$NEWUSER" "$NEWHOME/.config/hypr"
fi

# 6) migrate AccountsService entry (for graphical login managers)
ASDIR="/var/lib/AccountsService/users"
if [[ -f "$ASDIR/$OLDUSER" ]]; then
  echo "🖼  Migrating login manager cache..."
  mv "$ASDIR/$OLDUSER" "$ASDIR/$NEWUSER"
  sed -i "s/^User=$OLDUSER$/User=$NEWUSER/" "$ASDIR/$NEWUSER"
fi

echo "✅ Rename complete!"
cat <<EOF

Next steps:

1. **Log in** as '$NEWUSER'.
2. **Reload your user services** so Hyprland picks up any user-unit changes:
     systemctl --user daemon-reexec
     systemctl --user daemon-reload

3. **Start Hyprland** (or just log in via your display manager).

Verify:
  whoami           # should be $NEWUSER
  echo \$HOME      # should be $NEWHOME
  ls ~/.config/hypr # your old Hyprland files should still be there

Enjoy your session on the new account! 🎉
EOF
