-- =====================================================================
--  บทที่ 6: Subquery · CTE · Window functions (เครื่องมือหลักของ DE)
--  ข้อมูล: "mini shop v2" สร้างเองใน lab_ ของเรา (มี.ค.–ส.ค. 2026, ~400 orders)
--    categories (หมวดหลัก → หมวดย่อย) ─< products
--    customers ─< orders ─< order_items >─ products
--                   └─< payments
-- =====================================================================
USE lab_student;   -- ⚠️ แก้เป็น database ของตัวเอง

-- ---------------------------------------------------------------------
-- 6.0 เตรียมข้อมูล
--     เลือกตั้งแต่บรรทัดนี้ถึง "จบส่วนเตรียมข้อมูล" แล้วรันทั้งก้อนด้วย Alt+X (Execute script)
--     ⚠️ ใช้ชื่อตารางเดียวกับบทที่ 5 → ตารางของบทที่ 5 จะถูกแทนที่ (อยากกลับไปบทที่ 5 ให้รัน 5.1–5.2 ใหม่)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS customers;

CREATE TABLE categories (
    category_id         INT          NOT NULL PRIMARY KEY,
    category_code       VARCHAR(20)  NOT NULL UNIQUE,
    name_en             VARCHAR(50)  NOT NULL,
    parent_category_id  INT          NULL,                  -- NULL = หมวดหลัก
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_category_id) REFERENCES categories (category_id)
);

CREATE TABLE products (
    product_id    INT           NOT NULL PRIMARY KEY,
    sku           VARCHAR(20)   NOT NULL UNIQUE,
    product_name  VARCHAR(100)  NOT NULL,
    category_id   INT           NOT NULL,                  -- อ้างถึง "หมวดย่อย"
    price         DECIMAL(10,2) NOT NULL,
    status        VARCHAR(10)   NOT NULL,                  -- active / inactive
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (category_id)
);

CREATE TABLE customers (
    customer_id    INT          NOT NULL PRIMARY KEY,
    customer_code  VARCHAR(12)  NOT NULL UNIQUE,
    name           VARCHAR(100) NOT NULL,
    province       VARCHAR(50)  NOT NULL,
    registered_at  DATETIME     NOT NULL
);

