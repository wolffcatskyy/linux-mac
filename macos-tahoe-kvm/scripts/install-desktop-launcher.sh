#!/usr/bin/env bash
# =============================================================================
# First-boot script: Creates desktop launcher for macOS Tahoe KVM
# =============================================================================
# Add this to your Linux ISO's first-boot sequence (systemd oneshot, rc.local,
# or autostart). It creates:
#   1. A .desktop launcher on every user's desktop
#   2. A system-wide .desktop entry in /usr/share/applications
#   3. An unattended pre-download option (optional, via --prefetch)
#
# Usage in your ISO build:
#   - Copy this entire macos-tahoe-kvm/ directory to /opt/macos-tahoe-kvm/
#   - Add install-desktop-launcher.sh to first-boot
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="/opt/macos-tahoe-kvm"
ICON_NAME="macos-tahoe-kvm"

# -- Icon (embedded SVG) -------------------------------------------------------
create_icon() {
    local icon_dir="/usr/share/icons/hicolor/scalable/apps"
    mkdir -p "$icon_dir"

    cat > "${icon_dir}/${ICON_NAME}.svg" << 'ICON_SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="100%" style="stop-color:#16213e"/>
    </linearGradient>
    <linearGradient id="apple" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#a8e6cf"/>
      <stop offset="100%" style="stop-color:#3dc1d3"/>
    </linearGradient>
  </defs>
  <!-- Background -->
  <rect width="128" height="128" rx="24" fill="url(#bg)"/>
  <!-- Stylised Apple logo -->
  <g transform="translate(64,58) scale(0.55)">
    <path fill="url(#apple)" d="M-30,-48 C-30,-48 -18,-62 0,-62 C18,-62 30,-48 30,-48
      C44,-30 44,-8 38,14 C32,36 20,56 0,70
      C-20,56 -32,36 -38,14 C-44,-8 -44,-30 -30,-48Z"/>
    <ellipse cx="0" cy="-58" rx="8" ry="12" fill="url(#apple)" transform="rotate(15)"/>
  </g>
  <!-- "KVM" text -->
  <text x="64" y="118" text-anchor="middle" font-family="monospace" font-weight="bold"
    font-size="18" fill="#a8e6cf" opacity="0.9">KVM</text>
</svg>
ICON_SVG

    # Also create a PNG fallback for DEs that don't handle SVG well
    if command -v rsvg-convert &>/dev/null; then
        for size in 48 64 128 256; do
            local png_dir="/usr/share/icons/hicolor/${size}x${size}/apps"
            mkdir -p "$png_dir"
            rsvg-convert -w "$size" -h "$size" \
                "${icon_dir}/${ICON_NAME}.svg" \
                -o "${png_dir}/${ICON_NAME}.png" 2>/dev/null || true
        done
    fi

    echo "[OK] Icon installed"
}

# -- Desktop entry (system-wide) -----------------------------------------------
create_system_desktop_entry() {
    cat > "/usr/share/applications/${ICON_NAME}.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=macOS Tahoe KVM
GenericName=macOS Virtual Machine
Comment=Download and run macOS Tahoe in a pre-configured KVM virtual machine (Mac Pro 6,1)
Exec=bash -c 'cd ${INSTALL_DIR} && terminal_cmd=\$(which gnome-terminal 2>/dev/null || which xfce4-terminal 2>/dev/null || which konsole 2>/dev/null || which xterm 2>/dev/null) && case \$terminal_cmd in *gnome*) \$terminal_cmd -- bash ${INSTALL_DIR}/scripts/macos-tahoe-setup.sh;; *xfce4*) \$terminal_cmd -e "bash ${INSTALL_DIR}/scripts/macos-tahoe-setup.sh";; *konsole*) \$terminal_cmd -e bash ${INSTALL_DIR}/scripts/macos-tahoe-setup.sh;; *) \$terminal_cmd -e "bash ${INSTALL_DIR}/scripts/macos-tahoe-setup.sh";; esac'
Icon=${ICON_NAME}
Categories=System;Emulator;Virtualization;
Keywords=macOS;Apple;KVM;QEMU;Tahoe;Virtual;Machine;
Terminal=false
StartupNotify=true
EOF

    chmod 644 "/usr/share/applications/${ICON_NAME}.desktop"
    echo "[OK] System .desktop entry created"
}

