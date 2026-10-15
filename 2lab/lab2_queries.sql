-- =====================================================================
-- Лабораторная работа №2. Базовые SQL-запросы и фильтрация данных.
-- Выполнять на базе, где уже создана схема из marketplace_schema.sql
-- (лабораторная работа №1). Запускать целиком через Alt+X в DBeaver.
-- =====================================================================

-- =====================================================================
-- Задание 1. Наполнение таблиц тестовыми данными
-- =====================================================================

-- Продавцы (вводим вручную, их немного)
INSERT INTO sellers (company_name, contact_email)
VALUES
    ('ТехноМир', 'techno@mail.ru'),
    ('Электроника+', 'e-plus@mail.ru');

-- Категории
INSERT INTO categories (name)
VALUES
    ('Электроника'),
    ('Книги'),
    ('Одежда');

-- Пользователи (100 штук, генерируем через generate_series)
INSERT INTO users (full_name, email)
SELECT
    'Пользователь ' || g,
    'user' || g || '@mail.ru'
FROM generate_series(1, 100) AS g;

-- Товары (1000 штук, цена и категория — случайные)
INSERT INTO products (seller_id, category_id, title, price, is_active)
SELECT
    (random() * 1 + 1)::int,            -- seller_id: 1 или 2
    (random() * 2 + 1)::int,            -- category_id: 1, 2 или 3
    'Товар ' || g,
    (random() * 9000 + 1000)::numeric(12,2), -- цена от 1000 до 10000
    TRUE
FROM generate_series(1, 1000) AS g;

-- Проверка: сколько строк получилось в каждой таблице
SELECT 'sellers' AS table_name, COUNT(*) FROM sellers
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products;


-- =====================================================================
-- Задание 2. Запрос без повторов (DISTINCT) + псевдонимы столбцов
-- =====================================================================
SELECT DISTINCT
    category_id AS category,
    is_active   AS active
FROM products;


-- =====================================================================
-- Задание 3. Запрос с условиями AND / OR в скобках + BETWEEN
-- =====================================================================
SELECT title, price, category_id
FROM products
WHERE (category_id = 1 OR category_id = 2)
  AND price BETWEEN 2000 AND 8000
  AND is_active = TRUE;


-- =====================================================================
-- Задание 4. Условия IN, LIKE/ILIKE, IS NULL
-- =====================================================================

-- 4.1 IN — товары сразу из нескольких категорий
SELECT title, category_id
FROM products
WHERE category_id IN (1, 3);

-- 4.2 ILIKE — поиск по кусочку названия без учёта регистра
SELECT title
FROM products
WHERE title ILIKE '%1%';

-- 4.3 IS NULL — товары без описания
SELECT title
FROM products
WHERE description IS NULL;


-- =====================================================================
-- Задание 5. Сортировка по двум столбцам в разных направлениях
-- =====================================================================
SELECT title, category_id, price
FROM products
ORDER BY category_id ASC, price DESC;


-- =====================================================================
-- Задание 6. Постраничный вывод (LIMIT / OFFSET)
-- =====================================================================

-- Страница 1 (первые 20 строк)
SELECT title, price
FROM products
ORDER BY id
LIMIT 20 OFFSET 0;

-- Страница 2 (следующие 20 строк)
SELECT title, price
FROM products
ORDER BY id
LIMIT 20 OFFSET 20;
