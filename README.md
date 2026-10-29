# AAA API (Cloudflare Workers + D1)

API ตรวจสิทธิ์เข้า-ออกสำหรับ SEMA

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