# -- Copy to each user's desktop -----------------------------------------------
copy_to_user_desktops() {
    local desktop_file="/usr/share/applications/${ICON_NAME}.desktop"

    # Find all real user home directories
    while IFS=: read -r username _ uid _ _ home _; do
        # Skip system users (uid < 1000) except root if explicitly wanted
        [ "$uid" -lt 1000 ] && continue
        [ ! -d "$home" ] && continue

        local user_desktop="${home}/Desktop"
        # Some locales use translated folder names
        if [ -f "${home}/.config/user-dirs.dirs" ]; then
            local xdg_desktop
            xdg_desktop=$(grep '^XDG_DESKTOP_DIR' "${home}/.config/user-dirs.dirs" 2>/dev/null | \
                sed 's/.*="\(.*\)"/\1/' | sed "s|\$HOME|${home}|")
            [ -n "$xdg_desktop" ] && user_desktop="$xdg_desktop"
        fi

        if [ -d "$user_desktop" ]; then
            cp "$desktop_file" "${user_desktop}/${ICON_NAME}.desktop"
            chown "${username}:${username}" "${user_desktop}/${ICON_NAME}.desktop" 2>/dev/null || true
            chmod 755 "${user_desktop}/${ICON_NAME}.desktop"
            # Mark as trusted for GNOME
            if command -v gio &>/dev/null; then
                sudo -u "$username" gio set "${user_desktop}/${ICON_NAME}.desktop" \
                    metadata::trusted true 2>/dev/null || true
            fi
            echo "[OK] Desktop shortcut created for user: ${username}"
        fi
    done < /etc/passwd
}

# -- Create wrapper script for non-terminal launch -----------------------------
create_launcher_wrapper() {
    # This wrapper detects the terminal emulator and launches setup in it
    cat > "${INSTALL_DIR}/launch-gui.sh" << 'WRAPPER'
#!/usr/bin/env bash
# GUI-friendly wrapper — finds a terminal and runs setup inside it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect available terminal
for term in gnome-terminal xfce4-terminal konsole mate-terminal lxterminal xterm; do
    if command -v "$term" &>/dev/null; then
        TERMINAL="$term"
        break
    fi
done

if [ -z "${TERMINAL:-}" ]; then
    # Fallback: try to use xdg-terminal or x-terminal-emulator
    TERMINAL=$(which x-terminal-emulator 2>/dev/null || which xdg-terminal 2>/dev/null || echo "")
fi

if [ -z "$TERMINAL" ]; then
    # Last resort: zenity/kdialog error
    if command -v zenity &>/dev/null; then
        zenity --error --text="No terminal emulator found. Install gnome-terminal or xterm."
    elif command -v kdialog &>/dev/null; then
        kdialog --error "No terminal emulator found. Install gnome-terminal or xterm."
    fi
    exit 1
fi

cd "$SCRIPT_DIR"
case "$TERMINAL" in
    gnome-terminal) exec $TERMINAL --title="macOS Tahoe KVM Setup" -- bash scripts/macos-tahoe-setup.sh ;;
    xfce4-terminal) exec $TERMINAL --title="macOS Tahoe KVM Setup" -e "bash scripts/macos-tahoe-setup.sh" ;;
    konsole)        exec $TERMINAL --title "macOS Tahoe KVM Setup" -e bash scripts/macos-tahoe-setup.sh ;;
    mate-terminal)  exec $TERMINAL --title="macOS Tahoe KVM Setup" -e "bash scripts/macos-tahoe-setup.sh" ;;
    *)              exec $TERMINAL -e "bash scripts/macos-tahoe-setup.sh" ;;
esac
WRAPPER
    chmod +x "${INSTALL_DIR}/launch-gui.sh"
    echo "[OK] GUI launcher wrapper created"
}

