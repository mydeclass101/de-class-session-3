-- เฉลย A4: วิเคราะห์ข้อมูลจริง (ตัวเลขขึ้นกับข้อมูลที่ generate จึงเฉลยเป็น query)
USE ecommerce;

-- 1  Top 5 จังหวัด ปี 2026 + % ของทั้งปี (SUM() OVER คำนวณก่อน LIMIT จึงได้ผลรวมทุกจังหวัด)
WITH prov AS (
    SELECT pr.name_th, pr.name_en, SUM(o.total_amount) AS gmv
    FROM orders o
    JOIN customer_addresses a ON a.address_id = o.shipping_address_id
    JOIN provinces pr         ON pr.province_id = a.province_id
    WHERE o.status <> 'cancelled' AND o.ordered_at >= '2026-01-01' AND o.ordered_at < '2027-01-01'
    GROUP BY pr.province_id, pr.name_th, pr.name_en
)
SELECT name_th, name_en, gmv, ROUND(100 * gmv / SUM(gmv) OVER (), 2) AS pct_of_year
FROM prov ORDER BY gmv DESC LIMIT 5;

-- 2  AOV รายเดือน + MoM
WITH m AS (
    SELECT DATE_FORMAT(ordered_at, '%Y-%m') AS month, SUM(total_amount) / COUNT(*) AS aov
    FROM orders WHERE status <> 'cancelled' GROUP BY month
)
SELECT month, ROUND(aov, 2) AS aov,
       ROUND(100 * (aov / LAG(aov) OVER (ORDER BY month) - 1), 2) AS mom_pct
FROM m ORDER BY month;

-- 3  Top 3 แบรนด์ต่อหมวดหลัก ใน 90 วันล่าสุด (อิงเวลาของข้อมูล ไม่ใช่ NOW())
WITH bounds AS (SELECT MAX(ordered_at) - INTERVAL 90 DAY AS since FROM orders),
brand_sales AS (
    SELECT top.name_en AS category, b.brand_name, SUM(oi.line_total) AS revenue
    FROM order_items oi
    JOIN orders o       ON o.order_id = oi.order_id AND o.status <> 'cancelled'
    JOIN products p     ON p.product_id = oi.product_id
    JOIN brands b       ON b.brand_id = p.brand_id
    JOIN categories sub ON sub.category_id = p.category_id
    JOIN categories top ON top.category_id = sub.parent_category_id
    WHERE o.ordered_at >= (SELECT since FROM bounds)
    GROUP BY top.name_en, b.brand_id, b.brand_name
)
SELECT category, rnk, brand_name, revenue
FROM (SELECT bs.*, DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk FROM brand_sales bs) r
WHERE rnk <= 3 ORDER BY category, rnk;

-- 4  WELCOME100 กับการซื้อซ้ำ
WITH o AS (
    SELECT customer_id, coupon_id,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY ordered_at, order_id) AS rn,
           COUNT(*)     OVER (PARTITION BY customer_id)                              AS n_orders
    FROM orders WHERE status <> 'cancelled'
),
first_order AS (
    SELECT o.customer_id, o.n_orders, COALESCE(c.coupon_code = 'WELCOME100', 0) AS used_welcome
    FROM o LEFT JOIN coupons c ON c.coupon_id = o.coupon_id
    WHERE o.rn = 1
)
SELECT IF(used_welcome, 'used WELCOME100', 'no welcome coupon') AS grp,
       COUNT(*) AS customers, ROUND(100 * AVG(n_orders >= 2), 1) AS repeat_pct
FROM first_order GROUP BY used_welcome;

-- 5  การจัดส่งตามภาคปลายทาง
WITH s AS (
    SELECT pr.region,
           TIMESTAMPDIFF(MINUTE, sh.shipped_at, sh.delivered_at) / 60 AS hours,
           DATE(sh.delivered_at) <= sh.estimated_delivery_date        AS on_time
    FROM shipments sh
    JOIN orders o             ON o.order_id = sh.order_id
    JOIN customer_addresses a ON a.address_id = o.shipping_address_id
    JOIN provinces pr         ON pr.province_id = a.province_id
    WHERE sh.delivered_at IS NOT NULL
)
SELECT region, COUNT(*) AS delivered, ROUND(AVG(hours), 1) AS avg_hours, ROUND(100 * AVG(on_time), 1) AS on_time_pct
FROM s GROUP BY region ORDER BY avg_hours;

-- 6  Churn risk
WITH ref AS (SELECT MAX(ordered_at) AS as_of FROM orders),
cust AS (
    SELECT customer_id, COUNT(*) AS n_orders, SUM(total_amount) AS spend, MAX(ordered_at) AS last_order
    FROM orders WHERE status <> 'cancelled' GROUP BY customer_id
),
risk AS (
    SELECT c.*, cu.customer_code
    FROM cust c JOIN customers cu ON cu.customer_id = c.customer_id
    WHERE c.n_orders >= 3 AND c.last_order < (SELECT as_of FROM ref) - INTERVAL 90 DAY
)
SELECT (SELECT COUNT(*) FROM risk) AS n_at_risk, customer_code, n_orders, spend, last_order
FROM risk ORDER BY spend DESC LIMIT 10;

-- 7  Daily orders พ.ย. 2025 + MA7 + spike
WITH RECURSIVE days AS (
    SELECT DATE('2025-11-01') AS d
    UNION ALL SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2025-11-30'
),
daily AS (
    SELECT DATE(ordered_at) AS d, COUNT(*) AS orders
    FROM orders WHERE ordered_at >= '2025-11-01' AND ordered_at < '2025-12-01' GROUP BY DATE(ordered_at)
),
filled AS (
    SELECT days.d, COALESCE(daily.orders, 0) AS orders FROM days LEFT JOIN daily ON daily.d = days.d
)
SELECT d, orders,
       ROUND(AVG(orders) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS ma7,
       orders > 2 * AVG(orders) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS is_spike
FROM filled ORDER BY d;

-- 8  ขายดีแต่ของหมดทุกคลัง
WITH ref AS (SELECT MAX(ordered_at) - INTERVAL 30 DAY AS since FROM orders),
sold AS (
    SELECT oi.product_id, SUM(oi.quantity) AS units_30d
    FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
    WHERE o.ordered_at >= (SELECT since FROM ref) AND o.status <> 'cancelled'
    GROUP BY oi.product_id
),
ranked AS (SELECT product_id, units_30d, RANK() OVER (ORDER BY units_30d DESC) AS rnk FROM sold),
out_everywhere AS (
    SELECT product_id FROM inventory GROUP BY product_id HAVING SUM(quantity_on_hand) = 0
)
SELECT p.sku, p.product_name, r.units_30d, r.rnk
FROM ranked r
JOIN out_everywhere x ON x.product_id = r.product_id
JOIN products p       ON p.product_id = r.product_id AND p.status = 'active'
WHERE r.rnk <= 200
ORDER BY r.rnk;
