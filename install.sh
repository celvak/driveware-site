#!/usr/bin/env bash
# DriveWare installer — clones the public CLI + runs setup.
# Usage:  curl -fsSL https://driveware.dev/install.sh | bash
#         curl -fsSL https://driveware.dev/install.sh | bash -s -- --no-setup
#         curl -fsSL https://driveware.dev/install.sh | bash -s -- --prefix ~/Apps
set -euo pipefail

REPO_URL="${DW_REPO_URL:-https://github.com/celvak/driveware-cli.git}"
PREFIX="${HOME}/.driveware"
RUN_SETUP=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-setup) RUN_SETUP=false; shift ;;
    --prefix)   PREFIX="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: install.sh [--no-setup] [--prefix DIR]"
      echo "  --no-setup     don't run driveware-setup.sh after install"
      echo "  --prefix DIR   install location (default: ~/.driveware)"
      exit 0 ;;
    *) echo "!! unknown flag: $1"; exit 1 ;;
  esac
done

INSTALL_DIR="${PREFIX}/cli"

# ---- preflight ----
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "!! '$1' is required but not installed."
    case "$1" in
      git)    echo "   macOS: xcode-select --install      Linux: apt install git" ;;
      curl)   echo "   macOS: pre-installed              Linux: apt install curl" ;;
      rclone) echo "   macOS: brew install rclone        Linux: apt install rclone" ;;
      sqlite3) echo "   macOS: pre-installed             Linux: apt install sqlite3" ;;
    esac
    exit 1
  fi
}
need git
need curl
need rclone

OS="$(uname)"
case "$OS" in
  Darwin) ;;
  Linux)
    if ! command -v fusermount >/dev/null && ! command -v fusermount3 >/dev/null; then
      echo "   ! FUSE not installed — needed for mount (sync still works without it)"
      echo "     apt install fuse3   |   dnf install fuse3   |   pacman -S fuse3"
    fi ;;
  *) echo "!! Unsupported OS: $OS  (macOS + Linux supported; Windows uses windows/*.ps1 in the repo)"; exit 1 ;;
esac

# ---- clone or update ----
mkdir -p "$PREFIX"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "==> Updating $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only --quiet || {
    echo "   ! git pull failed — preserving local state. Re-clone manually if needed."
  }
else
  echo "==> Cloning $REPO_URL -> $INSTALL_DIR"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/bin/"*.sh

# ---- shell PATH hint ----
SHELL_RC=""
case "${SHELL##*/}" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
esac
PATH_LINE='export PATH="'"$INSTALL_DIR"'/bin:$PATH"'

if [[ -n "$SHELL_RC" ]] && ! grep -q "$INSTALL_DIR/bin" "$SHELL_RC" 2>/dev/null; then
  echo ""
  echo "   To put DriveWare on your PATH, add this to $SHELL_RC:"
  echo ""
  echo "       $PATH_LINE"
  echo ""
  echo "   Or run now:  echo '$PATH_LINE' >> $SHELL_RC && source $SHELL_RC"
fi

# ---- setup ----
echo ""
echo "==> Installed at $INSTALL_DIR"
echo "    bin/         — CLI scripts"
echo "    dashboard/   — local web dashboard (./bin/driveware-dashboard.sh start)"
echo "    menubar/     — macOS menu bar app (./menubar/build.sh)"
echo ""

if $RUN_SETUP; then
  echo "==> Running setup wizard..."
  echo ""
  exec "$INSTALL_DIR/bin/driveware-setup.sh"
else
  echo "Next: $INSTALL_DIR/bin/driveware-setup.sh"
fi