CREATE TABLE orders (
    order_id        INT           NOT NULL PRIMARY KEY,
    order_number    VARCHAR(20)   NOT NULL UNIQUE,
    customer_id     INT           NOT NULL,
    ordered_at      DATETIME      NOT NULL,
    status          VARCHAR(20)   NOT NULL,                -- completed / shipped / cancelled
    payment_method  VARCHAR(20)   NOT NULL,
    total_amount    DECIMAL(12,2) NOT NULL DEFAULT 0,
    paid_at         DATETIME      NULL,                    -- NULL = ยังไม่ได้จ่าย
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE TABLE order_items (
    order_id     INT           NOT NULL,
    line_number  INT           NOT NULL,
    product_id   INT           NOT NULL,
    quantity     INT           NOT NULL CHECK (quantity > 0),
    unit_price   DECIMAL(10,2) NOT NULL,
    line_total   DECIMAL(12,2) NOT NULL,                  -- quantity × unit_price
    PRIMARY KEY (order_id, line_number),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE payments (
    payment_id  INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
    order_id    INT           NOT NULL,
    attempt     INT           NOT NULL,
    method      VARCHAR(20)   NOT NULL,
    amount      DECIMAL(12,2) NOT NULL,
    status      VARCHAR(10)   NOT NULL,                  -- success / failed
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE
);

INSERT INTO categories VALUES
 (1, 'ELEC',   'Electronics',       NULL),
 (2, 'BEAUTY', 'Beauty',            NULL),
 (3, 'PET',    'Pet Supplies',      NULL),
 (4, 'FOOD',   'Food & Beverages',  NULL),
 (11, 'ELEC-ACC',  'Phone Accessories', 1),
 (12, 'ELEC-AUD',  'Audio',             1),
 (21, 'BEA-SKIN',  'Skincare',          2),
 (22, 'BEA-MAKE',  'Makeup',            2),
 (31, 'PET-DOG',   'Dog Food',          3),
 (32, 'PET-CAT',   'Cat Supplies',      3),
 (41, 'FOOD-SNK',  'Snacks',            4),
 (42, 'FOOD-BEV',  'Beverages',         4);

INSERT INTO products VALUES
 (1,  'ACC-ANK-00001', 'Anker สายชาร์จ USB-C',        11,  290, 'active'),
 (2,  'ACC-ANK-00002', 'Anker หัวชาร์จ 20W',           11,  590, 'active'),
 (3,  'AUD-SNY-00001', 'Sony หูฟังไร้สาย',             12, 3990, 'active'),
 (4,  'AUD-JBL-00001', 'JBL ลำโพงบลูทูธ',              12, 1890, 'active'),
 (5,  'SKN-MIS-00001', 'Mistine ครีมกันแดด 50ml',      21,  259, 'active'),
 (6,  'SKN-GAR-00001', 'Garnier เซรั่มวิตซี 30ml',     21,  399, 'active'),
 (7,  'MAK-MBL-00001', 'Maybelline ลิปสติก',           22,  329, 'active'),
 (8,  'MAK-SRC-00001', 'Srichand แป้งฝุ่น',             22,  189, 'active'),
 (9,  'DOG-PED-00001', 'Pedigree อาหารสุนัข 3kg',       31,  459, 'active'),
 (10, 'DOG-SMH-00001', 'SmartHeart อาหารสุนัข 10kg',    31, 1290, 'active'),
 (11, 'CAT-WHS-00001', 'Whiskas อาหารแมว 1.2kg',       32,  249, 'active'),
 (12, 'CAT-KAT-00001', 'ทรายแมว Kasty 10L',            32,  199, 'active'),
 (13, 'SNK-TAS-00001', 'Tasto มันฝรั่งทอดกรอบ',          41,   35, 'active'),
 (14, 'SNK-LAY-00001', 'Lay''s รสโนริสาหร่าย',           41,   30, 'active'),
 (15, 'BEV-OSO-00001', 'โออิชิ ชาเขียว 6 ขวด',          42,  120, 'active'),
 (16, 'BEV-NES-00001', 'Nescafe กาแฟกระป๋อง 6 กระป๋อง', 42,  105, 'active'),   -- สินค้าใหม่ ขายได้ไม่ทุกวัน
 (17, 'BEV-EST-00001', 'est โคล่า 12 กระป๋อง',          42,  150, 'inactive'); -- เลิกขายแล้ว

INSERT INTO customers VALUES
 (1,  'CUS-0000001', 'สมชาย ใจดี',     'กรุงเทพมหานคร', '2026-01-05 10:00'),
 (2,  'CUS-0000002', 'สมหญิง รักสวย',   'เชียงใหม่',      '2026-01-10 19:30'),
 (3,  'CUS-0000003', 'วิชัย มั่นคง',     'ขอนแก่น',        '2026-01-18 08:15'),
 (4,  'CUS-0000004', 'นภา ศรีสุข',      'ภูเก็ต',         '2026-01-20 21:00'),
 (5,  'CUS-0000005', 'ธนพล ทองดี',      'ชลบุรี',         '2026-01-25 12:45'),
 (6,  'CUS-0000006', 'ปิยะ บุญมา',      'กรุงเทพมหานคร', '2026-02-01 09:00'),
 (7,  'CUS-0000007', 'อรุณี แสงทอง',    'นนทบุรี',        '2026-02-03 14:20'),
 (8,  'CUS-0000008', 'กิตติ วงศ์ใหญ่',   'สงขลา',         '2026-02-07 18:10'),
 (9,  'CUS-0000009', 'มาลี ดอกไม้',     'เชียงราย',       '2026-02-10 11:30'),
 (10, 'CUS-0000010', 'ประเสริฐ สุขใจ',  'นครราชสีมา',     '2026-02-12 20:05'),
 (11, 'CUS-0000011', 'จันทร์เพ็ญ ศรีนวล', 'กรุงเทพมหานคร', '2026-02-15 07:45'),
 (12, 'CUS-0000012', 'ศักดิ์ชัย พลเยี่ยม', 'อุดรธานี',       '2026-02-18 16:00'),
 (13, 'CUS-0000013', 'วรรณา ทองคำ',     'ปทุมธานี',       '2026-02-20 10:10'),
 (14, 'CUS-0000014', 'ณัฐพล ชัยมงคล',   'ระยอง',          '2026-02-22 13:40'),
 (15, 'CUS-0000015', 'สุดารัตน์ มีสุข',  'กรุงเทพมหานคร', '2026-02-25 22:15'),
 (16, 'CUS-0000016', 'อนุชา เพชรดี',    'สุราษฎร์ธานี',   '2026-02-27 09:50'),
 (17, 'CUS-0000017', 'พิมพ์ชนก รุ่งเรือง', 'เชียงใหม่',      '2026-02-28 17:25'),
 (18, 'CUS-0000018', 'ธีรวัฒน์ แก้วใส',  'ขอนแก่น',        '2026-03-01 08:00'),
 (19, 'CUS-0000019', 'ชไมพร ใจงาม',     'กรุงเทพมหานคร', '2026-08-20 12:00'),   -- สมัครแล้วยังไม่เคยซื้อ
 (20, 'CUS-0000020', 'บุญส่ง มั่งมี',     'พิษณุโลก',       '2026-08-25 19:00');   -- สมัครแล้วยังไม่เคยซื้อ

-- orders / order_items / payments: สร้างด้วยสูตร (ได้ผลเหมือนกันทุกเครื่อง)
-- 💡 ยังไม่ต้องเข้าใจโค้ดส่วนนี้ อ่านรู้เรื่องเองหลังจบ 6.4 (recursive CTE)
DROP TABLE IF EXISTS seq;
CREATE TABLE seq (n INT NOT NULL PRIMARY KEY);
INSERT INTO seq
WITH RECURSIVE s AS (SELECT 1 AS n UNION ALL SELECT n + 1 FROM s WHERE n < 400)
SELECT n FROM s;

INSERT INTO orders (order_id, order_number, customer_id, ordered_at, status, payment_method)
SELECT order_id,
       CONCAT('ORD-', DATE_FORMAT(t, '%y%m%d'), '-', LPAD(order_id, 6, '0')),
       1 + MOD(CRC32(CONCAT('c', n)), 18),                               -- ลูกค้า 1–18
       t,
       CASE WHEN MOD(CRC32(CONCAT('s', n)), 12) = 0 THEN 'cancelled'
            WHEN t >= '2026-08-27'                  THEN 'shipped'       -- order ท้าย ๆ ยังส่งไม่ถึง
            ELSE 'completed' END,
       ELT(1 + MOD(CRC32(CONCAT('m', n)), 3), 'card', 'promptpay', 'cod')
FROM (SELECT n, t, ROW_NUMBER() OVER (ORDER BY t, n) AS order_id          -- order_id เรียงตามเวลา
      FROM (SELECT n,
                   TIMESTAMP(IF(MOD(CRC32(CONCAT('p', n)), 25) = 0,
                                '2026-07-07',                                                          -- โปร 7.7: order พุ่ง
                                DATE('2026-03-01') + INTERVAL FLOOR(184 * POW(MOD(CRC32(CONCAT('d', n)), 10000) / 10000, 0.7)) DAY))
                   + INTERVAL (8 + MOD(CRC32(CONCAT('h', n)), 15)) HOUR
                   + INTERVAL MOD(CRC32(CONCAT('i', n)), 60) MINUTE AS t   -- ยิ่งใกล้ ส.ค. order ยิ่งเยอะ (ร้านโต)
            FROM seq) a) b;

INSERT INTO order_items (order_id, line_number, product_id, quantity, unit_price, line_total)
SELECT order_id, k, product_id, quantity, price, quantity * price
FROM (SELECT o.order_id, k.k, p.product_id, p.price,
             ELT(1 + MOD(CRC32(CONCAT('q', o.order_id, '-', k.k)), 6), 1, 1, 1, 2, 2, 3) AS quantity
      FROM orders o
      JOIN (SELECT 1 AS k UNION ALL SELECT 2 UNION ALL SELECT 3) k
        ON k.k <= 1 + MOD(CRC32(CONCAT('l', o.order_id)), 3)                                      -- 1–3 บรรทัด/order
      JOIN products p ON p.product_id = 1 + MOD(CRC32(CONCAT('p', o.order_id)) + k.k * 5, 15)) x;

INSERT INTO order_items (order_id, line_number, product_id, quantity, unit_price, line_total)   -- สินค้า 16 ขายเฉพาะ ส.ค. บางวัน
SELECT order_id, 9, 16, 1, 105, 105
FROM orders
WHERE ordered_at >= '2026-08-01' AND MOD(CRC32(CONCAT('n', order_id)), 3) = 0;

UPDATE orders o
SET total_amount = (SELECT SUM(line_total) FROM order_items oi WHERE oi.order_id = o.order_id),
    paid_at = CASE WHEN o.status = 'cancelled'                              THEN NULL
                   WHEN o.payment_method = 'cod' AND o.status = 'shipped'   THEN NULL      -- เก็บเงินปลายทาง ยังไม่ได้เงิน
                   WHEN o.payment_method = 'cod'                            THEN o.ordered_at + INTERVAL 3 DAY
                   ELSE o.ordered_at + INTERVAL 10 MINUTE END;

INSERT INTO payments (order_id, attempt, method, amount, status)            -- บัตรไม่ผ่านครั้งแรก
SELECT order_id, 1, 'card', total_amount, 'failed'
FROM orders
WHERE MOD(CRC32(CONCAT('f', order_id)), 8) = 0 AND payment_method <> 'cod';

INSERT INTO payments (order_id, attempt, method, amount, status)            -- จ่ายสำเร็จ
SELECT o.order_id,
       1 + (SELECT COUNT(*) FROM payments f WHERE f.order_id = o.order_id),
       o.payment_method, o.total_amount, 'success'
FROM orders o
WHERE o.paid_at IS NOT NULL;

DROP TABLE seq;
-- จบส่วนเตรียมข้อมูล

SELECT (SELECT COUNT(*) FROM customers) AS customers, (SELECT COUNT(*) FROM products) AS products,
       (SELECT COUNT(*) FROM orders) AS orders, (SELECT COUNT(*) FROM order_items) AS order_items,
       (SELECT COUNT(*) FROM payments) AS payments;
-- ✅ ควรได้ 20 / 17 / 400 / 849 / 400


-- ---------------------------------------------------------------------
-- 6.1 Subquery: query ซ้อนอยู่ข้างใน query (ข้างในรันก่อน แล้วส่งผลให้ข้างนอกใช้)
-- ---------------------------------------------------------------------
-- (ก) ลองรันข้างในก่อน: ราคาเฉลี่ยของสินค้า
SELECT AVG(price) FROM products;

-- แล้วเอาไปซ้อน: สินค้าที่ราคา "แพงกว่าค่าเฉลี่ย"
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;

-- (ข) IN (subquery): ลูกค้าที่ "เคย" สั่งซื้อ
SELECT customer_id, name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders);

-- NOT IN: ลูกค้าที่ "ไม่เคย" สั่งซื้อเลย  → ควรได้ 2 คน (id 19, 20)
SELECT customer_id, name
FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders);

