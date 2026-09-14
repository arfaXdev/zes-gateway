#!/bin/sh
#
# ZES Gateway installer for Linux and macOS.
#
# Downloads a checksummed release from:
#   https://github.com/arfaXdev/zes-gateway
#
# Until that repository publishes its first binary release, the installer
# builds the ZES Gateway source instead. A source build requires Go 1.27.1 or
# newer, Node.js 22 or newer, and npm.
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
#   curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | ZES_VERSION=v0.1.0 sh
#
# Build a specific source branch, tag, or commit:
#   curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | ZES_REF=main sh
#
# Install to a custom directory:
#   curl -fsSL \
#     https://raw.githubusercontent.com/arfaXdev/zes-gateway/main/install.sh \
#     | ZES_INSTALL_DIR="$HOME/bin" sh
#
# Supported environment variables:
#   ZES_VERSION       Release tag, such as v0.1.0. Defaults to latest.
#   ZES_REF           Source branch, tag, or commit to build. Cannot be used
#                     together with ZES_VERSION. Defaults to main only when no
#                     ZES Gateway release has been published.
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

case "$REPO" in
    */*)
        ;;
    *)
        fail "invalid GitHub repository '$REPO'; expected owner/name"
        ;;
esac

case "$REPO" in
    *[!A-Za-z0-9._/-]* | */*/* | /* | */)
        fail "invalid GitHub repository '$REPO'; expected owner/name"
        ;;
esac

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

# Determine the CPU architecture used by published release archives.
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

# ZES_* takes priority. GOMODEL_* remains supported for compatibility with the
# original installer.
tag="${ZES_VERSION:-${GOMODEL_VERSION:-}}"
source_ref="${ZES_REF:-}"

if [ -n "$tag" ] && [ -n "$source_ref" ]; then
    fail "ZES_VERSION and ZES_REF cannot be used together"
fi

tmpdir="$(mktemp -d)" || fail "could not create a temporary directory"

cleanup() {
    rm -rf "$tmpdir"
}

trap cleanup 0
trap 'cleanup; exit 1' HUP INT TERM

install_release() {
    release_tag="$1"

    case "$release_tag" in
        v[0-9]*)
            ;;
        *)
            fail "invalid release tag '$release_tag'; expected a tag such as v0.1.0"
            ;;
    esac

    case "$release_tag" in
        *[!A-Za-z0-9._+-]*)
            fail "invalid release tag '$release_tag'; expected a tag such as v0.1.0"
            ;;
    esac

    version="${release_tag#v}"
    archive="${BINARY}_${version}_${os}_${arch}.tar.gz"
    base_url="https://github.com/$REPO/releases/download/$release_tag"

    say "Downloading ZES Gateway $release_tag for $os/$arch..."

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

    case "$expected" in
        *[!0-9A-Fa-f]* | '')
            fail "the release checksum for $archive is invalid"
            ;;
    esac

    [ "${#expected}" -eq 64 ] ||
        fail "the release checksum for $archive is invalid"

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

    installed_version="$release_tag"
}

build_source() {
    ref="$1"

    case "$ref" in
        '' | -* | /* | */ | *[!A-Za-z0-9._/-]*)
            fail "invalid source ref '$ref'"
            ;;
    esac

    case "/$ref/" in
        *//* | */../* | */./*)
            fail "invalid source ref '$ref'"
            ;;
    esac

    require_command go
    require_command node
    require_command npm
    require_command date

    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)" ||
        fail "could not determine the Node.js version"

    case "$node_major" in
        '' | *[!0-9]*)
            fail "could not determine the Node.js version"
            ;;
    esac

    [ "$node_major" -ge 22 ] ||
        fail "Node.js 22 or newer is required to build ZES Gateway"

    source_archive="$tmpdir/source.tar.gz"
    source_dir="$tmpdir/source"
    source_url="https://github.com/$REPO/archive/$ref.tar.gz"

    say "Building source ref '$ref' (requires Go 1.27.1+, Node.js 22+, and npm)..."

    curl -fL \
        --retry 3 \
        --retry-delay 1 \
        --connect-timeout 15 \
        -o "$source_archive" \
        "$source_url" ||
        fail "could not download $source_url"

    mkdir -p "$source_dir" || fail "could not create the source directory"
    tar -xzf "$source_archive" -C "$source_dir" --strip-components=1 ||
        fail "could not extract the ZES Gateway source"

    [ -f "$source_dir/go.mod" ] ||
        fail "the downloaded source archive does not contain go.mod"
    [ -f "$source_dir/web/dashboard/package-lock.json" ] ||
        fail "the downloaded source archive does not contain the dashboard"

    say "Building the ZES Frost Dashboard..."
    (
        cd "$source_dir/web/dashboard" &&
            npm ci --no-audit --no-fund --ignore-scripts &&
            npm run build
    ) || fail "could not build the ZES Frost Dashboard"

    build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    ldflags="-s -w -X github.com/enterpilot/gomodel/internal/version.Version=source -X github.com/enterpilot/gomodel/internal/version.Commit=$ref -X github.com/enterpilot/gomodel/internal/version.Date=$build_date"

    say "Building the gateway..."
    (
        cd "$source_dir" &&
            CGO_ENABLED=0 go build \
                -trimpath \
                -ldflags "$ldflags" \
                -o "$tmpdir/$BINARY" \
                ./cmd/gomodel
    ) || fail "could not build ZES Gateway; Go 1.27.1 or newer is required"

    [ -f "$tmpdir/$BINARY" ] || fail "the source build did not produce $BINARY"

    installed_version="source ref $ref"
}

if [ -n "$source_ref" ]; then
    build_source "$source_ref"
elif [ -n "$tag" ]; then
    install_release "$tag"
else
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

    latest_tag="${resolved_url##*/}"

    case "$latest_tag" in
        v[0-9]*)
            install_release "$latest_tag"
            ;;
        *)
            say "No published ZES Gateway release was found."
            build_source main
            ;;
    esac
fi

[ -x "$tmpdir/$BINARY" ] || chmod 755 "$tmpdir/$BINARY"

install_dir="${ZES_INSTALL_DIR:-${GOMODEL_INSTALL_DIR:-}}"

if [ -z "$install_dir" ]; then
    if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
        install_dir="/usr/local/bin"
    elif [ ! -e /usr/local/bin ] && [ -w /usr/local ]; then
        install_dir="/usr/local/bin"
    else
        [ -n "${HOME:-}" ] ||
            fail "HOME is not set; set ZES_INSTALL_DIR to a writable directory"
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
say "ZES Gateway ($installed_version) was installed successfully."
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
