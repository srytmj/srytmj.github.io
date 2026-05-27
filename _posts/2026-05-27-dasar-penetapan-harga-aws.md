---
title: "Gimana Cara AWS Ngitung Biaya? Ini Dasar-dasar Harganya"
description: "Biar nggak kaget pas lihat tagihan, pahami dulu gimana AWS menetapkan harga: dari model pembayaran, diskon, sampai layanan yang beneran gratis."
author: srytmj
date: 2026-05-27 20:00:00 +0700
categories: [Cloud Computing, AWS]
tags: [cloud, aws, pricing, free-tier, reserved-instance]
pin: false
math: false
mermaid: false
---

Salah satu hal yang bikin orang ragu pakai AWS di awal itu biasanya soal biaya. "Nanti tagihannya berapa? Tiba-tiba mahal gimana?" Wajar banget sih, apalagi kalau baru pertama kali coba.

Makanya penting buat ngerti dulu gimana AWS ngitung biaya sebelum mulai pakai. Biar nggak kaget.

---

## Tiga Dasar Penetapan Harga

AWS punya tiga komponen utama yang jadi dasar perhitungan biaya:

**Komputasi** dikenakan biaya per jam atau per detik, tergantung tipe instansnya. Khusus untuk Linux, hitungannya bisa per detik, jadi lebih presisi.

**Penyimpanan** dikenakan biaya per GB. Semakin besar storage yang dipakai, semakin besar tagihannya, tapi ada opsi diskon berbasis volume yang bakal kita bahas nanti.

**Transfer Data** punya aturan yang menarik: transfer data *masuk* ke AWS itu **gratis**. Yang berbayar adalah transfer data *keluar* (misalnya pengguna download file dari aplikasi kamu). Ini penting buat dipahami biar estimasi biayanya akurat.

> **Analogi:** mirip kayak langganan internet di on-premise, tapi bedanya di AWS nggak ada biaya internet tetap. Kamu baru kena tagihan transfer data kalau ada yang download dari project yang kamu deploy.
{: .prompt-info }

---

## Tiga Opsi Pembayaran di AWS

AWS ngasih fleksibilitas dalam cara bayar. Ada tiga opsi utama yang bisa disesuaikan sama kebutuhan dan kondisi kamu.

### 1. Bayar Sesuai Penggunaan

Ini opsi paling fleksibel. Kamu bayar hanya sesuai layanan yang aktif dipakai, tanpa kontrak dan tanpa biaya di muka.

Biayanya bisa naik-turun tiap bulan tergantung pemakaian. Bulan ini ringan, bulan depan butuh spek lebih tinggi, biaya ikut naik. Sepi lagi, biaya turun lagi.

Cocok banget buat yang baru mau coba-coba atau proyek yang belum bisa prediksi beban kerjanya.

### 2. Bayar Lebih Murah dengan Pemesanan

Kalau kamu udah yakin bakal butuh resource tertentu untuk jangka panjang (misalnya satu tahun), lebih worth it pesan di awal. Diskonnya bisa sampai **75%** dibanding bayar sesuai penggunaan.

Ada tiga jenis pemesanan instans cadangan (*Reserved Instances*):

| Tipe | Cara Bayar | Diskon |
| :--- | :--------- | :----- |
| **AURI** (All Upfront Reserved Instance) | Bayar penuh di muka | Paling besar |
| **PURI** (Partial Upfront Reserved Instance) | DP sebagian, sisanya bulanan | Menengah |
| **NURI** (No Upfront Reserved Instance) | Tanpa DP, bayar bulanan | Paling kecil |

> **Saran:** kalau perusahaan udah punya rencana pasti pakai AWS untuk jangka panjang, ambil AURI. Diskonnya paling gede. Dan kalau pemakaian ternyata melebihi kapasitas yang dipesan, tinggal bayar kelebihannya aja.
{: .prompt-tip }

### 3. Bayar Lebih Sedikit untuk Penggunaan yang Lebih Banyak

AWS ngasih diskon berbasis volume. Semakin banyak yang kamu pakai, harga per unitnya bisa semakin murah.

Ini paling sering dimanfaatkan di layanan storage seperti Amazon S3, EBS, dan EFS. Contoh konkretnya: kalau kamu cuma butuh simpan data arsip yang jarang diakses, pakai **S3 Glacier**. Harganya jauh lebih murah dari S3 biasa, dengan trade-off akses datanya lebih lambat.

---

## AWS Terus Nurunin Harga

Ini yang bikin AWS menarik jangka panjang. Sejak pertama rilis di 2006 sampai September 2019 aja, AWS udah nurunin harga sebanyak **75 kali**. Bukan naik, tapi turun.

Skala ekonomi yang besar bikin mereka bisa terus efisiensi dan ngerutin harga ke pelanggan. Ke depannya, resource dengan performa lebih tinggi juga bakal tersedia tanpa tambahan biaya.

AWS juga buka pintu untuk **negosiasi harga khusus** buat perusahaan dengan volume penggunaan yang tinggi. Jadi kalau proyekmu cukup besar, bisa langsung diskusi sama tim AWS soal harga yang lebih sesuai.

---

## Free Tier: Gratis Tapi Ada Batasnya

Buat akun baru, AWS nyediain **Free Tier selama 12 bulan**. Tapi jangan salah paham dulu soal "gratis" ini.

Kuotanya terbatas (sekitar $100 ekuivalen), dan kalau habis, tagihan tetap jalan dan ditarik dari metode pembayaran yang terdaftar.

> **Perhatian:** setelah nyalain instans buat coba-coba, **selalu matikan atau hapus** instansnya kalau sudah nggak dipakai. Instans yang jalan terus, meski nggak kamu akses, tetap dihitung biayanya.
{: .prompt-danger }

Di luar Free Tier yang berbatas waktu, ada juga beberapa layanan yang **beneran gratis** dari AWS:

- **Amazon VPC** — gratis
- **AWS Elastic Beanstalk** — layanannya gratis, tapi resource yang dipakai (EC2, dll) tetap berbayar
- **Auto Scaling** — gratis, tapi EC2 yang di-scale tetap dihitung
- **AWS CloudFormation** — gratis, tapi traffic resource-nya tetap dihitung
- **AWS IAM** — gratis sepenuhnya

---

## Rangkuman

- **3 dasar biaya AWS:** komputasi (per jam/detik), penyimpanan (per GB), transfer data keluar (per GB). Transfer data masuk gratis.
- **3 opsi bayar:** sesuai penggunaan (fleksibel), pemesanan di muka (hemat sampai 75%), dan diskon volume (makin banyak pakai, makin murah per unit)
- AWS konsisten nurunin harga dari waktu ke waktu, jadi nggak perlu takut biaya tiba-tiba melonjak
- Free Tier ada batasnya. Selalu matikan resource yang nggak dipakai biar nggak kena tagihan tak terduga

---
