---
title: "Setup Domain & Cloudflare Tunnel untuk AWS EC2"
description: "Dari zero ke live production domain: cara pointing suryatmaja.dev ke AWS EC2 t3.micro pakai Cloudflare Tunnel tanpa expose public IP."
author: srytmj
date: 2026-06-20 00:00:00 +0700
categories: [Cloud, AWS]
tags: [cloudflare, aws, ec2, domain, dns, tunnel, laravel]
pin: false
math: false
mermaid: false
published: true
---

Sebelumnya aku pernah beli hosting di Jagoan Hosting yang sekalian sama VPS-nya. Setup itu okaylah, tapi agak limited untuk development needs. Sekarang aku mau coba setup yang lebih scalable pakai AWS.

Baru-baru ini aku beli domain `suryatmaja.dev` — ini portfolio domain aku yang bakal jadi brand untuk all projects. Sekarang aku pengen deploy aplikasi ke AWS EC2 t3.micro (free tier) dan connect-in pakai domain ini.

Awalnya agak confused gimana caranya pointing domain ke EC2, terus aku cari solution yang aman dan ga perlu buka port. Hasilnya, aku pilih Cloudflare Tunnel. Jadi aku dokumentasin sini journey-nya.

## Pertanyaan Penting Sebelum Mulai

Waktu minta bantuan, yang ditanya pertama:

1. Project hosted di mana? (AWS EC2, Railway, Vercel, dsb?)
2. Pake teknologi apa?
3. Hostinger itu cuma domain aja atau ada hosting plan?

Situasi aku:

- Hosted di AWS EC2
- Laravel app
- Hostinger cuma beli domain doang, ga ada hosting

Jawabannya langsung jelas: tinggal pointing domain ke EC2.

## Pilihan: A Record vs Cloudflare Tunnel

Ada dua pilihan setup:

**Option A: A Record Pointing (Cepat)**
- Langsung create A record di DNS pointing ke IP public EC2
- Cepat, tapi IP expose ke internet
- Vulnerable terhadap DDoS attack
- Ga ideal untuk production

**Option B: Cloudflare Tunnel (Recommended)**
- Lebih aman, IP tersembunyi
- Built-in DDoS protection
- SSL/TLS gratis dari Cloudflare
- Performance optimization
- Sedikit lebih complex setup

Kalau ada opsi yang lebih aman dan gratis SSL, kenapa ga? Jadi aku pilih Cloudflare Tunnel.

## Kenapa Cloudflare?

Sebelum lanjut setup, worth untuk understand kenapa Cloudflare itu pilihan bagus:

1. **Security** — IP EC2 ga expose, protected dari DDoS
2. **SSL/TLS Gratis** — Cloudflare auto-provision certificate, auto-renew
3. **Performance** — CDN caching, optimize delivery globally
4. **Flexibility** — Bisa ganti EC2 instance tanpa update DNS
5. **No Port Opening** — Ga perlu buka port di security group
6. **No Static IP** — Tunnel bekerja dari EC2 meski pakai dynamic IP

Basically, Cloudflare ini middleware yang aman dan powerful antara user dan server.

Aku pake AWS free tier (t3.micro, 750 jam per bulan gratis), jadi infrastructure cost minimal. Dengan Cloudflare free tier juga, setup aku 100% gratis kecuali untuk domain `suryatmaja.dev` (sekitar $10–12/tahun).

## Architecture Overview

Setup akhir kurang lebih seperti ini:

```
User Request ke suryatmaja.dev
    ↓
Cloudflare (resolve DNS, handle SSL/TLS, block threats)
    ↓
Cloudflare Tunnel (encrypted tunnel ke EC2)
    ↓
cloudflared daemon (running di t3.micro EC2)
    ↓
Nginx/Laravel (localhost:80 atau :443)
```

Data dari user encrypted dari Cloudflare sampai EC2. IP EC2 ga pernah exposed. Dan karena pake free tier, cost-nya praktis $0 (except domain).

## Apa itu Cloudflare Tunnel?

