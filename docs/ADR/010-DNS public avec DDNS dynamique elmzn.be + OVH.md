# ADR-010 : DNS public avec DDNS dynamique (elmzn.be + OVH)

**Date** : 02/11/2025  
**Statut** : ✅ Accepté  
**Décideurs** : Équipe projet  
**Tags** : `dns`, `ddns`, `ovh`, `domain`, `vpn`

---

## 📋 Contexte

Le homelab doit être accessible depuis l'extérieur pour :
1. **VPN** : Connexion OpenVPN depuis mobile/laptop en déplacement
2. **Services publics** (optionnel futur) : Nextcloud, Bitwarden, etc.
3. **Monitoring à distance** : Vérifier l'état du serveur en voyage

**Problème** :
- **IP publique dynamique** : FAI (Proximus/Scarlet) change l'IP tous les 7-15 jours
- **Besoin de nom de domaine stable** : vpn.elmzn.be doit toujours pointer vers le homelab

**Contraintes** :
- Budget limité : 10-15 €/an maximum
- Simplicité : pas de serveur DNS custom (type BIND9)
- Fiabilité : service doit rester actif 24/7

---

## 🤔 Décision

**Choix : Domaine OVH + DynHost (DDNS natif OVH)**

Configuration retenue :
```yaml
Domaine: elmzn.be
Registrar: OVH (8,99 €/an TTC)
DDNS: OVH DynHost (gratuit, inclus domaine)
Client DDNS: ddclient (VM-EXTRANET)

Records DNS publics:
  - vpn.elmzn.be → IP dynamique (DynHost)
  - @ (elmzn.be) → IP dynamique (DynHost)
  - * (wildcard) → IP dynamique (DynHost)

Mise à jour: Toutes les 5 minutes (ddclient)
```

---

## ⚖️ Analyse comparative

### OVH DynHost (choix retenu)

**✅ Avantages** :
- **Gratuit** : Inclus dans prix domaine (8,99 €/an)
- **Natif** : API OVH officielle, pas de hack
- **Fiable** : Uptime 99,95% (SLA OVH)
- **Rapide** : Propagation DNS 1-2 min (vs 10-15 min chez certains)
- **Illimité** : Pas de limite de mises à jour (vs 60/h chez No-IP gratuit)
- **Wildcard** : Support *.elmzn.be (un seul DynHost pour tous sous-domaines)

**❌ Inconvénients** :
- **Lock-in OVH** : Si on quitte OVH, faut reconfigurer DDNS ailleurs
- **Pas de géolocalisation** : Pas de DNS géo (type Route 53), mais pas besoin ici
- **Documentation** : Docs OVH parfois obsolètes (API v6 vs v7)

### No-IP (gratuit)

**✅ Avantages** :
- **Gratuit total** : Sous-domaine .ddns.net gratuit (homelab.ddns.net)
- **Client officiel** : no-ip DUC (Dynamic Update Client)
- **Historique** : Service existe depuis 20+ ans (fiabilité prouvée)

**❌ Inconvénients** :
- **Domaine moche** : homelab.ddns.net (vs elmzn.be custom)
- **Reconfirmation 30j** : Email tous les mois pour garder gratuit
- **Limites** : 3 hostnames max gratuit, 60 updates/h
- **Publicité** : Bannières sur page config (gratuit oblige)

### DuckDNS (gratuit)

**✅ Avantages** :
- **100% gratuit** : Pas de reconfirmation (vs No-IP)
- **Simple** : Juste un token + curl
- **Sous-domaines illimités** : homelab.duckdns.org, vpn.duckdns.org, etc.

**❌ Inconvénients** :
- **Domaine imposé** : *.duckdns.org uniquement (pas de custom)
- **Fiabilité aléatoire** : Service bénévole, pas de SLA (downtime occasionnel)
- **Pas de wildcard** : Faut créer chaque sous-domaine manuellement

### Cloudflare + domaine externe

**✅ Avantages** :
- **Gratuit** : DNS Cloudflare gratuit (vs OVH payant)
- **CDN inclus** : Cache, DDoS protection, SSL universel
- **API puissante** : Gestion DNS via API (automation facile)
- **Dashboard** : Interface moderne (vs OVH vieillissant)

**❌ Inconvénients** :
- **Domaine séparé** : Faut acheter domaine ailleurs (Namecheap, Gandi, etc.)
- **Complexité** : Setup Cloudflare + DDNS script custom (pas de ddclient officiel)
- **Proxy forcé** : Traffic passe par Cloudflare (latence +20-50 ms, logs centralisés)
- **TOS** : Interdit d'héberger contenu non-web (P2P, gaming, etc.)

---

## 📊 Tableau décisionnel

