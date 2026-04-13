# GhostSurf

Transparent Tor proxy pour n'importe quelle distribution Linux. Inspiré de Tails, Whonix, anonsurf et paranoid-ninja — avec support SELinux, snapshot système et GUI systray.

```
sudo ghostsurf start     # active
sudo ghostsurf status    # vérifie
sudo ghostsurf stop      # restaure
```

## Installation rapide

```bash
git clone https://github.com/Gvte-Kali/ghostsurf
cd ghostsurf
sudo ./install.sh
sudo ghostsurf check
```

## Fonctionnalités

- Tout le trafic TCP/DNS redirigé via Tor (transparent proxy)
- Kill switch firewall (fail-closed, inspiré Whonix)
- Snapshot automatique avant chaque modification
- Rollback d'urgence si crash (trap ERR/INT/TERM)
- Support nftables + iptables + firewalld (Fedora)
- Support SELinux (Fedora, RHEL, Rocky...)
- Spoofing MAC, hostname, TCP timestamps
- Binaire Tor embarqué (indépendant du paquet système)
- Systray PyQt6 avec toggle on/off et nouvelle identité
- Distros testées: Fedora, Debian, Ubuntu, Arch

## Sources d'inspiration

| Fonctionnalité | Source |
|---|---|
| Deny-by-default firewall | Tails |
| Fail-closed / kill switch | Whonix |
| Stream isolation | Whonix |
| nftables dual-backend | paranoid-ninja |
| MAC/hostname spoofing | paranoid-ninja |
| Cycle de vie Tor | anonsurf |
| Launchers desktop | anonsurf |
| Binaire Tor embarqué | Tor Browser Bundle |

## Compatibilité

Toute distro Linux avec systemd, nftables ou iptables.
SELinux géré automatiquement sur Fedora/RHEL.
