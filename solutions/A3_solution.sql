-- เฉลย A3: Joins (รัน A3_seed.sql ก่อน)
USE lab_student;

-- 1
SELECT o.order_number, o.ordered_at, c.customer_code, c.name, c.province
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status = 'completed' ORDER BY o.ordered_at;

-- 2  (LEFT JOIN + เงื่อนไข cancelled อยู่ใน ON เพื่อไม่ตัดลูกค้าที่ไม่มี order ทิ้ง)
SELECT c.customer_code, c.name,
       COUNT(DISTINCT o.order_id)                      AS n_orders,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0)   AS total_spend
FROM customers c
LEFT JOIN orders o       ON o.customer_id = c.customer_id AND o.status <> 'cancelled'
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.customer_code, c.name
ORDER BY total_spend DESC;

-- 3  → CUS-0000004, 0000005, 0000006, 0000008
SELECT c.customer_code, c.name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.status = 'completed');

-- 4  → BKS-NMB-00001
SELECT p.sku, p.name
FROM products p
WHERE NOT EXISTS (SELECT 1 FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                  WHERE oi.product_id = p.product_id AND o.status <> 'cancelled');

-- 5
SELECT p.category, SUM(oi.quantity) AS units, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id AND o.status <> 'cancelled'
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category ORDER BY revenue DESC;

-- 6  → ORD-260322-000001 / AUD-SNY-00001 ส่วนต่าง 200
SELECT o.order_number, p.sku, p.price AS list_price, oi.unit_price AS sold_price, p.price - oi.unit_price AS diff
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE oi.unit_price < p.price;

-- 7  (aggregate ก่อน join เพื่อกัน fan-out)  104 → 1214 / 1214 / 1 ,  109 → 4370 / 4370 / 2
WITH items AS (SELECT order_id, SUM(quantity * unit_price) AS items_total FROM order_items GROUP BY order_id),
     pay   AS (SELECT order_id, SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) AS paid,
                      SUM(status = 'failed') AS failed_attempts
               FROM payments GROUP BY order_id)
SELECT o.order_number, o.status, i.items_total, COALESCE(p.paid, 0) AS paid, COALESCE(p.failed_attempts, 0) AS failed_attempts
FROM orders o
JOIN items i     ON i.order_id = o.order_id
LEFT JOIN pay p  ON p.order_id = o.order_id
ORDER BY o.order_id;

-- 8  ควรได้ 0 แถว: order ที่จบแล้วต้องมีการจ่ายเงินสำเร็จ ถ้ามีแถวออกมา = ข้อมูลผิดปกติ (bug ต้นทาง / โหลดไม่ครบ)
--    DQ check ที่ดีเขียนเป็น "query หาสิ่งที่ผิด" แล้วคาดหวังผล 0 แถว ทำให้ตั้งเป็น test อัตโนมัติได้
SELECT o.order_number
FROM orders o
WHERE o.status = 'completed'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id AND p.status = 'success');

-- 9
SELECT * FROM (
    SELECT o.ordered_at AS at_time, 1 AS seq, 'order' AS event, o.order_number AS ref, o.status AS detail
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_code = 'CUS-0000002'
    UNION ALL
    SELECT o.ordered_at, 1 + p.attempt, 'payment', o.order_number, CONCAT(p.method, ' ', p.status)
    FROM payments p JOIN orders o ON o.order_id = p.order_id
    JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_code = 'CUS-0000002'
) t ORDER BY at_time, seq;

-- 10 (รองรับการเสมอด้วย RANK)
WITH prov AS (
    SELECT c.province, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN customers c    ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY c.province
)
SELECT province, revenue FROM (SELECT prov.*, RANK() OVER (ORDER BY revenue DESC) AS rnk FROM prov) r WHERE rnk = 1;

-- คำถามท้ายบท: INNER JOIN จะตัดลูกค้าที่ไม่มี order (ปิยะ, อนุชา) ทิ้ง
-- ถ้าใส่ status <> 'cancelled' ใน WHERE แถวที่ order เป็น NULL จะถูกตัด (NULL <> 'cancelled' ไม่เป็นจริง) = กลายเป็น INNER JOIN
