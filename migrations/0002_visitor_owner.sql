-- ==========================================================
-- AAA Migration 0002 : Visitor / Guest Code / Owner (LINE LIFF) / Audit Log
-- ==========================================================

/* 1. tb_visitor: house_id เป็น NULL ได้ (ผู้เยี่ยมชมงานส่วนกลาง) + ผู้ออกสิทธิ์
   SQLite แก้ NOT NULL ไม่ได้ ต้องสร้างตารางใหม่แล้วย้ายข้อมูล */

PRAGMA defer_foreign_keys = true;

CREATE TABLE tb_visitor_new (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    visitor_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    -- NULL = ผู้เยี่ยมชมงานส่วนกลาง (Admin ออกให้)
    house_id TEXT,
    full_name TEXT,
    phone_number TEXT,
    license_plate TEXT,
    -- เช่น ส่งของ, แขก, งานส่วนกลาง
    purpose TEXT,
    valid_from DATETIME NOT NULL,
    valid_until DATETIME NOT NULL,
    -- ADMIN / OWNER และ admin_id / user_id ของผู้ออก
    issued_by_type TEXT,
    issued_by_id TEXT,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (house_id) REFERENCES tb_house(house_id)
);

INSERT INTO tb_visitor_new (autoID, visitor_id, project_id, house_id, full_name, phone_number, license_plate,
    valid_from, valid_until, is_active, id_status, create_date, update_date)
SELECT autoID, visitor_id, project_id, house_id, full_name, phone_number, license_plate,
    valid_from, valid_until, is_active, id_status, create_date, update_date
FROM tb_visitor;

DROP TABLE tb_visitor;
ALTER TABLE tb_visitor_new RENAME TO tb_visitor;

CREATE INDEX IX_tb_visitor_project_license ON tb_visitor(project_id, license_plate);
CREATE INDEX IX_tb_visitor_house_id ON tb_visitor(house_id);

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_visitor AFTER UPDATE ON tb_visitor
FOR EACH ROW BEGIN UPDATE tb_visitor SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

PRAGMA defer_foreign_keys = false;

/* 2. tb_house: รหัสบ้านแบบตัวเลข ใช้เป็นส่วนหน้าของ Guest Code (เช่น 9801+1234) */

ALTER TABLE tb_house ADD COLUMN house_code TEXT;
CREATE UNIQUE INDEX UX_tb_house_project_code ON tb_house(project_id, house_code);

/* 3. tb_user: ผูกบัญชี LINE (LIFF) */

-- LINE userId (sub จาก LIFF ID Token) ไม่ใช่ LINE ID ที่ผู้ใช้ตั้งเอง (line_id)
ALTER TABLE tb_user ADD COLUMN line_user_id TEXT;
-- รหัสผูกบัญชีครั้งเดียวที่ Admin ออกให้ เก็บเป็น SHA-256
ALTER TABLE tb_user ADD COLUMN link_code_hash TEXT;
ALTER TABLE tb_user ADD COLUMN link_code_expires DATETIME;
CREATE UNIQUE INDEX UX_tb_user_line_user_id ON tb_user(line_user_id);

/* 4. ตาราง Audit Log ของการกระทำโดย Admin / Owner */

-- 12. ตารางบันทึกการเปลี่ยนแปลงข้อมูล
-- actor_type = ADMIN / OWNER, action = "<METHOD> <route>", detail = JSON (ไม่มีรหัสผ่าน / credential)
CREATE TABLE tb_audit_log (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    actor_type TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    action TEXT NOT NULL,
    target_id TEXT,
    detail TEXT,
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

CREATE INDEX IX_tb_audit_log_project_date ON tb_audit_log(project_id, create_date);

/* 5. ใช้นับการเดารหัสผิดต่ออุปกรณ์ (กันสุ่ม Guest Code / PIN) */

CREATE INDEX IX_tb_access_log_device_date ON tb_access_log(device_id, timestamp);