-- ---------------------------------------------------------------------
-- 6.2 CTE (WITH): ตั้งชื่อให้ผลลัพธ์ชั่วคราว แล้วใช้ต่อเหมือนเป็นตาราง
--     อ่านจากบนลงล่างได้ง่ายกว่า subquery ซ้อนกันหลายชั้น
-- ---------------------------------------------------------------------
-- ขั้น 1: ยอดซื้อรวมของลูกค้าแต่ละคน (ตั้งชื่อว่า customer_spend)
-- ขั้น 2: เลือกจาก customer_spend เหมือนเป็นตารางปกติ → 5 คนที่ซื้อมากที่สุด
WITH customer_spend AS (
    SELECT customer_id, SUM(total_amount) AS total_spend
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT *
FROM customer_spend
ORDER BY total_spend DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 6.3 Window function: คำนวณ "ข้ามแถว" แต่ไม่ยุบแถว (ต่างจาก GROUP BY)
--     รูปแบบ: ฟังก์ชัน() OVER (PARTITION BY แบ่งกลุ่ม  ORDER BY เรียงลำดับ)
-- ---------------------------------------------------------------------
-- (ก) เทียบ GROUP BY กับ window
--     GROUP BY: 17 สินค้า เหลือ 1 แถว
SELECT AVG(price) AS avg_price FROM products;

--     window: ยังได้ครบ 17 แถว + มีค่าเฉลี่ยแปะไว้ทุกแถว
SELECT product_name, price,
       AVG(price) OVER () AS avg_price
FROM products;

-- (ข) ROW_NUMBER: ใส่เลขลำดับ 1, 2, 3, ...
SELECT product_name, price,
       ROW_NUMBER() OVER (ORDER BY price DESC) AS rn
FROM products;

-- (ค) PARTITION BY: เริ่มนับ 1 ใหม่ในแต่ละกลุ่ม (ที่นี่ = แต่ละหมวด)
SELECT category_id, product_name, price,
       ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) AS rn
