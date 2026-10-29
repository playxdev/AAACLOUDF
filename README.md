# AAA — Axis Auto Access (Cloud API)

Backend ตรวจสิทธิ์เข้า-ออกหมู่บ้าน/โครงการ รันบน Cloudflare Workers + D1
อุปกรณ์หน้างานของ SEMA (ANPR / RFID / QR / Keypad) เรียก API นี้เพื่อถามว่า "เข้าได้ไหม และเข้าด้วยวิธีไหนได้บ้าง"

```
SEMA Microcontroller --(4G/5G)--> SEMA Docker (Java) --HTTPS--> AAA API (Workers) --> D1
```

SEMA (Docker, Microcontroller, ไม้กั้น, Offline Mode) เป็น Blackbox สำหรับ repo นี้
ภาพรวมทั้งระบบดู [`SYSTEM/aaa-system-architecture.md`](SYSTEM/aaa-system-architecture.md)

## Tech Stack

| ส่วน | ใช้อะไร |
|---|---|
| Runtime | Cloudflare Workers, TypeScript (strict) |
| Database | Cloudflare D1 (`db1-aaa`) |
| Auth อุปกรณ์ | Device secret (SHA-256) → JWT HS256 อายุ 15 นาที |
| Auth Admin | รหัสผ่าน PBKDF2-SHA256 (100,000 รอบ) → JWT HS256 อายุ 1 ชั่วโมง |
| Credential | RFID / QR / PIN เก็บเป็น HMAC-SHA256 เท่านั้น |
| Test | Vitest + `@cloudflare/vitest-plugin` (รันใน workerd + D1 local) |

ไม่มี runtime dependency ภายนอก

## โครงสร้าง

```
src/index.ts                 routing, device token, authorize endpoint, audit log
src/authorize.ts             ตัดสินสิทธิ์ (ANPR / credential / policy)
src/admin.ts                 Admin API: login, บ้าน, ลูกบ้าน, รถ, บัตร/PIN
src/crypto.ts                SHA-256, HMAC, JWT, PBKDF2 (WebCrypto)
src/http.ts                  helper ของ request / response
scripts/hash-password.mjs    สร้าง hash รหัสผ่าน admin
migrations/0001_init.sql     D1 schema ทั้งหมด (v1.1.0)
seeds/default_policy.sql     policy ตั้งต้นของทุกโครงการ
test/                        integration tests
SYSTEM/                      เอกสาร architecture + ภาพ flow
```

## Setup

```sh
npm install
npx wrangler login
npx wrangler d1 info db1-aaa          # copy database_id ไปใส่ wrangler.jsonc
npx wrangler secret put JWT_SECRET    # key เซ็น device JWT
npx wrangler secret put CRED_PEPPER   # key HMAC ของ RFID / QR / PIN (ห้ามเปลี่ยนหลังลงทะเบียน credential แล้ว)
npx wrangler d1 migrations apply db1-aaa --remote
npm run deploy
```

Schema ทั้งหมดอยู่ไฟล์เดียว: `migrations/0001_init.sql` (v1.1.0) แก้ schema ครั้งต่อไปให้สร้างไฟล์
migration ใหม่ (`npx wrangler d1 migrations create db1-aaa <name>`) ห้ามแก้ 0001 หลัง apply ขึ้น remote แล้ว

ถ้า `db1-aaa` เคยรัน `schema.sql` v1.0.0 เดิมด้วย `d1 execute` ไปแล้ว `migrations apply` จะ error
เพราะตารางมีอยู่แล้ว ต้อง export ข้อมูลเก็บไว้ ลบตารางเดิม แล้วค่อย apply ใหม่ (ทำครั้งเดียว ข้อมูลเดิมหายถ้าไม่ได้ export):

```sh
npx wrangler d1 export db1-aaa --remote --output backup-v1.0.sql
npx wrangler d1 execute db1-aaa --remote --command "SELECT name FROM sqlite_master WHERE type='table'"
```

### สร้าง Admin คนแรก

Admin แต่ละคนผูกกับ 1 โครงการ (`tb_admin.project_id`) และเห็นเฉพาะข้อมูลของโครงการนั้น

```sh
node scripts/hash-password.mjs        # พิมพ์รหัสผ่าน (อย่างน้อย 12 ตัวอักษร) ได้ hash pbkdf2_sha256$...
npx wrangler d1 execute db1-aaa --remote --command \
  "INSERT INTO tb_admin (admin_id, project_id, admin_name, admin_password) VALUES ('ADM-001', '<project_id>', '<admin_name>', '<hash>')"
```

## Dev / Test

```sh
npm run dev     # local, ใช้ secrets จาก .dev.vars
npm test
```

## API

### `POST /api/v1/auth/device/token`

```json
{ "device_id": "D1", "device_secret": "..." }
```
→ `{ "access_token": "<JWT>", "token_type": "Bearer", "expires_in": 900 }`

### `POST /api/v1/access/authorize`

Header `Authorization: Bearer <JWT>`

```json
{ "event_id": "evt-unique-id", "method": "ANPR", "value": "กก9999" }
```
→ `{ "event_id": "...", "decision": "YES|NO|ERROR", "reason_code": "...", "allowed_methods": ["RFID"], "policy_version": 1 }`

