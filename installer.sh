#!/bin/bash
## setup command=wget -q --no-check-certificate https://raw.githubusercontent.com/Belfagor2005/EPGImport-99/main/installer.sh -O - | /bin/bash

version='99'
changelog='--My Fake Version'

TMPPATH=/tmp/EPGImport-99-install
TMPSources=/tmp/EPGimport-Sources-install
FILEPATH=/tmp/EPGImport-99-main.tar.gz

echo "Starting EPGImport $version installation..."

if [ ! -d /usr/lib64 ]; then
    PLUGINPATH=/usr/lib/enigma2/python/Plugins/Extensions/EPGImport
else
    PLUGINPATH=/usr/lib64/enigma2/python/Plugins/Extensions/EPGImport
fi

cleanup() {
    echo "Cleaning up temporary files..."
    [ -d "$TMPPATH" ] && rm -rf "$TMPPATH"
    [ -d "$TMPSources" ] && rm -rf "$TMPSources"
    [ -f "$FILEPATH" ] && rm -f "$FILEPATH"
    [ -d "/tmp/EPGImport-99-main" ] && rm -rf "/tmp/EPGImport-99-main"
    [ -f "/tmp/sources.tar.gz" ] && rm -f "/tmp/sources.tar.gz"
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

if python --version 2>&1 | grep -q '^Python 3\.'; then
    echo "Python3 image detected"
    Packagerequests="python3-requests"
else
    echo "Python2 image detected"
    Packagerequests="python-requests"
fi

install_pkg() {
    local pkg=$1
    if [ -z "$STATUS" ] || ! grep -qs "Package: $pkg" "$STATUS" 2>/dev/null; then
        echo "Installing $pkg..."
        case "$OSTYPE" in
            "DreamOs")
                apt-get update && apt-get install -y "$pkg" || { echo "Could not install $pkg, continuing anyway..."; }
                ;;
            "OE")
                opkg update && opkg install "$pkg" || { echo "Could not install $pkg, continuing anyway..."; }
                ;;
            *)
                echo "Cannot install $pkg on unknown OS type, continuing..."
                ;;
        esac
    else
        echo "$pkg already installed"
    fi
}

install_pkg "$Packagerequests"

echo "Downloading EPGImport plugin..."
mkdir -p "$TMPPATH"
wget --no-check-certificate 'https://github.com/Belfagor2005/EPGImport-99/archive/refs/heads/main.tar.gz' -O "$FILEPATH"
if [ $? -ne 0 ]; then
    echo "Failed to download EPGImport package!"
    cleanup
    exit 1
fi

echo "Extracting plugin..."
tar -xzf "$FILEPATH" -C "$TMPPATH"
if [ $? -ne 0 ]; then
    echo "Failed to extract EPGImport package!"
    cleanup
    exit 1
fi

echo "Installing plugin files..."
mkdir -p "$PLUGINPATH"

if [ -d "$TMPPATH/EPGImport-99-main/usr/lib/enigma2/python/Plugins/Extensions/EPGImport" ]; then
    cp -r "$TMPPATH/EPGImport-99-main/usr/lib/enigma2/python/Plugins/Extensions/EPGImport"/* "$PLUGINPATH/" 2>/dev/null
    echo "Copied from standard plugin directory"
elif [ -d "$TMPPATH/EPGImport-99-main/usr/lib64/enigma2/python/Plugins/Extensions/EPGImport" ]; then
    cp -r "$TMPPATH/EPGImport-99-main/usr/lib64/enigma2/python/Plugins/Extensions/EPGImport"/* "$PLUGINPATH/" 2>/dev/null
    echo "Copied from lib64 plugin directory"
elif [ -d "$TMPPATH/EPGImport-99-main/usr" ]; then
    cp -r "$TMPPATH/EPGImport-99-main/usr"/* /usr/ 2>/dev/null
    echo "Copied entire usr structure"
else
    echo "Could not find plugin files in extracted archive"
    echo "Available directories in tmp:"
    find "$TMPPATH" -type d | head -10
    cleanup
    exit 1
fi

echo "Downloading EPG sources..."
mkdir -p "$TMPSources"
mkdir -p '/etc/epgimport'

wget --no-check-certificate 'https://github.com/doglover3920/EPGimport-Sources/archive/refs/heads/main.tar.gz' -O "$TMPSources/sources.tar.gz"
if [ $? -ne 0 ]; then
    echo "Failed to download EPG sources, continuing without sources..."
else
    echo "Extracting sources..."
    tar -xzf "$TMPSources/sources.tar.gz" -C "$TMPSources"
    if [ $? -eq 0 ] && [ -d "$TMPSources/EPGimport-Sources-main" ]; then
        cp -r "$TMPSources/EPGimport-Sources-main"/* '/etc/epgimport/' 2>/dev/null
        echo "EPG sources installed to /etc/epgimport/"
    else
        echo "Failed to extract EPG sources, continuing without sources..."
    fi
fi

sync

echo "Verifying installation..."
if [ -d "$PLUGINPATH" ] && [ -n "$(ls -A "$PLUGINPATH" 2>/dev/null)" ]; then
    echo "Plugin directory found and not empty: $PLUGINPATH"
    echo "Plugin contents:"
    ls -la "$PLUGINPATH/" | head -5
    
    if [ -d "/etc/epgimport" ] && [ -n "$(ls -A "/etc/epgimport" 2>/dev/null)" ]; then
        echo "EPG sources directory found and not empty: /etc/epgimport"
        echo "Sources contents:"
        ls -la "/etc/epgimport/" | head -5
    else
        echo "EPG sources directory is empty or missing"
    fi
else
    echo "Plugin installation failed or directory is empty!"
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
#          EPGImport $version INSTALLED SUCCESSFULLY      #
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