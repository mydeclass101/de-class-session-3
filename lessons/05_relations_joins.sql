-- =====================================================================
--  บทที่ 5: หลายตาราง: Primary/Foreign key และ JOIN
--  ข้อมูล: "mini shop" 5 ตาราง ออกแบบให้ "หน้าตาเหมือนข้อมูลจริง" ใน ecommerce (บทที่ 7)
--    customers ─< orders ─< order_items >─ products
--                   │          └─< item_returns
--                   └─< payments
-- =====================================================================
USE lab_student;   -- ⚠️ แก้เป็น database ของตัวเอง

-- ลบตามลำดับ "ลูก → แม่" (ตารางที่ถูกอ้างอิงลบทีหลัง)
DROP TABLE IF EXISTS item_returns;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- ---------------------------------------------------------------------
-- 5.1 DDL: ตารางที่อ้างอิงกัน
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    INT          NOT NULL PRIMARY KEY,           -- surrogate key (ตัวเลขภายในระบบ)
    customer_code  VARCHAR(12)  NOT NULL UNIQUE,                -- business key (คนใช้จริง)
    name           VARCHAR(100) NOT NULL,
    province       VARCHAR(50)  NOT NULL,
    registered_at  DATETIME     NOT NULL
);

CREATE TABLE products (
    product_id  INT           NOT NULL PRIMARY KEY,
    sku         VARCHAR(20)   NOT NULL UNIQUE,
    name        VARCHAR(100)  NOT NULL,
    category    VARCHAR(30)   NOT NULL,
    price       DECIMAL(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id      INT          NOT NULL PRIMARY KEY,
    order_number  VARCHAR(20)  NOT NULL UNIQUE,
    customer_id   INT          NOT NULL,
    ordered_at    DATETIME     NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        -- default = ON DELETE RESTRICT: ห้ามลบลูกค้าที่ยังมี order
);

CREATE TABLE order_items (
    order_id     INT           NOT NULL,
    line_number  INT           NOT NULL,
    product_id   INT           NOT NULL,
    quantity     INT           NOT NULL CHECK (quantity > 0),
    unit_price   DECIMAL(10,2) NOT NULL,                 -- ราคา ณ วันที่ขาย (สินค้าอาจเปลี่ยนราคาทีหลัง)
    PRIMARY KEY (order_id, line_number),                 -- composite primary key
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE payments (
    payment_id  INT           NOT NULL PRIMARY KEY,
    order_id    INT           NOT NULL,
    attempt     INT           NOT NULL,
    method      VARCHAR(20)   NOT NULL,
    amount      DECIMAL(10,2) NOT NULL,
    status      VARCHAR(10)   NOT NULL,                  -- success / failed / pending
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE
);

CREATE TABLE item_returns (                              -- คืนสินค้า "รายบรรทัด" ของ order
    return_id    INT          NOT NULL PRIMARY KEY,
    order_id     INT          NOT NULL,
    line_number  INT          NOT NULL,
    quantity     INT          NOT NULL CHECK (quantity > 0),
    reason       VARCHAR(50)  NOT NULL,
    CONSTRAINT fk_returns_item FOREIGN KEY (order_id, line_number)          -- composite foreign key
        REFERENCES order_items (order_id, line_number) ON DELETE CASCADE    -- ต้องอ้าง "ครบทั้ง 2 คอลัมน์" ของ PK
);

-- ---------------------------------------------------------------------
-- 5.2 Seed data (ใส่ "แม่" ก่อน "ลูก")
-- ---------------------------------------------------------------------
INSERT INTO customers VALUES
 (1, 'CUS-0000001', 'สมชาย ใจดี',   'กรุงเทพมหานคร', '2026-01-05 10:00'),
 (2, 'CUS-0000002', 'สมหญิง รักสวย', 'เชียงใหม่',      '2026-01-10 19:30'),
 (3, 'CUS-0000003', 'วิชัย มั่นคง',   'ขอนแก่น',        '2026-02-01 08:15'),
 (4, 'CUS-0000004', 'นภา ศรีสุข',    'ภูเก็ต',         '2026-02-20 21:00'),
 (5, 'CUS-0000005', 'ธนพล ทองดี',    'ชลบุรี',         '2026-03-03 12:45'),
 (6, 'CUS-0000006', 'ปิยะ บุญมา',    'กรุงเทพมหานคร', '2026-03-15 09:00');   -- สมัครแล้วยังไม่เคยซื้อ

INSERT INTO products VALUES
 (1, 'ACC-ANK-00001', 'Anker สายชาร์จ USB-C',     'Electronics', 290),
 (2, 'AUD-SNY-00001', 'Sony หูฟังไร้สาย',          'Electronics', 3990),
 (3, 'SKN-MIS-00001', 'Mistine ครีมกันแดด 50ml',   'Beauty',      259),
 (4, 'SNK-TAS-00001', 'Tasto มันฝรั่งทอดกรอบ',      'Food',        35),
 (5, 'MEN-UNQ-00001', 'UNIQLO เสื้อยืดคอกลม ไซส์ M', 'Fashion',     390),
 (6, 'BKS-NMB-00001', 'Nanmeebooks หนังสือนิทาน',   'Books',       159);   -- ยังไม่เคยขายได้

INSERT INTO orders VALUES
 (101, 'ORD-260301-000001', 1, '2026-03-01 10:15', 'completed'),
 (102, 'ORD-260301-000002', 2, '2026-03-01 20:40', 'completed'),
 (103, 'ORD-260302-000001', 1, '2026-03-02 09:05', 'cancelled'),
 (104, 'ORD-260305-000001', 3, '2026-03-05 21:30', 'completed'),
 (105, 'ORD-260305-000002', 4, '2026-03-05 22:10', 'shipped'),
 (106, 'ORD-260310-000001', 1, '2026-03-10 12:00', 'completed'),
 (107, 'ORD-260310-000002', 5, '2026-03-10 19:45', 'pending_payment');

INSERT INTO order_items VALUES
 (101, 1, 1, 2, 290), (101, 2, 4, 3, 35),
 (102, 1, 3, 1, 259),
 (103, 1, 2, 1, 3990),
 (104, 1, 5, 2, 390), (104, 2, 4, 5, 35), (104, 3, 3, 1, 259),
 (105, 1, 2, 1, 3990),
 (106, 1, 1, 1, 290),
 (107, 1, 5, 1, 390);

INSERT INTO payments VALUES
 (1, 101, 1, 'card',      685,  'success'),
 (2, 102, 1, 'promptpay', 259,  'success'),
 (3, 103, 1, 'card',      3990, 'failed'),
 (4, 104, 1, 'card',      1214, 'failed'),      -- บัตรไม่ผ่าน
 (5, 104, 2, 'promptpay', 1214, 'success'),     -- ลองใหม่ด้วย promptpay
 (6, 105, 1, 'cod',       3990, 'pending'),
 (7, 106, 1, 'promptpay', 290,  'success');

INSERT INTO item_returns VALUES
 (1, 101, 1, 1, 'สายชาร์จชำรุด'),               -- order 101 บรรทัด 1 (สายชาร์จ 1 ใน 2 เส้น)
 (2, 104, 3, 1, 'แพ้ครีม'),                      -- order 104 บรรทัด 3 (ครีมกันแดด)
 (3, 104, 1, 1, 'ไซส์ไม่พอดี'),                  -- order 104 ซ้ำ แต่คนละบรรทัด (เสื้อยืด)
 (4, 102, 1, 1, 'สินค้าหมดอายุ'),                -- บรรทัด 1 ซ้ำ แต่คนละ order (ครีมกันแดด)
 (5, 106, 1, 1, 'ไม่ตรงปก');                     -- บรรทัด 1 ซ้ำอีก (สายชาร์จ)
-- 👀 order_id ซ้ำได้ (104 ×2) · line_number ซ้ำได้ (1 ×4) · แต่ "คู่" (order_id, line_number) ไม่ซ้ำเลย

-- Foreign key ทำงาน:
-- ❌ INSERT INTO orders VALUES (108, 'ORD-260311-000001', 99, '2026-03-11 10:00', 'completed');   -- ไม่มีลูกค้า id 99
-- ❌ DELETE FROM customers WHERE customer_id = 1;                                                  -- ลูกค้ามี order อยู่ (RESTRICT)
-- ❌ INSERT INTO order_items VALUES (101, 3, 77, 1, 10);                                           -- ไม่มีสินค้า id 77
-- ❌ INSERT INTO item_returns VALUES (3, 102, 2, 1, 'test');                                        -- order 102 ไม่มีบรรทัด 2 (FK เช็คคู่ order_id + line_number)

-- ---------------------------------------------------------------------
-- 5.3 LEFT JOIN: เก็บทุกแถวฝั่งซ้าย ฝั่งขวาไม่เจอ = NULL
-- ---------------------------------------------------------------------
SELECT c.customer_code, c.name, o.order_number, o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.ordered_at;           -- 👀 ปิยะ (CUS-0000006) ขึ้นมาด้วย แต่ order เป็น NULL

-- ---------------------------------------------------------------------
-- 5.4 INNER JOIN: เอาเฉพาะแถวที่ "จับคู่ได้" ทั้งสองฝั่ง
-- ---------------------------------------------------------------------
SELECT c.customer_code, c.name, o.order_number, o.status
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.ordered_at;   

-- ---------------------------------------------------------------------
-- 5.5 Anti-join: "สิ่งที่ไม่มีคู่" (DE ใช้หา orphan / ข้อมูลที่ยังไม่ถูกโหลด)
-- ---------------------------------------------------------------------


SELECT c.customer_code, c.name                         -- ลูกค้าที่ไม่เคยสั่ง
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;


SELECT c.customer_code, c.name                         -- ลูกค้าที่ไม่เคยสั่ง
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE c.customer_id = o.customer_id)

-- ---------------------------------------------------------------------

-- จำนวน order ต่อลูกค้า (รวมคนที่เป็น 0)
SELECT c.customer_code, c.name, COUNT(o.order_id) AS n_orders      -- ⚠️ COUNT(o.order_id) ไม่ใช่ COUNT(*)
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_code, c.name
ORDER BY n_orders DESC;


-- ---------------------------------------------------------------------
-- 5.6 JOIN หลายตาราง: ยอดเงินต่อ order
-- ---------------------------------------------------------------------
select 
	o.order_id, 
	o.order_number,  
	o.ordered_at, 
	c.name,
	sum(oi.quantity * oi.unit_price ) AS total  
from orders o
left join customers c 
on o.customer_id = c.customer_id 
left join order_items oi 
on o.order_id = oi.order_id 
left join products p
on oi.product_id = p.product_id 
group by o.order_id, o.order_number,  o.ordered_at , c.name 


-- ยอดขายตามหมวดสินค้า (ไม่นับ order ที่ยกเลิก)
SELECT p.category, SUM(oi.quantity) AS units, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id AND o.status <> 'cancelled'
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- ---------------------------------------------------------------------
-- 5.7 JOIN ด้วย composite key: ต้อง join "ครบทุกคอลัมน์" ของ key
-- ---------------------------------------------------------------------
-- order_items มี PK = (order_id, line_number) → item_returns ต้องจับคู่ทั้ง 2 คอลัมน์

select * from item_returns a
left join order_items b
on a.order_id = b.order_id
	and a.line_number = b.line_number ;


select a.return_id , a.order_id , a.line_number , p.name, p.category, a.reason    from item_returns a
left join order_items b
on a.order_id = b.order_id
	and a.line_number = b.line_number 
left join products p 
on b.product_id = p.product_id ;


-- ดูก่อน: แต่ละคอลัมน์ "ซ้ำได้" แต่พอรวมเป็นคู่แล้ว "ไม่ซ้ำ"
SELECT COUNT(*)                                 AS n_rows,          -- 10
       COUNT(DISTINCT order_id)                 AS n_order_id,      -- 7   (ซ้ำ)
       COUNT(DISTINCT line_number)              AS n_line_number,   -- 3   (ซ้ำ)
       COUNT(DISTINCT order_id, line_number)    AS n_pairs          -- 10  (ไม่ซ้ำ = ใช้เป็น key ได้)
FROM order_items;

-- ---------------------------------------------------------------------
-- 5.8 ⚠️ Fan-out: join ตาราง "หลายแถว" สองตารางพร้อมกัน ยอดเบิ้ล!
-- ---------------------------------------------------------------------
-- order 104 มี 3 items และ 2 payments → join แล้วได้ 3 × 2 = 6 แถว
SELECT o.order_number,
       SUM(oi.quantity * oi.unit_price) AS items_total_WRONG,
       SUM(p.amount)                    AS paid_WRONG
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN payments p     ON p.order_id  = o.order_id
WHERE o.order_id = 104
GROUP BY o.order_number;                        -- ได้ 2,428 และ 7,284 แทนที่จะเป็น 1,214 😱 (3 items × 2 payments = 6 แถว)

-- ✅ วิธีแก้: สรุปแต่ละตารางให้เหลือ 1 แถวต่อ order "ก่อน" แล้วค่อย join
SELECT o.order_number, i.items_total, pay.paid
FROM orders o
JOIN (SELECT order_id, SUM(quantity * unit_price) AS items_total FROM order_items GROUP BY order_id) i
     ON i.order_id = o.order_id
LEFT JOIN (SELECT order_id, SUM(amount) AS paid FROM payments WHERE status = 'success' GROUP BY order_id) pay
     ON pay.order_id = o.order_id
ORDER BY o.order_id;

-- 💡 ก่อน join ถามตัวเองเสมอ: "grain" (1 แถวแทนอะไร) ของแต่ละตารางคืออะไร
--    orders = 1 แถว/order · order_items = 1 แถว/สินค้าใน order · payments = 1 แถว/ครั้งที่จ่าย


-- ---------------------------------------------------------------------
-- 5.9 UNION ALL: ต่อผลลัพธ์ "แนวตั้ง" (คอลัมน์ต้องตรงกัน)
-- ---------------------------------------------------------------------
-- timeline เหตุการณ์ของลูกค้า 1 คน จาก 2 ตาราง
SELECT 'order'   AS event, o.order_number AS ref, o.ordered_at AS at_time, o.status AS detail
FROM orders o WHERE o.customer_id = 1
UNION ALL
SELECT 'payment', o.order_number, NULL, CONCAT(p.method, ' ', p.status)
FROM payments p JOIN orders o ON o.order_id = p.order_id WHERE o.customer_id = 1
ORDER BY ref, event DESC;
-- UNION (ไม่มี ALL) = ตัดแถวซ้ำด้วย → ช้ากว่า ใช้เมื่อ "ต้องการ" ตัดซ้ำจริง ๆ เท่านั้น

-- สรุปบทที่ 5
--   PK / FK / composite key (และการ join หลายคอลัมน์) / ON DELETE · INNER vs LEFT JOIN · เงื่อนไขใน ON vs WHERE
--   anti-join (LEFT JOIN ... IS NULL / NOT EXISTS) · fan-out และการ aggregate ก่อน join · UNION ALL
--   ➡️ ทำ Assignment A3
