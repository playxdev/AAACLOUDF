-- ==========================================================
-- AAA (Axis Auto Access) Database Schema for Cloudflare D1
-- Version : 1.1.0 (Serverless Edge Edition)
-- Standard : PenbunSQL v4.0 Compliant (SQLite Syntax)
-- 1.1.0 : รวม Device Auth + Access Authorization (Credential / Visitor / Policy)
-- ==========================================================

/* 1. CREATE TABLES */

-- 1. ตารางเก็บข้อมูลโครงการ/หมู่บ้าน
CREATE TABLE tb_project (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT UNIQUE NOT NULL,
    project_name TEXT NOT NULL,
    address TEXT,
    contact_number TEXT,
    -- เลข version ของ Policy ต่อโครงการ (เพิ่มทุกครั้งที่แก้ tb_policy)
    policy_version INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. ตารางเก็บข้อมูลบ้านเลขที่
CREATE TABLE tb_house (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    house_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    house_number TEXT NOT NULL,
    zone_or_soi TEXT,
    -- สถานะค้างชำระผูกกับบ้าน: NORMAL / OVERDUE (เหลือ RFID + PIN) / OVERDUE_SEVERE (เหลือ PIN)
    payment_status TEXT DEFAULT 'NORMAL',
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

-- 3. ตารางเก็บข้อมูลลูกบ้าน
CREATE TABLE tb_user (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    house_id TEXT,
    full_name TEXT NOT NULL,
    phone_number TEXT,
    line_id TEXT,
    role TEXT DEFAULT 'RESIDENT',
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (house_id) REFERENCES tb_house(house_id)
);

-- 4. ตารางเก็บข้อมูลผู้ดูแลระบบ (Admin)
CREATE TABLE tb_admin (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    admin_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    admin_name TEXT NOT NULL UNIQUE,
    -- PBKDF2-SHA256: pbkdf2_sha256$<iterations>$<salt hex>$<hash hex> (สร้างด้วย scripts/hash-password.mjs)
    admin_password TEXT NOT NULL,
    admin_level TEXT DEFAULT 'ADMIN',
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

-- 5. ตารางเก็บข้อมูลยานพาหนะ
CREATE TABLE tb_vehicle (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    license_plate TEXT NOT NULL,
    province TEXT,
    brand TEXT,
    color TEXT,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (user_id) REFERENCES tb_user(user_id)
);

-- 6. ตารางเก็บข้อมูลอุปกรณ์หน้าป้อม
CREATE TABLE tb_device (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    gate_name TEXT NOT NULL,
    device_type TEXT,
    ip_address TEXT,
    -- Device credential: เก็บเฉพาะ SHA-256 hex ของ secret ห้ามเก็บ secret จริง
    device_secret_hash TEXT,
    -- ทิศทางของอุปกรณ์: ENTRY / EXIT
    direction TEXT DEFAULT 'ENTRY',
    last_seen DATETIME,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

-- 7. ตารางเก็บบันทึกการเข้า-ออก
-- log_id = event_id จากอุปกรณ์ (ใช้เป็น Idempotency Key)
-- access_type = ENTRY / EXIT, user_type = RESIDENT / RESIDENT_OVERDUE / RESIDENT_OVERDUE_SEVERE / VISITOR / UNKNOWN
CREATE TABLE tb_access_log (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    log_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    device_id TEXT,
    license_plate TEXT,
    access_type TEXT,
    user_type TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    image_url TEXT,
    is_success INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'SUCCESS',
    remark TEXT,
    method TEXT,
    decision TEXT,
    reason_code TEXT,
    allowed_methods TEXT,
    policy_version INTEGER,
    credential_ref TEXT,
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (device_id) REFERENCES tb_device(device_id)
);

-- 8. ตารางบัญชีดำ
CREATE TABLE tb_blacklist (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    blacklist_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    license_plate TEXT,
    reason TEXT,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

-- 9. ตารางผู้เยี่ยมชม
CREATE TABLE tb_visitor (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    visitor_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    house_id TEXT NOT NULL,
    full_name TEXT,
    phone_number TEXT,
    license_plate TEXT,
    valid_from DATETIME NOT NULL,
    valid_until DATETIME NOT NULL,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (house_id) REFERENCES tb_house(house_id)
);

-- 10. ตาราง Credential (RFID / QRCODE / PIN) ของลูกบ้านหรือผู้เยี่ยมชม
-- cred_hash = HMAC-SHA256(CRED_PEPPER, project_id:cred_type:value) ห้ามเก็บค่าจริง
-- เจ้าของต้องมีอย่างใดอย่างหนึ่ง: user_id หรือ visitor_id
CREATE TABLE tb_credential (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    credential_id TEXT UNIQUE NOT NULL,
    project_id TEXT NOT NULL,
    user_id TEXT,
    visitor_id TEXT,
    cred_type TEXT NOT NULL,
    cred_hash TEXT NOT NULL,
    valid_from DATETIME,
    valid_until DATETIME,
    max_uses INTEGER,
    use_count INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    id_status TEXT DEFAULT 'ACTIVE',
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (project_id, cred_type, cred_hash),
    CHECK ((user_id IS NULL) <> (visitor_id IS NULL)),
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id),
    FOREIGN KEY (user_id) REFERENCES tb_user(user_id),
    FOREIGN KEY (visitor_id) REFERENCES tb_visitor(visitor_id)
);

-- 11. ตาราง Policy: กลุ่มใดเข้าด้วยวิธีใดได้ ไม่มีแถว = ไม่อนุญาต
-- subject_type = RESIDENT / RESIDENT_OVERDUE / RESIDENT_OVERDUE_SEVERE / VISITOR
-- method = ANPR / RFID / QRCODE / PIN
CREATE TABLE tb_policy (
    autoID INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL,
    subject_type TEXT NOT NULL,
    method TEXT NOT NULL,
    is_allowed INTEGER DEFAULT 1,
    create_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (project_id, subject_type, method),
    FOREIGN KEY (project_id) REFERENCES tb_project(project_id)
);

/* 2. INDEXES (คง Composite Index ไว้เพื่อความเร็วของกล้อง LPR หน้าป้อม) */

CREATE INDEX IX_tb_house_project_id ON tb_house(project_id);
CREATE INDEX IX_tb_user_project_id ON tb_user(project_id);
CREATE INDEX IX_tb_user_house_id ON tb_user(house_id);
CREATE INDEX IX_tb_admin_project_id ON tb_admin(project_id);
CREATE INDEX IX_tb_vehicle_project_id ON tb_vehicle(project_id);
CREATE INDEX IX_tb_vehicle_user_id ON tb_vehicle(user_id);
CREATE INDEX IX_tb_vehicle_project_license ON tb_vehicle(project_id, license_plate);
CREATE INDEX IX_tb_device_project_id ON tb_device(project_id);
CREATE INDEX IX_tb_access_log_project_id ON tb_access_log(project_id);
CREATE INDEX IX_tb_access_log_project_date ON tb_access_log(project_id, timestamp);
CREATE INDEX IX_tb_access_log_project_license ON tb_access_log(project_id, license_plate);
CREATE INDEX IX_tb_blacklist_project_id ON tb_blacklist(project_id);
CREATE INDEX IX_tb_blacklist_project_license ON tb_blacklist(project_id, license_plate);
CREATE INDEX IX_tb_visitor_project_license ON tb_visitor(project_id, license_plate);
CREATE INDEX IX_tb_credential_user_id ON tb_credential(user_id);
CREATE INDEX IX_tb_credential_visitor_id ON tb_credential(visitor_id);

/* 3. AUTO UPDATE DATE TRIGGERS (ปรับแก้ Syntax เป็นของ SQLite) */

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_project AFTER UPDATE ON tb_project
FOR EACH ROW BEGIN UPDATE tb_project SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_house AFTER UPDATE ON tb_house
FOR EACH ROW BEGIN UPDATE tb_house SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_user AFTER UPDATE ON tb_user
FOR EACH ROW BEGIN UPDATE tb_user SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_admin AFTER UPDATE ON tb_admin
FOR EACH ROW BEGIN UPDATE tb_admin SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_vehicle AFTER UPDATE ON tb_vehicle
FOR EACH ROW BEGIN UPDATE tb_vehicle SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_device AFTER UPDATE ON tb_device
FOR EACH ROW BEGIN UPDATE tb_device SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_blacklist AFTER UPDATE ON tb_blacklist
FOR EACH ROW BEGIN UPDATE tb_blacklist SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_visitor AFTER UPDATE ON tb_visitor
FOR EACH ROW BEGIN UPDATE tb_visitor SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_credential AFTER UPDATE ON tb_credential
FOR EACH ROW BEGIN UPDATE tb_credential SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;

CREATE TRIGGER TRIG_AUTO_UPDATE_DATE_tb_policy AFTER UPDATE ON tb_policy
FOR EACH ROW BEGIN UPDATE tb_policy SET update_date = CURRENT_TIMESTAMP WHERE autoID = OLD.autoID; END;
