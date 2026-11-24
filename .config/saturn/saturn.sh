
#!/usr/bin/env bash

PURPLE='\e[1;35m'
GREEN='\e[1;32m'
CYAN='\e[1;36m'
RESET='\e[0m'

VERBOSE=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        -v|--verbose)
            VERBOSE=true
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

option="${ARGS[0]:-}"
argument="${ARGS[1]:-}"

walldir="$HOME/Pictures/Wallpapers"
waydir="$HOME/.config/saturn/waybar"
configdir="$HOME/.config"
vicinae_theme="$HOME/.local/share/vicinae/themes/matugen.toml"
wallcard="$configdir/rofi/wallcard"

SUPPORTED_FORMATS=("jpg" "jpeg" "png" "bmp" "gif" "mp4")

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}[VERBOSE] $*${RESET}"
    fi
}

notify() {
    notify-send -a "Saturn" "$@" 2>/dev/null || true
}

check_dependencies() {
    local missing=()

    for cmd in vicinae yin yinctl matugen notify-send; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]})); then
        printf '[Saturn] Missing dependencies: %s\n' "${missing[*]}"
        return 1
    fi
}

ensure_yin() {
    mkdir -p "$HOME/.cache/yin"

    if ! pgrep -x yin >/dev/null; then
        log_verbose "Starting Yin daemon..."

        nohup yin > "$HOME/.cache/yin/yin.log" 2>&1 &

        for ((i=0; i<30; i++)); do
            pgrep -x yin >/dev/null && break
            sleep 0.1
        done
    fi

    if ! pgrep -x yin >/dev/null; then
        echo "[Saturn] Failed to start Yin."
        notify "Failed to start Yin."
        return 1
    fi
}

run_yinctl_with_progress() {
    local target_file="$1"
    local status
    local line
    local percent

    ensure_yin || return 1

    log_verbose "Applying wallpaper: $target_file"

    yinctl --img "$target_file" --trans mosaic 2>&1 |
    while IFS= read -r line; do
        log_verbose "[Yin] $line"

        if [[ "$line" =~ ([0-9]+)% ]]; then
            percent="${BASH_REMATCH[1]}"

            notify \
                -h string:x-mako-stack-tag:saturn_progress \
                -h int:value:"$percent" \
                "Caching wallpaper..." \
                "$percent% completed"
        fi
    done

    status="${PIPESTATUS[0]}"

    if [[ "$status" -eq 0 ]]; then
notify "Wallpaper applied! >_<"
    else
        echo "[Saturn] Yin failed to apply wallpaper."
        notify "Yin failed to apply wallpaper."
        return "$status"
    fi
}

run_post_hooks() {
    log_verbose "Reloading desktop components..."

    if command -v gsettings &>/dev/null; then
        local current

        current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)

        if [[ "$current" == "'prefer-dark'" ]]; then
            gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
        fi
    fi

    if pgrep -x waybar >/dev/null; then
        log_verbose "Reloading Waybar..."
        pkill -x waybar
        waybar >/dev/null 2>&1 &
    fi

    if command -v swaync-client &>/dev/null; then
        log_verbose "Reloading SwayNC..."
        swaync-client -R 2>/dev/null || true
        swaync-client -rs 2>/dev/null || true
    fi

    if pgrep -x vektop >/dev/null; then
        log_verbose "Reloading Vektop..."
        pkill -USR1 vektop 2>/dev/null || pkill -HUP vektop 2>/dev/null || true
    fi

    notify "All UI components reloaded!"
    echo "[Saturn] Post-hooks completed."
}

apply_vicinae() {
    if ! command -v vicinae >/dev/null 2>&1; then
        echo "[Saturn] Vicinae is not installed."
        return 1
    fi

    if [[ ! -f "$vicinae_theme" ]]; then
        echo "[Saturn] Matugen Vicinae theme was not generated."
        notify "Vicinae theme file not found."
        return 1
    fi

}

apply_wallpaper() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "[Saturn] Invalid wallpaper: $file"
        notify "Invalid wallpaper file."
        return 1
    fi

    run_yinctl_with_progress "$file"
}

