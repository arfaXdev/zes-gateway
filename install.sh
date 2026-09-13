#!/bin/sh
#
# ZES Gateway installer for Linux and macOS.
#
# Downloads a ZES Gateway release from:
#   https://github.com/arfaXdev/zes-gateway
#
# The executable remains named "gomodel" for compatibility with existing
# configuration, scripts, service definitions, and integrations.
#
# Usage:
#   curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | sh
#
# Install a specific release:
#   ZES_VERSION=v0.1.0 curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | sh
#
# Install to a custom directory:
#   ZES_INSTALL_DIR="$HOME/bin" curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | sh
#
# Supported environment variables:
#   ZES_VERSION       Release tag, such as v0.1.0. Defaults to latest.
#   ZES_INSTALL_DIR   Installation directory.
#   ZES_REPO          GitHub repository. Defaults to arfaXdev/zes-gateway.
#
# Legacy aliases are also accepted:
#   GOMODEL_VERSION
#   GOMODEL_INSTALL_DIR
#
# No telemetry is sent by this installer.

set -eu

REPO="${ZES_REPO:-arfaXdev/zes-gateway}"
BINARY="gomodel"

say() {
    printf '%s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "required command not found: $1"
}

require_command curl
require_command tar
require_command awk
require_command uname
require_command mktemp
require_command install

# Determine the operating system.
case "$(uname -s)" in
    Darwin)
        os="darwin"
        ;;
    Linux)
        os="linux"
        ;;
    *)
        fail "unsupported operating system: $(uname -s)"
        ;;
esac

# Determine the CPU architecture.
case "$(uname -m)" in
    x86_64 | amd64)
        arch="amd64"
        ;;
    arm64 | aarch64)
        arch="arm64"
        ;;
    *)
        fail "unsupported CPU architecture: $(uname -m)"
        ;;
esac

# ZES_VERSION takes priority. GOMODEL_VERSION remains supported for
# compatibility with the original installer.
tag="${ZES_VERSION:-${GOMODEL_VERSION:-}}"

if [ -z "$tag" ]; then
    say "Resolving the latest ZES Gateway release..."

    latest_url="https://github.com/$REPO/releases/latest"

    resolved_url="$(
        curl -fsSLI \
            --retry 3 \
            --retry-delay 1 \
            -o /dev/null \
            -w '%{url_effective}' \
            "$latest_url"
    )" || fail "could not resolve the latest release from $latest_url"

    tag="${resolved_url##*/}"

    case "$tag" in
        v*)
            ;;
        *)
            fail "no published ZES Gateway release was found"
            ;;
    esac
fi

case "$tag" in
    v*)
        ;;
    *)
        fail "invalid release tag '$tag'; expected a tag such as v0.1.0"
        ;;
esac

version="${tag#v}"
archive="${BINARY}_${version}_${os}_${arch}.tar.gz"
base_url="https://github.com/$REPO/releases/download/$tag"

tmpdir="$(mktemp -d)"

cleanup() {
    rm -rf "$tmpdir"
}

trap cleanup EXIT INT TERM HUP

say "Downloading ZES Gateway $tag for $os/$arch..."

curl -fL \
    --retry 3 \
    --retry-delay 1 \
    --connect-timeout 15 \
    -o "$tmpdir/$archive" \
    "$base_url/$archive" ||
    fail "could not download $base_url/$archive"

curl -fL \
    --retry 3 \
    --retry-delay 1 \
    --connect-timeout 15 \
    -o "$tmpdir/checksums.txt" \
    "$base_url/checksums.txt" ||
    fail "could not download $base_url/checksums.txt"

expected="$(
    awk -v filename="$archive" '
        $2 == filename || $2 == "*" filename {
            print $1
            exit
        }
    ' "$tmpdir/checksums.txt"
)"

[ -n "$expected" ] ||
    fail "the release checksum file does not contain $archive"

if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmpdir/$archive" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$tmpdir/$archive" | awk '{print $1}')"
else
    fail "sha256sum or shasum is required to verify the download"
fi

if [ "$actual" != "$expected" ]; then
    fail "checksum verification failed for $archive"
fi

say "Checksum verified."

tar -xzf "$tmpdir/$archive" -C "$tmpdir" "$BINARY" ||
    fail "could not extract $archive"

[ -f "$tmpdir/$BINARY" ] ||
    fail "the downloaded archive does not contain $BINARY"

[ -x "$tmpdir/$BINARY" ] ||
    chmod 755 "$tmpdir/$BINARY"

# ZES_INSTALL_DIR takes priority. GOMODEL_INSTALL_DIR remains supported for
# compatibility with the original installer.
install_dir="${ZES_INSTALL_DIR:-${GOMODEL_INSTALL_DIR:-}}"

if [ -z "$install_dir" ]; then
    if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
        install_dir="/usr/local/bin"
    elif [ ! -e /usr/local/bin ] && [ -w /usr/local ]; then
        install_dir="/usr/local/bin"
    else
        install_dir="$HOME/.local/bin"
    fi
fi

mkdir -p "$install_dir" ||
    fail "could not create installation directory: $install_dir"

[ -d "$install_dir" ] ||
    fail "installation path is not a directory: $install_dir"

[ -w "$install_dir" ] ||
    fail "$install_dir is not writable; set ZES_INSTALL_DIR to a writable directory"

destination="$install_dir/$BINARY"

if [ -e "$destination" ]; then
    say "Replacing the existing executable at $destination..."
fi

install -m 755 "$tmpdir/$BINARY" "$destination" ||
    fail "could not install $BINARY to $destination"

say ""
say "ZES Gateway $tag was installed successfully."
say ""
say "Executable:"
say "  $destination"

case ":$PATH:" in
    *":$install_dir:"*)
        ;;
    *)
        say ""
        warn "$install_dir is not currently in your PATH"
        say ""
        say "Add it for the current shell with:"
        say "  export PATH=\"$install_dir:\$PATH\""
        say ""
        say "To make that permanent, add the same command to your shell"
        say "configuration file, such as ~/.profile, ~/.bashrc, or ~/.zshrc."
        ;;
esac

say ""
say "Start ZES Gateway:"
say "  export OPENAI_API_KEY=\"your-openai-key\"  # optional"
say "  gomodel"
say ""
say "Then open the ZES Frost Dashboard:"
say "  http://localhost:8080/admin/dashboard"
say ""
say "Repository:"
say "  https://github.com/$REPO"