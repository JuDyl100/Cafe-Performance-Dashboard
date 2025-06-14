-- Create table and the attribute
CREATE TABLE cafe_sales_raw (
    transaction_id TEXT,
    item TEXT,
    quantity TEXT, 
    price_per_unit TEXT,
    total_spent TEXT,
    payment_method TEXT,
    location TEXT,
    transaction_date TEXT 
);

-- Import Data
COPY cafe_sales_raw 
FROM 'D:\Internship\TikTok\Cafe Sales\dirty_cafe_sales.csv'
DELIMITER ',' 
CSV HEADER;

-- Create Menu Table
CREATE TABLE menu (
    item TEXT,
    price_per_unit REAL
);

INSERT INTO menu (item, price_per_unit) VALUES
('Coffee', 2.0),
('Tea', 1.5),
('Sandwich', 4.0),
('Salad', 5.0),
('Cake', 3.0),
('Cookie', 1.0),
('Smoothie', 4.0),
('Juice', 3.0);

-- Check missing values for everything
SELECT *
FROM cafe_sales_raw
WHERE
  transaction_id IS NULL OR transaction_id = '' OR
  item IS NULL OR item = '' OR
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '' OR
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = '';

-- Transaction ID checking
SELECT
  COUNT(*) FILTER (WHERE transaction_id IS NULL) AS null_transaction_id,
  COUNT(*) FILTER (WHERE transaction_id ILIKE 'UNKNOWN') AS unknown_transaction_id,
  COUNT(*) FILTER (WHERE transaction_id ILIKE 'ERROR') AS error_transaction_id,
  COUNT(*) FILTER (WHERE transaction_id = '') AS empty_transaction_id
FROM cafe_sales_raw; 

-- Check for Item
SELECT *
FROM cafe_sales_raw
WHERE
  item IS NULL OR item = '' OR item = 'UNKNOWN' OR item = 'ERROR';

-- Fix Item base on the Menu and the price per unit (Not included Cake, Juice, Sandwich, Smoothie because of ambigious price)
UPDATE cafe_sales_raw
SET item = menu.item
FROM menu
WHERE 
  (cafe_sales_raw.item IS NULL 
   OR cafe_sales_raw.item ILIKE 'UNKNOWN' 
   OR cafe_sales_raw.item ILIKE 'ERROR')
  AND cafe_sales_raw.price_per_unit ~ '^[0-9]+(\.[0-9]+)?$'  -- only numeric values
  AND CAST(cafe_sales_raw.price_per_unit AS REAL) = menu.price_per_unit
  AND menu.item NOT IN ('Sandwich', 'Smoothie', 'Cake', 'Juice');

-- Check mode for (Cake and Juice, because same price 3.00) and (Sandwich and Smoothie, same price 4.00)
-- Mode for price 3.00 
SELECT item, COUNT(*) AS freq
FROM cafe_sales_raw
WHERE price_per_unit = '3.0'
  AND item IS NOT NULL AND item NOT ILIKE 'UNKNOWN' AND item NOT ILIKE 'ERROR'
GROUP BY item
ORDER BY freq DESC
LIMIT 1; -- Juice

-- Mode for price 4.00
SELECT item, COUNT(*) AS freq
FROM cafe_sales_raw
WHERE price_per_unit = '4.0'
  AND item IS NOT NULL AND item NOT ILIKE 'UNKNOWN' AND item NOT ILIKE 'ERROR'
GROUP BY item
ORDER BY freq DESC
LIMIT 1; -- Sandwich

-- Replace item where price is 3.00 with Juice and 4.00 with Sandwich
UPDATE cafe_sales_raw
SET item = 'Juice'
WHERE 
  (item IS NULL OR item ILIKE 'UNKNOWN' OR item ILIKE 'ERROR')
  AND price_per_unit = '3.0';

UPDATE cafe_sales_raw
SET item = 'Sandwich'  
WHERE 
  (item IS NULL OR item ILIKE 'UNKNOWN' OR item ILIKE 'ERROR')
  AND price_per_unit = '4.0';

SELECT *
FROM cafe_sales_raw
WHERE
  item IS NULL OR item = '' OR item = 'UNKNOWN' OR item = 'ERROR';

 -- To help identify the item let's fix the price per unit by doing (total_spent / quantity)
UPDATE cafe_sales_raw
SET price_per_unit = ROUND(
    CAST(total_spent AS NUMERIC) / CAST(quantity AS NUMERIC), 
    2
)::TEXT
WHERE 
  (price_per_unit IS NULL OR price_per_unit ILIKE 'UNKNOWN' OR price_per_unit ILIKE 'ERROR')
  AND quantity ~ '^\d+$'
  AND total_spent ~ '^[0-9]+(\.[0-9]+)?$';

-- Check for missing values in item
SELECT *
FROM cafe_sales_raw
WHERE
  item IS NULL OR item = '' OR item = 'UNKNOWN' OR item = 'ERROR';

