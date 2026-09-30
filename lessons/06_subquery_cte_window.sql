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
-- 6.1 Subquery
-- ---------------------------------------------------------------------
-- scalar subquery: ค่าเดียว ใช้เทียบได้
SELECT order_number, total_amount
FROM orders
WHERE status = 'completed'
  AND total_amount > 2 * (SELECT AVG(total_amount) FROM orders WHERE status = 'completed')
ORDER BY total_amount DESC
LIMIT 10;

-- IN (subquery): ลูกค้าที่เคยซื้อสินค้าหมวด Pet Supplies
SELECT COUNT(*) AS pet_owners
FROM customers
WHERE customer_id IN (
    SELECT o.customer_id
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories sub ON sub.category_id = p.category_id
    JOIN categories top ON top.category_id = sub.parent_category_id
    WHERE top.category_code = 'PET');

-- EXISTS: order ที่จ่ายเงินไม่ผ่านอย่างน้อย 1 ครั้ง แต่สุดท้ายจ่ายสำเร็จ
SELECT COUNT(*) AS recovered_orders
FROM orders o
WHERE o.paid_at IS NOT NULL
  AND EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id AND p.status = 'failed');

-- ---------------------------------------------------------------------
-- 6.2 CTE (WITH): แตก query ยาวเป็นขั้น ๆ อ่านง่ายเหมือน pipeline ย่อย
-- ---------------------------------------------------------------------
WITH monthly AS (                                  -- ขั้น 1: สรุปรายเดือน
    SELECT DATE_FORMAT(ordered_at, '%Y-%m') AS month, SUM(total_amount) AS gmv
    FROM orders
    WHERE status <> 'cancelled'
    GROUP BY month
),
ranked AS (                                        -- ขั้น 2: ใช้ผลของขั้น 1
    SELECT month, gmv, RANK() OVER (ORDER BY gmv DESC) AS rnk
    FROM monthly
)
SELECT * FROM ranked WHERE rnk <= 3;               -- 3 เดือนที่ขายดีที่สุด

-- ---------------------------------------------------------------------
-- 6.3 Window function: คำนวณ "ข้ามแถว" โดยไม่ยุบแถวแบบ GROUP BY
--     รูปแบบ: FUNC() OVER (PARTITION BY ... ORDER BY ... [ROWS ...])
-- ---------------------------------------------------------------------
-- (ก) % ของทั้งหมด: SUM() OVER () = ผลรวมทั้งตาราง
SELECT payment_method, COUNT(*) AS n,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM orders
GROUP BY payment_method;

-- (ข) LAG: เทียบกับแถวก่อนหน้า → การเติบโตเดือนต่อเดือน (MoM)
WITH monthly AS (
    SELECT DATE_FORMAT(ordered_at, '%Y-%m') AS month, SUM(total_amount) AS gmv
    FROM orders WHERE status <> 'cancelled' GROUP BY month
)
SELECT month, gmv,
       LAG(gmv) OVER (ORDER BY month)                                  AS prev_gmv,
       ROUND(100 * (gmv / LAG(gmv) OVER (ORDER BY month) - 1), 1)      AS mom_growth_pct,
       SUM(gmv) OVER (ORDER BY month)                                  AS running_gmv     -- ยอดสะสม
FROM monthly
ORDER BY month;

-- (ค) Moving average 7 วัน (ลด noise ของยอดรายวัน)
WITH daily AS (
    SELECT DATE(ordered_at) AS d, COUNT(*) AS orders
    FROM orders WHERE ordered_at >= '2026-06-01' GROUP BY d
)
SELECT d, orders,
       ROUND(AVG(orders) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS ma_7d
FROM daily
ORDER BY d;

-- (ง) ROW_NUMBER: "เอาแถวล่าสุดของแต่ละกลุ่ม" ⭐ pattern ที่ DE ใช้บ่อยที่สุด (dedup)
--     order ล่าสุดของลูกค้าแต่ละคน
WITH ranked AS (
    SELECT customer_id, order_number, ordered_at, total_amount,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ordered_at DESC, order_id DESC) AS rn
    FROM orders
)
SELECT customer_id, order_number, ordered_at, total_amount
FROM ranked
WHERE rn = 1
ORDER BY customer_id
LIMIT 20;

