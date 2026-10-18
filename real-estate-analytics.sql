/* 
Проект первого модуля: анализ данных для агентства недвижимости
Часть 2. Решаем ad hoc задачи
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 categorized AS (
    SELECT 
        fl.id,
        ci.city,
        fl.total_area,
        fl.rooms,
        fl.balcony,
        ad.days_exposition,
        ad.last_price/nullif (fl.total_area, 0) AS price_m2,
        CASE 
            WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN days_exposition >= 181 THEN '181+ days'
            ELSE 'non category'
        END AS category, 
        CASE
            WHEN ci.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region_group
FROM real_estate.advertisement ad
JOIN filtered_id fi ON ad.id = fi.id
join real_estate.flats as fl on fi.id = fl.id
join real_estate.city as ci on fl.city_id =ci.city_id
join real_estate.type as t on fl.type_id = t.type_id
WHERE t.type = 'город'
AND ad.first_day_exposition >= DATE '2015-01-01'
  AND ad.first_day_exposition <  DATE '2019-01-01'
)
SELECT 
    region_group,
    category,
    COUNT(id) AS flats_count,
    FLOOR(AVG(price_m2)* 100) / 100 AS avg_price_per_m2,
    FLOOR(AVG(total_area) * 100) / 100 AS avg_total_area,
    FLOOR(AVG(rooms) * 100) / 100 AS avg_rooms,
    FLOOR(AVG(balcony)* 100) / 100 AS avg_balcony
FROM categorized
WHERE region_group IN ('Санкт-Петербург', 'Ленинградская область')
GROUP BY region_group, category
ORDER BY region_group, category;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
       PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
       PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
       PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
       PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
   SELECT id
    FROM real_estate.flats
   WHERE
       total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
   ),
ad_periods AS (
    SELECT
        fi.id,
        date_trunc('month', ad.first_day_exposition) AS month_publication,
        date_trunc('month', ad.first_day_exposition + (ad.days_exposition || ' days')::interval) AS month_removal,
        ad.last_price,
        fl.total_area
    FROM real_estate.advertisement ad
    JOIN real_estate.flats fl ON ad.id = fl.id
    join filtered_id as fi on fl.id = fi.id
    join real_estate.type as t on fl.type_id = t.type_id
    WHERE fl.total_area > 0
    AND t.type = 'город'
    AND ad.first_day_exposition >= DATE '2015-01-01'
    AND ad.first_day_exposition <  DATE '2019-01-01'
),
stats_publication AS (
    SELECT 
        EXTRACT(MONTH FROM month_publication) AS month,
        COUNT(*) AS announcements_count,
        AVG(last_price / total_area) AS avg_price_per_m2,
        AVG(total_area) AS avg_total_area
    FROM ad_periods
    GROUP BY EXTRACT(MONTH FROM month_publication)
),
stats_removal AS (
    SELECT 
        EXTRACT(MONTH FROM month_removal) AS month,
        COUNT(*) AS announcements_count,
        AVG(last_price / total_area) AS avg_price_per_m2,
        AVG(total_area) AS avg_total_area
    FROM ad_periods
    GROUP BY EXTRACT(MONTH FROM month_removal)
)
SELECT
    month,
    announcements_count,
    FLOOR(avg_price_per_m2 * 100) / 100 as avg_price_per_m2,
    FLOOR(avg_total_area * 100) / 100 as avg_total_area,
    'publication' AS period_type
FROM stats_publication
UNION ALL
SELECT
    month,
    announcements_count,
    FLOOR(avg_price_per_m2 * 100) / 100 as avg_price_per_m2,
    FLOOR(avg_total_area * 100) / 100 as avg_total_area,
    'removal' AS period_type
FROM stats_removal
ORDER BY month, period_type;