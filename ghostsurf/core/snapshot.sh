#!/usr/bin/env bash
# snapshot.sh — capture et restauration de l'état système

SNAPSHOT_BASE="${STATE_DIR:-/var/lib/ghostsurf}/snapshots"
CURRENT_SNAPSHOT=""

snapshot_create() {
    mkdir -p "$SNAPSHOT_BASE"
    local ts; ts=$(date +%s)
    local dir="$SNAPSHOT_BASE/$ts"
    mkdir -p "$dir"
    CURRENT_SNAPSHOT="$dir"
    export CURRENT_SNAPSHOT

    log_info "Création snapshot $ts..."

    # Règles firewall
    if command -v nft &>/dev/null; then
        nft list ruleset > "$dir/nftables.rules" 2>/dev/null || echo "# vide" > "$dir/nftables.rules"
        echo "nft" > "$dir/fw_backend"
    fi
    if command -v iptables-save &>/dev/null; then
        iptables-save  > "$dir/iptables.rules"  2>/dev/null || true
        ip6tables-save > "$dir/ip6tables.rules" 2>/dev/null || true
        [[ ! -f "$dir/fw_backend" ]] && echo "iptables" > "$dir/fw_backend"
    fi

    # DNS
    cp /etc/resolv.conf "$dir/resolv.conf" 2>/dev/null || true
    [[ -f /etc/systemd/resolved.conf ]] && cp /etc/systemd/resolved.conf "$dir/resolved.conf"

    # torrc (trouve le bon chemin selon la distro)
    local torrc
    torrc=$(find /etc/tor /usr/local/etc/tor -name torrc 2>/dev/null | head -1 || true)
    if [[ -n "$torrc" && -f "$torrc" ]]; then
        cp "$torrc" "$dir/torrc"
        echo "$torrc" > "$dir/torrc.path"
    fi

    # Interfaces réseau (MAC)
    ip link show > "$dir/ip-link.txt" 2>/dev/null || true
    while IFS= read -r iface; do
        [[ "$iface" == "lo" ]] && continue
        cat "/sys/class/net/$iface/address" > "$dir/mac_${iface}" 2>/dev/null || true
    done < <(ip link show | grep -oP '^\d+: \K\w+' 2>/dev/null || true)

    # Hostname
    hostname > "$dir/hostname" 2>/dev/null || true
    [[ -f /etc/hostname ]] && cp /etc/hostname "$dir/etc-hostname"

    # Timezone
    [[ -L /etc/localtime ]] && readlink /etc/localtime > "$dir/localtime.link" 2>/dev/null || true

    # SELinux
    if command -v semanage &>/dev/null && command -v getsebool &>/dev/null; then
        semanage port -l > "$dir/semanage-ports.txt" 2>/dev/null || true
        getsebool -a    > "$dir/sebooleans.txt"      2>/dev/null || true
    fi

    # État des services
    for svc in tor NetworkManager systemd-resolved firewalld; do
        systemctl is-active "$svc" > "$dir/svc_${svc}" 2>/dev/null || echo "inactive" > "$dir/svc_${svc}"
    done

    echo "$ts" > "$dir/timestamp"
    echo "ghostsurf-snapshot-v1" > "$dir/version"
    snapshot_cleanup_old
    log_debug "Snapshot créé: $dir"
    echo "$dir"
}

snapshot_restore() {
    local dir="${1:-$CURRENT_SNAPSHOT}"
    if [[ -z "$dir" ]]; then
        dir=$(ls -dt "$SNAPSHOT_BASE"/*/  2>/dev/null | head -1)
    fi
    [[ -z "$dir" || ! -d "$dir" ]] && { log_warn "Aucun snapshot à restaurer"; return 0; }

    log_info "Restauration depuis $(basename "$dir")..."

    # Firewall
    local backend; backend=$(cat "$dir/fw_backend" 2>/dev/null || echo "nft")
    if [[ "$backend" == "nft" && -f "$dir/nftables.rules" ]]; then
        nft flush ruleset 2>/dev/null || true
        nft -f "$dir/nftables.rules" 2>/dev/null || true
    elif [[ -f "$dir/iptables.rules" ]]; then
        iptables-restore  < "$dir/iptables.rules"  2>/dev/null || true
        ip6tables-restore < "$dir/ip6tables.rules" 2>/dev/null || true
    fi

    # DNS
    [[ -f "$dir/resolv.conf" ]] && cp "$dir/resolv.conf" /etc/resolv.conf 2>/dev/null || true

    # torrc
    if [[ -f "$dir/torrc.path" && -f "$dir/torrc" ]]; then
        cp "$dir/torrc" "$(cat "$dir/torrc.path")" 2>/dev/null || true
    fi

    # MAC
    for mac_file in "$dir"/mac_*; do
        [[ -f "$mac_file" ]] || continue
        local iface="${mac_file##*/mac_}"
        local orig; orig=$(cat "$mac_file")
        ip link set "$iface" down 2>/dev/null || true
        ip link set "$iface" address "$orig" 2>/dev/null || true
        ip link set "$iface" up   2>/dev/null || true
    done

    # Hostname
    [[ -f "$dir/hostname" ]] && hostname "$(cat "$dir/hostname")" 2>/dev/null || true
    [[ -f "$dir/etc-hostname" ]] && cp "$dir/etc-hostname" /etc/hostname 2>/dev/null || true

    # Timezone
    if [[ -f "$dir/localtime.link" ]]; then
        local tz; tz=$(sed 's|.*/zoneinfo/||' "$dir/localtime.link")
        timedatectl set-timezone "$tz" 2>/dev/null || true
    fi

    log_success "Restauration terminée"
}

snapshot_list() {
    echo "Snapshots disponibles:"
    while IFS= read -r d; do
        local ts; ts=$(basename "$d")
        local date; date=$(date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$ts" 2>/dev/null || echo "$ts")
        printf "  %s  (%s)\n" "$ts" "$date"
    done < <(ls -dt "$SNAPSHOT_BASE"/*/  2>/dev/null || true)
}

snapshot_latest_date() {
    local latest; latest=$(ls -dt "$SNAPSHOT_BASE"/*/  2>/dev/null | head -1 || true)
    [[ -z "$latest" ]] && echo "aucun" && return
    local ts; ts=$(basename "$latest")
    date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts"
}

snapshot_cleanup_old() {
    # Garde les 10 derniers snapshots
    ls -dt "$SNAPSHOT_BASE"/*/  2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null || true
}
