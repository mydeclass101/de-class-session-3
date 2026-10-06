-- เฉลย A2: SELECT & Aggregation (รัน A2_seed.sql ก่อน)
USE lab_student;

-- 1  (30 ออเดอร์, 56 แก้ว, 3,210 บาท)
SELECT COUNT(*) AS orders, SUM(qty) AS cups, SUM(qty * unit_price - discount) AS net_sales FROM tea_orders;
-- 2
SELECT order_id, menu, qty, qty * unit_price - discount AS net
FROM tea_orders ORDER BY net DESC, order_id LIMIT 5;
-- 3
SELECT channel, SUM(qty * unit_price - discount) AS net_sales
FROM tea_orders GROUP BY channel ORDER BY net_sales DESC;
-- 4
SELECT menu, SUM(qty) AS cups FROM tea_orders GROUP BY menu HAVING SUM(qty) >= 8 ORDER BY cups DESC;
-- 5
SELECT ROUND(100 * AVG(member_id IS NOT NULL), 1) AS member_pct FROM tea_orders;
-- 6
SELECT DATE(ordered_at) AS sale_date, COUNT(*) AS orders, SUM(qty * unit_price - discount) AS net_sales
FROM tea_orders GROUP BY sale_date ORDER BY sale_date;
-- 7
SELECT size, sweetness, SUM(qty) AS cups FROM tea_orders GROUP BY size, sweetness ORDER BY size, cups DESC;
-- 8  AVG/COUNT(col) ข้าม NULL อัตโนมัติ: ค่าเฉลี่ยคิดจากออเดอร์ที่ให้คะแนนเท่านั้น (ไม่ใช่นับ NULL เป็น 0)
SELECT branch, ROUND(AVG(rating), 2) AS avg_rating, COUNT(rating) AS rated_orders, COUNT(*) AS all_orders
FROM tea_orders GROUP BY branch;
-- 9
SELECT branch,
       SUM(CASE WHEN channel = 'walk_in' THEN qty * unit_price - discount ELSE 0 END) AS walk_in,
       SUM(CASE WHEN channel = 'grab'    THEN qty * unit_price - discount ELSE 0 END) AS grab,
       SUM(CASE WHEN channel = 'lineman' THEN qty * unit_price - discount ELSE 0 END) AS lineman
FROM tea_orders GROUP BY branch;
-- 10
SELECT order_id, menu, discount FROM tea_orders WHERE discount > 0 AND member_id IS NULL;
-- 11
SELECT CASE WHEN TIME(ordered_at) < '11:00' THEN '1) เช้า'
            WHEN TIME(ordered_at) < '14:00' THEN '2) กลางวัน'
            WHEN TIME(ordered_at) < '18:00' THEN '3) บ่าย'
            ELSE '4) เย็น' END AS daypart,
       COUNT(*) AS orders, SUM(qty * unit_price - discount) AS net_sales
FROM tea_orders GROUP BY daypart ORDER BY daypart;
-- 12 (รันซ้ำได้: DELETE ก่อน INSERT หรือใช้ ON DUPLICATE KEY UPDATE)
CREATE TABLE IF NOT EXISTS daily_channel_sales (
    sale_date DATE          NOT NULL,
    channel   VARCHAR(10)   NOT NULL,
    orders    INT           NOT NULL,
    cups      INT           NOT NULL,
    net_sales DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (sale_date, channel)
);
INSERT INTO daily_channel_sales (sale_date, channel, orders, cups, net_sales)
SELECT * FROM (
    SELECT DATE(ordered_at) AS sale_date, channel, COUNT(*) AS orders, SUM(qty) AS cups,
           SUM(qty * unit_price - discount) AS net_sales
    FROM tea_orders GROUP BY DATE(ordered_at), channel
) AS src
ON DUPLICATE KEY UPDATE orders = src.orders, cups = src.cups, net_sales = src.net_sales;
SELECT * FROM daily_channel_sales ORDER BY sale_date, channel;
