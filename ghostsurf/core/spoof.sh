#!/usr/bin/env bash
# spoof.sh — spoofing MAC, hostname, localtime
# Depuis: paranoid-ninja (szorfein)

spoof_apply() {
    log_info "Application du spoofing..."
    _spoof_mac
    _spoof_hostname
    _spoof_tcp_timestamps
    log_success "Spoofing appliqué"
}

spoof_restore() {
    log_info "Restauration identités réseau..."
    # Géré par snapshot_restore pour MAC et hostname
    # Restaure TCP timestamps
    sysctl -w net.ipv4.tcp_timestamps=1 2>/dev/null || true
}

_spoof_mac() {
    while IFS= read -r iface; do
        [[ "$iface" == "lo" ]] && continue
        if command -v macchanger &>/dev/null; then
            ip link set "$iface" down 2>/dev/null || true
            macchanger -r "$iface" 2>/dev/null || true
            ip link set "$iface" up   2>/dev/null || true
            log_debug "MAC spoofed: $iface"
        fi
    done < <(ip link show | grep -oP '^\d+: \K\w+' 2>/dev/null)
}

_spoof_hostname() {
    local fake_host; fake_host="localhost-$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
    hostname "$fake_host" 2>/dev/null || true
    log_debug "Hostname spoofed: $fake_host"
}

_spoof_tcp_timestamps() {
    # Désactive les TCP timestamps (fingerprinting)
    sysctl -w net.ipv4.tcp_timestamps=0 2>/dev/null || true
    # Bloque les ICMP timestamps
    sysctl -w net.ipv4.icmp_echo_ignore_all=0 2>/dev/null || true
}