- `method`: `ANPR` / `RFID` / `QRCODE` / `PIN`
- `event_id` ซ้ำ → ได้คำตอบเดิม ไม่ตัดสินซ้ำ
- `ERROR` ตอบ HTTP 500 และห้ามตีความเป็น `YES`

`reason_code`: `RESIDENT_ACTIVE`, `RESIDENT_OVERDUE_ALLOWED`, `VISITOR_VALID`, `RESIDENT_OVERDUE`, `RESIDENT_OVERDUE_SEVERE`,
`METHOD_NOT_ALLOWED`, `BLACKLISTED`, `UNKNOWN_PLATE`, `UNKNOWN_CREDENTIAL`, `CREDENTIAL_REVOKED`,
`CREDENTIAL_NOT_YET_VALID`, `CREDENTIAL_EXPIRED`, `CREDENTIAL_USED_UP`, `USER_INACTIVE`, `VISITOR_NOT_VALID`,
`INTERNAL_ERROR`, `LOG_FAILED`

## Admin API

ทุก endpoint (ยกเว้น login) ต้องส่ง Header `Authorization: Bearer <admin JWT>`
`project_id` มาจาก token เสมอ admin โครงการอื่นจะได้ `404` เหมือนไม่มีข้อมูล

| Method | Endpoint | Body / หมายเหตุ |
|---|---|---|
| `POST` | `/api/v1/admin/login` | `{ admin_name, password }` → `{ access_token, expires_in: 3600 }` |
| `GET` | `/api/v1/admin/houses` | รายการบ้าน |
| `POST` | `/api/v1/admin/houses` | `{ house_number, zone_or_soi? }` |
| `PATCH` | `/api/v1/admin/houses/:id` | `{ house_number?, zone_or_soi?, payment_status?, is_active? }` |
| `GET` | `/api/v1/admin/residents` | `?house_id=` กรองตามบ้านได้ |
| `POST` | `/api/v1/admin/residents` | `{ house_id, full_name, phone_number?, line_id? }` |
| `GET` | `/api/v1/admin/residents/:id` | ลูกบ้าน + รถ + credential (ไม่มี hash / ค่าจริง) |
| `PATCH` | `/api/v1/admin/residents/:id` | `{ house_id?, full_name?, phone_number?, line_id?, is_active? }` |
| `DELETE` | `/api/v1/admin/residents/:id` | ปิดใช้งาน (soft delete) เข้าไม่ได้ทุกวิธี |
| `POST` | `/api/v1/admin/residents/:id/vehicles` | `{ license_plate, province?, brand?, color? }` ทะเบียนซ้ำในโครงการ → `409` |
| `DELETE` | `/api/v1/admin/vehicles/:id` | ปิดใช้งานรถ |
| `POST` | `/api/v1/admin/residents/:id/credentials` | `{ cred_type: RFID\|QRCODE\|PIN, value, valid_from?, valid_until? }` PIN = ตัวเลข 4–8 หลัก, ซ้ำ → `409` |
| `DELETE` | `/api/v1/admin/credentials/:id` | เพิกถอน (`REVOKED`) |

- `payment_status`: `NORMAL` / `OVERDUE` / `OVERDUE_SEVERE`
- Error: `{ "error": "BAD_REQUEST", "field": "<ชื่อ field>" }`, `NOT_FOUND`, `PLATE_EXISTS`, `CREDENTIAL_EXISTS`, `UNAUTHORIZED`
- ค่าของ RFID / QR / PIN ถูก hash ทันที อ่านค่าจริงกลับจาก API ไม่ได้

## กติกาข้อมูล

- `tb_policy`: ไม่มีแถว = ไม่อนุญาต หลังเพิ่มโครงการใหม่ต้องรัน `seeds/default_policy.sql`
  (`npx wrangler d1 execute db1-aaa --remote --file=./seeds/default_policy.sql`) รันซ้ำได้
  - ลูกบ้านปกติ: ANPR / RFID / QRCODE / PIN
  - ลูกบ้านค้างชำระ (`tb_house.payment_status = 'OVERDUE'`): RFID / PIN เท่านั้น ไม่ได้ห้ามเข้า แต่ไม่ได้ใช้ ANPR
  - ลูกบ้านค้างชำระต่อเนื่อง (`'OVERDUE_SEVERE'`): PIN เท่านั้น (ต้องกด Keypad)
  - การเลื่อนระดับ NORMAL → OVERDUE → OVERDUE_SEVERE ตอนนี้ admin / ระบบบิลเป็นคนแก้ `payment_status` เอง
  - Visitor: QRCODE (ANPR ของ Visitor ต้องเพิ่มแถวเองรายโครงการ)
- ทะเบียนรถใน `tb_vehicle` / `tb_visitor` / `tb_blacklist` ต้องเก็บแบบไม่มีช่องว่างและ `-` (เช่น `กก9999`)
- `tb_device.device_secret_hash` = SHA-256 hex ของ device secret
- `tb_credential.cred_hash` = HMAC-SHA256(`CRED_PEPPER`, `project_id:cred_type:value`) ดู `credentialHash()` ใน `src/authorize.ts`
- เวลาใน `valid_from` / `valid_until` เป็น UTC
