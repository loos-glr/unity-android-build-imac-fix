#!/bin/bash

# Unity staat op de iMacs in /Applications/Unity/Unity.app (geen Hub-installatie).
# De versie wordt automatisch uitgelezen. Een versie uit
# /Applications/Unity/Hub/Editor kan ook als eerste argument worden meegegeven:
#   ./fix_unity_android.command 6000.0.77f1
# Of direct vanaf GitHub (zie README.md):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/loos-glr/unity-android-build-imac-fix/main/fix_unity_android.command)"

DEFAULT_DIR="/Applications/Unity"
HUB_EDITOR_ROOT="/Applications/Unity/Hub/Editor"
TARGET_BASE="$HOME/UnityEditors"
HUB_BIN="/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
# Extra ruimte (in KB) voor Android Build Support + SDK/NDK/OpenJDK (~12 GB,
# inclusief ruimte voor de download die op dat moment wordt uitgepakt)
EXTRA_SPACE_KB=$((12 * 1024 * 1024))

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

# Leest de Unity-versie (bijv. 6000.0.77f1) uit een Unity.app
unity_version_of() {
    local plist="$1/Contents/Info.plist" key v
    for key in CFBundleVersion CFBundleShortVersionString CFBundleGetInfoString; do
        v=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null \
            | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+[abfp][0-9]+' | head -1)
        [ -n "$v" ] && { echo "$v"; return 0; }
    done
    return 1
}

echo "=== Stap 1: Controleer broninstallatie ==="
if [ -n "$1" ]; then
    UNITY_VERSION="$1"
    if [ -d "$HUB_EDITOR_ROOT/$1/Unity.app" ]; then
        SOURCE_DIR="$HUB_EDITOR_ROOT/$1"
    elif [ "$(unity_version_of "$DEFAULT_DIR/Unity.app")" = "$1" ]; then
        SOURCE_DIR="$DEFAULT_DIR"
    else
        echo "Kan Unity $1 niet vinden."
        echo "Gevonden in $DEFAULT_DIR: $(unity_version_of "$DEFAULT_DIR/Unity.app" || echo geen)"
        echo "Gevonden in $HUB_EDITOR_ROOT:"
        ls -1 "$HUB_EDITOR_ROOT" 2>/dev/null | sed 's/^/  - /'
        fail "Geef een van deze versies mee, of laat het argument weg."
    fi
else
    [ -d "$DEFAULT_DIR/Unity.app" ] || fail "Unity niet gevonden op $DEFAULT_DIR/Unity.app"
    SOURCE_DIR="$DEFAULT_DIR"
    UNITY_VERSION=$(unity_version_of "$DEFAULT_DIR/Unity.app") \
        || fail "Kan de Unity-versie niet uitlezen uit $DEFAULT_DIR/Unity.app"
fi
echo "Unity $UNITY_VERSION gevonden in $SOURCE_DIR"
[ -x "$HUB_BIN" ] || fail "Unity Hub niet gevonden op: $HUB_BIN"
TARGET_DIR="$TARGET_BASE/$UNITY_VERSION"

echo "=== Stap 2: Kopieer Unity naar eigen gebruikersmap (geen admin nodig) ==="
mkdir -p "$TARGET_BASE" || fail "Kan map $TARGET_BASE niet aanmaken."
if [ -d "$TARGET_DIR/Unity.app" ]; then
    echo "Lokale kopie bestaat al in $TARGET_DIR."
