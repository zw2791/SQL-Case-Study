CREATE SCHEMA dannys_diner;
USE dannys_diner;

CREATE TABLE sales (
customer_id VARCHAR(1),
order_date DATE,
product_id INTEGER );

INSERT INTO sales VALUES
('A', '2021-01-01', '1'),
('A', '2021-01-01', '2'),
('A', '2021-01-07', '2'),
('A', '2021-01-10', '3'),
('A', '2021-01-11', '3'),
('A', '2021-01-11', '3'),
('B', '2021-01-01', '2'),
('B', '2021-01-02', '2'),
('B', '2021-01-04', '1'),
('B', '2021-01-11', '1'),
('B', '2021-01-16', '3'),
('B', '2021-02-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-07', '3');

SELECT * from menu;

CREATE TABLE menu (
product_id INTEGER,
product_name VARCHAR(10),
price VARCHAR(2));

INSERT INTO menu VALUES
(1, "sushi", "10"), (2, "curry", "15"), (3, "ramen", "12");

CREATE TABLE members (
customer_id VARCHAR(1),
join_date DATE );

INSERT INTO members VALUES 
("A", "2021-01-07"), ("B", "2021-01-09");

-- cari yang paling banyak dipesan
WITH temp AS (
	SELECT 
		row_number() OVER(order by s.product_id) AS max_product_id
	FROM sales s
    ) 
select max_product_id from temp;

select * from sales;





-- 1. What is the total amount each customer spent at the restaurant?
select s.customer_id, sum(m.price) as tot_consumption
from sales s left join menu m
	on s.product_id = m.product_id
group by s.customer_id
order by tot_consumption desc


-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct order_date) as visit
from sales
group by customer_id
order by visit desc


-- 3. What was the first item from the menu purchased by each customer?
with order_rank as (
	select
	s.customer_id, 
	s.order_date, 
	m.product_name,
		dense_rank() over(partition by s.customer_id order by s.order_date) as drank
	from sales s join menu m
		on s.product_id = m.product_id)
select customer_id,
	   product_name,
	   order_date
from order_rank
where drank = 1
group by customer_id, product_name, order_date


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select product_name, 
	   count(m.product_name) as times
from sales s left join menu m
	on s.product_id = m.product_id
group by product_name
order by times desc
limit 1


-- 5. Which item was the most popular for each customer?
with product_rank as(
	select s.customer_id,
	       m.product_name,
		   count(m.product_id) as order_count,
	   	   dense_rank() over(partition by s.customer_id
							 	order by count(s.product_id) desc) as drank
	from sales s left join menu m
	on s.product_id = m.product_id
	group by s.customer_id, m.product_name)
select customer_id, 
	   product_name,
	   order_count
from product_rank
where drank = 1


-- 6. Which item was purchased first by the customer after they became a member?
WITH cte_members AS (
	SELECT
		s.customer_id,
        s.product_id,
        mb.join_date,
        s.order_date,
        DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank_member
	FROM sales s
    JOIN members mb ON s.customer_id = mb.customer_id
    WHERE s.order_date >= mb.join_date)
SELECT 
	cm.customer_id,
    cm.order_date,
    m.product_name
FROM cte_members cm
JOIN menu m ON cm.product_id = m.product_id
WHERE rank_member = 1
ORDER BY cm.customer_id;
	   

-- 7. Which item was purchased just before the customer became a member?
with date_rank as(
	select  s.customer_id,
			s.order_date,
			s.product_id,
			mb.join_date,
				rank() over(partition by s.customer_id
						  	order by s.order_date desc) as rk
	from sales s left join
		members mb on s.customer_id = mb.customer_id
	where mb.join_date > s.order_date)
select  customer_id,
		order_date,
		join_date,
		m.product_name
from date_rank dr
	left join menu m
		on m.product_id = dr.product_id
where rk = 1


-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
	s.customer_id,
	m.product_name,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS price
FROM sales s 
JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;


-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier 
--    how many points would each customer have?
WITH price_point AS (
	SELECT *,
		CASE 
			WHEN product_name = 'sushi' THEN price * 20
            ELSE price * 10
		END AS points
	FROM menu)
SELECT 
	s.customer_id,
    SUM(p.points) AS total_point
FROM price_point p
JOIN sales s ON p.product_id = s.product_id
JOIN members m ON s.customer_id = m.customer_id
GROUP BY s.customer_id;


-- 10. In the first week after a customer joins the program (including their join date)
--     they earn 2x points on all items, not just sushi - how many points do customer
--     A and B have at the end of January?
WITH dates AS (
	SELECT 
		*,
		DATE_ADD(join_date, INTERVAL 6 DAY) AS firstweek_join,
        LAST_DAY('2021-01-31') AS last_date
	FROM members mb)
SELECT 
	dt.customer_id,
    dt.join_date,
    dt.firstweek_join,
    dt.last_date,
    s.order_date,
	m.product_name,
    m.price,
		SUM(CASE
				WHEN m.product_name = 'sushi' THEN m.price*2*10
                WHEN s.order_date BETWEEN dt.join_date AND dt.firstweek_join THEN m.price*2*10
                ELSE m.price*10 
			END) AS points
FROM dates dt
JOIN sales s ON s.customer_id = dt.customer_id
JOIN menu m ON m.product_id = s.product_id
WHERE s.order_date < dt.firstweek_join
GROUP BY dt.customer_id;