Cloudflare Tunnel adalah service yang memungkinkan connecting server ke Cloudflare tanpa expose public IP address. Cara kerjanya:

1. Install `cloudflared` daemon di EC2 instance
2. Daemon establish outbound connection ke Cloudflare edge network
3. User requests route through Cloudflare tunnel menuju server
4. Server IP tetap private, tidak pernah expose ke internet

Ini solve beberapa problem sekaligus: no IP exposure, no need to open ports, works behind NAT, dan Cloudflare edge locations route traffic efficiently.

## Cara Kerja Tunnel (Simplified)

```
Traditional Setup:
User -> Internet -> Your EC2 IP (exposed)

Cloudflare Tunnel Setup:
User -> Cloudflare Edge -> Encrypted Tunnel -> Your EC2 (IP hidden)
```

Ketika user akses `suryatmaja.dev`:

1. DNS resolve ke Cloudflare nameserver
2. Cloudflare check tunnel routing config
3. Cloudflare forward request through tunnel
4. `cloudflared` daemon di EC2 forward ke localhost
5. Response kembali melalui tunnel, encrypted
6. User terima response dengan HTTPS

Entire flow: encrypted, IP hidden, protected.

## Apa yang Terjadi di Balik Layar

Waktu user akses `suryatmaja.dev`:

1. Browser query DNS: "Dimana suryatmaja.dev?"
2. DNS resolve ke Cloudflare nameserver
3. Cloudflare check public hostname config: "Ah, `suryatmaja.dev` mau ke `localhost:80` via tunnel `suryatmaja-prod`"
4. User get routed ke Cloudflare edge network terdekat
5. Cloudflare forward request melalui tunnel ke `cloudflared` di t3.micro EC2
6. `cloudflared` forward ke `localhost:80` (Nginx/aplikasi)
7. Response balik through tunnel, encrypted end-to-end
8. User receive response dengan HTTPS, green lock di browser

> IP public EC2 ga pernah exposed di process ini. Perfect untuk security dan cost-efficiency.
{: .prompt-info }

## SSL/TLS Automatic

One more thing yang cool: Cloudflare auto-provision SSL certificate untuk `suryatmaja.dev`. Ga perlu manual setup Let's Encrypt atau generate certificate sendiri. Certificate langsung valid dan auto-renew sebelum expiry.

Di Laravel `.env`:

```ini
APP_URL=https://suryatmaja.dev
ASSET_URL=https://suryatmaja.dev
```
{: file='.env'}

Tambahkan juga middleware untuk force HTTPS kalau ada yang akses HTTP.

## Lessons Learned

1. **Planning matters** — Mikir tentang security, cost, dan maintenance dari awal
2. **Free tools powerful** — Cloudflare free tier lebih dari cukup untuk startup/side project
3. **DNS ga magic** — Understanding DNS fundamental buat troubleshoot jadi easier
4. **Automation penting** — Setup service auto-run saves headache saat server restart

## Takeaway

Dari zero ke live production domain. Setup awal terasa complicated, tapi once understand flow-nya, actually straightforward. Cloudflare + AWS free tier combo itu solid untuk indie projects dan portfolio showcase.

Cost-wise sangat optimal: domain `suryatmaja.dev` cuma ~$10/tahun, Cloudflare free tier (no cost), AWS t3.micro free tier (750 jam/bulan gratis). Overall infrastructure investment minimal, tapi setup-nya professional-grade dan production-ready.

Dulu waktu pakai Jagoan Hosting + VPS, bayar monthly dan agak limited. Sekarang pake AWS + Cloudflare, malah lebih flexible, scalable, dan gratis. Win-win.

---

## Glossary

### VPS (Virtual Private Server)
Server virtual punya kamu sendiri, hosted di data center provider. Kamu dapat access penuh, bisa install apa aja, tapi perlu manage sendiri (updates, security, backups). Berbeda dengan AWS EC2, VPS lebih sederhana tapi kurang scalable.