FROM products
ORDER BY category_id, rn;

-- ⭐ pattern ที่ DE ใช้บ่อยมาก: เอา "อันดับ 1 ของแต่ละกลุ่ม"
--    สินค้าที่แพงที่สุดของแต่ละหมวด (WHERE ใช้กับ window ตรง ๆ ไม่ได้ → ห่อด้วย CTE ก่อน)
WITH ranked AS (
    SELECT category_id, product_name, price,
           ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) AS rn
    FROM products
)
SELECT category_id, product_name, price
FROM ranked
WHERE rn = 1;

-- (ง) ROW_NUMBER vs RANK vs DENSE_RANK: ต่างกันตอน "ค่าเท่ากัน"
WITH order_count AS (
    SELECT customer_id, COUNT(*) AS n_orders
    FROM orders
    GROUP BY customer_id
)
SELECT customer_id, n_orders,
       ROW_NUMBER() OVER (ORDER BY n_orders DESC) AS row_num,      -- 1,2,3,4 (ไม่มีเสมอ)
       RANK()       OVER (ORDER BY n_orders DESC) AS rnk,          -- 1,2,2,4 (เสมอแล้วข้ามเลข)
       DENSE_RANK() OVER (ORDER BY n_orders DESC) AS dense_rnk     -- 1,2,2,3 (เสมอแต่ไม่ข้าม)
