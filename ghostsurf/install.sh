#!/usr/bin/env bash
# install.sh — installation de GhostSurf
set -eE

INSTALL_BIN="/usr/bin/ghostsurf"
INSTALL_LIB="/usr/lib/ghostsurf"
INSTALL_CONF="/etc/ghostsurf"
STATE_DIR="/var/lib/ghostsurf"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }

[[ $EUID -eq 0 ]] || { error "Installation requiert root: sudo ./install.sh"; exit 1; }

echo ""
echo "  GhostSurf — Installation"
echo "  ─────────────────────────────"
echo ""

source "$SRC_DIR/core/logger.sh"
source "$SRC_DIR/core/distro.sh"
distro_detect

# --- Étape 1 : Dépendances système ---
info "Vérification des dépendances système..."

MISSING_PKGS=()

check_pkg() {
    local cmd=$1 pkg_apt=$2 pkg_dnf=$3 pkg_pacman=$4
    command -v "$cmd" &>/dev/null || MISSING_PKGS+=("$cmd|$pkg_apt|$pkg_dnf|$pkg_pacman")
}

check_pkg tor         tor          tor          tor
check_pkg nft         nftables     nftables     nftables
check_pkg curl        curl         curl         curl
check_pkg ip          iproute2     iproute      iproute2
check_pkg macchanger  macchanger   macchanger   macchanger
check_pkg torsocks    torsocks     torsocks     torsocks
check_pkg python3     python3      python3      python3
check_pkg socat       socat        socat        socat

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    warn "Dépendances manquantes détectées :"
    for entry in "${MISSING_PKGS[@]}"; do
        IFS='|' read -r cmd _ _ _ <<< "$entry"
        echo "    - $cmd"
    done

    info "Installation automatique..."
    case "${PKG_MANAGER:-}" in
        apt)
            apt_pkgs=()
            for entry in "${MISSING_PKGS[@]}"; do
                IFS='|' read -r _ pkg _ _ <<< "$entry"
                apt_pkgs+=("$pkg")
            done
            if command -v debconf-set-selections &>/dev/null; then
                echo "macchanger macchanger/automatically_run boolean false" | \
                    debconf-set-selections
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${apt_pkgs[@]}" || {
                error "Échec installation. Installez manuellement :"
                echo "  sudo apt install tor nftables curl iproute2 macchanger torsocks python3"
                exit 1
            }
            ;;
        dnf)
            dnf_pkgs=()
            for entry in "${MISSING_PKGS[@]}"; do
                IFS='|' read -r _ _ pkg _ <<< "$entry"
                dnf_pkgs+=("$pkg")
            done
            dnf install -y "${dnf_pkgs[@]}" || {
                error "Échec installation. Installez manuellement :"
                echo "  sudo dnf install tor nftables curl iproute macchanger torsocks python3"
                exit 1
            }
            ;;
        pacman)
            pac_pkgs=()
            for entry in "${MISSING_PKGS[@]}"; do
                IFS='|' read -r _ _ _ pkg <<< "$entry"
                pac_pkgs+=("$pkg")
            done
            pacman -S --noconfirm "${pac_pkgs[@]}" || {
                error "Échec installation. Installez manuellement :"
                echo "  sudo pacman -S tor nftables curl iproute2 macchanger torsocks python3"
                exit 1
            }
            ;;
        *)
            error "Package manager non reconnu. Installez manuellement les dépendances."
            exit 1
            ;;
    esac
    success "Dépendances système installées"
else
    success "Toutes les dépendances système sont présentes"
fi

# --- Étape 2 : PyQt6 ---
info "Vérification PyQt6..."
if ! python3 -c "import PyQt6" 2>/dev/null; then
    warn "PyQt6 absent — installation..."
    case "${PKG_MANAGER:-}" in
        apt)
            apt-get install -y python3-pyqt6 python3-pyqt6.qtsvg 2>/dev/null && \
                success "PyQt6 installé via apt" || \
                pip3 install PyQt6 --break-system-packages --quiet && \
                success "PyQt6 installé via pip" || \
                { error "Impossible d'installer PyQt6"; exit 1; }
            ;;
        dnf)
            dnf install -y python3-qt6 python3-qt6-devel 2>/dev/null && \
                success "PyQt6 installé via dnf" || \
                pip3 install PyQt6 --quiet && \
                success "PyQt6 installé via pip" || \
                { error "Impossible d'installer PyQt6"; exit 1; }
            ;;
        pacman)
            pacman -S --noconfirm python-pyqt6 2>/dev/null && \
                success "PyQt6 installé via pacman" || \
                { error "Impossible d'installer PyQt6"; exit 1; }
            ;;
        *)
            pip3 install PyQt6 --quiet || \
                { error "Impossible d'installer PyQt6 — pip install PyQt6"; exit 1; }
            ;;
    esac
else
    success "PyQt6 présent"
fi