apply_matugen() {
    local file="$1"
    local target="$file"
    local ext="${file##*.}"

    ext="${ext,,}"

    if [[ "$ext" == "mp4" ]]; then
        target="/tmp/saturn_matugen_frame.png"

        log_verbose "Extracting MP4 frame..."

        if ! ffmpeg -y -i "$file" -frames:v 1 "$target" -loglevel error; then
            echo "[Saturn] Failed to extract video frame."
            notify "Failed to extract video frame."
            return 1
        fi
    fi

    mkdir -p "$configdir/rofi"

    ln -sfn "$target" "$wallcard"

    log_verbose "Generating Matugen colors..."

    if ! matugen image "$target" --source-color-index 0; then
        echo "[Saturn] Matugen failed."
        notify "Matugen failed."
        return 1
    fi

    apply_vicinae || true

    run_post_hooks

    notify "Matugen theme applied!"
    echo "[Saturn] Matugen theme applied."
}
wallpaper_gui() {
    if [[ ! -d "$walldir" ]]; then
        notify "Wallpaper directory not found."
        return 1
    fi

    log_verbose "Opening Vicinae wallpaper picker..."

    local selected

    selected=$(
        find "$walldir" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' \
            -o -iname '*.png' -o -iname '*.bmp' \
            -o -iname '*.gif' -o -iname '*.mp4' \) |
        sort |
        while IFS= read -r file; do
            basename "$file"
        done |
        vicinae dmenu --placeholder "Select Wallpaper"
    )

    [[ -z "$selected" ]] && return 0

    local file="$walldir/$selected"

    log_verbose "Selected wallpaper: $file"

    apply_wallpaper "$file" || return 1
    apply_matugen "$file"
}
switch_waybar() {
    if [[ ! -d "$waydir" ]]; then
        notify "Waybar themes directory not found."
        return 1
    fi

    log_verbose "Opening Vicinae Waybar picker..."

    local selected

    selected=$(
        find "$waydir" -mindepth 1 -maxdepth 1 -type d \
            -printf '%f\n' |
        sort |
        vicinae dmenu --placeholder "Select Waybar Theme"
    )

    [[ -z "$selected" ]] && return 0

    local source="$waydir/$selected"

    if [[ ! -f "$source/config.jsonc" || ! -f "$source/style.css" ]]; then
        notify "Invalid Waybar theme: $selected"
        return 1
    fi

    mkdir -p "$configdir/waybar"

    cp "$source/config.jsonc" "$configdir/waybar/config.jsonc"
    cp "$source/style.css" "$configdir/waybar/style.css"

    if pgrep -x waybar >/dev/null; then
        pkill -x waybar
    fi

    waybar >/dev/null 2>&1 &

    notify "Waybar switched to '$selected'!"
    echo "[Saturn] Waybar theme: $selected"
}

case "$option" in
    "")
        echo -e "$PURPLE"

        cat << "EOF"

 ███████╗ █████╗ ████████╗██╗   ██╗██████╗ ███╗   ██╗
 ██╔════╝██╔══██╗╚══██╔══╝██║   ██║██╔══██╗████╗  ██║
 ███████╗███████║   ██║   ██║   ██║██████╔╝██╔██╗ ██║
 ╚════██║██╔══██║   ██║   ██║   ██║██╔══██╗██║╚██╗██║
 ███████║██║  ██║   ██║   ╚██████╔╝██║  ██║██║ ╚████║
 ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝

                  Hello, I'm Saturn.
                    Arch • Hyprland

EOF

        echo -e "$RESET"
        ;;

    help|-h|--help)
        echo "Saturn commands:"
        echo "  img <file>     Apply wallpaper using Yin"
        echo "  imgm <file>    Apply wallpaper + Matugen + Vicinae"
        echo "  themegui       Open Vicinae wallpaper picker"
        echo "  wavey          Open Vicinae Waybar picker"
        echo "  reload         Reload desktop components"
        echo "  help           Show this help"
        echo "  -v             Enable verbose output"
        ;;

    img)
        if [[ -z "$argument" ]]; then
            notify "Usage: sat img <file>"
            exit 1
        fi

        apply_wallpaper "$argument"
        ;;

    imgm)
        if [[ -z "$argument" ]]; then
            notify "Usage: sat imgm <file>"
            exit 1
        fi

        apply_wallpaper "$argument" &&
        apply_matugen "$argument"
        ;;

    themegui)
        wallpaper_gui
        ;;

    wavey)
        switch_waybar
        ;;

    reload|-r)
        run_post_hooks
        ;;

    *)
        echo "[Saturn] Unknown command: $option"
        echo "Run 'sat help' for available commands."
        exit 1
        ;;
esac