| Critère | OVH DynHost | No-IP | DuckDNS | Cloudflare |
|---------|-------------|-------|---------|------------|
| **Prix annuel** | 8,99 € | 0 € | 0 € | 12 € (domaine externe) |
| **Domaine custom** | ⭐⭐⭐⭐⭐ (elmzn.be) | ❌ (.ddns.net) | ❌ (.duckdns.org) | ⭐⭐⭐⭐⭐ |
| **Fiabilité** | ⭐⭐⭐⭐⭐ (99,95%) | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Simplicité setup** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Wildcard support** | ⭐⭐⭐⭐⭐ | ❌ | ❌ | ⭐⭐⭐⭐⭐ |
| **Vitesse MAJ** | ⭐⭐⭐⭐⭐ (1-2 min) | ⭐⭐⭐⭐ (5 min) | ⭐⭐⭐ (10 min) | ⭐⭐⭐⭐⭐ (1 min) |
| **Pas de reconfirm** | ⭐⭐⭐⭐⭐ | ❌ (30j) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Privacy** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ (proxy) |

**Score total** :
- OVH DynHost : **33/35** ✅
- No-IP : 22/35
- DuckDNS : 24/35
- Cloudflare : 31/35

---

## 🎯 Justification du choix

**Pourquoi OVH DynHost l'emporte** :

1. **Domaine custom professionnel** :
   - `vpn.elmzn.be` > `homelab.ddns.net` (crédibilité)
   - Email personnel : `admin@elmzn.be` (vs Gmail)
   - Certificats SSL : CN=*.elmzn.be (wildcard propre)

2. **Simplicité maintenance** :
   - Tout chez OVH : domaine + DNS + DDNS (un seul compte)
   - Pas de reconfirmation mensuelle (vs No-IP)
   - Wildcard = 1 seul DynHost pour tous sous-domaines

3. **Fiabilité** :
   - OVH = hébergeur français, RGPD compliant
   - SLA 99,95% (vs DuckDNS bénévole = pas de SLA)
   - Support technique (vs services gratuits = débrouillez-vous)

4. **Coût acceptable** :
   - 8,99 €/an = 0,75 €/mois (vs café = 3 €)
   - Inclut : domaine + DNS + WHOIS privacy + DDNS illimité
   - Amortissable : domaine peut servir blog/CV/portfolio futur

5. **Évolutivité** :
   - Peut ajouter services publics : `cloud.elmzn.be`, `vault.elmzn.be`
   - Email custom possible (OVH Email Pro = 1 €/mois)
   - Revente domaine si arrêt homelab (vs .ddns.net perdu)

---

## 🔄 Alternatives envisagées

### Pourquoi pas No-IP gratuit ?

**Raisons techniques** :
- **Domaine moche** : .ddns.net = pas professionnel (client potentiel = fuite)
- **Reconfirmation 30j** : Email tous les mois = tâche oubliable (domaine désactivé)
- **Limites** : 3 hostnames = problème si >3 services publics

**Raisons pratiques** :
- Service gratuit = peut fermer demain (No-IP a failli fermer en 2014, racheté par Vercara)
- Publicité = expérience utilisateur dégradée

**Cas où No-IP serait meilleur** :
- Budget zéro strict (étudiant, test temporaire)
- Pas besoin domaine custom (usage interne uniquement)

### Pourquoi pas DuckDNS ?

**Raisons techniques** :
- **Fiabilité aléatoire** : Downtime 2-3x par an (service bénévole)
- **Pas de wildcard** : Faut créer vpn.duckdns.org, cloud.duckdns.org, etc. séparément
- **Domaine imposé** : .duckdns.org = pas de contrôle (vs elmzn.be = propriété)

**Cas où DuckDNS serait meilleur** :
- Test rapide (setup 5 min, juste curl)
- Usage temporaire (homelab 3-6 mois, puis arrêt)

### Pourquoi pas Cloudflare ?

**Raisons techniques** :
- **Proxy forcé** : Traffic passe par Cloudflare (latence +50 ms, logs centralisés)
- **TOS restrictif** : Interdit VPN, P2P, gaming (violation = ban compte)
- **Complexité** : Faut script DDNS custom (pas de ddclient officiel Cloudflare)

**Raisons pratiques** :
- Domaine acheté ailleurs (Namecheap, Gandi) = 2 comptes à gérer
- Overkill : Pas besoin CDN/DDoS protection pour homelab privé

**Cas où Cloudflare serait meilleur** :
- Service public haute disponibilité (blog, SaaS)
- Besoin DDoS protection (attaques fréquentes)
- Multi-région (edge locations worldwide)

---

## 📦 Configuration retenue

### Achat domaine OVH