# --- Étape 2b : Police emoji ---
info "Vérification police emoji (Noto Color Emoji)..."
case "${PKG_MANAGER:-}" in
    apt)
        DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-noto-color-emoji 2>/dev/null && \
            success "fonts-noto-color-emoji installé" || \
            warn "Impossible d'installer fonts-noto-color-emoji (non bloquant)"
        ;;
    dnf)
        dnf install -y google-noto-emoji-color-fonts 2>/dev/null && \
            success "Noto Color Emoji installé" || \
            warn "Impossible d'installer Noto Color Emoji (non bloquant)"
        ;;
    pacman)
        pacman -S --noconfirm noto-fonts-emoji 2>/dev/null && \
            success "noto-fonts-emoji installé" || \
            warn "Impossible d'installer noto-fonts-emoji (non bloquant)"
        ;;
    *)
        warn "Police emoji : installez manuellement fonts-noto-color-emoji"
        ;;
esac

# --- Étape 3 : Tests avant installation ---
echo ""
info "Lancement des tests de validation..."
echo ""

TESTS_FAILED=0

run_test() {
    local script=$1 needs_root=${2:-false}
    local name; name=$(basename "$script")
    echo "  ► $name"

    if bash "$SRC_DIR/$script" 2>&1 | sed 's/^/    /'; then
        success "$name — OK"
    else
        error "$name — ÉCHEC"
        ((TESTS_FAILED++)) || true
    fi
    echo ""
}

export STATE_DIR
run_test "tests/test_distro.sh"   false
run_test "tests/test_snapshot.sh" true
run_test "tests/test_firewall.sh" true
run_test "tests/test_spoof.sh"    true

if [[ $TESTS_FAILED -gt 0 ]]; then
    error "$TESTS_FAILED suite(s) de tests en échec."
    error "Installation annulée — corrigez les erreurs avant de continuer."
    exit 1
fi

success "Tous les tests passent — installation en cours..."
echo ""

# --- Étape 4 : Installation des fichiers ---
info "Création des répertoires..."
mkdir -p "$INSTALL_LIB/core" \
         "$INSTALL_LIB/assets/tor-binaries" \
         "$INSTALL_LIB/gui" \
         "$INSTALL_LIB/tests" \
         "$INSTALL_CONF" \
         "$STATE_DIR/snapshots"

info "Copie des fichiers..."
cp -r "$SRC_DIR/core/"   "$INSTALL_LIB/"
cp -r "$SRC_DIR/assets/" "$INSTALL_LIB/"
cp -r "$SRC_DIR/gui/"    "$INSTALL_LIB/"
cp -r "$SRC_DIR/tests/"  "$INSTALL_LIB/"
cp    "$SRC_DIR/ghostsurf" "$INSTALL_BIN"

info "Application des permissions..."
chmod +x "$INSTALL_BIN"
chmod +x "$INSTALL_LIB/core/"*.sh
chmod +x "$INSTALL_LIB/tests/"*.sh

# Autostart systray au démarrage de session
info "Configuration de l'autostart..."
AUTOSTART_DIR="/etc/xdg/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/ghostsurf-tray.desktop" <<EOF
[Desktop Entry]
Name=GhostSurf
Comment=Transparent Tor proxy — systray
Exec=/bin/bash -c 'sleep 3 && ghostsurf tray'
Icon=network-vpn
Type=Application
Categories=Network;Security;
StartupNotify=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
EOF
cp "$AUTOSTART_DIR/ghostsurf-tray.desktop" \
   /usr/share/applications/ghostsurf.desktop 2>/dev/null || true
success "Autostart configuré"

# Config par défaut
if [[ ! -f "$INSTALL_CONF/ghostsurf.conf" ]]; then
    cp "$SRC_DIR/config/ghostsurf.conf.default" "$INSTALL_CONF/ghostsurf.conf"
    info "Configuration créée: $INSTALL_CONF/ghostsurf.conf"
fi

# Corrige le chemin GHOSTSURF_DIR dans le binaire installé
sed -i "s|GHOSTSURF_DIR=.*|GHOSTSURF_DIR=\"$INSTALL_LIB\"|" "$INSTALL_BIN"

# --- Étape 5 : Systemd ---
info "Installation des services systemd..."
cp "$SRC_DIR/sys-units/"*.service /etc/systemd/system/
systemctl daemon-reload
success "Services installés"

# --- Étape 6 : Sudoers ---
info "Installation de la règle sudoers..."
SUDOERS_FILE="/etc/sudoers.d/ghostsurf"
cat > "$SUDOERS_FILE" <<EOF
# GhostSurf — permet l'exécution sans mot de passe
%sudo ALL=(ALL) NOPASSWD: /usr/bin/ghostsurf
%wheel ALL=(ALL) NOPASSWD: /usr/bin/ghostsurf
${SUDO_USER:-root} ALL=(ALL) NOPASSWD: /usr/bin/ghostsurf
EOF
chmod 440 "$SUDOERS_FILE"
if visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    success "Règle sudoers installée ($SUDOERS_FILE)"
else
    rm -f "$SUDOERS_FILE"
    warn "Règle sudoers invalide — ignorée"
fi

# --- Étape 7 : Résumé ---
echo ""
echo "  ─────────────────────────────"
success "GhostSurf installé avec succès !"
echo ""
echo "  Commandes disponibles:"
echo "    sudo ghostsurf start    — active le proxy Tor"
echo "    sudo ghostsurf stop     — désactive et restaure"
echo "    sudo ghostsurf status   — affiche l'état"
echo "    sudo ghostsurf check    — vérifie les dépendances"
echo ""