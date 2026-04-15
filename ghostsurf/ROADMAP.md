# GhostSurf — Roadmap

## Phase 1 — Fondations ✓
- [x] Structure du projet
- [x] `logger.sh`, `distro.sh`
- [x] `ghostsurf check` fonctionnel
- [x] `tests/test_distro.sh` — 9/9
- [ ] CI GitHub Actions shellcheck

## Phase 2 — Snapshot ✓
- [x] `snapshot_create` / `snapshot_restore`
- [x] Limite 5 snapshots
- [x] Rollback DNS via NetworkManager
- [x] `tests/test_snapshot.sh` — 10/10

## Phase 3 — Firewall ✓
- [x] nftables deny-by-default (inspiré Tails)
- [x] Kill switch fail-closed (inspiré Whonix)
- [x] Dry-run avant application
- [x] Flush propre au stop
- [x] IPv6 désactivé
- [x] `tests/test_firewall.sh` — 8/8
- [ ] Règles Whonix manquantes :
  - [ ] INPUT chain avec policy drop
  - [ ] Bloquer multicast/broadcast explicitement
  - [ ] Bloquer ICMP sortant

## Phase 4 — Tor + identité ✓
- [x] Démarrage / arrêt Tor
- [x] Détection `tor@default` vs `tor`
- [x] Bootstrap via journalctl
- [x] DNS via resolv.conf → Tor
- [x] `tor_check_ip` via socks5
- [x] `ghostsurf newid`
- [ ] Commande `myip` avec IP + IsTor + pays
- [ ] Commande `check-leaks` (DNS, IPv6, WebRTC, IP)
- [ ] Détection DNS leak dans `status`
- [ ] Uptime Tor dans `status`
- [ ] `tests/test_tor.sh`

## Phase 5 — Spoof ✓
- [x] MAC spoofing
- [x] Hostname spoofing
- [x] TCP timestamps
- [x] IPv6 désactivé
- [x] `tests/test_spoof.sh` — 7/7

## Phase 6 — GUI systray
- [x] `gui/tray.py` PyQt6 dark theme
- [x] Icônes SVG inline (actif/inactif/chargement)
- [x] Fenêtre status avec toutes les infos
- [x] Vérification anti-root au lancement
- [ ] Test toggle on/off fonctionnel
- [ ] Test affichage IP Tor en temps réel
- [ ] Test nouvelle identité depuis le tray
- [ ] Intégration commande `myip` dans la fenêtre
- [ ] Autostart au démarrage du bureau

## Phase 7 — Binaires Tor embarqués
- [ ] `assets/tor-binaries/update.sh`
- [ ] Vérification SHA256 + GPG
- [ ] Support x86_64 et aarch64
- [ ] Fallback binaire système si embarqué absent
- [ ] Intégration dans `distro_detect`

## Phase 8 — Tests complets
- [ ] `tests/test_tor.sh` (myip, dns_leak, check-leaks)
- [ ] Mise à jour `tests/run_all.sh`
- [ ] Tests sur Fedora avec SELinux enforcing
- [ ] Tests sur Arch Linux
- [ ] Tests sur Ubuntu 24.04

## Phase 9 — Polish & release
- [ ] CI GitHub Actions shellcheck
- [ ] `docs/ARCHITECTURE.md`
- [ ] README finalisé
- [ ] `uninstall.sh` testé
- [ ] Package .deb basique
- [ ] Release v0.1.0