### AWS EC2 (Elastic Compute Cloud)
Service dari Amazon Web Services untuk rent virtual machines. EC2 instances bisa di-scale up/down sesuai kebutuhan. t3.micro (free tier) ngasih 750 jam gratis per bulan.

### t3.micro
Tipe instance AWS yang paling kecil dan cheapest. Cocok untuk development, testing, atau low-traffic apps. Free tier covers 750 jam per bulan — kalau instance running 24/7, masih gratis selama dalam batas.

### Domain
Nama website yang mudah diingat (e.g., `suryatmaja.dev`). Domain adalah alias untuk IP address. User ketik domain di browser, DNS translate ke IP server actual.

### DNS (Domain Name System)
"Phone book" internet. Ketika user ketik `suryatmaja.dev`, DNS resolve ke IP address server (e.g., `1.2.3.4`). Tanpa DNS, users harus ketik IP address langsung.

### IP Address
Alamat unik untuk server di internet. Format: `123.45.67.89` (IPv4) atau format panjang (IPv6). Kalau expose IP public, bisa jadi target DDoS.

### Nameserver
Server yang manage DNS records untuk domain lo. Nameserver told DNS resolvers "Dimana suryatmaja.dev?". Biasanya provider (Cloudflare, Hostinger, etc) yang manage.

### A Record
DNS record yang map domain ke IPv4 address. Contoh: `suryatmaja.dev` → `1.2.3.4`. Paling basic DNS record.

### HTTPS / SSL / TLS

- **HTTP**: Protokol unencrypted untuk web. Data visible if intercepted.
- **HTTPS**: HTTP + encryption (SSL/TLS). Data encrypted end-to-end.
- **SSL/TLS**: Protocols untuk encrypt data between browser and server. SSL (old), TLS (modern). Browser show green lock kalau HTTPS valid.

### Certificate
Digital proof bahwa domain kamu legitimate. Browser trust certificate issued by Certificate Authorities (CA). Cloudflare auto-provision certificate gratis untuk domain kamu.

### Cloudflare
Service provider yang offer DNS, CDN, security, dan features lainnya. Dipakai untuk manage domain, secure traffic, dan provide Tunnel service.

### Cloudflare Tunnel
Service yang allow connecting server ke Cloudflare tanpa expose public IP. User traffic route through Cloudflare, terus forward ke server via encrypted tunnel. IP server tetap private.

### cloudflared
Daemon (background process) yang running di server, maintain connection ke Cloudflare. Ini yang receive requests from Cloudflare dan forward ke local application.

### Daemon
Background process yang running terus di server, even kalau ga actively use. Seperti Windows service di Windows. `cloudflared` adalah daemon yang maintain tunnel connection.

### CDN (Content Delivery Network)
Network of servers di berbagai lokasi global. Cloudflare adalah CDN. Ketika user request, served dari Cloudflare edge location terdekat — lebih cepat.

### DDoS Attack
Distributed Denial of Service. Attacker send massive requests ke server, overwhelming resources, causing downtime. Expose public IP = vulnerable to DDoS. Cloudflare protect against this.

### Encryption
Convert data ke format yang unreadable tanpa key. HTTPS encrypt data between browser dan server. Even kalau intercepted, attacker ga bisa baca.

### Nginx / Web Server
Software yang serve HTTP requests. Nginx listen di `localhost:80` (HTTP) atau `:443` (HTTPS), forward requests ke application (Laravel, etc).

### Localhost
Refers to the server itself. `localhost:80` means port 80 pada current server. Ketika `cloudflared` forward request, it forward ke `localhost:80` where aplikasi listening.

### Port
Number yang identify specific service on server. Common ports: `80` (HTTP), `443` (HTTPS), `3306` (MySQL), `5432` (PostgreSQL).

### Security Group (AWS)
Firewall rules untuk EC2 instance. Control incoming/outgoing traffic. Dengan Cloudflare Tunnel, ga perlu open port di security group — lebih aman.

### Free Tier
Free limited offer dari service provider. AWS free tier: 750 jam EC2 per month. Cloudflare free tier: DNS hosting, DDoS protection, basic features. Domain biasanya tetap bayar.
