-- ==========================================================
-- AAA Default Access Policy
-- ใส่ policy ตั้งต้นให้ทุกโครงการใน tb_project (รันซ้ำได้ แถวที่มีอยู่แล้วไม่ถูกแก้)
--   RESIDENT                : ANPR / RFID / QRCODE / PIN
--   RESIDENT_OVERDUE        : RFID / PIN เท่านั้น (ไม่ได้ห้ามเข้า แต่ไม่ได้ความสะดวกของ ANPR)
--   RESIDENT_OVERDUE_SEVERE : PIN เท่านั้น (ต้องลงมากด Keypad)
--   VISITOR                 : QRCODE (ANPR ของ Visitor ต้องเปิดเองรายโครงการ)
-- รัน: npx wrangler d1 execute db1-aaa --remote --file=./seeds/default_policy.sql
-- ==========================================================

INSERT OR IGNORE INTO tb_policy (project_id, subject_type, method)
SELECT p.project_id, d.column1, d.column2
FROM tb_project p
CROSS JOIN (VALUES
    ('RESIDENT', 'ANPR'),
    ('RESIDENT', 'RFID'),
    ('RESIDENT', 'QRCODE'),
    ('RESIDENT', 'PIN'),
    ('RESIDENT_OVERDUE', 'RFID'),
    ('RESIDENT_OVERDUE', 'PIN'),
    ('RESIDENT_OVERDUE_SEVERE', 'PIN'),
    ('VISITOR', 'QRCODE')
) d;
