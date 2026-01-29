#!/bin/bash

if ! command -v jq &> /dev/null; then
    echo "❌ 'jq' is not installed. Please run: sudo pacman -S jq"
    exit 1
fi

EXPECTED_APPID="1407200"
STEAM_MANIFEST_GLOB="$HOME/.steam/steam/steamapps"/*.acf

mapfile -t MANIFEST_MATCHES < <(grep -l "World of Tanks" $STEAM_MANIFEST_GLOB 2>/dev/null)

if [ ${#MANIFEST_MATCHES[@]} -eq 0 ]; then
    echo "❌ Could not find a Steam manifest for World of Tanks in: $STEAM_MANIFEST_GLOB"
    echo "💡 Make sure the game is installed and Steam has created the appmanifest file."
    exit 1
fi

if [ ${#MANIFEST_MATCHES[@]} -gt 1 ]; then
    echo "❌ Multiple Steam manifests matched 'World of Tanks':"
    printf ' - %s\n' "${MANIFEST_MATCHES[@]}"
    echo "💡 Please uninstall duplicate entries or remove extra manifests to disambiguate."
    exit 1
fi

MANIFEST_PATH="${MANIFEST_MATCHES[0]}"

mapfile -t APPID_MATCHES < <(grep -E '^\s*"appid"\s+' "$MANIFEST_PATH" | awk '{print $2}' | tr -d '"')

if [ ${#APPID_MATCHES[@]} -eq 0 ]; then
    echo "❌ Could not find World of Tanks AppID in manifest: $MANIFEST_PATH"
    exit 1
fi

UNIQUE_APPIDS=()
for id in "${APPID_MATCHES[@]}"; do
    if [[ ! " ${UNIQUE_APPIDS[*]} " =~ " ${id} " ]]; then
        UNIQUE_APPIDS+=("$id")
    fi
done

if [ ${#UNIQUE_APPIDS[@]} -gt 1 ]; then
    echo "❌ Multiple AppIDs detected in manifest: $MANIFEST_PATH"
    printf ' - %s\n' "${UNIQUE_APPIDS[@]}"
    echo "💡 Please uninstall duplicate entries or remove extra manifests to disambiguate."
    exit 1
fi

APPID="${UNIQUE_APPIDS[0]}"

if [ "$APPID" != "$EXPECTED_APPID" ]; then
    echo "⚠️  Detected AppID $APPID does not match expected World of Tanks AppID $EXPECTED_APPID."
fi

echo "✅ Detected AppID: $APPID"

# --- 1. Find the Steam Library & AppID ---
STEAM_ROOT="$HOME/.steam/steam"
COMMON_DIR="$STEAM_ROOT/steamapps/common"
COMPAT_DIR="$STEAM_ROOT/steamapps/compatdata/$APPID"

# --- 2. Resolve Proton Path Automatically ---
# We look for the 'version' file in the compatdata folder to see which Proton was last used
if [ -f "$COMPAT_DIR/version" ]; then
    PROTON_VER_NAME=$(cat "$COMPAT_DIR/version")
    # Mapping the version string to the actual folder name in 'common'
    # Steam often names folders "Proton 9.0" while the version file says "9.0-..."
    PROTON_BASE_VER=$(echo "$PROTON_VER_NAME" | cut -d'-' -f1)
    PROTON_PATH=$(find "$COMMON_DIR" -maxdepth 1 -type d -name "Proton $PROTON_BASE_VER*" | head -n 1)

    # Fallback to Experimental if specific version not found
    if [ -z "$PROTON_PATH" ]; then
        PROTON_PATH="$COMMON_DIR/Proton - Experimental"
    fi
else
    # Fallback: try Experimental, then any Proton
    PROTON_PATH="$COMMON_DIR/Proton - Experimental"
    if [ ! -d "$PROTON_PATH" ]; then
        PROTON_PATH=$(find "$COMMON_DIR" -maxdepth 1 -type d -name "Proton *" | head -n 1)
    fi
    if [ -z "$PROTON_PATH" ]; then
        echo "❌ Could not find a Proton installation. Install Proton or launch the game once."
        exit 1
    fi
fi

echo "✅ Found Proton at: $PROTON_PATH"
echo "✅ Found Prefix at: $COMPAT_DIR"

# --- 3. Fetch Aslain's Version Info ---
echo "🔍 Checking for latest Aslain version..."
JSON_DATA=$(curl -s https://aslain.com/update_checker/WoT_installer.json)
VERSION=$(echo "$JSON_DATA" | jq -r '.installer.version')

# Format version for URL (replace last dot with underscore)
URL_VERSION=$(echo "$VERSION" | sed 's/\.\([^.]*\)$/_\1/')
DOWNLOAD_URL="https://modp.wgcdn.co/media/mod_files/Aslains_WoT_Modpack_Installer_v.${URL_VERSION}.exe"
FILE_NAME="Aslains_Installer_${VERSION}.exe"

# --- 4. Download and Execute ---
if [ ! -f "$FILE_NAME" ]; then
    echo "📥 Downloading version $VERSION..."
    curl -L -o "$FILE_NAME" "$DOWNLOAD_URL"
else
    echo "📦 Installer already exists, skipping download."
fi

echo "🎮 Launching installer in WoT prefix environment..."

# Critical environment variables for Proton
export STEAM_COMPAT_DATA_PATH="$COMPAT_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
export PROTON_LOG=0
export WINEDEBUG=-all

"$PROTON_PATH/proton" run "./$FILE_NAME"
