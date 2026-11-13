-- Лабораторная работа №6. Современные возможности PostgreSQL и оптимизация запросов
-- База: marketplace (PostgreSQL 16). Скрипт можно запускать повторно.

-- Очистка (чтобы скрипт выполнялся заново с нуля)
DROP TABLE IF EXISTS bulk_no_index, bulk_with_index;
DROP INDEX IF EXISTS idx_products_cat_price, idx_order_items_product, idx_orders_user, idx_products_attrs;
ALTER TABLE products DROP COLUMN IF EXISTS attributes;


-- Задание 1. Столбец JSONB для характеристик товаров
ALTER TABLE products ADD COLUMN attributes JSONB;

UPDATE products SET attributes = jsonb_build_object(
    'color', (ARRAY['black','white','blue','red'])[1 + (id / 9) % 4],
    'memory_gb', (ARRAY[64,128,256])[1 + (id / 9) % 3],
    'screen', (ARRAY[6.1,6.5,6.7])[1 + (id / 9) % 3])
WHERE category_id = 4;

UPDATE products SET attributes = jsonb_build_object(
    'color', (ARRAY['gray','silver','black'])[1 + (id / 9) % 3],
    'ram_gb', (ARRAY[8,16,32])[1 + (id / 9) % 3])
WHERE category_id = 5;

UPDATE products SET attributes = jsonb_build_object(
    'author', 'Автор ' || ((id / 9) % 100),
    'pages', 100 + (id / 9) % 500,
    'language', (ARRAY['ru','en'])[1 + (id / 9) % 2])
WHERE category_id IN (6, 7);

UPDATE products SET attributes = jsonb_build_object(
    'size', (ARRAY['S','M','L','XL'])[1 + (id / 9) % 4],
    'color', (ARRAY['black','white','blue','red'])[1 + (id / 9) % 4],
    'material', (ARRAY['cotton','polyester','leather'])[1 + (id / 9) % 3])
WHERE category_id IN (8, 9, 12);

UPDATE products SET attributes = jsonb_build_object(
    'color', (ARRAY['black','white','pink'])[1 + (id / 9) % 3],
    'wireless', ((id / 9) % 2 = 0))
WHERE category_id IN (10, 11);

UPDATE products SET attributes = '{"color": "black", "weight": 180}'
WHERE id = 7;

SELECT id, category_id, attributes
FROM products
WHERE id BETWEEN 1 AND 9
ORDER BY id;


-- Задание 2. Запросы к полям JSONB (->, ->>, @>, ?)
SELECT id, title,
       attributes -> 'color'  AS color_json,
       attributes ->> 'color' AS color_text
FROM products
WHERE id BETWEEN 1 AND 5
ORDER BY id;

SELECT title,
       attributes ->> 'memory_gb' AS memory_gb,
       attributes ->> 'screen'    AS screen
FROM products
WHERE category_id = 4
ORDER BY id
LIMIT 5;

SELECT id, title, price
FROM products
WHERE attributes @> '{"color": "black", "memory_gb": 128}'
ORDER BY id
LIMIT 5;

SELECT count(*) AS black_128gb
FROM products
WHERE attributes @> '{"color": "black", "memory_gb": 128}';

SELECT count(*) AS books_with_pages
FROM products
WHERE attributes ? 'pages';


-- Задание 3. Планы запросов ДО индексов (Seq Scan)
EXPLAIN ANALYZE
SELECT title, price FROM products
WHERE category_id = 5 AND price < 3000;

EXPLAIN ANALYZE
SELECT * FROM order_items
WHERE product_id = 7;

EXPLAIN ANALYZE
SELECT id, total_amount FROM orders
WHERE user_id = 100;


-- Задание 4. B-tree индексы и планы ПОСЛЕ
CREATE INDEX idx_products_cat_price ON products(category_id, price);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_orders_user ON orders(user_id);
ANALYZE products;
ANALYZE order_items;
ANALYZE orders;

EXPLAIN ANALYZE
SELECT title, price FROM products
WHERE category_id = 5 AND price < 3000;

EXPLAIN ANALYZE
SELECT * FROM order_items
WHERE product_id = 7;

EXPLAIN ANALYZE
SELECT id, total_amount FROM orders
WHERE user_id = 100;


-- Задание 5. GIN-индекс для JSONB
EXPLAIN ANALYZE
SELECT title FROM products
WHERE attributes @> '{"color": "red", "memory_gb": 256}';

CREATE INDEX idx_products_attrs ON products USING GIN (attributes);
ANALYZE products;

EXPLAIN ANALYZE
SELECT title FROM products
WHERE attributes @> '{"color": "red", "memory_gb": 256}';


-- Задание 6. Скорость вставки: таблицы без индексов и с индексами
CREATE TABLE bulk_no_index (
    id         INTEGER,
    product_id INTEGER,
    qty        INTEGER,
    attrs      JSONB
);
CREATE TABLE bulk_with_index (
    id         INTEGER,
    product_id INTEGER,
    qty        INTEGER,
    attrs      JSONB
);
CREATE INDEX idx_bulk_id      ON bulk_with_index(id);
CREATE INDEX idx_bulk_product ON bulk_with_index(product_id);
CREATE INDEX idx_bulk_qty     ON bulk_with_index(qty);
CREATE INDEX idx_bulk_attrs   ON bulk_with_index USING GIN (attrs);

EXPLAIN ANALYZE
INSERT INTO bulk_no_index
SELECT g, g % 50000, 1 + g % 10,
       jsonb_build_object('color', (ARRAY['black','white','red'])[1 + g % 3])
FROM generate_series(1, 200000) g;

EXPLAIN ANALYZE
INSERT INTO bulk_with_index
SELECT g, g % 50000, 1 + g % 10,
       jsonb_build_object('color', (ARRAY['black','white','red'])[1 + g % 3])
FROM generate_series(1, 200000) g;

SELECT relname AS table_name,
       pg_size_pretty(pg_table_size(oid))   AS table_size,
       pg_size_pretty(pg_indexes_size(oid)) AS indexes_size
FROM pg_class
WHERE relname IN ('bulk_no_index', 'bulk_with_index')
ORDER BY relname;


-- Задание 7. Список созданных индексов
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('products', 'order_items', 'orders')
  AND indexname NOT LIKE '%pkey'
ORDER BY indexname;