-- Now do the same again by filling item missing value base on the menu (Exclude cake and smoothie)
UPDATE cafe_sales_raw
SET item = menu.item
FROM menu
WHERE 
  (cafe_sales_raw.item IS NULL 
   OR cafe_sales_raw.item ILIKE 'UNKNOWN' 
   OR cafe_sales_raw.item ILIKE 'ERROR')
  AND cafe_sales_raw.price_per_unit ~ '^[0-9]+(\.[0-9]+)?$'
  AND CAST(cafe_sales_raw.price_per_unit AS REAL) = menu.price_per_unit
  AND menu.item NOT IN ('Cake', 'Smoothie');

-- Remove rows where item, price per unit and total spent are unknwon
DELETE FROM cafe_sales_raw
WHERE 
  (item IS NULL OR item ILIKE 'UNKNOWN' OR item ILIKE 'ERROR') AND
  (price_per_unit IS NULL OR price_per_unit ILIKE 'UNKNOWN' OR price_per_unit ILIKE 'ERROR' OR price_per_unit !~ '^[0-9]+(\.[0-9]+)?$') AND
  (total_spent IS NULL OR total_spent ILIKE 'UNKNOWN' OR total_spent ILIKE 'ERROR' OR total_spent !~ '^[0-9]+(\.[0-9]+)?$') AND
  (quantity IS NULL OR total_spent ILIKE 'UNKNOWN' OR total_spent ILIKE 'ERROR' OR total_spent !~ '^[0-9]+(\.[0-9]+)?$')

-- Remove where item, quantity, and price per unit is unknown
DELETE FROM cafe_sales_raw
WHERE 
  (item IS NULL OR item ILIKE 'UNKNOWN' OR item ILIKE 'ERROR') AND
  (price_per_unit IS NULL OR price_per_unit ILIKE 'UNKNOWN' OR price_per_unit ILIKE 'ERROR' OR price_per_unit !~ '^[0-9]+(\.[0-9]+)?$') AND
  (quantity IS NULL OR quantity ILIKE 'UNKNOWN' OR quantity ILIKE 'ERROR' OR quantity !~ '^\d+$');

-- Check for missing values in item
SELECT *
FROM cafe_sales_raw
WHERE
  item IS NULL OR item = '' OR item = 'UNKNOWN' OR item = 'ERROR'; -- Finish for item !

-- Check for missing values everything again
SELECT *
FROM cafe_sales_raw
WHERE
  transaction_id IS NULL OR transaction_id = '' OR
  item IS NULL OR item = '' OR
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '' OR
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = '';

 -- Let's fix total spent first by doing (quantity x price per unit)
UPDATE cafe_sales_raw
SET total_spent = ROUND(CAST(quantity AS NUMERIC) * CAST(price_per_unit AS NUMERIC), 2)::TEXT
WHERE 
  (total_spent IS NULL 
   OR total_spent ILIKE 'UNKNOWN' 
   OR total_spent ILIKE 'ERROR' 
   OR total_spent !~ '^[0-9]+(\.[0-9]+)?$')
  AND quantity ~ '^\d+$'
  AND price_per_unit ~ '^[0-9]+(\.[0-9]+)?$';


-- Check for everything again :D
SELECT *
FROM cafe_sales_raw
WHERE
  transaction_id IS NULL OR transaction_id = '' OR
  item IS NULL OR item = '' OR
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '' OR
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = '';

-- Let's go back to quantity let's fix it by (total spent / price per unit) 
UPDATE cafe_sales_raw
SET quantity = CAST(ROUND(CAST(total_spent AS NUMERIC) / CAST(price_per_unit AS NUMERIC)) AS INT)::TEXT
WHERE 
  (quantity IS NULL 
   OR quantity ILIKE 'UNKNOWN' 
   OR quantity ILIKE 'ERROR' 
   OR quantity !~ '^\d+$')
  AND total_spent ~ '^[0-9]+(\.[0-9]+)?$'
  AND price_per_unit ~ '^[0-9]+(\.[0-9]+)?$';

-- Check for everything
SELECT *
FROM cafe_sales_raw
WHERE
  transaction_id IS NULL OR transaction_id = '' OR
  item IS NULL OR item = '' OR
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '' OR
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = '';

-- Fix missing price per unit by match with item name with the menu
UPDATE cafe_sales_raw
SET price_per_unit = menu.price_per_unit::TEXT
FROM menu
WHERE 
  (cafe_sales_raw.price_per_unit IS NULL 
   OR cafe_sales_raw.price_per_unit ILIKE 'UNKNOWN' 
   OR cafe_sales_raw.price_per_unit ILIKE 'ERROR' 
   OR cafe_sales_raw.price_per_unit !~ '^[0-9]+(\.[0-9]+)?$')
  AND LOWER(TRIM(cafe_sales_raw.item)) = LOWER(TRIM(menu.item));

-- Redo calculation for some missing values in total sales
UPDATE cafe_sales_raw
SET total_spent = ROUND(CAST(quantity AS NUMERIC) * CAST(price_per_unit AS NUMERIC), 2)::TEXT
WHERE 
  (total_spent IS NULL 
   OR total_spent ILIKE 'UNKNOWN' 
   OR total_spent ILIKE 'ERROR' 
   OR total_spent !~ '^[0-9]+(\.[0-9]+)?$')
  AND quantity ~ '^\d+$'
  AND price_per_unit ~ '^[0-9]+(\.[0-9]+)?$';

