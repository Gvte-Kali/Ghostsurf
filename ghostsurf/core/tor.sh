#!/usr/bin/env bash
# tor.sh — cycle de vie Tor
# Inspiré de anonsurf (ParrotSec)

TORRC_PATH="/etc/tor/torrc"
TORRC_GHOSTSURF="/etc/tor/ghostsurf.torrc"
TOR_CONTROL_PORT="9051"
TOR_SOCKS_PORT="9050"

# Détecte le bon nom de service Tor selon la distro
_tor_service_name() {
    if systemctl list-units --all | grep -q "tor@default"; then
        echo "tor@default"
    else
        echo "tor"
    fi
}

tor_start() {
    _tor_write_config
    local svc; svc=$(_tor_service_name)
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        log_info "Redémarrage Tor ($svc)..."
        systemctl restart "$svc"
    else
        log_info "Démarrage Tor ($svc)..."
        systemctl start "$svc"
    fi
    _tor_wait_ready
    _tor_configure_dns
}

tor_stop() {
    log_info "Arrêt Tor..."
    local svc; svc=$(_tor_service_name)
    systemctl stop "$svc" 2>/dev/null || true
    _tor_restore_config
}

tor_is_active() {
    local svc; svc=$(_tor_service_name)
    systemctl is-active --quiet "$svc" 2>/dev/null
}

tor_check_ip() {
    curl -s --max-time 10 \
        --socks5-hostname "127.0.0.1:$TOR_SOCKS_PORT" \
        https://check.torproject.org/api/ip 2>/dev/null | \
        grep -oP '"IP":"\K[^"]+' || echo "?"
}

_tor_write_config() {
    [[ -f "$TORRC_PATH" && ! -f "${TORRC_PATH}.ghostsurf.bak" ]] && \
        cp "$TORRC_PATH" "${TORRC_PATH}.ghostsurf.bak"

    cat > "$TORRC_GHOSTSURF" <<TORRC
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:5353
DNSPort 127.0.0.1:53
SocksPort 9050
SocksPort 9100 IsolateClientAddr IsolateSOCKSAuth
ControlPort 9051
TORRC

    grep -q "ghostsurf.torrc" "$TORRC_PATH" 2>/dev/null || \
        echo "%include $TORRC_GHOSTSURF" >> "$TORRC_PATH"
}

_tor_restore_config() {
    [[ -f "${TORRC_PATH}.ghostsurf.bak" ]] && \
        cp "${TORRC_PATH}.ghostsurf.bak" "$TORRC_PATH"
    rm -f "$TORRC_GHOSTSURF"
}

_tor_configure_dns() {
    cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1
EOF
    systemctl stop systemd-resolved 2>/dev/null || true
    log_debug "DNS système redirigé vers Tor (port 53)"
}

_tor_wait_ready() {
    local tries=0
    log_info "Attente bootstrap Tor..."

    while true; do
        local progress
        # Couvre toutes les distros : tor@default (Debian), tor (Fedora/Arch)
        progress=$(journalctl -u tor@default -u tor \
            --no-pager -n 50 2>/dev/null \
            | grep -oP 'Bootstrapped \K[0-9]+' \
            | tail -1 || echo "0")

        log_debug "Bootstrap Tor: ${progress}%"

        if [[ "${progress:-0}" -ge 100 ]]; then
            log_success "Tor connecté (100%)"
            return 0
        fi

        ((tries++)) || true
        [[ $tries -ge 40 ]] && { log_error "Tor timeout après 120s"; return 1; }
        sleep 3
    done
}
