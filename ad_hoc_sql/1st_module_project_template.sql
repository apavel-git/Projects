/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Абрамов Павел
 * Дата: 07.08.2025
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Напишите ваш запрос здесь
-- Фильтрация
WITH filter AS (
SELECT 
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS filter_ta,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS filter_r,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS filter_b,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_top,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_low
FROM real_estate.flats 
),
filtered_id AS (
SELECT id
FROM real_estate.flats
	WHERE total_area < (SELECT filter_ta FROM filter)
	AND (rooms < (SELECT filter_r FROM filter) OR rooms IS NULL)
	AND (balcony < (SELECT filter_b FROM filter) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT filter_ceiling_top FROM filter) 
	AND ceiling_height > (SELECT filter_ceiling_low FROM filter)) OR ceiling_height IS NULL)
),
-- Создаем категории по времени
filtered_adv AS (
SELECT *,
CASE
  WHEN days_exposition IS NULL THEN 'Информация отсутствует'
  WHEN days_exposition <= 30 THEN 'до 1 месяца'
  WHEN days_exposition <= 90 THEN 'до 3 месяцев'
  WHEN days_exposition <= 180 THEN 'до 6 месяцев'
  ELSE 'дольше 6 месяцев'
END AS category
FROM real_estate.advertisement),
-- Создаем регион в зависимости от населенного пункта
filtered_region AS (
SELECT *, 
	CASE
	WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
	ELSE 'Ленинградская область'
	END AS region
FROM real_estate.city
)
-- Основной расчет с необходимыми показателями и группировкой
SELECT
	region,
	category,
	count(*) AS count_adv,
	ROUND(COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY region)*100::NUMERIC, 2) AS percent_in_region,
	ROUND(avg(last_price/total_area)::NUMERIC,0) AS avg_price_per_area, 
	ROUND(avg(total_area)::NUMERIC,0) AS avg_area,
	MODE() WITHIN GROUP (ORDER BY rooms) AS mode_rooms,
	ROUND(avg(rooms)::NUMERIC,2) AS avg_rooms,
	MODE() WITHIN GROUP (ORDER BY balcony) AS mode_balcony,
	ROUND(avg(balcony)::NUMERIC,2) AS avg_balcony,
	ROUND(avg(ceiling_height)::NUMERIC,2) AS avg_ceiling
FROM real_estate.flats
JOIN filtered_adv USING(id)
JOIN filtered_region USING(city_id)
JOIN real_estate.TYPE USING(type_id)
	WHERE id IN (SELECT * FROM filtered_id)
	AND category<>'Информация отсутствует'
	AND type='город'
	GROUP BY region, category
	ORDER BY region DESC, category;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Напишите ваш запрос здесь
-- Фильтрация
WITH filter AS (
SELECT 
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS filter_ta,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS filter_r,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS filter_b,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_top,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_low
FROM real_estate.flats 
),
filtered_id AS (
SELECT id
FROM real_estate.flats
	WHERE total_area < (SELECT filter_ta FROM filter)
	AND (rooms < (SELECT filter_r FROM filter) OR rooms IS NULL)
	AND (balcony < (SELECT filter_b FROM filter) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT filter_ceiling_top FROM filter) 
	AND ceiling_height > (SELECT filter_ceiling_low FROM filter)) OR ceiling_height IS NULL)
),
-- Считаем показатели в разрезе месяцев по публикации
-- Добавляем фильтр по датам, чтобы попадали только полные месяцы для избежания искажений
grouped_exposition AS (
SELECT 
	EXTRACT (month FROM first_day_exposition) AS month,
	COUNT(*) AS count_exposition,
	ROUND(avg(last_price/total_area)::NUMERIC,0) AS avg_price_per_area,
	ROUND(avg(total_area)::NUMERIC,2) AS avg_area,
	DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS rank_count_exposition
FROM real_estate.advertisement
JOIN real_estate.flats USING(id)
	WHERE id IN(SELECT * FROM filtered_id)
	AND first_day_exposition BETWEEN '2014-12-01' AND '2019-04-30'
	GROUP BY month
	ORDER BY month
	),
-- Считаем показатели в разрезе месяцев по продажам
grouped_sold AS (
SELECT
	EXTRACT(month FROM first_day_exposition + INTERVAL '1 DAY' * days_exposition) AS month,
	COUNT(*) AS count_sold,
	ROUND(avg(last_price/total_area)::NUMERIC,0) AS sold_avg_price_per_area,
	ROUND(avg(total_area)::NUMERIC,2) sold_avg_area,
	DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS rank_count_sold
FROM real_estate.advertisement
JOIN real_estate.flats USING(id)
	WHERE days_exposition IS NOT NULL AND id IN(SELECT * FROM filtered_id)
	AND first_day_exposition BETWEEN '2014-12-01' AND '2019-04-30'
GROUP BY month
ORDER BY MONTH
)
-- Основной запрос с нужными показателями по месяцам
SELECT 
	month,
	count_exposition,
	rank_count_exposition,
	avg_price_per_area,
	avg_area,
	count_sold,
	rank_count_sold,
	sold_avg_price_per_area,
	sold_avg_area
FROM grouped_exposition
JOIN grouped_sold USING(month);

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Напишите ваш запрос здесь
-- Фильтрация
WITH filter AS (
SELECT 
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS filter_ta,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS filter_r,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS filter_b,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_top,
	PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS filter_ceiling_low
FROM real_estate.flats 
),
filtered_id AS (
SELECT id
FROM real_estate.flats
	WHERE total_area < (SELECT filter_ta FROM filter)
	AND (rooms < (SELECT filter_r FROM filter) OR rooms IS NULL)
	AND (balcony < (SELECT filter_b FROM filter) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT filter_ceiling_top FROM filter) 
	AND ceiling_height > (SELECT filter_ceiling_low FROM filter)) OR ceiling_height IS NULL)
)
-- В запросе выводим информацию для топ-15 по публикациям
-- Для вычисления доли продаж используем FILTER в SELECT
SELECT
	city,
	COUNT(*) AS total_count,
	ROUND(COUNT(*) FILTER (WHERE days_exposition IS NOT NULL) / COUNT(*)::numeric, 2) AS share_sold_in_total,
	ROUND(avg(last_price/total_area)::numeric,0) AS avg_price_per_area,
	ROUND(avg(total_area)::numeric,0) AS avg_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS median_days
FROM real_estate.advertisement
JOIN real_estate.flats using(id)
JOIN real_estate.city using(city_id)
WHERE id in(SELECT * FROM filtered_id)
	AND city<>'Санкт-Петербург'
	GROUP BY city
	ORDER BY total_count DESC
LIMIT 15;
