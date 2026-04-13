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
# GhostSurf nftables ruleset
# Inspiré de Tails (deny-by-default) + Whonix (fail-closed)
flush table inet ghostsurf

table inet ghostsurf {

    # Adresses non routables via Tor
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

    # --- NAT: redirection transparente vers Tor ---
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        # DNS → DNSPort Tor
        meta l4proto udp udp dport 53 redirect to :$DNS_PORT

        # Adresses virtuelles Tor (.onion)
        ip daddr $VIRT_NET tcp dport != 9050 redirect to :$TRANS_PORT

        # Ne pas rediriger les adresses locales/privées
        ip daddr @non_tor_ipv4 return

        # Tout le reste TCP → TransPort
        meta l4proto tcp redirect to :$TRANS_PORT
    }

    chain output {
        type nat hook output priority -100; policy accept;

        # Le processus Tor lui-même ne se redirige pas (Tails pattern)
        meta skuid $tor_uid return

        # Loopback OK
        ip daddr 127.0.0.1 return

        # DNS → DNSPort Tor
        meta l4proto udp udp dport 53 redirect to :$DNS_PORT

        # Adresses virtuelles Tor
        ip daddr $VIRT_NET tcp dport != 9050 redirect to :$TRANS_PORT

        # Adresses privées passent (LAN)
        ip daddr @non_tor_ipv4 return

        # Tout le reste TCP → TransPort
        meta l4proto tcp redirect to :$TRANS_PORT
    }

    # --- FILTER: kill switch (Whonix fail-closed) ---
    chain filter_output {
        type filter hook output priority 0; policy drop;

        # Tor peut sortir librement (nécessaire pour établir les circuits)
        meta skuid $tor_uid accept

        # Loopback
        oifname lo accept

        # Connexions établies/related
        ct state established,related accept

        # Bloquer IPv6 complètement (pas supporté par Tor)
        meta nfproto ipv6 drop

        # Bloquer UDP sauf DNS local (WebRTC kill)
        meta l4proto udp udp dport != $DNS_PORT drop

        # Autoriser TCP vers TransPort local (trafic redirigé)
        ip daddr 127.0.0.1 tcp dport $TRANS_PORT accept

        # DROP tout le reste (fail-closed)
    }
}
NFTRULES
}

firewall_dryrun() {
    local tmp; tmp=$(mktemp /tmp/ghostsurf-nft-XXXXX.rules)
    _generate_nft_rules > "$tmp"
    log_info "Validation des règles nftables (dry-run)..."
    if nft -c -f "$tmp"; then
        log_success "Règles valides"
        rm -f "$tmp"
        return 0
    else
        log_error "Règles invalides"
        rm -f "$tmp"
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
    nft -c -f "$tmp" || { log_error "Règles invalides, abandon"; rm -f "$tmp"; return 1; }
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
    nft delete table inet ghostsurf 2>/dev/null || true
    # Nettoie les chaînes iptables custom si présentes
    iptables -t nat -D OUTPUT    -j GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -D PREROUTING -j GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -F GHOSTSURF_NAT 2>/dev/null || true
    iptables -t nat -X GHOSTSURF_NAT 2>/dev/null || true
    # Restaure firewalld si nécessaire
    if command -v firewalld &>/dev/null; then
        systemctl start firewalld 2>/dev/null || true
    fi
}
