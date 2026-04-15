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
sudo ghostsurf status         # Affiche l'état complet (IP, circuits, DNS...)
sudo ghostsurf newid          # Nouvelle identité Tor
sudo ghostsurf myip           # Affiche l'IP Tor, IsTor et pays du nœud de sortie
sudo ghostsurf check-leaks    # Vérifie les fuites DNS, WebRTC, IPv6 et IP

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

## Vérification de l'anonymat

### Afficher l'IP Tor

```bash
sudo ghostsurf myip
```

Exemple de sortie :
```
  IP Tor   : 185.220.101.16
  IsTor    : true
  Pays     : Germany
```

### Vérifier les fuites

```bash
sudo ghostsurf check-leaks
```

Vérifie automatiquement :

| Test | Description |
|---|---|
| DNS leak | `resolv.conf` pointe vers `127.0.0.1` (Tor) et `systemd-resolved` est désactivé |
| WebRTC (UDP/STUN) | Le kill switch UDP bloque le port 3478 (prévient la fuite WebRTC) |
| IPv6 leak | Aucune connexion IPv6 possible (IPv6 désactivé par spoof.sh) |
| Tor actif (IsTor) | `check.torproject.org` confirme que l'IP sort bien via Tor |

Exemple de sortie :
```
  GhostSurf — Vérification des fuites
  ─────────────────────────────────────

  [OK]   PASS  DNS leak
  [OK]   PASS  WebRTC (UDP/STUN)
  [OK]   PASS  IPv6 leak
  [OK]   PASS  Tor actif (IsTor)  (IP=185.220.101.16)

  ─────────────────────────────────────
  Résultat : 4 PASS, 0 FAIL
```

## Fonctionnalités

- Tout le trafic TCP/DNS redirigé via Tor (transparent proxy)
- Kill switch firewall fail-closed (inspiré Whonix) — si Tor tombe, rien ne passe
- Chain INPUT policy drop — aucune connexion entrante non établie acceptée
- Blocage ICMP sortant, multicast (224.0.0.0/4) et broadcast (255.255.255.255)
- Snapshot automatique avant chaque modification système
- Rollback d'urgence automatique si crash (trap ERR/INT/TERM)
- Watchdog de connectivité en mode dev (rollback si perte réseau >30s)
- Support nftables + iptables + firewalld (Fedora)
- Support SELinux (Fedora, RHEL, Rocky...)
- Spoofing MAC, hostname, TCP timestamps, désactivation IPv6
- DNS système redirigé vers le DNSPort Tor (port 53 et 5353)
- Détection de fuites DNS, WebRTC, IPv6 intégrée
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

| Distro | Statut | Notes |
|---|---|---|
| Debian 12/13 | ✓ Testé | Service `tor@default` |
| Ubuntu 22.04/24.04 | ✓ Supporté | Service `tor@default` |
| Fedora 39+ | ✓ Supporté | SELinux + firewalld |
| Arch Linux | ✓ Supporté | Service `tor` |
| RHEL / Rocky / Alma | ✓ Supporté | SELinux |

Requiert : `systemd`, `nftables` ou `iptables`, `tor`, `curl`, `iproute2`, `nc` (netcat)

## Binaires Tor embarqués

Pour utiliser un binaire Tor indépendant du système (utile sur distros avec paquets anciens) :

```bash
cd assets/tor-binaries
sudo bash update.sh          # Détecte et télécharge la dernière version
sudo bash update.sh 13.5.6   # Version spécifique
```

Les binaires sont vérifiés par SHA256 et GPG (si `gpg` est disponible).
`distro.sh` préfère automatiquement le binaire embarqué si présent.

## Dépendances

```bash
# Debian / Ubuntu
sudo apt install tor nftables curl iproute2 macchanger torsocks netcat-openbsd

# Fedora / RHEL
sudo dnf install tor nftables curl iproute macchanger torsocks nmap-ncat

# Arch
sudo pacman -S tor nftables curl iproute2 macchanger torsocks openbsd-netcat
```

## Sources d'inspiration

| Fonctionnalité | Source |
|---|---|
| Deny-by-default firewall | Tails |
| Fail-closed / kill switch | Whonix |
| INPUT chain policy drop | Whonix firewall |
| Stream isolation | Whonix |
| nftables dual-backend | paranoid-ninja |
| MAC/hostname spoofing | paranoid-ninja |
| Cycle de vie Tor | anonsurf (ParrotSec) |
| myip + check-leaks | anonsurf (ParrotSec) |
| Binaire Tor embarqué | Tor Browser Bundle |
| Network namespace isolation | Nouveau |

## Licence

MIT