else
    # Restanten van een eerder afgebroken kopie opruimen
    rm -rf "$TARGET_DIR" "$TARGET_DIR.partial"
    mkdir -p "$TARGET_DIR.partial" || fail "Kan $TARGET_DIR.partial niet aanmaken."

    # Alles naast Unity.app meenemen (bijv. PlaybackEngines), maar niet de map
    # 'Hub' (die bevat andere editors als /Applications/Unity de bron is)
    ITEMS=()
    for item in "$SOURCE_DIR"/*; do
        [ "$(basename "$item")" = "Hub" ] && continue
        ITEMS+=("$item")
    done

    echo "Controleer vrije schijfruimte..."
    NEEDED_KB=$(( $(du -skc "${ITEMS[@]}" | tail -1 | awk '{print $1}') + EXTRA_SPACE_KB ))
    FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    if [ "$FREE_KB" -lt "$NEEDED_KB" ]; then
        fail "Te weinig schijfruimte: nodig ~$((NEEDED_KB / 1024 / 1024)) GB, vrij $((FREE_KB / 1024 / 1024)) GB."
    fi

    echo "Bezig met kopiëren van Unity Editor (dit kan enkele minuten duren)..."
    for item in "${ITEMS[@]}"; do
        ditto "$item" "$TARGET_DIR.partial/$(basename "$item")" || fail "Kopiëren mislukt: $item"
    done
    # Zorg dat alle gekopieerde bestanden schrijfrechten hebben voor de student
    chmod -R u+w "$TARGET_DIR.partial" || fail "Kan schrijfrechten niet instellen."
    mv "$TARGET_DIR.partial" "$TARGET_DIR" || fail "Kan kopie niet op zijn plek zetten."
fi

echo "=== Stap 3: Installeer Android Build Support, SDK/NDK & OpenJDK ==="
# Unity Hub kan geen modules toevoegen aan een editor die niet via de Hub is
# geïnstalleerd. Daarom doet dit script wat de Hub zelf doet: de module-lijst
# ophalen bij Unity en elk onderdeel downloaden en uitpakken in de kopie.
ANDROID_DIR="$TARGET_DIR/PlaybackEngines/AndroidPlayer"
MARKER_DIR="$TARGET_DIR/.android-modules"
DL_DIR="$TARGET_BASE/.downloads/$UNITY_VERSION"
MOUNT_POINT=""
mkdir -p "$MARKER_DIR" "$DL_DIR" || fail "Kan downloadmap $DL_DIR niet aanmaken."

cleanup() {
    [ -n "$MOUNT_POINT" ] && hdiutil detach -quiet -force "$MOUNT_POINT" 2>/dev/null
    rm -rf "${DL_DIR:?}/pkg" "${DL_DIR:?}/mnt"
}
trap cleanup EXIT

# Voorkom dat de iMac in slaap valt tijdens het downloaden
caffeinate -dims -w $$ &

if file "$TARGET_DIR/Unity.app/Contents/MacOS/Unity" | grep -q arm64; then
    ARCH="ARM64"
else
    ARCH="X86_64"
fi

echo "Module-lijst ophalen voor Unity $UNITY_VERSION ($ARCH)..."
API_URL="https://services.api.unity.com/unity/editor/release/v1/releases?version=$UNITY_VERSION&platform=MAC_OS&architecture=$ARCH&limit=1"
curl -fsSL --retry 3 -o "$DL_DIR/release.json" "$API_URL" \
    || fail "Kan de module-lijst niet ophalen bij Unity. Controleer de internetverbinding."

# JSON uitlezen met JavaScript for Automation (standaard op macOS, geen Python nodig).
# Uitvoer: één regel per module (ouder vóór kind), velden gescheiden door tabs:
#   id  url  bestemming  hernoem-van  hernoem-naar   ('-' = leeg)
cat > "$DL_DIR/modules.js" <<'JXA'
ObjC.import("Foundation");
function run(argv) {
    const json = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
    if (!json || json.isNil()) return "";
    const data = JSON.parse(json.js);
    const unityPath = argv[1], arch = argv[2];
    if (!data.results || !data.results.length) return "";
    const dl = data.results[0].downloads.find(d => d.platform === "MAC_OS" && d.architecture === arch);
    if (!dl) return "";
    const root = (dl.modules || []).find(m => m.id === "android");
    if (!root) return "";
    const fix = p => (p ? p.split("{UNITY_PATH}").join(unityPath) : "-");
    const lines = [];
    const walk = m => {
        const r = m.extractedPathRename || {};
        lines.push([m.id, m.url, fix(m.destination), fix(r.from), fix(r.to)].join("\t"));
        (m.subModules || []).forEach(walk);
    };
    walk(root);
    return lines.join("\n");
}
JXA
osascript -l JavaScript "$DL_DIR/modules.js" "$DL_DIR/release.json" "$TARGET_DIR" "$ARCH" \
    > "$DL_DIR/modules.tsv" 2>/dev/null
[ -s "$DL_DIR/modules.tsv" ] \
    || fail "Geen Android-modules gevonden voor Unity $UNITY_VERSION ($ARCH) bij Unity."

TOTAL=$(wc -l < "$DL_DIR/modules.tsv" | tr -d ' ')
TODO=0
while IFS=$'\t' read -r id _; do
    [ -f "$MARKER_DIR/$id" ] || TODO=$((TODO + 1))
done < "$DL_DIR/modules.tsv"

if [ "$TODO" -gt 0 ]; then
    FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    if [ "$FREE_KB" -lt "$EXTRA_SPACE_KB" ]; then
        fail "Te weinig schijfruimte voor Android: nodig ~$((EXTRA_SPACE_KB / 1024 / 1024)) GB, vrij $((FREE_KB / 1024 / 1024)) GB."
    fi
fi

# Verplaatst $1 naar $2 (ook als $1 binnen $2 ligt, zoals NDK/Contents/NDK -> NDK)
rename_path() {
    local from="$1" to="$2" tmp
    if [ "$from" = "-" ] || [ "$to" = "-" ] || [ ! -e "$from" ]; then
        return 0
    fi
    tmp="$(dirname "$to")/.rename.$$"
    rm -rf "$tmp"
    mv "$from" "$tmp" && rm -rf "$to" && mv "$tmp" "$to"
}

# Installeert één module: downloaden, uitpakken naar de bestemming, hernoemen
install_module() {
    local id="$1" url="$2" dest="$3" from="$4" to="$5"
    local file src app
    file="$DL_DIR/$(basename "${url%%\?*}")"

    curl -fL --retry 3 --retry-delay 5 -C - --progress-bar -o "$file" "$url" || return 1

    case "$file" in
        *.pkg)
            rm -rf "$DL_DIR/pkg"
            pkgutil --expand-full "$file" "$DL_DIR/pkg" || { rm -f "$file"; return 1; }
            # De map met de Android-playerbestanden in de uitgepakte payload
            src=$(find "$DL_DIR/pkg" -name "UnityEditor.Android.Extensions.dll" -print -quit)
            if [ -n "$src" ]; then
                src=$(dirname "$src")
            else
                src=$(find "$DL_DIR/pkg" -type d -name Payload -print -quit)
            fi
            [ -n "$src" ] || return 1
            mkdir -p "$dest" && ditto "$src" "$dest" || return 1
            rm -rf "$DL_DIR/pkg"
            ;;
        *.dmg)
            MOUNT_POINT="$DL_DIR/mnt"
            mkdir -p "$MOUNT_POINT"
            # 'yes' accepteert een eventuele licentievraag van de dmg
            yes | hdiutil attach -nobrowse -readonly -noverify -quiet \
                -mountpoint "$MOUNT_POINT" "$file" >/dev/null || { rm -f "$file"; return 1; }
            app=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" -print -quit)
            if [ -n "$app" ]; then
                rm -rf "$dest" && ditto "$app" "$dest"
            else
                mkdir -p "$dest" && ditto "$MOUNT_POINT" "$dest"
            fi
            local rc=$?
            hdiutil detach -quiet "$MOUNT_POINT" || hdiutil detach -quiet -force "$MOUNT_POINT"
            MOUNT_POINT=""
            [ $rc -eq 0 ] || return 1
            ;;
        *)
            mkdir -p "$dest" && ditto -x -k "$file" "$dest" || { rm -f "$file"; return 1; }
            ;;
    esac

    rename_path "$from" "$to" || return 1
    rm -f "$file"
    touch "$MARKER_DIR/$id"
}

N=0
while IFS=$'\t' read -r -u 3 id url dest from to; do
    N=$((N + 1))
    if [ -f "$MARKER_DIR/$id" ]; then
        echo "[$N/$TOTAL] $id: al geïnstalleerd"
        continue
    fi
    echo "[$N/$TOTAL] $id: downloaden en installeren..."
    install_module "$id" "$url" "$dest" "$from" "$to" \
        || fail "Installeren van $id mislukt. Draai het script opnieuw; het gaat verder waar het gebleven was."
done 3< "$DL_DIR/modules.tsv"

# Zorg dat de Hub de kopie in ~/UnityEditors vindt (niet kritiek als dit mislukt)
pkill -f "Unity Hub.app/Contents/" 2>/dev/null
for _ in $(seq 1 15); do
    pgrep -f "Unity Hub.app/Contents/" >/dev/null || break
    sleep 1
done
UNITY_HUB_CLI_NO_DEPRECATION_WARNING=1 "$HUB_BIN" -- --headless install-path -s "$TARGET_BASE" >/dev/null 2>&1

echo "=== Stap 4: Controleer installatie ==="
ANDROID_DIR="$TARGET_DIR/PlaybackEngines/AndroidPlayer"
MISSING=""
[ -d "$ANDROID_DIR" ]         || MISSING="$MISSING AndroidPlayer"
[ -d "$ANDROID_DIR/SDK" ]     || MISSING="$MISSING SDK"
[ -d "$ANDROID_DIR/NDK" ]     || MISSING="$MISSING NDK"
[ -d "$ANDROID_DIR/OpenJDK" ] || MISSING="$MISSING OpenJDK"
if [ -n "$MISSING" ]; then
    fail "Android onderdelen ontbreken:$MISSING (in $ANDROID_DIR). Draai het script opnieuw."
fi
rm -rf "$DL_DIR"

echo "=== Klaar! ==="
echo "Android Build Support is geïnstalleerd in: $TARGET_DIR"
echo ""
echo "Volgende stappen:"
echo "  1. Open Unity Hub. Staat $UNITY_VERSION niet onder Installs? Kies Locate en selecteer:"
echo "     $TARGET_DIR/Unity.app"
echo "  2. Open je project met deze editor en kies File > Build Profiles > Android > Switch Platform."
echo "  3. Controleer in Unity > Settings > External Tools dat JDK, SDK, NDK en Gradle op"
echo "     'installed with Unity' staan."
