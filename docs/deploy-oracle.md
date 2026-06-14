# Deploy runbook — Backend su Oracle Cloud Always Free (VM ARM warm)

Come mettere in piedi il manajudge **Backend** su una VM **Oracle Cloud Always Free**
Ampere **A1 (ARM64)**, sempre accesa, con un **volume persistente** per il DB SQLite — come
deciso in [ADR 0002](./adr/0002-flutter-companion-backend-as-service.md).

**Perché warm + stateful, no serverless:** `better-sqlite3` è sincrono/single-process e il
modello di embedding si carica in RAM. Con scale-to-zero ogni risveglio ricaricherebbe
modello + DB (cold start). Serve quindi un'istanza always-on con un volume persistente.

> **HITL.** Questi passi richiedono un account Oracle, provisioning infra e una build ARM64
> sulla VM. La capacità A1 può scarseggiare per regione: se il provisioning fallisce, usa il
> **fallback self-host + Cloudflare Tunnel** in fondo. Gli artefatti (`backend/Dockerfile`,
> `backend/docker-compose.yml`, `backend/deploy/manajudge.service`) sono già nel repo.

---

## 0. Cosa pubblichiamo

- App: server SvelteKit standalone (`adapter-node`, `node build/index.js`) sulla porta 3000.
- Stato persistente: `data/judge.db` (~270 MB: ~37k carte + Comprehensive Rules + vettori).
- Modello di embedding: **baked nell'immagine** (`MODEL_CACHE_DIR`), così il boot è caldo.
- Endpoint chiave: `GET /api/health` (readiness/warm), `POST /api/chat` (Judge),
  `POST /api/search` (Card Search), `GET /api/me` (uso/Quota).

## 1. Provisioning della VM A1 (ARM64)

1. Oracle Cloud Console → **Compute → Instances → Create**.
2. **Shape:** `VM.Standard.A1.Flex` (Ampere ARM). Always Free copre fino a 4 OCPU / 24 GB RAM
   complessivi: per manajudge bastano 1–2 OCPU e 6–12 GB (RAM per modello + page cache SQLite).
3. **Image:** Ubuntu 22.04/24.04 (ARM64) o Oracle Linux.
4. **SSH keys:** carica la tua chiave pubblica.
5. **Networking:** subnet pubblica; apri la porta in ingresso (vedi §6 per HTTPS). Se usi
   Cloudflare Tunnel **non** serve aprire porte pubbliche.

> Se compare *"Out of host capacity"*: riprova in un'altra Availability Domain/regione o più
> tardi (è la scarsità tipica di A1). In alternativa vai al fallback self-host.

## 2. Volume persistente a blocchi

1. **Storage → Block Volumes → Create Block Volume** (es. 50 GB), stessa AD della VM.
2. **Attach** il volume alla VM (iSCSI o paravirtualized).
3. Sulla VM: formatta e monta su un mount point stabile, es. `/mnt/manajudge-data`, e
   aggiungilo a `/etc/fstab` perché sopravviva al reboot.
   ```bash
   sudo mkfs.ext4 /dev/sdb            # o il device giusto (lsblk)
   sudo mkdir -p /mnt/manajudge-data
   sudo mount /dev/sdb /mnt/manajudge-data
   echo '/dev/sdb /mnt/manajudge-data ext4 defaults,_netdev 0 2' | sudo tee -a /etc/fstab
   ```

## 3. Docker

```bash
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # poi ri-login
```

## 4. Codice + segreti

```bash
git clone https://github.com/BluHal/manajudge.git
cd manajudge/backend
cp .env.example .env
# inserisci GEMINI_API_KEY=... (e, se vuoi, GEMINI_MODEL / GEMINI_MODEL_FAST)
```

Per usare il **block volume** invece del volume Docker di default, in
`backend/docker-compose.yml` sostituisci il blocco `volumes:` finale con il bind-mount al
mount point (vedi il commento già presente nel file):

```yaml
volumes:
  manajudge-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/manajudge-data
```

