-- =====================================================================
-- Лабораторная работа №1. Структура БД маркетплейса.
-- Скрипт идемпотентен: повторный запуск полностью пересоздаёт схему.
-- Выполнять ЦЕЛИКОМ через Alt+X (Execute SQL Script), не Ctrl+Enter.
-- =====================================================================

DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS product_images CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS user_addresses CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- =====================================================================
-- 1. Пользователи
-- =====================================================================
CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    phone         TEXT,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE users IS 'Покупатели маркетплейса';
COMMENT ON COLUMN users.email IS 'Уникальный email, используется для входа';

-- =====================================================================
-- 2. Адреса пользователей (1:N к users)
-- =====================================================================
CREATE TABLE user_addresses (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    country     TEXT NOT NULL,
    city        TEXT NOT NULL,
    street      TEXT NOT NULL,
    postal_code TEXT,
    is_default  BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE user_addresses IS 'Адреса доставки пользователя; при удалении пользователя удаляются каскадно';

-- =====================================================================
-- 3. Продавцы
-- =====================================================================
CREATE TABLE sellers (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name  TEXT NOT NULL UNIQUE,
    contact_email TEXT NOT NULL UNIQUE,
    rating        NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE sellers IS 'Продавцы, размещающие товары на маркетплейсе';

-- =====================================================================
-- 4. Категории (иерархия — самоссылка)
-- =====================================================================
CREATE TABLE categories (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES categories(id) ON DELETE RESTRICT,
    name      TEXT NOT NULL UNIQUE
);

COMMENT ON TABLE categories IS 'Дерево категорий товаров; parent_id = NULL — корневая категория';

-- =====================================================================
-- 5. Товары
-- =====================================================================
CREATE TABLE products (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id   BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    title       TEXT NOT NULL,
    description TEXT,
    price       NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE products IS 'Товары; удаление продавца или категории с товарами запрещено (RESTRICT)';

-- =====================================================================
-- 6. Изображения товаров (1:N к products)
-- =====================================================================
CREATE TABLE product_images (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    url        TEXT NOT NULL,
    position   INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE product_images IS 'Галерея изображений товара; удаляются вместе с товаром';

-- =====================================================================
-- 7. Корзины (1:1 к users)
-- =====================================================================
CREATE TABLE carts (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE carts IS 'Корзина пользователя; UNIQUE(user_id) задаёт связь 1:1';

-- =====================================================================
-- 8. Позиции корзины (M:N между carts и products)
-- =====================================================================
CREATE TABLE cart_items (
    cart_id    BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

COMMENT ON TABLE cart_items IS 'Ассоциативная таблица связи многие-ко-многим между корзинами и товарами';

-- =====================================================================
-- 9. Заказы
-- =====================================================================
CREATE TABLE orders (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    address_id BIGINT NOT NULL REFERENCES user_addresses(id) ON DELETE RESTRICT,
    status     TEXT NOT NULL DEFAULT 'created'
               CHECK (status IN ('created', 'paid', 'shipped', 'delivered', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE orders IS 'Заказы пользователей; удаление пользователя с заказами запрещено, чтобы не терять историю';

-- =====================================================================
-- 10. Позиции заказа (M:N между orders и products)
-- =====================================================================
CREATE TABLE order_items (
    order_id   BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

COMMENT ON TABLE order_items IS 'Ассоциативная таблица позиций заказа; unit_price фиксирует цену на момент покупки';

-- =====================================================================
-- 11. Оплаты (1:1 к orders)
-- =====================================================================
CREATE TABLE payments (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    amount   NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method   TEXT NOT NULL CHECK (method IN ('card', 'cash', 'bank_transfer')),
    status   TEXT NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    paid_at  TIMESTAMPTZ
);

COMMENT ON TABLE payments IS 'Оплата заказа; UNIQUE(order_id) задаёт связь 1:1 с orders';

-- =====================================================================
-- 12. Отзывы (M:N между users и products с атрибутами)
-- =====================================================================
CREATE TABLE reviews (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, user_id)
);

COMMENT ON TABLE reviews IS 'Отзывы; UNIQUE(product_id, user_id) — один пользователь оставляет один отзыв на товар';
