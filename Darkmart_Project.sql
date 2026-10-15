CREATE TABLE stores (
  store_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  city       VARCHAR(50)  NOT NULL,
  area       VARCHAR(50),
  opened_on  DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE categories (
  category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE,
  parent_id   INT REFERENCES categories(category_id)
);



CREATE TABLE products (
  product_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           VARCHAR(120) NOT NULL,
  category_id    INT NOT NULL REFERENCES categories(category_id),
  brand          VARCHAR(60),
  mrp            NUMERIC(8,2) NOT NULL CHECK (mrp > 0),
  is_perishable  BOOLEAN NOT NULL DEFAULT FALSE,
  attributes     JSONB
);

CREATE TABLE inventory (
  store_id       INT REFERENCES stores(store_id),
  product_id     INT REFERENCES products(product_id),
  quantity       INT NOT NULL CHECK (quantity >= 0),
  reorder_level  INT NOT NULL DEFAULT 10,
  PRIMARY KEY (store_id, product_id)
);


CREATE TABLE customers (
  customer_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  phone        VARCHAR(15) UNIQUE NOT NULL,
  city         VARCHAR(50),
  signup_date  DATE NOT NULL
);

CREATE TABLE riders (
  rider_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  store_id   INT NOT NULL REFERENCES stores(store_id),
  joined_on  DATE NOT NULL
);

CREATE TABLE orders (
  order_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id     INT NOT NULL REFERENCES customers(customer_id),
  store_id        INT NOT NULL REFERENCES stores(store_id),
  rider_id        INT REFERENCES riders(rider_id),
  ordered_at      TIMESTAMP NOT NULL,
  delivered_at    TIMESTAMP,
  status          VARCHAR(20) NOT NULL CHECK (status IN ('placed','delivered','cancelled')),
  payment_method  VARCHAR(20) NOT NULL
);

CREATE TABLE order_items (
  order_id    INT REFERENCES orders(order_id),
  product_id  INT REFERENCES products(product_id),
  quantity    INT NOT NULL CHECK (quantity > 0),
  unit_price  NUMERIC(8,2) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

INSERT INTO stores (name, city, area) VALUES
 ('DarkMart Kanhangad Central','Kanhangad','Central'),
 ('DarkMart Kasaragod Town','Kasaragod','Town'),
 ('DarkMart Kannur Fort','Kannur','Fort'),
 ('DarkMart Mangaluru Hampankatta','Mangaluru','Hampankatta'),
 ('DarkMart Kozhikode Beach','Kozhikode','Beach');

 select * from stores;

 INSERT INTO categories (name, parent_id) VALUES ('Grocery', NULL), ('Dairy', 1), ('Beverages', 1), ('Snacks', 1), ('Fruits & Veg', 1);

select * from categories;

INSERT INTO products (name, category_id, brand, mrp, is_perishable, attributes) VALUES
 ('Toned Milk 500ml', 2, 'Milma', 29, TRUE,  '{"veg": true, "pack": "pouch"}'),
 ('Curd 400g',        2, 'Milma', 35, TRUE,  '{"veg": true, "pack": "cup"}'),
 ('Banana Chips 200g',4, 'Local', 60, FALSE, '{"veg": true, "spicy": false}'),
 ('Cola 750ml',       3, 'Generic', 40, FALSE,'{"veg": true}'),
 ('Tomato 1kg',       5, 'Fresh', 45, TRUE,  '{"veg": true, "organic": false}');

 select * from products;

 INSERT INTO products (name, category_id, brand, mrp, is_perishable)
SELECT 'Product ' || g, 1 + (g % 5), 'Brand ' || (g % 8), 10 + (random()*290)::int, (g % 3 = 0)
FROM generate_series(1,50) g;

INSERT INTO inventory (store_id, product_id, quantity, reorder_level)
SELECT s.store_id, p.product_id, (random()*100)::int, 10
FROM stores s CROSS JOIN products p;

select * from inventory;

INSERT INTO customers (name, phone, city, signup_date)
SELECT 'Customer ' || g, '9' || lpad(g::text, 9, '0'),
       (ARRAY['Kanhangad','Kasaragod','Kannur','Mangaluru','Kozhikode'])[1 + g % 5],
       DATE '2025-01-01' + (random()*400)::int
FROM generate_series(1,500) g;

select * from customers;

INSERT INTO riders (name, store_id, joined_on)
SELECT 'Rider ' || g, 1 + (g % 5), DATE '2025-01-01' + (random()*300)::int
FROM generate_series(1,40) g;

select * from riders;

INSERT INTO orders (customer_id, store_id, ordered_at, status, payment_method)
SELECT 1 + (random()*499)::int,
       1 + (random()*4)::int,
       TIMESTAMP '2026-04-01' + random() * INTERVAL '180 days',
       'placed',
       (ARRAY['UPI','Card','COD'])[1 + (random()*2)::int]
FROM generate_series(1,5000);

select * from orders;

UPDATE orders o
SET rider_id = (SELECT r.rider_id FROM riders r
                WHERE r.store_id = o.store_id
                ORDER BY random() LIMIT 1);

-- delivery times (5 to 25 min); a few cancelled
UPDATE orders
SET delivered_at = ordered_at + (5 + random()*20) * INTERVAL '1 minute',
    status = 'delivered';
UPDATE orders SET status='cancelled', delivered_at=NULL WHERE order_id % 25 = 0;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1 + (random()*3)::int, p.mrp
FROM orders o
CROSS JOIN LATERAL (
   SELECT product_id, mrp FROM products
   ORDER BY md5(o.order_id::text || product_id::text) LIMIT 3
) p;

select * from order_items;

-- Orders per store

SELECT store_id, COUNT(*) AS total_orders
FROM orders GROUP BY store_id ORDER BY total_orders DESC;

-- Average delivery time in minutes per store
SELECT store_id,
       ROUND(AVG(EXTRACT(EPOCH FROM (delivered_at - ordered_at))/60), 1) AS avg_minutes
FROM orders WHERE status = 'delivered'
GROUP BY store_id;

-- Payment methods used in more than 1500 orders
SELECT payment_method, COUNT(*) FROM orders
GROUP BY payment_method HAVING COUNT(*) > 1500;

-- Which perishable products cost more than ₹40?
select name from products where mrp > 40 and is_perishable = 'True';

-- Revenue per store (4 tables? no, 3)
SELECT s.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN stores s       ON s.store_id  = o.store_id
WHERE o.status = 'delivered'
GROUP BY s.name ORDER BY revenue DESC;

-- Customers who NEVER ordered (LEFT JOIN + IS NULL pattern)
SELECT c.customer_id, c.name
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

SELECT c.customer_id, c.name
FROM customers c
WHERE c.customer_id NOT IN (
    SELECT o.customer_id
    FROM orders o
);

-- Self join: category with its parent's name
SELECT c.name AS category, p.name AS parent
FROM categories c LEFT JOIN categories p ON c.parent_id = p.category_id;


-- Products priced above the average (subquery)
SELECT name, product_id, mrp FROM products
WHERE mrp > (SELECT AVG(mrp) as average FROM products)


-- Top spending customers using a CTE
WITH customer_spend AS (
  SELECT o.customer_id, SUM(oi.quantity*oi.unit_price) AS spend
  FROM orders o JOIN order_items oi USING (order_id)
  WHERE o.status='delivered'
  GROUP BY o.customer_id
)
SELECT c.name, cs.spend
FROM customer_spend cs JOIN customers c USING (customer_id)
ORDER BY cs.spend DESC LIMIT 10;



-- Rank riders by deliveries within each store
SELECT store_id, rider_id, deliveries,
       RANK() OVER (PARTITION BY store_id ORDER BY deliveries DESC) AS rank_in_store
FROM (
  SELECT store_id, rider_id, COUNT(*) AS deliveries
  FROM orders WHERE status='delivered' GROUP BY store_id, rider_id
) t;



-- Daily revenue, running total and day-over-day change
WITH daily AS (
  SELECT ordered_at::date AS day, SUM(oi.quantity*oi.unit_price) AS revenue
  FROM orders o JOIN order_items oi USING (order_id)
  WHERE status='delivered' GROUP BY 1
)
SELECT day, revenue,
       SUM(revenue) OVER (ORDER BY day) AS running_total,
       revenue - LAG(revenue) OVER (ORDER BY day) AS change_vs_yesterday,
       AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM daily;


--How many orders are there in total, and how many were delivered?
SELECT COUNT(*) AS total_orders,
       COUNT(*) FILTER (WHERE status = 'delivered') AS delivered_orders
FROM orders;

-- How many orders were paid with each payment method?
SELECT payment_method, count(order_id) as order_count
from orders group by payment_method
order by order_count desc;


-- How many riders does each store have?
SELECT s.name, count(r.rider_id) from stores s left join riders r
on s.store_id = r.store_id
group by s.name;


--What is the total revenue of each store from delivered orders?
SELECT s.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN stores s       ON s.store_id  = o.store_id
WHERE o.status = 'delivered'
GROUP BY s.name
ORDER BY revenue DESC;


-- Find the top 5 customers by total spending.
SELECT c.name, SUM(oi.quantity * oi.unit_price) AS total_spend
from customers c
join orders o on c.customer_id = o.customer_id
join order_items oi on oi.order_id = o.order_id
group by c.name
order by total_spend desc limit 5;

-- How many orders were placed in each month?
SELECT DATE_TRUNC('month', ordered_at)::date AS month, COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

--Label each product as Budget (under ₹50), Standard (₹50 to ₹150) or Premium (above ₹150).
SELECT name, mrp,
  CASE WHEN mrp < 50 THEN 'Budget'
       WHEN mrp <= 150 THEN 'Standard'
       ELSE 'Premium' END AS price_band
FROM products;

-- Rank products by price within each category.
SELECT c.name AS category, p.name AS product, p.mrp,
       RANK() OVER (PARTITION BY c.name ORDER BY p.mrp DESC) AS price_rank
FROM products p
JOIN categories c ON c.category_id = p.category_id;