-- Check for everything
SELECT *
FROM cafe_sales_raw
WHERE
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '';

-- Fix quantity (total spent / price per unit)
UPDATE cafe_sales_raw
SET quantity = CAST(ROUND(CAST(total_spent AS NUMERIC) / CAST(price_per_unit AS NUMERIC)) AS INT)::TEXT
WHERE 
  (cafe_sales_raw.quantity IS NULL 
   OR cafe_sales_raw.quantity ILIKE 'UNKNOWN' 
   OR cafe_sales_raw.quantity ILIKE 'ERROR' 
   OR cafe_sales_raw.quantity !~ '^\d+$')
  AND cafe_sales_raw.total_spent ~ '^[0-9]+(\.[0-9]+)?$'
  AND cafe_sales_raw.price_per_unit ~ '^[0-9]+(\.[0-9]+)?$';

-- Delete rows where quantity is unknwon and total spent is unknown since we cannot determine anything
DELETE FROM cafe_sales_raw
WHERE 
  (quantity IS NULL OR quantity ILIKE 'UNKNOWN' OR quantity ILIKE 'ERROR' OR quantity !~ '^\d+$')
  AND (total_spent IS NULL OR total_spent ILIKE 'UNKNOWN' OR total_spent ILIKE 'ERROR' OR total_spent !~ '^[0-9]+(\.[0-9]+)?$');

-- Check for Unknown values in payment method, location and transaction date
SELECT *
FROM cafe_sales_raw
WHERE
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = '';

-- Check for mode in Payment Method
SELECT 
  payment_method, 
  COUNT(*) AS frequency
FROM cafe_sales_raw
WHERE 
  payment_method IS NOT NULL 
  AND payment_method NOT ILIKE 'UNKNOWN' 
  AND payment_method NOT ILIKE 'ERROR'
GROUP BY payment_method
ORDER BY frequency DESC
LIMIT 1; -- Digital Wallet

-- Replace the Invalid Values with 'Digital Wallet'
UPDATE cafe_sales_raw
SET payment_method = 'Digital Wallet'
WHERE 
  payment_method IS NULL 
  OR payment_method ILIKE 'UNKNOWN' 
  OR payment_method ILIKE 'ERROR';

-- Check for invalid values in payment_method
SELECT *
FROM cafe_sales_raw
WHERE
  payment_method IS NULL OR payment_method = ''; -- Done !

-- Check for missing values in location 
SELECT *
FROM cafe_sales_raw
WHERE
  location IS NULL OR location = '' OR location = 'UNKNOWN' OR location = 'ERROR';

-- Check the mode for location
SELECT 
  location, 
  COUNT(*) AS frequency
FROM cafe_sales_raw
WHERE 
  location IS NOT NULL 
  AND location NOT ILIKE 'UNKNOWN' 
  AND location NOT ILIKE 'ERROR'
  AND location NOT ILIKE 'Not Defined'
GROUP BY location
ORDER BY frequency DESC
LIMIT 1; -- Takeaway

-- Change invalid values in location to 'Takeaway'
UPDATE cafe_sales_raw
SET location = 'Takeaway'
WHERE 
  location IS NULL 
  OR location = ''
  OR location ILIKE 'UNKNOWN'
  OR location ILIKE 'ERROR';


-- Check for invalid values in location
SELECT *
FROM cafe_sales_raw
WHERE
  location IS NULL OR location = '' OR location = 'UNKNOWN' OR location = 'ERROR';

-- Replace the missing transaction_date with random date between min and max date
SELECT 
  MIN(CAST(transaction_date AS DATE)) AS min_date,
  MAX(CAST(transaction_date AS DATE)) AS max_date
FROM cafe_sales_raw
WHERE transaction_date ~ '^\d{4}-\d{2}-\d{2}$'; 

-- min date = 2023-01-01, max date = 2023-12-31

UPDATE cafe_sales_raw
SET transaction_date = (
    TO_CHAR(
        DATE '2023-01-01' + FLOOR(RANDOM() * (DATE '2023-12-31' - DATE '2023-01-01' + 1)) * INTERVAL '1 day',
        'YYYY-MM-DD'
    )
)
WHERE 
  transaction_date IS NULL 
  OR transaction_date = ''
  OR transaction_date ILIKE 'UNKNOWN'
  OR transaction_date ILIKE 'ERROR'
  OR transaction_date !~ '^\d{4}-\d{2}-\d{2}$';


-- Check for more missing
SELECT *
FROM cafe_sales_raw
WHERE
  transaction_id IS NULL OR transaction_id = '' OR
  item IS NULL OR item = '' OR
  quantity IS NULL OR quantity = '' OR
  price_per_unit IS NULL OR price_per_unit = '' OR
  total_spent IS NULL OR total_spent = '' OR
  payment_method IS NULL OR payment_method = '' OR
  location IS NULL OR location = '' OR
  transaction_date IS NULL OR transaction_date = ''; -- Done for everything : D

SELECT * FROM cafe_sales_raw;
  