FROM order_count;

-- (จ) LAG + ยอดสะสม: จำนวน order รายเดือน เทียบกับเดือนก่อน
WITH monthly AS (
    SELECT DATE_FORMAT(ordered_at, '%Y-%m') AS month, COUNT(*) AS n_orders
    FROM orders
    GROUP BY month
)
SELECT month, n_orders,
       LAG(n_orders) OVER (ORDER BY month) AS prev_month,          -- ค่าของแถวก่อนหน้า
       SUM(n_orders) OVER (ORDER BY month) AS running_total        -- รวมสะสมตั้งแต่เดือนแรก
FROM monthly
ORDER BY month;

-- สรุปบทที่ 6
--   subquery: query ซ้อน (ค่าเดียว / IN / NOT IN)
--   CTE: WITH ชื่อ AS (...) ตั้งชื่อผลลัพธ์ชั่วคราว
--   window: OVER (), ROW_NUMBER ⭐, PARTITION BY, RANK / DENSE_RANK, LAG, ยอดสะสม
--   🎓 จบเนื้อหาในคลาส
--   📖 ศึกษาต่อเอง: บทที่ 7 (สำรวจข้อมูลจริง ecommerce) · 8 (load patterns) · 9 (modeling / quality / performance)
--      และลองทำ Assignment A4 (ใช้ความรู้บทที่ 6 กับข้อมูล ecommerce) หลังอ่านบทที่ 7
