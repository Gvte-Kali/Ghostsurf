#!/usr/bin/env bash
# update.sh — télécharge et vérifie les binaires Tor officiels embarqués
# Source : https://dist.torproject.org/torbrowser/
# Usage  : sudo bash update.sh [version]
# Exemple: sudo bash update.sh 13.5.6
set -eE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOR_DIST_BASE="https://dist.torproject.org/torbrowser"
ARCHS=(x86_64 aarch64)
# Clé GPG Tor Browser (Signing key — https://www.torproject.org/docs/signing-keys/)
TOR_SIGNING_KEY="0x4E2C6E8793298290"

# ── Couleurs ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Détection de la dernière version ──────────────────────────────────────
_latest_version() {
    curl -s "${TOR_DIST_BASE}/" 2>/dev/null | \
        grep -oP '(?<=href=")[0-9]+\.[0-9]+\.[0-9]+(?=/)' | \
        sort -V | tail -1
}

# ── Vérification GPG (optionnelle) ────────────────────────────────────────
_verify_gpg() {
    local filepath=$1 sigpath="${1}.asc"
    if ! command -v gpg &>/dev/null; then
        warn "gpg non disponible — vérification GPG ignorée"
        return 0
    fi
    if ! curl -sL -o "$sigpath" "${TOR_DIST_BASE}/${VERSION}/$(basename "$sigpath")" 2>/dev/null; then
        warn "Signature GPG non téléchargeable — ignorée"
        return 0
    fi
    gpg --keyserver keys.openpgp.org --recv-keys "$TOR_SIGNING_KEY" 2>/dev/null || true
    if gpg --verify "$sigpath" "$filepath" 2>/dev/null; then
        info "GPG: signature valide"
    else
        warn "GPG: vérification échouée (clé manquante ?) — continuer avec SHA256 uniquement"
    fi
    rm -f "$sigpath"
}

# ── Téléchargement et extraction pour une architecture ────────────────────
_download_arch() {
    local arch=$1
    local filename="tor-expert-bundle-linux-${arch}-${VERSION}.tar.gz"
    local url="${TOR_DIST_BASE}/${VERSION}/${filename}"
    local sha_url="${url}.sha256sum"
    local tmpfile="/tmp/${filename}"
    local dest_dir="${SCRIPT_DIR}/${arch}"

    info "[$arch] Téléchargement: $url"
    if ! curl -L --progress-bar -o "$tmpfile" "$url" 2>/dev/null; then
        warn "[$arch] Téléchargement échoué (non disponible pour cette version ?)"
        return 1
    fi

    # Vérification SHA256
    info "[$arch] Vérification SHA256..."
    curl -sL -o "${tmpfile}.sha256sum" "$sha_url" 2>/dev/null || {
        warn "[$arch] Fichier SHA256 non disponible"
    }
    if [[ -f "${tmpfile}.sha256sum" ]]; then
        (cd /tmp && sha256sum -c "$(basename "${tmpfile}.sha256sum")") || {
            error "[$arch] Échec vérification SHA256 — binaire compromis ?"
        }
        info "[$arch] SHA256: OK"
    fi

    # Vérification GPG
    _verify_gpg "$tmpfile"

    # Extraction du binaire tor
    info "[$arch] Extraction du binaire tor..."
    mkdir -p "$dest_dir"
    # L'expert bundle contient tor dans data/tor ou directement tor
    if tar -tzf "$tmpfile" 2>/dev/null | grep -q 'data/tor$'; then
        tar -xzf "$tmpfile" -C /tmp "data/tor"
        mv /tmp/data/tor "${dest_dir}/tor"
        rmdir /tmp/data 2>/dev/null || true
    elif tar -tzf "$tmpfile" 2>/dev/null | grep -q '[/]tor$'; then
        tar -xzf "$tmpfile" -C /tmp --wildcards '*/tor' --strip-components=1
        mv /tmp/tor "${dest_dir}/tor"
    else
        error "[$arch] Binaire tor introuvable dans l'archive"
    fi
    chmod +x "${dest_dir}/tor"

    # Empreinte du binaire extrait
    local checksum; checksum=$(sha256sum "${dest_dir}/tor" | awk '{print $1}')
    echo "$checksum  ${arch}/tor" > "${dest_dir}/tor.sha256"
    info "[$arch] Installé: ${dest_dir}/tor (sha256: ${checksum:0:16}...)"

    rm -f "$tmpfile" "${tmpfile}.sha256sum"
}

# ── Mise à jour du fichier SHA256SUMS global ──────────────────────────────
_update_sums() {
    local sums_file="${SCRIPT_DIR}/SHA256SUMS"
    : > "$sums_file"
    for arch in "${ARCHS[@]}"; do
        [[ -f "${SCRIPT_DIR}/${arch}/tor" ]] && \
            sha256sum "${SCRIPT_DIR}/${arch}/tor" >> "$sums_file"
    done
    info "SHA256SUMS mis à jour:"
    cat "$sums_file"
}

# ── Main ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Mise à jour des binaires Tor embarqués ==="
echo ""

# Version : argument ou auto-détection
if [[ -n "${1:-}" ]]; then
    VERSION="$1"
else
    info "Détection de la dernière version..."
    VERSION=$(_latest_version)
    [[ -z "$VERSION" ]] && error "Impossible de détecter la version. Spécifiez-la en argument."
fi
info "Version cible: $VERSION"
echo ""

success_count=0
for arch in "${ARCHS[@]}"; do
    if _download_arch "$arch"; then
        ((success_count++)) || true
    fi
    echo ""
done

[[ $success_count -eq 0 ]] && error "Aucun binaire téléchargé"

_update_sums

echo ""
echo "=== Terminé — $success_count/${#ARCHS[@]} architecture(s) mise(s) à jour ==="
echo ""
echo "Pour utiliser les binaires embarqués plutôt que le Tor système,"
echo "ghostsurf les détecte automatiquement via distro.sh."
