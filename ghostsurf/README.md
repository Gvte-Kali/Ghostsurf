# GhostSurf

Transparent Tor proxy pour n'importe quelle distribution Linux.
Inspiré de Tails, Whonix, anonsurf et paranoid-ninja — avec support SELinux,
snapshot système automatique et GUI systray.

## Démarrage rapide

```bash
git clone https://github.com/Gvte-Kali/ghostsurf
cd ghostsurf
sudo ./install.sh
sudo ghostsurf start
```

## Commandes

```bash
sudo ghostsurf start          # Active le proxy Tor transparent
sudo ghostsurf stop           # Désactive et restaure l'état original
sudo ghostsurf restart        # Redémarre
sudo ghostsurf status         # Affiche l'état (IP, Tor, firewall)
sudo ghostsurf newid          # Nouvelle identité Tor

sudo ghostsurf snapshot       # Crée un snapshot manuel
sudo ghostsurf restore        # Restaure le dernier snapshot
sudo ghostsurf snapshots      # Liste les snapshots disponibles

sudo ghostsurf dev-start      # Démarre avec watchdog (rollback auto)
sudo ghostsurf check          # Vérifie les dépendances
sudo ghostsurf firewall-check # Dry-run des règles nftables
ghostsurf tray                # Lance le systray
```

## Options

```bash
--no-spoof      Désactive le spoofing MAC/hostname
--no-selinux    Ignore la configuration SELinux
-v, --verbose   Mode verbeux
```

## Fonctionnalités

- Tout le trafic TCP/DNS redirigé via Tor (transparent proxy)
- Kill switch firewall fail-closed (inspiré Whonix) — si Tor tombe, rien ne passe
- Snapshot automatique avant chaque modification système
- Rollback d'urgence automatique si crash (trap ERR/INT/TERM)
- Watchdog de connectivité en mode dev (rollback si perte réseau >30s)
- Support nftables + iptables + firewalld (Fedora)
- Support SELinux (Fedora, RHEL, Rocky...)
- Spoofing MAC, hostname, TCP timestamps, désactivation IPv6
- Binaire Tor embarqué disponible (indépendant du paquet système)
- Systray PyQt6 avec toggle on/off et nouvelle identité

## Navigation web

Le trafic TCP est redirigé automatiquement via Tor.
Pour les navigateurs, configurez le proxy SOCKS5 `127.0.0.1:9050`
ou utilisez `torsocks` :

```bash
torsocks firefox
torsocks curl https://exemple.com
```

## Compatibilité

| Distro | Statut |
|---|---|
| Debian 12/13 | ✓ Testé |
| Ubuntu 22.04/24.04 | ✓ Supporté |
| Fedora 39+ | ✓ Supporté (SELinux + firewalld) |
| Arch Linux | ✓ Supporté |
| RHEL / Rocky / Alma | ✓ Supporté |

Requiert : `systemd`, `nftables` ou `iptables`, `tor`, `curl`, `iproute2`

## Dépendances

```bash
# Debian / Ubuntu
sudo apt install tor nftables curl iproute2 macchanger torsocks

# Fedora / RHEL
sudo dnf install tor nftables curl iproute macchanger torsocks

# Arch
sudo pacman -S tor nftables curl iproute2 macchanger torsocks
```

## Sources d'inspiration

| Fonctionnalité | Source |
|---|---|
| Deny-by-default firewall | Tails |
| Fail-closed / kill switch | Whonix |
| Stream isolation | Whonix |
| nftables dual-backend | paranoid-ninja |
| MAC/hostname spoofing | paranoid-ninja |
| Cycle de vie Tor | anonsurf (ParrotSec) |
| Launchers desktop | anonsurf (ParrotSec) |
| Binaire Tor embarqué | Tor Browser Bundle |
| Network namespace isolation | Nouveau |

## Licence

MIT