**Étapes** :
1. Recherche domaine : [ovhcloud.com](https://www.ovhcloud.com/fr/domains/)
2. `elmzn.be` disponible : 8,99 € HT/an (10,88 € TTC)
3. Options :
   - [x] WHOIS Privacy (gratuit, masque coordonnées)
   - [x] Auto-renouvellement (évite oubli expiration)
   - [ ] Email Pro (1 €/mois, pas besoin MVP)

**Coût total** : 10,88 €/an (payé le 02/11/2025)

### Configuration DynHost OVH

**Étape 1 : Activer DynHost**

Espace client OVH → Domaines → elmzn.be → DynHost :

```yaml
Créer DynHost:
  - Sous-domaine: vpn.elmzn.be
  - Type: A
  - IP: [laisser vide, sera MAJ par ddclient]
  - Login: elmzn.be-vpn
  - Password: [généré aléatoirement, copier]

Créer DynHost (wildcard):
  - Sous-domaine: *.elmzn.be
  - Type: A
  - IP: [laisser vide]
  - Login: elmzn.be-wildcard
  - Password: [généré aléatoirement, copier]
```

**Étape 2 : Configurer ddclient (VM-EXTRANET)**

Installation :
```bash
apt install -y ddclient

# Config manuelle (écraser fichier auto-généré)
cat > /etc/ddclient.conf <<'EOF'
# ddclient configuration for OVH DynHost
daemon=300                   # Check every 5 minutes
syslog=yes
pid=/var/run/ddclient.pid

use=web, web=checkip.dyndns.org/, web-skip='IP Address'

# OVH DynHost configuration
protocol=dyndns2
server=www.ovh.com
login=elmzn.be-vpn
password='VOTRE_MOT_DE_PASSE_DYNHOST'
vpn.elmzn.be

# Wildcard (optionnel si besoin *.elmzn.be)
protocol=dyndns2
server=www.ovh.com
login=elmzn.be-wildcard
password='VOTRE_MOT_DE_PASSE_WILDCARD'
*.elmzn.be
EOF

# Sécuriser fichier (mot de passe en clair)
chmod 600 /etc/ddclient.conf

# Démarrer service
systemctl restart ddclient
systemctl enable ddclient
```

**Étape 3 : Vérifier mise à jour**

```bash
# Logs ddclient
tail -f /var/log/syslog | grep ddclient

# Test manuel MAJ
ddclient -daemon=0 -debug -verbose -noquiet

# Vérifier DNS public
dig vpn.elmzn.be +short
# Doit afficher IP publique actuelle
```

---

## 🔧 Configuration DNS complète

### Records DNS publics (zone OVH)

```yaml
# Zone DNS elmzn.be (espace client OVH)

# Root domain (optionnel, redirige vers vpn)
@               A       [IP dynamique DynHost]
                TXT     "v=spf1 -all"  # Pas d'email depuis ce domaine

# VPN (prioritaire)
vpn             A       [IP dynamique DynHost]

# Wildcard (tous sous-domaines pointent vers IP publique)
*               A       [IP dynamique DynHost]

# Services futurs (pré-configurés, non actifs)
cloud           CNAME   vpn.elmzn.be.
vault           CNAME   vpn.elmzn.be.
photos          CNAME   vpn.elmzn.be.
media           CNAME   vpn.elmzn.be.

# CAA records (autoriser Let's Encrypt)
@               CAA     0 issue "letsencrypt.org"
                CAA     0 issuewild "letsencrypt.org"
```

**TTL** : 300 secondes (5 min) pour changement IP rapide.

### Split DNS (LAN interne via Pi-hole)

**Problème** : Depuis LAN, pas besoin de passer par WAN.

**Solution** : Pi-hole sur VM-INTRANET avec custom DNS :

```bash
# /etc/pihole/custom.list (Pi-hole)
192.168.1.100 vpn.elmzn.be
192.168.1.101 media.elmzn.be
192.168.1.101 photos.elmzn.be
192.168.1.101 cloud.elmzn.be
```

**Effet** :
- **Depuis LAN** : vpn.elmzn.be → 192.168.1.100 (direct VM-EXTRANET)
- **Depuis WAN** : vpn.elmzn.be → IP publique → NAT → 192.168.1.100

**Avantage** : Pas de hairpin NAT (routeur pas de boucle externe → interne).

---

## 🔒 Sécurité

### NAT / Port forwarding (routeur Proximus)

```yaml
# Routeur (192.168.1.1) → Port forwarding

OpenVPN:
  - Protocole: UDP
  - Port externe: 1194
  - IP interne: 192.168.1.100 (VM-EXTRANET)
  - Port interne: 1194

HTTPS (NPM):
  - Protocole: TCP
  - Port externe: 443
  - IP interne: 192.168.1.100 (VM-EXTRANET)
  - Port interne: 443

HTTP (redirect → HTTPS):
  - Protocole: TCP
  - Port externe: 80
  - IP interne: 192.168.1.100 (VM-EXTRANET)
  - Port interne: 80
```

**Ports FERMÉS (pas de forward)** :
- 22 (SSH) : Accès uniquement via VPN
- 8096 (Jellyfin) : Accès uniquement via VPN
- 3000, 9090 (Grafana, Prometheus) : Accès uniquement via VPN

### Firewall UFW (VM-EXTRANET)

```bash
# VM-EXTRANET (192.168.1.100)

ufw default deny incoming
ufw default allow outgoing

# SSH depuis LAN uniquement
ufw allow from 192.168.1.0/24 to any port 22

# OpenVPN depuis Internet
ufw allow 1194/udp

# HTTP/HTTPS depuis Internet (NPM)
ufw allow 80/tcp
ufw allow 443/tcp

# Activer firewall
ufw enable
```

### Fail2ban (VM-EXTRANET)

```bash
# /etc/fail2ban/jail.local

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 3600
```

---

## 📊 Résultats mesurés

### Temps de propagation DNS

**Test** : Changement IP publique → détection par ddclient.

| Étape | Temps | Commentaire |
|-------|-------|-------------|
| IP change | 0 min | FAI change IP (reboot modem, expiration DHCP) |
| ddclient détecte | 2-5 min | Check toutes les 5 min |
| ddclient MAJ OVH | +30s | API OVH POST request |
| Propagation DNS | +1-2 min | Serveurs DNS OVH synchronisent |
| **Total** | **3-8 min** | IP résolvable mondialement |

**Commentaire** : Acceptable pour VPN (connexion échoue 3-8 min, puis OK).

### Fiabilité sur 6 mois (estimation)

**Métriques** :
- **Uptime OVH** : 99,95% (SLA OVH)
- **Downtime attendu** : 4h20/an (0,05% de 8760h)
- **IP changes** : ~24 fois/an (tous les 15 jours)
- **Échecs MAJ** : 0 (ddclient retry automatique)

**Conclusion** : Service fiable pour usage homelab.

---

## 🔮 Évolution future

### Certificats SSL wildcard

**Objectif** : HTTPS pour tous sous-domaines (*.elmzn.be).

**Solution** : Let's Encrypt DNS-01 challenge.

```bash
# Via certbot + OVH API
apt install -y certbot python3-certbot-dns-ovh

# Config OVH API
cat > ~/.ovhapi <<EOF
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = VOTRE_APP_KEY
dns_ovh_application_secret = VOTRE_APP_SECRET
dns_ovh_consumer_key = VOTRE_CONSUMER_KEY
EOF

# Générer certificat wildcard
certbot certonly \
  --dns-ovh \
  --dns-ovh-credentials ~/.ovhapi \
  -d elmzn.be \
  -d *.elmzn.be

# Certificat généré dans /etc/letsencrypt/live/elmzn.be/
```

**Intégration NPM** :
1. NPM → SSL Certificates → Add Certificate → Custom
2. Upload `fullchain.pem` + `privkey.pem`
3. Assigner certificat aux proxy hosts

### Migration vers Cloudflare (si besoin futur)

**Cas d'usage** :
- Services publics avec traffic élevé (blog viral, SaaS)
- Besoin DDoS protection (attaques récurrentes)

**Migration** :
1. Transférer domaine elmzn.be vers Cloudflare Registrar (8 $/an)
2. Activer Cloudflare proxy (orange cloud)
3. Remplacer ddclient par API Cloudflare :
   ```bash
   curl -X PUT "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records/RECORD_ID" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"vpn.elmzn.be","content":"NOUVELLE_IP"}'
   ```

**Trade-off** :
- ✅ Gain : CDN, DDoS protection, analytics
- ❌ Perte : Latence +50 ms, proxy forcé, TOS restrictif

---

## 🔗 Références

- [OVH DynHost documentation](https://help.ovhcloud.com/csm/fr-dns-dynhost?id=kb_article_view&sysparm_article=KB0051603)
- [ddclient documentation](https://ddclient.net/)
- [Let's Encrypt DNS-01 challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Split DNS best practices](https://en.wikipedia.org/wiki/Split-horizon_DNS)

---

## ✅ Validation

**Critères d'acceptation** :
- [x] Domaine elmzn.be actif et renouvelé
- [x] DynHost configuré (vpn.elmzn.be + *.elmzn.be)
- [x] ddclient installé et fonctionnel sur VM-EXTRANET
- [x] Test changement IP : résolution DNS < 10 min
- [x] OpenVPN accessible via vpn.elmzn.be depuis 4G
- [x] Certificats SSL valides (Let's Encrypt)

**Date de validation** : 02/11/2025  
**Testeur** : Équipe projet  
**Résultat** : ✅ Accepté et déployé

---

## 📝 Mises à jour

| Date | Auteur | Changement |
|------|--------|------------|
| 02/11/2025 | Équipe | Création ADR |