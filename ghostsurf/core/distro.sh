#!/usr/bin/env bash
# distro.sh — détection distro et abstraction des différences système

DISTRO_ID=""
DISTRO_LIKE=""
TOR_UID=""
TOR_USER=""
TOR_BIN=""
PKG_MANAGER=""

distro_detect() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    fi

    # Détecte le user Tor selon la distro
    for user in debian-tor _tor tor toranon; do
        if id "$user" &>/dev/null; then
            TOR_USER="$user"
            TOR_UID=$(id -u "$user")
            break
        fi
    done
    [[ -z "$TOR_UID" ]] && TOR_UID="65534"  # nobody fallback

    # Binaire Tor : embarqué en priorité, sinon système
    local arch; arch=$(uname -m)
    local embedded="${GHOSTSURF_DIR}/assets/tor-binaries/${arch}/tor"
    if [[ -x "$embedded" ]]; then
        TOR_BIN="$embedded"
        log_debug "Tor embarqué: $TOR_BIN"
    elif command -v tor &>/dev/null; then
        TOR_BIN=$(command -v tor)
        log_debug "Tor système: $TOR_BIN"
    else
        log_error "Binaire Tor introuvable"
        return 1
    fi

    # Package manager
    for pm in apt dnf pacman zypper apk; do
        command -v "$pm" &>/dev/null && { PKG_MANAGER="$pm"; break; }
    done

    log_debug "Distro: $DISTRO_ID | Tor user: $TOR_USER ($TOR_UID) | PM: $PKG_MANAGER"
    export DISTRO_ID DISTRO_LIKE TOR_UID TOR_USER TOR_BIN PKG_MANAGER
}

distro_name() {
    source /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}"
}

distro_is_selinux_distro() {
    case "${DISTRO_ID:-}" in
        fedora|rhel|centos|rocky|alma) return 0 ;;
        *) [[ "${DISTRO_LIKE:-}" == *"rhel"* || "${DISTRO_LIKE:-}" == *"fedora"* ]] && return 0 ;;
    esac
    return 1
}

distro_check_deps() {
    local missing=()
    local required=(tor nft curl ip iproute2)
    # nft peut s'appeler nft ou nftables
    for dep in tor curl ip; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    # nft séparé car le binaire peut manquer mais les règles fonctionner via iptables
    command -v nft &>/dev/null || command -v iptables &>/dev/null || missing+=("nftables ou iptables")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        log_info  "Installation selon votre distro:"
        case "${PKG_MANAGER:-}" in
            apt)   log_info "  sudo apt install tor nftables curl iproute2 macchanger" ;;
            dnf)   log_info "  sudo dnf install tor nftables curl iproute macchanger" ;;
            pacman)log_info "  sudo pacman -S tor nftables curl iproute2 macchanger" ;;
        esac
        return 1
    fi
    log_success "Toutes les dépendances sont présentes"
}

distro_firewalld_active() {
    systemctl is-active --quiet firewalld 2>/dev/null
}
