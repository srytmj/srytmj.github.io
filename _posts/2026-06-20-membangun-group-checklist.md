---
title: "Membangun Realtime Checklist App dengan Bun, Hono, dan Alpine.js"
description: "Cerita di balik group-checklist: dari ide sederhana sampai live di AWS EC2 + Cloudflare, lengkap dengan gotcha JWT di Bun, Alpine.js reactivity, dan WebSocket room management."
author: srytmj
date: 2026-06-20 12:00:00 +0700
categories: [Project, Web Development]
tags: [bun, hono, postgresql, alpine.js, websocket, typescript, aws, ec2, cloudflare, nginx, neon]
pin: false
math: false
mermaid: false
published: true
---

Jadi setiap kali aku punya tugas kelompok, pasti kami bagi-bagi tugasnya lewat chat, terus kami bikin checklist di notes atau Google Docs, terus nggak ada yang tahu siapa yang sudah ngerjain apa. Atau lebih parahnya satu orang update checklist-nya, yang lain nggak tahu. Bolak-balik nanya di chat.

Dari frustrasi itu, aku bikin [group-checklist](https://github.com/srytmj/group-checklist) — aplikasi checklist kolaboratif yang realtime. Kalau satu orang centang item, semua orang di halaman yang sama langsung lihat update-nya tanpa reload. Live di [checky.suryatmaja.dev](https://checky.suryatmaja.dev).

Ini cerita di balik proses membangunnya.

---

## Kenapa Bun dan Bukan Node.js?

Waktu mulai project ini, aku pengen coba runtime baru selain Node. Bun menarik karena beberapa alasan:

1. **Performa** — Bun diklaim jauh lebih cepat dari Node untuk startup time dan throughput.
2. **Built-in tools** — Bun punya bundler, test runner, dan package manager bawaan, jadi dependency-nya lebih sedikit.
3. **Native WebSocket** — `createBunWebSocket` dari Hono sudah terintegrasi rapi, tanpa perlu library tambahan seperti `ws`.

Dan yang paling menarik: Bun punya `crypto.subtle` yang fully functional, jadi aku bisa bikin JWT dari scratch tanpa external dependency.

Tapi pilih Bun bukan berarti tanpa risiko. Ada beberapa library Node yang belum kompatibel penuh, dan ini yang bikin aku ketemu salah satu gotcha paling menyebalkan di project ini.

---

## Stack Akhir

| Layer       | Teknologi                                       |
|-------------|------------------------------------------------|
| Runtime     | Bun                                             |
| Framework   | Hono v4.7                                       |
| Database    | Neon PostgreSQL                                 |
| Frontend    | Vanilla HTML + Alpine.js 3 (no build step)      |
| Auth        | JWT HS256 via `crypto.subtle`                   |
| Realtime    | WebSockets via `createBunWebSocket`             |
| Hosting     | AWS EC2 t3.micro + Nginx + Cloudflare           |

Alasan pilih Hono: ringan, TypeScript-first, dan ada adapter bawaan untuk Bun. API-nya familiar kalau sudah pernah pakai Express atau Fastify.

Untuk database, aku pakai [Neon](https://neon.tech) karena mereka punya free tier yang nyaman untuk side project, dan koneksi-nya bisa pakai driver `postgres` biasa dengan SSL mode `prefer`, tadinya aku mau pakai RDS, tapi karena udah keburu pake neon dan aku malas migrasi, yaudah aku pake neon aja hehe.

Frontend sengaja aku buat seminimal mungkin: vanilla HTML dan Alpine.js. Nggak ada build step, nggak ada bundler, nggak ada React. Kalau mau ubah file, langsung edit HTML-nya. Sesederhana itu.

---

## Gotcha #1: `hono/jwt` Tidak Bekerja di Bun

Ini yang paling bikin aku pusing di awal.

Aku awalnya pakai `hono/jwt` yang memang disediakan Hono untuk JWT handling. Kodenya rapi, satu baris verifikasi token. Tapi begitu di-test, hasilnya selalu gagal. Nggak ada error yang jelas, token-nya dianggap invalid padahal sudah benar.

Setelah investigasi, ternyata `hono/jwt` secara internal bergantung pada implementasi crypto yang belum fully compatible sama Bun. Silently fails — dan ini tipe bug yang paling susah di-debug karena tidak ada error message yang informatif.

Solusinya: implementasi JWT manual pakai `crypto.subtle` dari Web Crypto API. Ini API standar yang sudah ada di browser dan sekarang di Bun juga.

Ini implementasi sign-nya:

```typescript
async function jwtSign(payload: object): Promise<string> {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const body = btoa(JSON.stringify(payload))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const data = `${header}.${body}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return `${data}.${b64urlEncode(sig)}`;
}
```

Dan satu hal lagi yang aku temukan: `hono/cookie` untuk baca cookie juga bermasalah. Akhirnya aku parse cookie header secara manual dengan regex:

```typescript
function parseCookieHeader(header: string | undefined, name: string): string | null {
  if (!header) return null;
  const match = header.match(new RegExp(`(?:^|;\\s*)${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}
```

Kelihatannya low-level, tapi justru ini yang reliable.

---

## Gotcha #2: Alpine.js Reactivity Tidak Otomatis untuk Nested Object

Ini gotcha kedua yang cukup makan waktu.

Alpine.js bekerja dengan reactive data, tapi ada satu aturan yang perlu diingat: **jangan pernah mutasi property dari array item secara langsung**. Alpine tidak akan mendeteksi perubahannya.

Contoh kasus: aku ingin update status completion sebuah item checklist setelah API response.

```js
// SALAH — Alpine tidak akan re-render
this.items[idx].completion = data;
this.items[idx].pics.push(pic);

// BENAR — ganti seluruh object-nya
this.items[idx] = { ...this.items[idx], completion: data };
this.items[idx] = { ...this.items[idx], pics: [...this.items[idx].pics, pic] };
```

Waktu pertama kali ketemu bug ini, aku bingung karena data-nya sudah berubah di console, tapi tampilan tidak update. Setelah baca lebih dalam, ternyata Alpine hanya track reactive array itu sendiri, bukan properti nested dari item-nya. Jadi solusinya: selalu replace item object-nya, bukan mutasi propertinya.

---

## Arsitektur WebSocket: Rooms per Project

Untuk fitur realtime, aku pakai WebSocket dengan konsep "room" — setiap project punya room sendiri berdasarkan slug-nya.

```typescript
// ws.ts
export const rooms = new Map<string, Set<ServerWebSocket<unknown>>>();

export function broadcastToRoom(slug: string, message: object) {
  const clients = rooms.get(slug);
  if (!clients || clients.size === 0) return;
  const payload = JSON.stringify(message);
  for (const ws of clients) {
    try {
      ws.send(payload);
    } catch {
      clients.delete(ws);
    }
  }
}
```

Sederhana tapi cukup. Ketika client buka project `/projects/morning-standup`, mereka connect ke `/ws/morning-standup`. Semua event yang terjadi di project itu (item dibuat, dicentang, diurutkan ulang) langsung di-broadcast ke semua client yang ada di room yang sama.

Event yang di-support:
- `item.created`, `item.updated`, `item.deleted`
- `item.reordered`
- `item.completed`, `item.uncompleted`
- `item.pic_added`, `item.pic_removed`
- `project.updated`, `project.deleted`
- `comment.added`, `comment.deleted`

Client-side punya heartbeat ping setiap 25 detik dan auto-reconnect setelah 3 detik kalau koneksi terputus. Cukup robust untuk use case side project.

---

## Skema Database

Aku sengaja buat schema yang bersih dan normalized sejak awal. Ini struktur tabelnya:

```sql
users           -- id, username, password_hash
projects        -- id, owner_id, name, slug, visibility
checklist_items -- id, project_id, title, description, display_order, item_type
item_pics       -- id, item_id, name, assigned_by  (PIC = Person in Charge)
item_completions -- id, item_id, done_by_name, notes, completed_at
item_comments   -- id, item_id, author_id, author_name, body
logs            -- id, project_id, item_id, actor_name, action, payload, ...
```

Beberapa keputusan desain yang menarik:

**`item_completions` itu separate table, bukan kolom boolean.** Ini karena completion menyimpan konteks: siapa yang complete, kapan, dan ada notes-nya. Plus bisa di-undo dengan `DELETE` tanpa butuh state management yang rumit.

**`display_order` itu integer biasa.** Aku bisa reorder item dengan UPDATE bulk dalam satu transaction. Tidak perlu linked list atau gap sequence yang complex.

**`item_type` untuk sections dan tasks.** Checklist bisa punya section header (seperti "Phase 1", "Phase 2") dan task biasa. Ini membuat import dari Markdown jadi natural karena `## Heading` jadi section dan `- [ ] Task` jadi task.

Ada satu SQL gotcha yang aku temukan juga: `FILTER (WHERE ...)` hanya bekerja dengan aggregate functions. Untuk conditional value biasa, harus pakai `CASE WHEN`:

```sql
-- SALAH
jsonb_build_object(...) FILTER (WHERE ic.id IS NOT NULL)

-- BENAR
CASE WHEN ic.id IS NOT NULL THEN jsonb_build_object(...) END
```

---

## Fitur Import: Lempar Markdown, Dapat Checklist

Ini fitur yang paling sering aku pakai sendiri dan cukup proud sama hasilnya.

Idenya sederhana: daripada user harus input task satu per satu lewat form, kenapa nggak bisa langsung import dari file? Dan karena formatnya Markdown, siapa pun bisa minta AI untuk generate-nya dulu, terus paste hasilnya ke sini.

Contoh workflow-nya: kamu cerita ke AI, "buatin checklist persiapan deploy backend ke production", AI generate Markdown-nya, kamu copy-paste ke field import, selesai. Dalam hitungan detik, semua task langsung masuk ke checklist dengan struktur section yang rapi.

Format Markdown yang didukung:

```markdown
## Pre-deployment
Persiapan sebelum deploy

- [ ] Review semua environment variable
  Pastikan .env.production sudah lengkap
- [ ] Run migration di staging dulu
- [ ] Cek endpoint /health

## Deployment
- [ ] Push ke branch main
- [ ] Monitor log 5 menit pertama
```

`## Heading` jadi section, `- [ ] Title` jadi task. Kalau baris berikutnya indented, itu jadi deskripsi task. Parser ini aku tulis dari scratch — detect format otomatis dari content sniffing, jadi user nggak perlu pilih "ini Markdown" atau "ini CSV".

Selain Markdown, ada juga format CSV untuk yang mau struktur lebih rigid:

```
type,title,description
section,Pre-deployment,Persiapan sebelum deploy
task,Review environment variable,Pastikan .env.production sudah lengkap
task,Run migration di staging dulu,
```

Setelah import, semua item langsung di-broadcast via WebSocket ke semua user yang lagi buka project yang sama. Jadi kalau ada tim yang sedang stand-by di halaman project, mereka langsung lihat checklist baru muncul tanpa reload.

---

## Project Chat dan Comment per Item

Checklist tanpa komunikasi itu setengah-setengah. Makanya ada dua level diskusi di app ini.

**Project chat** ada di level project — tempat diskusi umum seputar project itu. Cocok untuk koordinasi atau update yang nggak spesifik ke satu task tertentu.

**Comment per item** ada di level checklist item. Kalau ada yang mau tanya soal task tertentu, atau mau kasih context kenapa task itu di-mark complete dengan catatan tertentu, bisa langsung comment di item-nya.

Keduanya realtime, jadi semua member yang lagi buka project akan dapat update-nya seketika lewat WebSocket event `comment.added` dan `comment.deleted`.

Satu detail menarik di fitur comment: ada time-limited delete. User hanya bisa hapus komentar mereka sendiri, dan hanya dalam 5 menit setelah posting. Lebih dari itu, komentar terkunci. Ini sengaja aku desain supaya riwayat diskusi tetap terjaga dan nggak bisa dihapus seenaknya setelah project sudah berjalan.

```typescript
const ageMs = Date.now() - new Date(comment.created_at).getTime();
if (ageMs > 5 * 60 * 1000) {
  return c.json({ error: "comments can only be deleted within 5 minutes of posting" }, 403);
}
```

---

## Audit Log: Siapa Ngapain Kapan

Ini fitur yang menurutku underrated tapi penting banget untuk collaborative tool.

Setiap action yang terjadi di project — item dibuat, dicentang, diedit, PIC ditambah, project di-rename — semuanya dicatat di tabel `logs`. Isinya: siapa yang melakukan (registered user atau guest), action apa, timestamp, IP, user agent, dan payload perubahan (nilai lama dan nilai baru).

```sql
logs (
  project_id, item_id,
  actor_name,   -- nama user atau guest
  action,       -- contoh: "item.completed", "item.updated"
  payload,      -- JSONB, isi perubahan
  ip, user_agent,
  log_level,    -- 'public' atau 'admin'
  created_at
)
```

Ini solve masalah yang sering terjadi di checklist kolaboratif: nggak ada yang tahu siapa yang terakhir ubah sesuatu, atau kapan sebuah task di-mark done. Dengan audit log, semua itu tercatat.

Log di-query dengan cursor pagination supaya performa tetap baik meski log sudah ribuan baris:

```typescript
// GET /api/projects/:slug/logs?cursor=<timestamp>&limit=20
const rows = await sql`
  SELECT * FROM logs
  WHERE project_id = ${project.id}
    AND created_at < ${cursor}
  ORDER BY created_at DESC
  LIMIT ${limit}
`;
```

Untuk guest user, nama mereka tetap tercatat di `actor_name` dari request body. Jadi meski nggak punya akun, jejak aktivitasnya masih kelihatan di log.

---

## Guest User: Tanpa Register pun Bisa

Salah satu decision product yang aku buat: project dengan visibility `public` bisa diakses dan diedit tanpa login. User cukup ketik nama mereka yang akan disimpan di `localStorage` sebagai `guestName`.

Ini memudahkan use case seperti event atau meeting: owner bikin project, share link-nya, semua orang bisa langsung participate tanpa harus create account.

Di server, setiap request yang modify data bisa kirim `actor_name` di request body. Kalau user sudah login, nama mereka yang dipakai. Kalau guest, `actor_name` dari body dipakai, dan dicatat di audit log.

```typescript
function resolveActor(
  user: { username: string } | null,
  body: { actor_name?: string }
): string {
  return user?.username ?? body.actor_name?.trim() ?? "anonymous";
}
```

---

## Deployment: AWS EC2 + Nginx + Cloudflare

Setup hosting-nya aku buat di AWS EC2 t3.micro (free tier), diproteksi Cloudflare, dengan Nginx sebagai reverse proxy. Ini flow-nya secara umum:

```
User request ke checky.suryatmaja.dev
    ↓
Cloudflare (DNS + SSL/TLS termination)
    ↓
Nginx (port 443, SSL dengan Cloudflare Origin Certificate)
    ↓
Bun app (localhost:3000)
```

### First-time Setup

Untuk inisiasi server baru dari awal, tinggal jalankan satu skrip:

```bash
# SSH ke EC2 dulu
ssh -i your-key.pem ubuntu@<EC2_IP>

# Clone repo
git clone https://github.com/srytmj/group-checklist.git
cd group-checklist

# Jalankan setup wizard
bash init.sh
```

Skrip `init.sh` akan handle semua ini secara interaktif:

1. Install system packages (nginx, curl, git)
2. Install Bun
3. `bun install --frozen-lockfile`
4. Setup `.env` — minta `DATABASE_URL` dan generate `JWT_SECRET` otomatis
5. Run database migrations (`bun scripts/migrate.ts`)
6. Panduan setup Cloudflare DNS dan Origin Certificate
7. Configure Nginx dari template (`nginx/group-checklist.conf`)
8. Install dan enable systemd service

Untuk bagian Cloudflare, skrip akan kasih instruksi manual yang perlu dilakukan di dashboard Cloudflare:

- Buat A record pointing ke IP EC2, proxy aktif (orange cloud)
- Set SSL/TLS mode ke **Full (strict)**
- Buat Origin Certificate, lalu taruh di `/etc/ssl/cloudflare/cert.pem` dan `key.pem`

Begitu cert terpasang, Nginx dikonfigurasi untuk listen di port 443 dengan cert tersebut. Koneksi antara Cloudflare dan EC2 terenkripsi end-to-end, dan IP EC2 tidak pernah exposed ke publik.

### Update Setelah Deploy

Kalau ada perubahan kode:

```bash
# Dari dalam EC2
bash update.sh
```

Atau kalau perlu re-apply konfigurasi Nginx atau systemd service:

```bash
bash scripts/deploy.sh --nginx    # re-apply Nginx config
bash scripts/deploy.sh --service  # re-install systemd service
```

`update.sh` melakukan git pull, install dependencies, dan restart service. Simple.

---

## Lessons Learned

Beberapa hal yang aku catat dari project ini:

**Bun itu promising tapi perlu hati-hati dengan library compatibility.** Kalau ada behavior yang aneh, cek dulu apakah library yang dipakai sudah fully supported di Bun. `hono/jwt` dan `hono/cookie` adalah contoh yang aku temukan.

**Alpine.js cocok untuk app yang tidak butuh complex state management.** Kalau state-nya flatten dan konsisten dalam cara mutasinya (selalu replace, jangan mutate), Alpine sangat nyaman dipakai tanpa build step.

**Separation of concerns di WebSocket itu penting.** Menjaga `rooms` dan `broadcastToRoom` di file terpisah (`ws.ts`) bikin code jauh lebih clean. Route handlers tinggal call `broadcastToRoom(slug, payload)` tanpa perlu tau implementasi detailnya.

**Schema database yang bersih menghemat banyak waktu refactor.** `item_completions` sebagai separate table terasa over-engineering di awal, tapi ketika aku tambah fitur notes dan undo, tidak perlu ubah schema sama sekali.

---

## Takeaway

Project ini awalnya cuma pengen solve masalah kecil: checklist yang bisa dilihat bareng secara realtime. Tapi proses membangunnya ngajarin banyak hal, mulai dari gotcha runtime-level sampai keputusan schema yang impactful di jangka panjang.

Kalau kamu penasaran lihat hasilnya, bisa langsung buka [checky.suryatmaja.dev](https://checky.suryatmaja.dev). Source code-nya public di [github.com/srytmj/group-checklist](https://github.com/srytmj/group-checklist).

Dan kalau kamu lagi build sesuatu dengan Bun dan Hono, semoga catatan gotcha di atas bisa menghemat beberapa jam debugging. wkwkw.
