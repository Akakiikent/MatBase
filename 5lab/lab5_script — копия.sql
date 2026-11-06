-- Лабораторная работа №5. Транзакции, целостность данных и серверная логика
-- Выполняется в базе marketplace_lab5, созданной скриптом lab5_database.sql.
-- Скрипт ИЗМЕНЯЕТ данные (заказы, остатки, цены, отзывы), поэтому для результатов,
-- как в отчёте, пересоздайте базу lab5_database.sql перед запуском.
-- Запускайте целиком (в DBeaver: Alt+X).
SET search_path TO public;

-- Блок Q1a
SELECT (SELECT COUNT(*) FROM orders) AS orders_total,
       (SELECT quantity FROM stock WHERE product_id = 7) AS stock_product_7;

BEGIN;
WITH new_order AS (
    INSERT INTO orders (user_id, status) VALUES (5, 'new') RETURNING id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT new_order.id, p.id, 2, p.price
FROM new_order, products AS p
WHERE p.id = 7;

UPDATE stock SET quantity = quantity - 2 WHERE product_id = 7;
COMMIT;

SELECT (SELECT COUNT(*) FROM orders) AS orders_total,
       (SELECT quantity FROM stock WHERE product_id = 7) AS stock_product_7;
-- Блок Q1b
BEGIN;
WITH new_order AS (
    INSERT INTO orders (user_id, status) VALUES (5, 'new') RETURNING id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT new_order.id, p.id, 3, p.price
FROM new_order, products AS p
WHERE p.id = 7;

UPDATE stock SET quantity = quantity - 3 WHERE product_id = 7;

SELECT 'внутри транзакции' AS moment,
       (SELECT COUNT(*) FROM orders) AS orders_total,
       (SELECT quantity FROM stock WHERE product_id = 7) AS stock_product_7;

ROLLBACK;     -- обнаружили ошибку: отменяем всё

SELECT 'после ROLLBACK' AS moment,
       (SELECT COUNT(*) FROM orders) AS orders_total,
       (SELECT quantity FROM stock WHERE product_id = 7) AS stock_product_7;
-- Блок Q1c
BEGIN;
UPDATE stock SET quantity = quantity - 1 WHERE product_id = 8;
SAVEPOINT after_first;
UPDATE stock SET quantity = quantity - 5 WHERE product_id = 9;

SELECT product_id, quantity FROM stock
WHERE product_id IN (8, 9) ORDER BY product_id;

ROLLBACK TO SAVEPOINT after_first;    -- отменяем только второе изменение

SELECT product_id, quantity FROM stock
WHERE product_id IN (8, 9) ORDER BY product_id;
COMMIT;
-- Блок F2
CREATE OR REPLACE FUNCTION place_order(p_user BIGINT, p_product BIGINT,
                                       p_qty INT)
RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_price    NUMERIC(12,2);
    v_stock    INTEGER;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть положительным: %', p_qty;
    END IF;

    SELECT price INTO v_price
    FROM products WHERE id = p_product AND is_active;
    IF v_price IS NULL THEN
        RAISE EXCEPTION 'Товар % не найден или не продаётся', p_product;
    END IF;

    -- блокируем строку остатка: защита от одновременной покупки
    SELECT quantity INTO v_stock
    FROM stock WHERE product_id = p_product FOR UPDATE;
    IF v_stock IS NULL OR v_stock < p_qty THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%, нужно %, есть %)',
                        p_product, p_qty, COALESCE(v_stock, 0);
    END IF;

    INSERT INTO orders (user_id, status, total_amount)
    VALUES (p_user, 'new', v_price * p_qty)
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product, p_qty, v_price);

    UPDATE stock
    SET quantity = quantity - p_qty, updated_at = now()
    WHERE product_id = p_product;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;
-- Блок Q2a
SELECT place_order(10, 7, 2) AS new_order_id;

SELECT o.id AS order_id, o.user_id, o.total_amount,
       oi.quantity, oi.unit_price, s.quantity AS stock_left
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.id
JOIN stock AS s ON s.product_id = oi.product_id
WHERE o.id = (SELECT MAX(id) FROM orders);
-- Блок Q2b
DO $$
DECLARE
    v_before BIGINT;
    v_after  BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_before FROM orders;
    BEGIN
        PERFORM place_order(10, 7, 1000);       -- на складе столько нет
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка перехвачена: %', SQLERRM;
    END;
    SELECT COUNT(*) INTO v_after FROM orders;
    RAISE NOTICE 'Заказов до: %, после: % (изменений нет)', v_before, v_after;
END $$;

SELECT quantity AS stock_product_7 FROM stock WHERE product_id = 7;
-- Блок F3
CREATE OR REPLACE FUNCTION seller_revenue_for_period(
    p_seller BIGINT, p_from DATE, p_to DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_revenue NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
    INTO v_revenue
    FROM order_items AS oi
    JOIN products AS p ON p.id = oi.product_id
    JOIN orders   AS o ON o.id = oi.order_id
    WHERE p.seller_id = p_seller
      AND o.created_at >= p_from
      AND o.created_at <  p_to + 1;    -- включая последний день
    RETURN v_revenue;
END;
$$ LANGUAGE plpgsql STABLE;
-- Блок Q3
SELECT s.id, s.company_name,
       seller_revenue_for_period(s.id, DATE '2026-09-01',
                                 DATE '2026-09-30') AS revenue_sept
FROM sellers AS s
ORDER BY s.id;

SELECT SUM(oi.quantity * oi.unit_price) AS total_sept
FROM order_items AS oi
JOIN orders AS o ON o.id = oi.order_id
WHERE o.created_at >= DATE '2026-09-01' AND o.created_at < DATE '2026-10-01';
-- Блок F4
CREATE OR REPLACE FUNCTION log_price_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO price_audit (product_id, old_price, new_price)
    VALUES (OLD.id, OLD.price, NEW.price);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_price_audit ON products;
CREATE TRIGGER trg_price_audit
AFTER UPDATE OF price ON products
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION log_price_change();
-- Блок Q4
UPDATE products SET price = ROUND(price * 1.10, 2) WHERE id IN (7, 8);
UPDATE products SET price = price WHERE id = 9;   -- цена та же

SELECT product_id, old_price, new_price,
       ROUND(100 * (new_price - old_price) / old_price, 1) AS change_percent
FROM price_audit
ORDER BY id;
-- Блок F5
CREATE OR REPLACE FUNCTION refresh_product_rating()
RETURNS TRIGGER AS $$
DECLARE
    v_product BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_product := OLD.product_id;
    ELSE
        v_product := NEW.product_id;
    END IF;

    UPDATE products
    SET rating = (SELECT ROUND(AVG(score), 2) FROM reviews
                  WHERE product_id = v_product)
    WHERE id = v_product;

    RETURN NULL;       -- для AFTER-триггера значение не используется
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_refresh_rating ON reviews;
CREATE TRIGGER trg_refresh_rating
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_product_rating();
-- Блок Q5
SELECT rating AS rating_before FROM products WHERE id = 7;

INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (1, 7, 5, 'Отлично');
SELECT rating AS after_first_review_5 FROM products WHERE id = 7;

INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (2, 7, 3, 'Нормально');
SELECT rating AS after_second_review_3 FROM products WHERE id = 7;

UPDATE reviews SET score = 1 WHERE user_id = 1 AND product_id = 7;
SELECT rating AS after_score_5_changed_to_1 FROM products WHERE id = 7;

DELETE FROM reviews WHERE user_id = 1 AND product_id = 7;
SELECT rating AS after_delete FROM products WHERE id = 7;