-- (จ) RANK / DENSE_RANK: top 3 สินค้าขายดีในแต่ละหมวดหลัก
WITH product_sales AS (
    SELECT top.name_en AS category, p.sku, p.product_name, SUM(oi.line_total) AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id AND o.status <> 'cancelled'
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories sub ON sub.category_id = p.category_id
    JOIN categories top ON top.category_id = sub.parent_category_id
    GROUP BY top.name_en, p.product_id, p.sku, p.product_name
),
ranked AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM product_sales
)
SELECT category, rnk, sku, product_name, revenue
FROM ranked WHERE rnk <= 3
ORDER BY category, rnk;
--   ROW_NUMBER = 1,2,3,4 (ไม่มีเสมอ) · RANK = 1,2,2,4 · DENSE_RANK = 1,2,2,3

-- (ฉ) LAG ภายในกลุ่ม: ลูกค้ากลับมาซื้อซ้ำห่างกันกี่วัน
WITH gaps AS (
    SELECT customer_id, ordered_at,
           DATEDIFF(ordered_at, LAG(ordered_at) OVER (PARTITION BY customer_id ORDER BY ordered_at)) AS days_since_prev
    FROM orders
    WHERE status <> 'cancelled'
)
SELECT CASE WHEN days_since_prev <= 3 THEN '1) ≤ 3 วัน'
            WHEN days_since_prev <= 7 THEN '2) 4-7 วัน'
            WHEN days_since_prev <= 14 THEN '3) 8-14 วัน'
            ELSE '4) > 14 วัน' END AS gap_bucket,
       COUNT(*) AS repeat_orders
FROM gaps
WHERE days_since_prev IS NOT NULL                   -- order แรกของลูกค้าไม่มีแถวก่อนหน้า
GROUP BY gap_bucket
ORDER BY gap_bucket;

-- (ช) NTILE: แบ่งลูกค้าเป็น 4 กลุ่มตามยอดซื้อ (quartile)
WITH spend AS (
    SELECT customer_id, SUM(total_amount) AS total_spend
    FROM orders WHERE status = 'completed' GROUP BY customer_id
)
SELECT quartile, COUNT(*) AS customers, MIN(total_spend) AS min_spend, MAX(total_spend) AS max_spend,
       ROUND(SUM(total_spend) / (SELECT SUM(total_spend) FROM spend) * 100, 1) AS pct_of_revenue
FROM (SELECT customer_id, total_spend, NTILE(4) OVER (ORDER BY total_spend DESC) AS quartile FROM spend) q
GROUP BY quartile
ORDER BY quartile;

-- ---------------------------------------------------------------------
-- 6.4 Recursive CTE: สร้าง "date spine" (ตารางวันที่ต่อเนื่อง) เติมวันที่ไม่มีข้อมูล
-- ---------------------------------------------------------------------
-- ปัญหา: GROUP BY วันที่ จะ "ไม่มีแถว" ในวันที่ขายไม่ได้เลย → กราฟ/ค่าเฉลี่ยผิด
SET @sku = (SELECT sku FROM products WHERE status = 'active' ORDER BY product_id DESC LIMIT 1);

WITH RECURSIVE days AS (
    SELECT DATE('2026-08-01') AS d
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2026-08-31'
),
sold AS (
    SELECT DATE(o.ordered_at) AS d, SUM(oi.quantity) AS units
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE p.sku = @sku AND o.ordered_at >= '2026-08-01' AND o.ordered_at < '2026-09-01'
    GROUP BY DATE(o.ordered_at)
)
SELECT days.d, COALESCE(sold.units, 0) AS units       -- วันที่ขายไม่ได้ = 0 (ไม่หายไป)
FROM days LEFT JOIN sold ON sold.d = days.d
ORDER BY days.d;

-- สรุปบทที่ 6
--   subquery (scalar / IN / EXISTS) · CTE · window: SUM() OVER, LAG, moving average,
--   ROW_NUMBER (dedup/latest) ⭐, RANK/DENSE_RANK, NTILE · recursive CTE date spine
--   🎓 จบเนื้อหาในคลาส
--   📖 ศึกษาต่อเอง: บทที่ 7 (สำรวจข้อมูลจริง ecommerce) · 8 (load patterns) · 9 (modeling / quality / performance)
--      และลองทำ Assignment A4 (ใช้ความรู้บทที่ 6 กับข้อมูล ecommerce) หลังอ่านบทที่ 7