## 5. Popolare il DB la prima volta

Il volume parte vuoto: serve `judge.db`. Due strade.

**A) Copia un DB già costruito in locale (consigliato, è più veloce):**
```bash
# dalla tua macchina, dove hai già girato gli script dati:
scp backend/data/judge.db ubuntu@<VM_IP>:/mnt/manajudge-data/judge.db
```

**B) Costruiscilo sulla VM** (richiede le dev-deps e un po' di tempo/CPU per i vettori):
```bash
cd manajudge/backend
npm ci
npm run data:rules
npm run data:cards
npm run data:card-vectors
sudo cp data/judge.db /mnt/manajudge-data/judge.db
```

## 6. Build & run

La build dell'immagine ARM64 avviene **sulla VM** (stessa arch del target):
```bash
cd manajudge/backend
docker compose up -d --build
docker compose logs -f        # attendi che l'healthcheck diventi healthy
```

Verifica:
```bash
curl -s http://localhost:3000/api/health            # { "status": "ok", "cards": ..., "rules": ... }
TOKEN=dev-test-1
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/me
curl -s -X POST http://localhost:3000/api/search -H 'content-type: application/json' \
     -H "Authorization: Bearer $TOKEN" -d '{"query":"counter target spell"}' | head -c 300
```

## 7. HTTPS

L'app Flutter chiama il Backend su **HTTPS**. Due opzioni:

- **Reverse proxy + Let's Encrypt** (Caddy è il più semplice): punta un dominio alla VM,
  apri 80/443 nella security list, e fai proxy verso `127.0.0.1:3000`. Esempio `Caddyfile`:
  ```
  api.tuodominio.tld {
      reverse_proxy 127.0.0.1:3000
  }
  ```
- **Cloudflare Tunnel:** nessuna porta pubblica aperta, TLS gestito da Cloudflare (vedi sotto).

## 8. Aggiornamenti / redeploy

```bash
cd manajudge/backend && git pull && docker compose up -d --build
```
Il volume (`/mnt/manajudge-data` o `manajudge-data`) sopravvive: il DB e i suoi User/Quota
restano. Il modello resta baked nell'immagine.

---

## Fallback — Self-host + Cloudflare Tunnel

Se la capacità A1 non è disponibile, ospita il Backend su un PC/mini-PC sempre acceso ed
esponilo con **Cloudflare Tunnel** ($0, nessuna porta aperta; disponibilità legata alla
macchina accesa).

**Con Docker** (uguale ai passi 3–6, su qualsiasi host Linux), poi:
```bash
cloudflared tunnel login
cloudflared tunnel create manajudge
# instrada un hostname -> http://localhost:3000, poi:
cloudflared tunnel run manajudge
```

**Senza Docker** (Node diretto, gestito da systemd):
```bash
cd backend && npm ci --omit=dev && npm run build
MODEL_CACHE_DIR=$PWD/.model-cache npm run prewarm   # scarica il modello una volta
# DB su DB_PATH (vedi §5). Poi installa la unit:
sudo cp deploy/manajudge.service /etc/systemd/system/manajudge.service
# adatta User/WorkingDirectory/EnvironmentFile/DB_PATH dentro la unit
sudo systemctl daemon-reload && sudo systemctl enable --now manajudge
```
Il servizio espone `127.0.0.1:3000`; mettilo dietro Cloudflare Tunnel come sopra.

---

## Note / caveat

- **Capacità A1:** può non essere disponibile a ondate per regione — riprova o usa il fallback.
- **Build ARM64:** `better-sqlite3` viene compilato sulla VM (toolchain nel Dockerfile);
  `sqlite-vec` e `onnxruntime-node` (transformers.js) usano binari precompilati arm64.
- **Free tier Gemini:** il rate-limit per-progetto non regge multi-utente reale: è un tema di
  *public-readiness* (tier a pagamento + rate-limit per-utente), fuori dallo scopo di v1.
- **Quota/Plan:** in v1 l'enforcement arriva con la issue #12; qui il metering è già attivo.
