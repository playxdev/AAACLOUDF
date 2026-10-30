# AAACLOUDF — Axis Auto Access: เอกสารและ Tech Stack

ระบบควบคุมการเข้า-ออกหมู่บ้าน/โครงการ บน Cloudflare (Workers + D1 + Pages)
อุปกรณ์หน้างานของ SEMA (ANPR / RFID / QR / Keypad) เรียก AAA API เพื่อถามว่า "เข้าได้ไหม และเข้าด้วยวิธีไหนได้บ้าง"
repo นี้เก็บเฉพาะเอกสารและ tech stack โค้ดอยู่ใน repo อื่นตามตารางด้านล่าง

```
SEMA Microcontroller --(4G/5G)--> SEMA Docker (Java) --HTTPS--> AAA API (Workers) --> D1
Admin WebApp (Cloudflare Pages) ----------------------HTTPS--> /api/v1/admin/*
LINE LIFF (ลูกบ้าน / เจ้าของบ้าน) ----------------------HTTPS--> /api/v1/owner/*
```

SEMA (Docker, Microcontroller, ไม้กั้น, Offline Mode) เป็น Blackbox สำหรับระบบ AAA
ภาพรวมทั้งระบบดู [`SYSTEM/aaa-system-architecture.md`](SYSTEM/aaa-system-architecture.md)

## Repositories

ทุก repo อยู่ใน folder `aaa/v1/` ข้างกัน

| Folder | หน้าที่ | Stack |
|---|---|---|
| **AAACLOUDF** (repo นี้) | เอกสาร architecture, tech stack, ภาพ flow | Markdown |
| [AAAAPI](https://github.com/playxdev/AAAAPI) | Backend API: ตรวจสิทธิ์ (SEMA), Admin API, Owner API | Cloudflare Workers + TypeScript |
| [AAASQL](https://github.com/playxdev/AAASQL) | D1 schema / migrations / seed, R2 (ภาพ), มาตรฐาน DB | Cloudflare D1 (SQLite), R2 |
| [AAAADMIN](https://github.com/playxdev/AAAADMIN) | Admin WebApp | Vite + TypeScript + Tailwind บน Cloudflare Pages |
| AAAAPP | LIFF app สำหรับลูกบ้าน (ยังไม่เริ่ม) | LINE LIFF บน Cloudflare Pages |

## Production

| ส่วน | ค่า |
|---|---|
| API | `https://aaa-api.cookievirus.workers.dev` (Worker `aaa-api`) |
| D1 | `db1-aaa` region APAC |
| บัญชี Cloudflare | Cookievirus (`30ec5dca725dd7acef6a6ef89342e403`) |
| ข้อมูล | โครงการ `PRJ-001` หมู่บ้านทดสอบ, admin `admin` |

## Tech Stack

| ส่วน | ใช้อะไร |
|---|---|
| Runtime | Cloudflare Workers, TypeScript (strict) |
| Database | Cloudflare D1 (`db1-aaa`) |
| Auth อุปกรณ์ | Device secret (SHA-256) → JWT HS256 อายุ 15 นาที |
| Auth Admin | รหัสผ่าน PBKDF2-SHA256 (100,000 รอบ) → JWT HS256 อายุ 1 ชั่วโมง |
| Auth Owner | LINE LIFF ID Token (ตรวจกับ LINE) → JWT HS256 อายุ 1 ชั่วโมง |
| Credential | RFID / QR / PIN / Guest Code เก็บเป็น HMAC-SHA256 เท่านั้น |
| Test | Vitest + `@cloudflare/vitest-plugin` (รันใน workerd + D1 local) |
| Admin WebApp / LIFF | Cloudflare Pages |
| ภาพ ANPR / ไม้กั้น | Cloudflare R2 (ยังไม่ได้ทำ) |

API ไม่มี runtime dependency ภายนอก (เรียก LINE แค่ตอนตรวจ ID Token ที่ `/owner/login` และ `/owner/link`)
