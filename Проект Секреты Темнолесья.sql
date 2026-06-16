/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Тишонкова Лада
 * Дата: 05 июня 2025 г
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT COUNT(*) AS total_users, --  общее количество пользователей
	SUM(payer) AS total_payer, --  количество пользователей, которые делали покупки за "райские лепестки"
	AVG(payer)::NUMERIC(5,4) AS share_users_payer --  доля платящих пользователей
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT	race, 
	COUNT(id) AS race_total_count,--общее количество пользователей в каждой расе
	SUM(payer) AS race_payer_count,--количество платящих игроков в каждой расе
	AVG(payer)::numeric(5,4) AS share_race_payer--доля платящих пользователей по расам
FROM fantasy.users 
LEFT JOIN fantasy.race USING(race_id)
GROUP BY race -- группируем по расе
ORDER BY share_race_payer DESC;


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
--рассчитаем данные по полю amount
SELECT COUNT(transaction_id) AS total_count, --общее количество покупок
	SUM(amount) AS total_amount,--суммарная стоимость всех покупок
	MIN(amount) AS min_amount,--минимальная стоимость всех покупок
	MAX(amount) AS max_amount,--максимальная стоимость всех покупок
	AVG(amount)::NUMERIC(5,2) AS avg_amount,--среднее значение стоимости покупок
	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS mediana_amount,--медиана стоимости покупок
	STDDEV(amount)::numeric(6,2) AS standart_deviation--стандартное отклонение стоимости покупок
FROM fantasy.events
WHERE amount>0;--исключим покупки со стоимостью 0


-- 2.2: Аномальные нулевые покупки:

SELECT COUNT(CASE WHEN amount=0 THEN 1
			ELSE NULL 
			END) AS count_amountless, --количество покупок со стоимостью 0
		(COUNT(CASE WHEN amount=0 THEN 1
			ELSE NULL 
			END)::NUMERIC(10,6)/COUNT(*)) AS share_amountless -- доля покупок со стоимостью 0
FROM fantasy.events;

--посмотрим на покупки с 0 стоимостью и как часто их покупали
SELECT DISTINCT game_items,
	id,
	COUNT(transaction_id) AS count_transaction--количество покупок
FROM fantasy.events 
LEFT JOIN fantasy.items USING(item_code)
WHERE amount=0
GROUP BY game_items,id
ORDER BY count_transaction DESC;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

SELECT CASE WHEN payer=1 THEN 'payers'
			WHEN payer=0 THEN 'no_payers'
			END AS group_users,
	COUNT(DISTINCT id) AS count_id,--количество игроков
	COUNT(transaction_id)/COUNT(DISTINCT id) AS avg_count_transaction,--среднее количество покупок на 1 игрока
	(SUM(amount)/COUNT(DISTINCT id))::NUMERIC(10) AS avg_amount--средняя суммарная стоимость покупок на 1 игрока
FROM fantasy.events 
LEFT JOIN fantasy.users USING(id) -- присоединением фильтруем игроков, которые совершали покупки
WHERE amount>0 --исключим покупки со стоимостью 0
GROUP BY payer;
-- проверим  платящих и неплатящих игроков в разрезе по расам
SELECT race,
	CASE WHEN payer=1 THEN 'payers'
		WHEN payer=0 THEN 'no_payers'
		END AS group_users,
	COUNT(DISTINCT id) AS count_id,--количество игроков
	COUNT(transaction_id)/COUNT(DISTINCT id) AS avg_count_transaction,--среднее количество покупок на 1 игрока
	(SUM(amount)/COUNT(DISTINCT id))::numeric(10) AS avg_amount--средняя суммарная стоимость покупок на 1 игрока
FROM fantasy.events 
LEFT JOIN fantasy.users USING(id)
LEFT JOIN fantasy.race USING(race_id)
WHERE amount>0 --исключим покупки со стоимостью 0
GROUP BY race, payer;
	
	
	-- 2.4 Популярные эпические предметы:

WITH 
-- рассчитаем общее количество покупок и общее количество игроков
	total_pay AS (
	SELECT COUNT (transaction_id) AS total,
		(SELECT COUNT(id)
		FROM fantasy.users) AS total_users
	FROM fantasy.events 
	WHERE amount>0)--не учитываем покупки со стоимостью 0
-- Основной запрос рассчитаем показатели
SELECT item_code,
	game_items, -- название эпического предмета
	COUNT(transaction_id) AS count_transaction, -- число покупок предмета
	ROUND(COUNT(transaction_id)::numeric/(SELECT total FROM total_pay),4) AS share_count_transaction, -- доля покупок предмета
	ROUND(COUNT(DISTINCT id)::numeric/(SELECT total_users FROM total_pay),4) AS share_users--доля покупателей, которые хоть раз купили предмет
