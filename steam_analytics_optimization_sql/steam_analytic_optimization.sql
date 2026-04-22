-- Добавление ключей

alter table players 
add constraint players_id_pk primary key (player_id);

alter table games 
add constraint games_id_pk primary key (game_id);

alter table purchased_games 
add constraint purch_games_players_p_id_fk foreign key (player_id)
references players(player_id);

alter table purchased_games 
add constraint purch_games_players_g_id_fk foreign key (game_id)
references games(game_id);

alter table reviews 
add constraint reviews_id_pk primary key (review_id);

alter table reviews 
add constraint reviews_games_g_id_fk foreign key (game_id)
references games(game_id);

alter table  achievements
add constraint achievements_id_pk primary key (achievement_id);

alter table achievements 
add constraint achievements_games_g_id_fk foreign key (game_id)
references games(game_id);

alter table history  
add constraint history_players_p_id_fk foreign key (player_id)
references players(player_id);

alter table history  
add constraint history_achievements_a_id_fk foreign key (achievement_id)
references achievements(achievement_id);

alter table friends   
add constraint friends_players_p_id_fk foreign key (player_id)
references players(player_id);
  
alter table private_steamids   
add constraint private_steamids_players_p_id_fk foreign key (player_id)
references players(player_id);

-- Удаление строк

DELETE FROM reviews
WHERE review_id = 659351;

-- Наполнение таблицы

INSERT INTO reviews (review_id, player_id, game_id, 
review, helpful, funny, awards, posted) VALUES (1185896, 76561198012771369, 280,
'Отличная игра!', 0, 0, 5, '2025-04-28');

-- Ad hoc запрос

SELECT avg(awards)
from reviews r
join games g on r.game_id=g.game_id and title = 'Half-Life: Source';

-- Обновление данных

UPDATE reviews
SET review = 'Отличная игра! Очень понравилось!'
WHERE review_id = 647595;

-- Анализ выполнения запросов

EXPLAIN analyze SELECT *
FROM players p
INNER JOIN (SELECT * FROM purchased_games ORDER BY 1, 2) pg ON p.player_id = pg.player_id
FULL JOIN (SELECT * FROM games ORDER BY 1, 2, 3, 4, 5) g ON pg.game_id = g.game_id
WHERE  p.player_id IS NOT NULL AND  g.title != 'NULL'
AND p.created IS NOT NULL
ORDER BY p.country, g.developers;

EXPLAIN analyze SELECT p.player_id, g.title AS game_title, g.genres
FROM players p
INNER JOIN purchased_games pg ON p.player_id = pg.player_id
INNER JOIN games g ON pg.game_id = g.game_id;

EXPLAIN analyze SELECT *
FROM achievements
WHERE game_id = 12345;

-- Создание индексов

CREATE INDEX idx_achievements_game_id_hash 
ON achievements USING HASH (game_id);

EXPLAIN analyze SELECT *
FROM  history
order by player_id;

CREATE INDEX idx_history_player_id ON history(player_id);

-- Партиционирование

CREATE TABLE history_partitioned (
       player_id int8 NULL,
       achievement_id text NULL,
       date_acquired timestamp NULL,
       CONSTRAINT history_achievements_fk_p FOREIGN KEY (achievement_id) REFERENCES steam.achievements(achievement_id),
       CONSTRAINT history_players_fk_p FOREIGN KEY (player_id) REFERENCES steam.players(player_id)
)
PARTITION BY RANGE (date_acquired);

CREATE TABLE history_partitioned_2020 PARTITION OF history_partitioned
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
 
CREATE TABLE history_partitioned_2021 PARTITION OF history_partitioned
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
 
CREATE TABLE history_partitioned_2022 PARTITION OF history_partitioned
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
 
CREATE TABLE history_partitioned_2023 PARTITION OF history_partitioned
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
 
CREATE TABLE history_partitioned_2024 PARTITION OF history_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

INSERT INTO history_partitioned (player_id, achievement_id, date_acquired)
SELECT player_id, achievement_id, date_acquired
FROM history;

-- Создание и наполнение витрины данных

CREATE TABLE player_activity_vitrine (
player_id int,
    country varchar(50),
    game_id int,
    game_title text,
    achievement_id text,
    date_acquired timestamp,
    review_id int,
    review text,
    helpful_reviews_count int,
    funny_reviews_count int,
    awards_reviews_count int
);

ALTER TABLE player_activity_vitrine
ALTER COLUMN player_id TYPE bigint;


INSERT INTO player_activity_vitrine (
   player_id,
   country,
   game_id,
   game_title,
   achievement_id,
   date_acquired,
   review_id,
   review,
   helpful_reviews_count,
   funny_reviews_count,
   awards_reviews_count
)
SELECT
    p.player_id,
    coalesce(p.country, 'Не указана') as country,
    g.game_id,
    g.title AS game_title,
    h.achievement_id,
    h.date_acquired,
    r.review_id,    
r.review,
    COALESCE(r.helpful, 0) AS helpful_reviews_count,
    COALESCE(r.funny, 0) AS funny_reviews_count,
    COALESCE(r.awards, 0) AS awards_reviews_count
FROM steam.players p
INNER JOIN purchased_games pg ON p.player_id = pg.player_id
INNER JOIN games g ON pg.game_id = g.game_id
INNER JOIN achievements a ON g.game_id = a.game_id
INNER JOIN history_partitioned h ON h.achievement_id = a.achievement_id and h.player_id = p.player_id
LEFT JOIN reviews r ON p.player_id = r.player_id AND g.game_id = r.game_id
WHERE h.date_acquired between '2024-01-01' and '2024-12-31'
AND p.player_id IN (
     SELECT player_id
     FROM purchased_games
     GROUP BY player_id
     HAVING COUNT(game_id) > 3
);



