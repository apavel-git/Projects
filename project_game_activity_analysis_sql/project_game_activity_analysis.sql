/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Абрамов Павел Владимирович
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- Запрос рассчитывает кол-во зарегистрированных и платящих игроков, а также долю платящих среди зарегистрированных
SELECT 
COUNT(id) AS all_users, 
SUM(payer) AS payers, 
ROUND(SUM(payer)::NUMERIC/COUNT(id),3) AS share_payers_in_all
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Запрос рассчитывает кол-во зарегистрированных и платящих игроков, а также долю платящих среди зарегистрированных 
-- в разрезе расы
SELECT 
race, 
SUM(payer) AS payers_per_race, 
COUNT(id) AS all_users_per_race, 
ROUND(SUM(payer)::NUMERIC/COUNT(id),3) AS share_payers_in_all_per_race
FROM fantasy.users
JOIN fantasy.race USING(race_id)
GROUP BY race;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Запрос рассчитывает по полю amount общее количество покупок, суммарную стоимость всех покупок,
--минимальную и максимальную стоимость покупки, среднее значение, медиану и стандартное отклонение стоимости покупки.
SELECT 
COUNT(amount) AS count_amount, 
SUM(amount) AS sum_amount,
MIN(amount) AS min_amount,
MAX(amount) AS max_amount,
ROUND(AVG(amount)::NUMERIC,2) AS avg_amount,
PERCENTILE_DISC(0.5)
WITHIN GROUP (ORDER BY amount) AS median_amount,
ROUND(STDDEV(amount)::NUMERIC,2) AS st_dev_amount
FROM fantasy.events;
-- 2.2: Аномальные нулевые покупки:
-- Запрос рассчитывает кол-во покупок с нулевой стоимостью и их долю от общего числа покупок
-- Подзапрос рассчитывает общее кол-во покупок
SELECT COUNT(amount) AS count_zero_amount, 
ROUND(COUNT(amount)::numeric / (SELECT COUNT(amount) FROM fantasy.events),6) AS share_zero_in_general_amount
FROM fantasy.events
WHERE amount=0;
-- 2.3: Популярные эпические предметы:
-- Запрос рассчитывает для каждого предмета общее кол-во продаж и их долю от всех продаж,
-- а также долю игроков покупавших предмет от общего числа покупателей
-- Подзапросы рассчитывают общее кол-во продаж и покупателей
SELECT item_code, game_items, 
COUNT(*) AS count_per_item,
COUNT(*)::NUMERIC/(SELECT COUNT(*) FROM fantasy.events WHERE amount<>0) AS share_item_in_general,
COUNT(DISTINCT ID)::NUMERIC/(SELECT COUNT(DISTINCT ID) FROM fantasy.events WHERE amount<>0) AS share_players_in_general
FROM fantasy.events
JOIN fantasy.items USING(item_code)
WHERE amount<>0
GROUP BY item_code, game_items
ORDER BY share_players_in_general DESC;
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- В подзапросах рассчитываются показатели по кол-ву игроков в разных разрезах,
-- общее, покупатели (а также средние значения по покупателям), платящие.
-- В основном запросе информация объединяется и рассчитываются доли покупателей в
-- в общем кол-ве и платящие в покупателях
WITH general_count AS (SELECT race, 
COUNT(u.id) AS count_player_per_race
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY race),
buy_players_count AS (SELECT race, 
COUNT(DISTINCT e.id) AS count_buy_player_per_race,
ROUND(COUNT(transaction_id)::NUMERIC/COUNT(DISTINCT e.id),2) AS avg_events_per_user,
ROUND(SUM(amount)::NUMERIC/COUNT(transaction_id),2) AS avg_price_per_user,
ROUND(SUM(amount)::NUMERIC/COUNT(DISTINCT e.id),2) AS avg_gen_price_per_user
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
JOIN fantasy.events AS e ON u.id=e.id AND amount<>0
GROUP BY race),
pay_players_count AS (SELECT race, 
COUNT(DISTINCT e.id) AS count_pay_player_per_race
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
JOIN fantasy.events AS e ON u.id=e.id AND amount<>0
WHERE payer=1
GROUP BY race)
	SELECT race,
	count_player_per_race,
	count_buy_player_per_race,
	ROUND(count_buy_player_per_race::NUMERIC/count_player_per_race,3) AS share_buy_in_general,
	ROUND(count_pay_player_per_race::NUMERIC/count_buy_player_per_race,3) AS share_pay_in_buy,
	avg_events_per_user,
	avg_price_per_user,
	avg_gen_price_per_user
	FROM general_count
	LEFT JOIN buy_players_count USING(race)
	LEFT JOIN pay_players_count USING(race);