FROM fantasy.events AS e 
JOIN fantasy.items AS i USING(item_code)
WHERE amount>0--не учитываем покупки со стоимостью 0
GROUP BY item_code,game_items 
ORDER BY count_transaction DESC -- сортируем по убыванию для выявления наиболее популярных предметов
LIMIT 10; -- выведем первые 10 строк

--посмотрим сколько эпических предметов ни разу не покупали
SELECT COUNT(*) AS count_items_no_transaction
FROM fantasy.items 
LEFT JOIN fantasy.events USING(item_code)
WHERE transaction_id IS NULL;

-- Часть 2. Решение ad hoc-задач

-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH 
--рассчитаем общее количество зарегистрированных игроков для каждой расы
	race_count AS(
	SELECT race_id,
		COUNT(id) AS count_race
	FROM fantasy.users
	GROUP BY race_id),
--для каждой расы посчитаем данные
	race_events_count AS(
	SELECT  u.race_id,
		COUNT(DISTINCT e.id)  AS count_race_events, -- количество игроков, совершивших покупки
		COUNT(DISTINCT transaction_id) AS count_transaction_race, --количество покупок, совершенных каждой расой
		ROUND(AVG(amount)::numeric) AS avg_amount_race,--средняя стоимость одной покупки, совершенной на 1 игрока в каждой расе
		SUM(amount) AS total_amount_race --общая сумма покупок в каждой расе
	FROM fantasy.events AS e 
	LEFT JOIN fantasy.users AS u USING(id) 
	WHERE amount>0
	GROUP BY u.race_id),
--посчитаем количество платящих игроков, которые совершили покупки
	race_payer AS ( 
	SELECT u.race_id,
		COUNT(DISTINCT e.id) count_race_payer
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u USING(id)
	WHERE payer=1 AND amount>0
	GROUP BY u.race_id)
--в основном запросе считаем все необходимые данные
SELECT race,
	count_race,
	count_race_events,
	ROUND(count_race_events::numeric/count_race,4) AS share_race_events, -- доля игроков, совершивших покупки в каждой расе
	ROUND(count_race_payer::numeric/count_race_events,4) AS share_race_payer, -- доля платящих игроков, совершивших покупки в каждой расе
	ROUND(count_transaction_race::numeric/count_race_events) AS avg_count_transaction_race,--среднее количество покупок на 1 игрока в каждой расе
	avg_amount_race,
	ROUND(total_amount_race::numeric/count_race_events) AS avg_total_amount_race--средняя суммарная стоимость всех покупок на 1 игрока в каждой расе
FROM race_events_count 
LEFT JOIN race_count USING(race_id)
LEFT JOIN race_payer USING(race_id)
JOIN fantasy.race AS r USING(race_id)
ORDER BY avg_count_transaction_race DESC;

-- Задача 2: Частота покупок

WITH
--рассчитаем интервал между покупками
	interval_event AS(
	SELECT *,
		date::DATE - LAG(date::DATE)OVER(PARTITION BY id ORDER BY date::DATE) AS interval_event --интерал между покупками в днях для каждого игрока
	FROM fantasy.events
	WHERE amount>0), -- исключаем из расчетов покупки со стоимостью 0
--рассчитаем количество покупок и их частоту для каждого игрока, проранжируем
	user_stat AS(
	SELECT id,
		COUNT(transaction_id) AS count_event,--количество покупок
		AVG(interval_event) AS avg_interval_event,--среднее количество дней между покупками
		payer,
		NTILE(3)OVER(ORDER BY AVG(interval_event)) AS rang_user--делим игроков на 3 равные группы по частоте покупок
	FROM interval_event 
	LEFT JOIN fantasy.users USING(id)
	GROUP BY id,payer
	HAVING COUNT(transaction_id)>=25)--исключаем игроков, которые совершили менее 25 покупок
--в основном запросе сгруппируем по частоте покупок и рассчитаем данные по этим группам
SELECT rang_user,	
		CASE WHEN rang_user=1 THEN 'высокая частота'
			WHEN rang_user=2 THEN 'умеренная частота'
			WHEN rang_user=3 THEN 'низкая частота'
			END AS name_rang,
		COUNT(id) AS count_id, -- количество игроков
		SUM(payer) AS count_payer,-- количество платящих игроков
		ROUND(SUM(payer)::NUMERIC/COUNT(id),4) AS share_payer,--доля платящих игроков
		ROUND(AVG(count_event)::NUMERIC) AS avg_count_event,--среднее количество покупок
		ROUND(AVG(avg_interval_event)::NUMERIC,1) AS avg_interval--среднее количество дней между покупками
FROM user_stat
GROUP BY rang_user, name_rang
ORDER BY rang_user;

	
	





