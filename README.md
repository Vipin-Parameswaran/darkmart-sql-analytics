# 🛒 DarkMart: Quick-Commerce Dark Store Analytics (PostgreSQL)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?logo=postgresql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange)
![Level](https://img.shields.io/badge/Level-Beginner%20to%20Intermediate-green)

A complete relational database and analytics project modelled on **quick-commerce companies** (Blinkit, Zepto, Swiggy Instamart style) that promise groceries in about 10 minutes from small local warehouses called **dark stores**.

The project covers the whole workflow: designing the schema, loading realistic data, answering business questions, tuning performance, and protecting data integrity.

---

## 📑 Table of Contents
- [Business Problem](#-business-problem)
- [SQL Concepts Covered](#-sql-concepts-covered)
- [Database Design](#-database-design)
- [Dataset](#-dataset)
- [How to Run This Project](#-how-to-run-this-project)
- [Sample Business Questions and Queries](#-sample-business-questions-and-queries)
- [Project Structure](#-project-structure)
- [Key Learnings](#-key-learnings)
- [Author](#-author)

---

## 🎯 Business Problem

A quick-commerce company runs several dark stores across multiple cities. Management needs answers to questions like:

- Which stores and products generate the most revenue?
- Are we meeting the **10-minute delivery promise**?
- Which products are running out of stock?
- Who are the best-performing delivery riders?
- Which customers are the most valuable, and which have stopped ordering?
- What are the peak ordering hours?

This project builds the database and the SQL needed to answer them.

---

## 🧠 SQL Concepts Covered

| Category | Topics |
|---|---|
| **DDL** | `CREATE`, `ALTER`, `DROP`, data types, `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT` |
| **DML** | `INSERT`, `UPDATE`, `DELETE`, bulk data generation with `generate_series` |
| **Querying** | `SELECT`, `WHERE`, `ORDER BY`, `LIMIT`, `DISTINCT`, `LIKE`, `IN`, `BETWEEN`, `IS NULL` |
| **Aggregation** | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING` |
| **Joins** | `INNER`, `LEFT`, `CROSS`, self join, multi-table joins |
| **Advanced queries** | Subqueries, `EXISTS`, CTEs (`WITH`), recursive CTEs |
| **Window functions** | `RANK`, `ROW_NUMBER`, `LAG`, running totals, moving averages |
| **Functions** | Date/time, string, `CASE`, `COALESCE`, JSONB operators |
| **Views** | Views and materialized views |
| **Performance** | Indexes, `EXPLAIN ANALYZE` |
| **Transactions** | `BEGIN`, `COMMIT`, `ROLLBACK`, row locking, ACID |
| **Programming** | PL/pgSQL functions and triggers (automatic stock deduction, audit log) |
| **Security** | Roles, `GRANT`, `REVOKE` |

---

## 🗂 Database Design

The database has **8 core tables** plus a stock audit table:

| Table | Description |
|---|---|
| `stores` | Dark store locations (city, area, opening date) |
| `categories` | Product categories with parent-child hierarchy |
| `products` | Items sold, with price, perishable flag and JSONB attributes |
| `inventory` | Stock quantity of each product in each store |
| `customers` | Customer profiles |
| `riders` | Delivery riders, each assigned to a store |
| `orders` | One row per order (customer, store, rider, timestamps, status, payment) |
| `order_items` | Products and quantities inside each order |
| `stock_audit` | Automatic log of every inventory change (maintained by a trigger) |

### Relationships
- One **store** has many **riders** and many **orders**
- One **customer** has many **orders**
- One **order** has many **order_items**
- **Products** and **stores** are linked many-to-many through **inventory**
- **Categories** reference themselves (e.g. Grocery → Dairy)

<!-- OPTIONAL: Add your ER diagram. Save the image as images/er_diagram.png in the repo, then remove this comment markers:
![ER Diagram](images/er_diagram.png)
-->

---

## 📊 Dataset

All data is **synthetic**, generated inside SQL using `generate_series` and `random()`, so no external files are needed.

| Entity | Approx. rows |
|---|---|
| Stores | 5 |
| Products | 55 |
| Customers | 500 |
| Riders | 40 |
| Orders | 5,000 (about 6 months) |
| Order items | about 15,000 |

---

## ▶️ How to Run This Project

### Prerequisites
- [PostgreSQL](https://www.postgresql.org/download/) (version 14 or newer recommended)
- pgAdmin 4 (installed together with PostgreSQL) or any SQL client

### Option 1: Using pgAdmin (easiest)
1. Open pgAdmin and connect to your server.
2. Right-click **Databases → Create → Database**, name it `darkmart`.
3. Right-click the `darkmart` database → **Query Tool**.
4. Click the **Open File** icon and select `Darkmart_Project.sql`.
5. Press **F5** (or the ▶ button) to run the script.

### Option 2: Using the command line
```bash
createdb -U postgres darkmart
psql -U postgres -d darkmart -f Darkmart_Project.sql
```

### Verify the setup
```sql
SELECT COUNT(*) FROM orders;      -- should return about 5000
SELECT COUNT(*) FROM customers;   -- should return about 500
```

> **Note:** The data is random, so your exact numbers and results will differ slightly from any example outputs.

---

## 💡 Sample Business Questions and Queries

### 1. Revenue per store
```sql
SELECT s.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN stores s       ON s.store_id  = o.store_id
WHERE o.status = 'delivered'
GROUP BY s.name
ORDER BY revenue DESC;
```

### 2. Is the 10-minute delivery promise being met?
```sql
SELECT CASE WHEN delivered_at - ordered_at <= INTERVAL '10 minutes'
            THEN 'On time' ELSE 'Late' END AS sla,
       COUNT(*) AS orders
FROM orders
WHERE status = 'delivered'
GROUP BY 1;
```

### 3. Rider leaderboard inside each store (window function)
```sql
SELECT store_id, rider_id, deliveries,
       RANK() OVER (PARTITION BY store_id ORDER BY deliveries DESC) AS rank_in_store
FROM (
  SELECT store_id, rider_id, COUNT(*) AS deliveries
  FROM orders
  WHERE status = 'delivered'
  GROUP BY store_id, rider_id
) t;
```

### 4. Daily revenue with running total and 7-day moving average
```sql
WITH daily AS (
  SELECT ordered_at::date AS day, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o JOIN order_items oi USING (order_id)
  WHERE status = 'delivered'
  GROUP BY 1
)
SELECT day, revenue,
       SUM(revenue) OVER (ORDER BY day) AS running_total,
       AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM daily;
```

### 5. Customers who never ordered
```sql
SELECT c.customer_id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```

### 6. Automatic stock deduction with a trigger
```sql
CREATE FUNCTION deduct_stock() RETURNS trigger AS $$
BEGIN
  UPDATE inventory
  SET quantity = quantity - NEW.quantity
  WHERE product_id = NEW.product_id
    AND store_id = (SELECT store_id FROM orders WHERE order_id = NEW.order_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_deduct_stock
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION deduct_stock();
```

---

## 📁 Project Structure

```
darkmart-sql-analytics/
├── Darkmart_Project.sql   # Full script: schema, data generation, queries, views, triggers
└── README.md              # Project documentation
```

---

## 📚 Key Learnings

- Designing a normalized relational schema with proper keys and constraints
- Generating realistic test data entirely in SQL
- Translating business questions into queries using joins, CTEs and window functions
- Using indexes and `EXPLAIN ANALYZE` to understand query performance
- Keeping data consistent with transactions, constraints and triggers
- Controlling data access with roles and permissions

---

## 👤 Author

**[Your Name]**

- GitHub: [@your-github-username](https://github.com/your-github-username)
- LinkedIn: [Your LinkedIn URL]
- Email: [your-email@example.com]

⭐ If you found this project helpful, consider giving the repository a star!
