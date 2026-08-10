#!/bin/bash

version="1.2"
changelog="\n--Update Source xml EPGImport"

TMPSources=/tmp/EPGimport-Sources-install

echo "Starting EPGImport Sources installation..."

if [ ! -d /usr/lib64 ]; then
    PLUGINPATH=/usr/lib/enigma2/python/Plugins/Extensions/EPGImport
else
    PLUGINPATH=/usr/lib64/enigma2/python/Plugins/Extensions/EPGImport
fi

cleanup() {
    echo "Cleaning up temporary files..."
    [ -d "$TMPSources" ] && rm -rf "$TMPSources"
}

detect_os() {
    if [ -f /var/lib/dpkg/status ]; then
        OSTYPE="DreamOs"
        STATUS="/var/lib/dpkg/status"
    elif [ -f /etc/opkg/opkg.conf ] || [ -f /var/lib/opkg/status ]; then
        OSTYPE="OE"
        STATUS="/var/lib/opkg/status"
    else
        OSTYPE="Unknown"
        STATUS=""
    fi
    echo "Detected OS type: $OSTYPE"
}

detect_os

cleanup

if ! command -v wget >/dev/null 2>&1; then
    echo "Installing wget..."
    case "$OSTYPE" in
        "DreamOs")
            apt-get update && apt-get install -y wget || { echo "Failed to install wget"; exit 1; }
            ;;
        "OE")
            opkg update && opkg install wget || { echo "Failed to install wget"; exit 1; }
            ;;
        *)
            echo "Unsupported OS type. Cannot install wget."
            exit 1
            ;;
    esac
fi

if [ ! -d "$PLUGINPATH" ]; then
    echo "EPGImport plugin not found at $PLUGINPATH"
    echo "Please install EPGImport plugin first"
    exit 1
fi

echo "Downloading EPG sources..."
mkdir -p "$TMPSources"
mkdir -p '/etc/epgimport'

wget --no-check-certificate 'https://github.com/Belfagor2005/EPGimport-Sources/archive/refs/heads/main.tar.gz' -O "$TMPSources/main.tar.gz"
if [ $? -ne 0 ]; then
    echo "Failed to download EPG sources!"
    cleanup
    exit 1
fi

echo "Extracting sources..."
tar -xzf "$TMPSources/main.tar.gz" -C "$TMPSources"
if [ $? -ne 0 ]; then
    echo "Failed to extract EPG sources!"
    cleanup
    exit 1
fi

echo "Cleaning up unnecessary files..."
find "$TMPSources/EPGimport-Sources-main" -type f -name "*.bb" -delete

echo "Installing EPG sources..."
if [ -d "$TMPSources/EPGimport-Sources-main" ]; then
    cp -r "$TMPSources/EPGimport-Sources-main"/* '/etc/epgimport/' 2>/dev/null
    echo "EPG sources installed to /etc/epgimport/"
else
    echo "Sources directory not found after extraction!"
    cleanup
    exit 1
fi

sync

echo "Verifying installation..."
if [ -d "/etc/epgimport" ] && [ -n "$(ls -A "/etc/epgimport" 2>/dev/null)" ]; then
    echo "EPG sources directory found and not empty: /etc/epgimport"
    echo "Installed sources:"
    ls -la "/etc/epgimport/" | head -10
    echo ""
    echo "Total files installed: $(find "/etc/epgimport" -type f | wc -l)"
else
    echo "EPG sources installation failed - directory is empty!"
    cleanup
    exit 1
fi

cleanup
sync

FILE="/etc/image-version"
box_type=$(sed -n '1p' /etc/hostname 2>/dev/null || echo "Unknown")
# distro_value=$(grep '^distro=' "$FILE" 2>/dev/null | awk -F '=' '{print $2}')
# distro_version=$(grep '^version=' "$FILE" 2>/dev/null | awk -F '=' '{print $2}')
distro_value="Unknown"
distro_version="Unknown"
if [ -r /etc/os-release ]; then
    distro_value=$(grep '^NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2)
    distro_version=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d'"' -f2)
elif [ -r /etc/issue ]; then
    distro_value=$(head -n 1 /etc/issue 2>/dev/null | awk '{print $1}')
    distro_version=$(head -n 1 /etc/issue 2>/dev/null | awk '{print $2}')
elif [ -r /etc/vtiversion.info ]; then
    distro_value=$(head -n 1 /etc/vtiversion.info 2>/dev/null)
elif [ -r /etc/issue.net ]; then
    distro_value=$(head -n 1 /etc/issue.net 2>/dev/null | awk '{print $1}')
    distro_version=$(head -n 1 /etc/issue.net 2>/dev/null | awk '{print $2}')
fi

[ -z "$distro_value" ] && distro_value="Unknown"
[ -z "$distro_version" ] && distro_version="Unknown"
python_vers=$(python --version 2>&1)

cat <<EOF

#########################################################
#          EPGImport Sources $version INSTALLED         #
#                developed by LULULLA                   #
#               https://corvoboys.org                   #
#########################################################
#           your Device will RESTART Now                #
#########################################################
Debug information:
BOX MODEL: $box_type
OS SYSTEM: $OSTYPE
PYTHON: $python_vers
IMAGE NAME: ${distro_value:-Unknown}
IMAGE VERSION: ${distro_version:-Unknown}
CHANGELOG: $changelog
PLUGIN PATH: $PLUGINPATH
PLUGIN VERSION: $version
EOF

exit 0