# -- Optional: prefetch recovery in background ----------------------------------
prefetch_recovery() {
    if [ "${1:-}" = "--prefetch" ]; then
        echo "[INFO] Pre-fetching macOS recovery in background..."
        nohup bash "${INSTALL_DIR}/scripts/macos-tahoe-setup.sh" --download-only \
            > /var/log/macos-tahoe-prefetch.log 2>&1 &
        echo "[OK] Recovery download started in background (PID: $!)"
        echo "     Log: /var/log/macos-tahoe-prefetch.log"
    fi
}

# -- Systemd service for first-boot (optional) ---------------------------------
create_firstboot_service() {
    cat > /etc/systemd/system/macos-tahoe-setup.service << EOF
[Unit]
Description=macOS Tahoe KVM — First Boot Desktop Icon Setup
After=graphical.target
ConditionPathExists=!/var/lib/macos-tahoe-kvm-installed

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/scripts/install-desktop-launcher.sh
ExecStartPost=/bin/touch /var/lib/macos-tahoe-kvm-installed
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable macos-tahoe-setup.service
    echo "[OK] First-boot systemd service installed and enabled"
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "════════════════════════════════════════════════════════"
    echo "  macOS Tahoe KVM — Desktop Launcher Installer"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Ensure we're running as root (needed for system-wide install)
    if [ "$(id -u)" -ne 0 ]; then
        echo "[WARN] Not running as root — installing for current user only"
        # User-local install
        local user_apps="${HOME}/.local/share/applications"
        mkdir -p "$user_apps"

        # Minimal .desktop for current user
        cat > "${user_apps}/${ICON_NAME}.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=macOS Tahoe KVM
Comment=macOS Tahoe virtual machine (Mac Pro 6,1)
Exec=bash -c 'cd ${PROJECT_DIR} && gnome-terminal -- bash scripts/macos-tahoe-setup.sh 2>/dev/null || xterm -e "bash scripts/macos-tahoe-setup.sh"'
Icon=computer
Categories=System;Emulator;
Terminal=false
EOF
        chmod 755 "${user_apps}/${ICON_NAME}.desktop"
        echo "[OK] User-local .desktop entry created"

        # Copy to Desktop
        local desktop="${HOME}/Desktop"
        [ -d "$desktop" ] && cp "${user_apps}/${ICON_NAME}.desktop" "${desktop}/"
        echo "[OK] Desktop shortcut created"
        return
    fi

    # Root install — full setup
    # Copy project to /opt if not already there
    if [ "$PROJECT_DIR" != "$INSTALL_DIR" ]; then
        echo "[INFO] Installing to ${INSTALL_DIR}..."
        mkdir -p "$INSTALL_DIR"
        cp -r "${PROJECT_DIR}"/* "$INSTALL_DIR"/
        chmod -R 755 "$INSTALL_DIR/scripts"
    fi

    create_icon
    create_launcher_wrapper
    create_system_desktop_entry
    copy_to_user_desktops

    # Parse args
    CREATE_SERVICE=false
    PREFETCH=false
    for arg in "$@"; do
        case "$arg" in
            --systemd)   CREATE_SERVICE=true ;;
            --prefetch)  PREFETCH=true ;;
        esac
    done

    if $CREATE_SERVICE; then
        create_firstboot_service
    fi

    if $PREFETCH; then
        prefetch_recovery --prefetch
    fi

    # Update icon caches
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
    update-desktop-database /usr/share/applications/ 2>/dev/null || true

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  ✓ Installation complete"
    echo ""
    echo "  Desktop icon: 'macOS Tahoe KVM'"
    echo "  Application:  /usr/share/applications/${ICON_NAME}.desktop"
    echo "  Install dir:  ${INSTALL_DIR}"
    echo ""
    echo "  Integration into your ISO:"
    echo "    1. Copy macos-tahoe-kvm/ to /opt/macos-tahoe-kvm/"
    echo "    2. Run: /opt/macos-tahoe-kvm/scripts/install-desktop-launcher.sh --systemd"
    echo "    3. (Optional) Add --prefetch to start download on first boot"
    echo "════════════════════════════════════════════════════════"
}

main "$@"
