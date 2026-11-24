#!/bin/bash

# Unity versie op de iMacs. Kan ook als eerste argument worden meegegeven:
#   ./fix_unity_android.command 6000.0.77f1
# Of direct vanaf GitHub (zie README.md):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/loos-glr/unity-android-build-imac-fix/main/fix_unity_android.command)"
UNITY_VERSION="${1:-6000.0.77f1}"

EDITOR_ROOT="/Applications/Unity/Hub/Editor"
SOURCE_DIR="$EDITOR_ROOT/$UNITY_VERSION"
TARGET_BASE="$HOME/UnityEditors"
TARGET_DIR="$TARGET_BASE/$UNITY_VERSION"
HUB_BIN="/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
# Extra ruimte (in KB) voor Android SDK/NDK/OpenJDK bovenop de editor zelf (~6 GB)
EXTRA_SPACE_KB=$((6 * 1024 * 1024))

fail() {
    echo ""
    echo "FOUT: $1"
    # Alleen wachten als er een echte terminal is (niet bij 'curl | bash')
    if [ -t 0 ]; then
        echo "Druk op Enter om af te sluiten."
        read -r _
    fi
    exit 1
}

echo "=== Stap 1: Controleer broninstallatie ($UNITY_VERSION) ==="
if [ ! -d "$SOURCE_DIR/Unity.app" ]; then
    echo "Kan Unity $UNITY_VERSION niet vinden in $SOURCE_DIR"
    echo "Beschikbare versies in $EDITOR_ROOT:"
    ls -1 "$EDITOR_ROOT" 2>/dev/null | sed 's/^/  - /'
    fail "Pas UNITY_VERSION aan of geef de juiste versie mee als argument."
fi
[ -x "$HUB_BIN" ] || fail "Unity Hub niet gevonden op: $HUB_BIN"

echo "=== Stap 2: Kopieer Unity naar eigen gebruikersmap (geen admin nodig) ==="
mkdir -p "$TARGET_BASE" || fail "Kan map $TARGET_BASE niet aanmaken."
if [ -d "$TARGET_DIR/Unity.app" ]; then
    echo "Lokale kopie bestaat al in $TARGET_DIR."
else
    # Restanten van een eerder afgebroken kopie opruimen
    rm -rf "$TARGET_DIR" "$TARGET_DIR.partial"

    echo "Controleer vrije schijfruimte..."
    NEEDED_KB=$(( $(du -sk "$SOURCE_DIR" | awk '{print $1}') + EXTRA_SPACE_KB ))
    FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    if [ "$FREE_KB" -lt "$NEEDED_KB" ]; then
        fail "Te weinig schijfruimte: nodig ~$((NEEDED_KB / 1024 / 1024)) GB, vrij $((FREE_KB / 1024 / 1024)) GB."
    fi

    echo "Bezig met kopiëren van Unity Editor (dit kan enkele minuten duren)..."
    ditto "$SOURCE_DIR" "$TARGET_DIR.partial" || fail "Kopiëren mislukt."
    # Zorg dat alle gekopieerde bestanden schrijfrechten hebben voor de student
    chmod -R u+w "$TARGET_DIR.partial" || fail "Kan schrijfrechten niet instellen."
    mv "$TARGET_DIR.partial" "$TARGET_DIR" || fail "Kan kopie niet op zijn plek zetten."
fi

echo "=== Stap 3: Installeer Android Build Support, SDK/NDK & OpenJDK ==="
# Sluit Unity Hub (inclusief helper-processen), anders werkt de CLI niet
pkill -f "Unity Hub.app/Contents/" 2>/dev/null
for _ in $(seq 1 15); do
    pgrep -f "Unity Hub.app/Contents/" >/dev/null || break
    sleep 1
done

# Installatiemap van de Hub naar de eigen map zetten, zodat de Hub de kopie vindt
"$HUB_BIN" -- --headless install-path -s "$TARGET_BASE"

# 'android' + --cm installeert ook de submodules (SDK/NDK tools en OpenJDK),
# ongeacht hun exacte (versie-afhankelijke) module-ID's.
"$HUB_BIN" -- --headless install-modules --version "$UNITY_VERSION" -m android --cm

echo "=== Stap 4: Controleer installatie ==="
ANDROID_DIR="$TARGET_DIR/PlaybackEngines/AndroidPlayer"
MISSING=""
[ -d "$ANDROID_DIR" ]         || MISSING="$MISSING AndroidPlayer"
[ -d "$ANDROID_DIR/SDK" ]     || MISSING="$MISSING SDK"
[ -d "$ANDROID_DIR/NDK" ]     || MISSING="$MISSING NDK"
[ -d "$ANDROID_DIR/OpenJDK" ] || MISSING="$MISSING OpenJDK"
if [ -n "$MISSING" ]; then
    fail "Android onderdelen ontbreken:$MISSING (in $ANDROID_DIR). Bekijk de Hub-output hierboven."
fi

echo "=== Klaar! ==="
echo "Android Build Support is geïnstalleerd in: $TARGET_DIR"
echo "Open Unity Hub. Staat de editor niet onder Installs? Kies dan Locate en selecteer:"
echo "  $TARGET_DIR/Unity.app"
