#!/usr/bin/env bash
# selinux.sh — configuration SELinux pour Tor transparent proxy
# Nécessaire sur Fedora, RHEL, Rocky, Alma...

selinux_status() {
    command -v getenforce &>/dev/null && getenforce || echo "N/A"
}

selinux_is_enforcing() {
    command -v getenforce &>/dev/null && [[ $(getenforce) == "Enforcing" ]]
}

selinux_setup() {
    command -v getenforce &>/dev/null || return 0
    [[ $(getenforce) == "Disabled" ]] && return 0

    log_info "Configuration SELinux pour Tor transparent proxy..."

    # Labellise les ports custom Tor
    for port_spec in "tcp:9040" "udp:5353" "tcp:9051" "tcp:9100"; do
        local proto="${port_spec%%:*}"
        local port="${port_spec##*:}"
        semanage port -a -t tor_port_t -p "$proto" "$port" 2>/dev/null || \
        semanage port -m -t tor_port_t -p "$proto" "$port" 2>/dev/null || \
        log_warn "SELinux: impossible de labelliser $proto/$port (peut déjà être labellisé)"
    done

    # Booleans utiles
    setsebool -P tor_bind_all_unreserved_ports 1 2>/dev/null || true

    log_success "SELinux configuré"
}

selinux_teardown() {
    command -v getenforce &>/dev/null || return 0
    [[ $(getenforce) == "Disabled" ]] && return 0

    log_info "Nettoyage SELinux..."
    for port_spec in "tcp:9040" "udp:5353" "tcp:9051" "tcp:9100"; do
        local proto="${port_spec%%:*}"
        local port="${port_spec##*:}"
        semanage port -d -t tor_port_t -p "$proto" "$port" 2>/dev/null || true
    done
}
