-- ЗАДАНИЕ 1

SELECT  usage_geo_id_name city_or_region, 
		ROUND(SUM(hours)) sum_hours_general, 
		ROUND(sumIf(hours , usage_platform_ru = 'Букмейт iOS')) sum_hours_ios,
		ROUND(sumIf(hours, usage_platform_ru = 'Букмейт Android')) sum_hours_android
FROM  source_db.audition a
WHERE 	usage_geo_id_name NOT LIKE '%федеральный округ%' AND usage_geo_id_name NOT LIKE '%Россия%' 
		AND usage_country_name = 'Россия' AND usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
		AND a.hours > 0
GROUP BY usage_geo_id_name
ORDER BY sum_hours_general DESC
LIMIT 20;

-- ЗАДАНИЕ 2

SELECT 	c.main_content_name book_name, 
		c.main_author_name author_name,
		ROUND(SUM(a.hours),2) sum_hours_general,
		ROUND(avgIf(a.hours, c.main_content_type = 'Book'),2) avg_hours_textbook,
		ROUND(avgIf(a.hours, c.main_content_type = 'Audiobook'),2) avg_hours_audiobook
FROM source_db.audition a
JOIN source_db.content c USING(main_content_id)
WHERE 	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
		AND c.main_content_type IN ('Book', 'Audiobook') AND a.hours > 0
GROUP BY c.main_content_name, c.main_author_name
HAVING 	countIf(c.main_content_type = 'Audiobook') > 0 
		AND countIf(c.main_content_type = 'Book') > 0
ORDER BY sum_hours_general DESC
LIMIT 5;

-- ЗАДАНИЕ 3

SELECT 	c.main_author_name author_name,
		ROUND(sumIf(a.hours, c.main_content_type = 'Book'),2) sum_hours_alltextbooks, 
		uniqExactIf(c.main_content_id, c.main_content_type = 'Book') unique_count_textbooks,
		ROUND(avgIf(a.hours, a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android') 
		AND c.main_content_type = 'Audiobook'),2) avg_audio_hours_mobile
FROM source_db.audition a
JOIN source_db.content c USING(main_content_id)
WHERE 	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
		AND c.main_content_type IN ('Book', 'Audiobook') AND a.hours > 0
GROUP BY c.main_author_name
HAVING countIf(c.main_content_type = 'Audiobook') > 0
ORDER BY sum_hours_alltextbooks DESC
LIMIT 10;

-- ЗАДАНИЕ 4

WITH marked_data AS (
SELECT 	puid user_id,
		multiIf(sumIf(a.hours, c.main_content_type = 'Audiobook')/sum(a.hours) >= 0.7, 'Слушатель',
		sumIf(a.hours, c.main_content_type = 'Book')/sum(a.hours) >= 0.7, 'Читатель', 'Оба') user_type,
		multiIf(sumIf(a.hours, a.usage_platform_ru = 'Букмейт Android') 
		> sumIf(a.hours, a.usage_platform_ru = 'Букмейт iOS'), 'Android',
		sumIf(a.hours, a.usage_platform_ru = 'Букмейт Android') 
		< sumIf(a.hours, a.usage_platform_ru = 'Букмейт iOS'), 'iOS', 'Поровну') main_platform
FROM source_db.audition a
JOIN source_db.content c USING(main_content_id)
WHERE 	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
		AND c.main_content_type IN ('Book', 'Audiobook') AND a.hours > 0
GROUP BY puid
HAVING countIf(c.main_content_type = 'Audiobook') > 0 
		OR countIf(c.main_content_type = 'Book') > 0
		)
SELECT  main_platform, user_type, COUNT(user_id) count_users
FROM marked_data
GROUP BY main_platform, user_type
ORDER BY main_platform, user_type;

-- Задание 5

SELECT DISTINCT
    multiIf(c.main_content_type = 'Audiobook', 'Audiobook',
    c.main_content_type = 'Book', 'Book', 'Other') AS category,
    ROUND(avgIf(a.hours, toDayOfWeek(msk_business_dt_str) <= 5) 
        OVER(PARTITION BY category)) AS avg_workdays,
    ROUND(avgIf(a.hours, toDayOfWeek(msk_business_dt_str) >= 6) 
        OVER(PARTITION BY category)) AS avg_weekends
FROM source_db.audition a
JOIN source_db.content c USING(main_content_id)
WHERE 	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web') 
		AND c.main_content_type IN  ('Audiobook', 'Book') AND a.hours > 0;
		
-- Задание 6
		
WITH prepared_data AS (
SELECT 	DISTINCT puid user_id,
		usage_platform_ru platform,
		argMax(app_version, msk_business_dt_str) OVER(PARTITION BY user_id) user_last_version,
		-- Переводим '1.2.3' в [1, 2, 3] и находим макс. по числам
        argMax(app_version, arrayMap(x -> toUInt32(assumeNotNull(x)), 
    	splitByChar('.', assumeNotNull(app_version)))) OVER(PARTITION BY platform) platform_last_version
FROM source_db.audition
WHERE usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
)
SELECT 
    platform,
    round(countIf(user_last_version = platform_last_version) / count() * 100, 2) latest_version_percentage
FROM prepared_data
GROUP BY platform;

-- Задание 7

WITH prepared_data AS (
SELECT 	puid user_id,
		usage_platform_ru platform,
		uniqExact(app_version) - 1 updates_freq
FROM source_db.audition
WHERE usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP BY user_id, platform
)
SELECT platform, ROUND(AVG(updates_freq),2) update_rate
FROM prepared_data
GROUP BY platform;

-- Задание 8

SELECT countIf(has(published_topic_title_list, 'Магия'))
FROM source_db.content
WHERE main_content_type IN  ('Audiobook', 'Book');

-- Задание 9

SELECT 	countIf(main_content_name ILIKE '%магия%' AND NOT has(published_topic_title_list, 'Магия')
		AND NOT has(published_topic_title_list, 'Художественная литература'))
FROM source_db.content
WHERE main_content_type IN  ('Audiobook', 'Book');

-- Задание 10

SELECT ROUND(avgIf(length(published_topic_title_list), has(published_topic_title_list, 'Магия')),2) avg_magic,
ROUND(avg(length(published_topic_title_list)),2) avg_all
FROM source_db.content
WHERE main_content_type IN  ('Audiobook', 'Book');

-- Задание 11

WITH prepared_data AS (
SELECT 	usage_country_name country,
		usage_platform_ru platform,
		round(stddevSamp(hours_sessions_long)/AVG(hours_sessions_long),2) var_coef
FROM source_db.audition
WHERE 	usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
		AND hours_sessions_long > 0
GROUP BY country, platform
-- Оставляем только те группы, где больше одной записи
HAVING count() > 1)
SELECT *
FROM prepared_data
WHERE country = 
(
SELECT country
FROM prepared_data
ORDER BY var_coef DESC
LIMIT 1
)
ORDER BY var_coef DESC;
