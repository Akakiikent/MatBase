
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM order_items) THEN
    RAISE EXCEPTION 'Нет заказов: сначала выполните скрипт ЛР №3';
  END IF;
END $$;

-- Запрос Q1
SELECT category, title, price, rn, rnk, dense_rnk
FROM (
    SELECT c.name AS category, p.title, p.price,
           ROW_NUMBER() OVER w AS rn,
           RANK()       OVER w AS rnk,
           DENSE_RANK() OVER w AS dense_rnk
    FROM products AS p
    JOIN categories AS c ON c.id = p.category_id
    WINDOW w AS (PARTITION BY p.category_id ORDER BY p.price DESC)
) AS t
WHERE category IN ('Смартфоны', 'Ноутбуки') AND rn <= 3
ORDER BY category, rn;
-- Запрос Q1b
SELECT x,
       ROW_NUMBER() OVER w AS rn,
       RANK()       OVER w AS rnk,
       DENSE_RANK() OVER w AS dense_rnk
FROM (VALUES (900), (800), (800), (700)) AS t(x)
WINDOW w AS (ORDER BY x DESC);
-- Запрос Q2
WITH ranked AS (
    SELECT c.name AS category, p.title, p.price,
           ROW_NUMBER() OVER (PARTITION BY p.category_id
                              ORDER BY p.price DESC) AS rn
    FROM products AS p
    JOIN categories AS c ON c.id = p.category_id
)
SELECT category, rn, title, price
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;
-- Запрос Q3
WITH daily AS (
    SELECT o.created_at::date AS day,
           SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT day, day_revenue,
       SUM(day_revenue) OVER (ORDER BY day
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM daily
ORDER BY day;
-- Запрос Q3b
WITH daily AS (
    SELECT o.created_at::date AS day,
           SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT (SELECT running_total FROM (
            SELECT day, SUM(day_revenue) OVER (ORDER BY day) AS running_total
            FROM daily) AS r
        ORDER BY day DESC LIMIT 1) AS last_running_total,
       (SELECT SUM(quantity * unit_price) FROM order_items) AS total_revenue;
-- Запрос Q4
WITH cat_seller AS (
    SELECT c.name AS category, s.company_name AS seller,
           SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items AS oi
    JOIN products   AS p ON p.id = oi.product_id
    JOIN categories AS c ON c.id = p.category_id
    JOIN sellers    AS s ON s.id = p.seller_id
    GROUP BY c.name, s.company_name
)
SELECT category, seller, revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (PARTITION BY category), 1)
           AS share_percent
FROM cat_seller
ORDER BY category, share_percent DESC;
-- Запрос Q5
WITH daily AS (
    SELECT o.created_at::date AS day,
           SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT day, day_revenue,
       LAG(day_revenue)  OVER w AS prev_day,
       day_revenue - LAG(day_revenue) OVER w AS growth,
       ROUND(100 * (day_revenue - LAG(day_revenue) OVER w)
             / LAG(day_revenue) OVER w, 1) AS growth_percent,
       LEAD(day_revenue) OVER w AS next_day
FROM daily
WINDOW w AS (ORDER BY day)
ORDER BY day;
-- Запрос Q6a
SELECT p.id, p.title, p.price,
       ROUND(a.avg_price, 2) AS category_avg,
       ROUND(p.price - a.avg_price, 2) AS diff
FROM products AS p
JOIN (SELECT category_id, AVG(price) AS avg_price
      FROM products
      GROUP BY category_id) AS a ON a.category_id = p.category_id
ORDER BY p.id
LIMIT 5;
-- Запрос Q6b
SELECT p.id, p.title, p.price,
       ROUND(AVG(p.price) OVER w, 2) AS category_avg,
       ROUND(p.price - AVG(p.price) OVER w, 2) AS diff
FROM products AS p
WINDOW w AS (PARTITION BY p.category_id)
ORDER BY p.id
LIMIT 5;
-- Запрос Q6c
SELECT COUNT(*) AS differing_rows
FROM (
    (SELECT p.id, ROUND(p.price - a.avg_price, 2) AS diff
     FROM products AS p
     JOIN (SELECT category_id, AVG(price) AS avg_price
           FROM products GROUP BY category_id) AS a
       ON a.category_id = p.category_id
     EXCEPT
     SELECT p.id, ROUND(p.price - AVG(p.price) OVER (PARTITION BY p.category_id), 2)
     FROM products AS p)
    UNION ALL
    (SELECT p.id, ROUND(p.price - AVG(p.price) OVER (PARTITION BY p.category_id), 2)
     FROM products AS p
     EXCEPT
     SELECT p.id, ROUND(p.price - a.avg_price, 2)
     FROM products AS p
     JOIN (SELECT category_id, AVG(price) AS avg_price
           FROM products GROUP BY category_id) AS a
       ON a.category_id = p.category_id)
) AS x;

