#!/usr/bin/env bash
# tor.sh — cycle de vie Tor
# Inspiré de anonsurf (ParrotSec)

TORRC_PATH="/etc/tor/torrc"
TORRC_GHOSTSURF="/etc/tor/ghostsurf.torrc"
TOR_CONTROL_PORT="9051"
TOR_SOCKS_PORT="9050"

tor_start() {
    _tor_write_config
    if systemctl is-active --quiet tor 2>/dev/null; then
        log_info "Redémarrage Tor..."
        systemctl reload-or-restart tor
    else
        log_info "Démarrage Tor..."
        systemctl start tor
    fi
    _tor_wait_ready
}

tor_stop() {
    log_info "Arrêt Tor..."
    systemctl stop tor 2>/dev/null || true
    _tor_restore_config
}

tor_is_active() {
    systemctl is-active --quiet tor 2>/dev/null
}

tor_check_ip() {
    curl -s --max-time 10 --socks5 "127.0.0.1:$TOR_SOCKS_PORT" \
        https://check.torproject.org/api/ip 2>/dev/null | \
        grep -oP '"IP":"\K[^"]+' || echo "?"
}

_tor_write_config() {
    # Backup du torrc original
    [[ -f "$TORRC_PATH" && ! -f "${TORRC_PATH}.ghostsurf.bak" ]] && \
        cp "$TORRC_PATH" "${TORRC_PATH}.ghostsurf.bak"

    cat > "$TORRC_GHOSTSURF" <<TORRC
# GhostSurf torrc — généré automatiquement
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:5353
SocksPort 9050
ControlPort 9051
# Stream isolation pour apps spécifiques (Whonix pattern)
SocksPort 9100 IsolateClientAddr IsolateSOCKSAuth
RunAsDaemon 1
TORRC

    # Inclut notre config dans le torrc principal
    grep -q "ghostsurf.torrc" "$TORRC_PATH" 2>/dev/null || \
        echo "%include $TORRC_GHOSTSURF" >> "$TORRC_PATH"
}

_tor_restore_config() {
    [[ -f "${TORRC_PATH}.ghostsurf.bak" ]] && \
        cp "${TORRC_PATH}.ghostsurf.bak" "$TORRC_PATH"
    rm -f "$TORRC_GHOSTSURF"
}

_tor_wait_ready() {
    local tries=0
    log_info "Attente connexion Tor..."
    while ! curl -s --max-time 3 --socks5 "127.0.0.1:$TOR_SOCKS_PORT" \
            https://check.torproject.org/api/ip >/dev/null 2>&1; do
        ((tries++))
        [[ $tries -ge 20 ]] && { log_error "Tor ne répond pas après 60s"; return 1; }
        sleep 3
    done
    log_success "Tor connecté"
}
