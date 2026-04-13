#!/usr/bin/env bash
# firewall.sh — règles nftables/iptables pour le transparent proxy Tor
# Inspiré de: Tails (deny-by-default), Whonix (fail-closed), paranoid-ninja (nftables)

TRANS_PORT="9040"
DNS_PORT="5353"
VIRT_NET="10.192.0.0/10"
NON_TOR_NETS="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

firewall_detect_backend() {
    if distro_firewalld_active 2>/dev/null; then
        echo "firewalld-nft"
    elif command -v nft &>/dev/null; then
        echo "nft"
    elif command -v iptables &>/dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

firewall_is_active() {
    nft list table inet ghostsurf &>/dev/null
}

_generate_nft_rules() {
    local tor_uid="${TOR_UID:-$(id -u tor 2>/dev/null || echo 65534)}"
    cat <<NFTRULES
flush table inet ghostsurf

table inet ghostsurf {

    set non_tor_ipv4 {
        type ipv4_addr
        flags interval
        elements = {
            0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8,
            169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24,
            192.168.0.0/16, 198.18.0.0/15, 224.0.0.0/4,
            240.0.0.0/4
        }
    }

    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        meta l4proto udp udp dport 53 redirect to :$DNS_PORT
        ip daddr $VIRT_NET tcp dport != 9050 redirect to :$TRANS_PORT
        ip daddr @non_tor_ipv4 return
        meta l4proto tcp redirect to :$TRANS_PORT
    }

    chain output_nat {
        type nat hook output priority -100; policy accept;
        meta skuid $tor_uid return
        ip daddr 127.0.0.1 return
        meta l4proto udp udp dport 53 redirect to :$DNS_PORT
        ip daddr $VIRT_NET tcp dport != 9050 redirect to :$TRANS_PORT
        ip daddr @non_tor_ipv4 return
        meta l4proto tcp redirect to :$TRANS_PORT
    }

    chain filter_output {
        type filter hook output priority 0; policy drop;

        # Tor peut sortir librement
        meta skuid $tor_uid accept

        # Loopback
        oifname "lo" accept

        # Connexions établies et related (trafic retour)
        ct state established,related accept

        # Nouvelles connexions vers TransPort et DNSPort locaux
        ip daddr 127.0.0.1 tcp dport $TRANS_PORT ct state new accept
        ip daddr 127.0.0.1 udp dport $DNS_PORT ct state new accept

        # Bloque IPv6
        meta nfproto ipv6 drop

        # Bloque tout UDP qui ne soit pas DNS local
        meta l4proto udp drop

        # DROP tout le reste (fail-closed)
    }
}
NFTRULES
}

firewall_dryrun() {
    local tmp; tmp=$(mktemp /tmp/ghostsurf-nft-XXXXX.rules)
    _generate_nft_rules > "$tmp"
    log_info "Validation des règles nftables (dry-run)..."
    # Crée la table temporairement pour que flush soit valide
    nft add table inet ghostsurf 2>/dev/null || true
    if nft -c -f "$tmp"; then
        log_success "Règles valides"
        rm -f "$tmp"
        nft delete table inet ghostsurf 2>/dev/null || true
        return 0
    else
        log_error "Règles invalides"
        rm -f "$tmp"
        nft delete table inet ghostsurf 2>/dev/null || true
        return 1
    fi
}

firewall_apply() {
    local backend; backend=$(firewall_detect_backend)
    log_info "Application firewall (backend: $backend)..."

    case "$backend" in
        firewalld-nft)
            # Sur Fedora/RHEL: on passe par firewalld pour ne pas le contrarier
            # On désactive firewalld temporairement et on applique nos règles nft directement
            systemctl stop firewalld
            _apply_nft_rules
            ;;
        nft)
            _apply_nft_rules
            ;;
        iptables)
            _apply_iptables_rules
            ;;
        none)
            log_error "Aucun backend firewall disponible"
            return 1
            ;;
    esac
    log_success "Firewall appliqué"
}

_apply_nft_rules() {
    local tmp; tmp=$(mktemp /tmp/ghostsurf-nft-XXXXX.rules)
    _generate_nft_rules > "$tmp"
    
    # Dry-run : crée la table temporairement si elle n'existe pas
    # pour que nft -c puisse valider le flush
    nft add table inet ghostsurf 2>/dev/null || true
    
    if ! nft -c -f "$tmp"; then
        log_error "Règles invalides, abandon"
        rm -f "$tmp"
        nft delete table inet ghostsurf 2>/dev/null || true
        return 1
    fi
    
    nft -f "$tmp"
    rm -f "$tmp"
}

_apply_iptables_rules() {
    local tor_uid="${TOR_UID:-65534}"
    # Flush uniquement notre table custom, pas tout le système
    iptables -t nat -F GHOSTSURF_NAT  2>/dev/null || true
    iptables -t nat -X GHOSTSURF_NAT  2>/dev/null || true
    iptables -t nat -N GHOSTSURF_NAT

    # DNS
    iptables -t nat -A GHOSTSURF_NAT -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
    # Virtual addresses
    iptables -t nat -A GHOSTSURF_NAT -d "$VIRT_NET" -p tcp -j REDIRECT --to-ports "$TRANS_PORT"
    # Non-Tor nets
    for net in $NON_TOR_NETS; do
        iptables -t nat -A GHOSTSURF_NAT -d "$net" -j RETURN
    done
    # Tor process exception
    iptables -t nat -A GHOSTSURF_NAT -m owner --uid-owner "$tor_uid" -j RETURN
    # Everything else → TransPort
    iptables -t nat -A GHOSTSURF_NAT -p tcp -j REDIRECT --to-ports "$TRANS_PORT"

    iptables -t nat -I OUTPUT    1 -j GHOSTSURF_NAT
    iptables -t nat -I PREROUTING 1 -j GHOSTSURF_NAT

    # Kill switch
    iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -j DROP
}

firewall_restore() {
    log_info "Suppression des règles GhostSurf..."
    # Flush complet forcé avant delete
    nft flush ruleset 2>/dev/null || true
    nft delete table inet ghostsurf 2>/dev/null || true
    # Iptables cleanup
    iptables -t nat -D OUTPUT    -j GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -D PREROUTING -j GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -F GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -X GHOSTSURF_NAT 2>/dev/null || true
    # Restaure firewalld si nécessaire
    if command -v firewalld &>/dev/null; then
        systemctl start firewalld 2>/dev/null || true
    fi
    # Relance NetworkManager pour récupérer le DNS proprement
    systemctl restart NetworkManager 2>/dev/null || true
}
