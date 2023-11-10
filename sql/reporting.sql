/*
Tutaj zdefiniuj schemę `reporting`
*/
CREATE SCHEMA IF NOT EXISTS reporting;
/*
Tutaj napisz definicję widoku reporting.flight, która:
- będzie usuwać dane o lotach anulowanych `cancelled = 0`
- będzie zawierać kolumnę `is_delayed`, zgodnie z wcześniejszą definicją tj. `is_delayed = 1 if dep_delay_new > 0 else 0` (zaimplementowana w SQL)

Wskazówka:
- SQL - analiza danych > Dzień 4 Proceduralny SQL > Wyrażenia warunkowe
- SQL - analiza danych > Przygotowanie do zjazdu 2 > Widoki
*/
CREATE OR REPLACE VIEW reporting.flight AS
SELECT *, 
  CASE
    WHEN dep_delay_new > 0 THEN 1
    ELSE 0
  END AS is_delayed
FROM public.flight
WHERE cancelled = 0;
/*
Tutaj napisz definicję widoku reporting.top_reliability_roads, która będzie zawierała następujące kolumny:
- `origin_airport_id`,
- `origin_airport_name`,
- `dest_airport_id`,
- `dest_airport_name`,
- `year`,
- `cnt` - jako liczba wykonananych lotów na danej trasie,
- `reliability` - jako odsetek opóźnień na danej trasie,
- `nb` - numerowane od 1, 2, 3 według kolumny `reliability`. W przypadku takich samych wartości powino zwrócić 1, 2, 2, 3... 
Pamiętaj o tym, że w wyniku powinny pojawić się takie trasy, na których odbyło się ponad 10000 lotów.

Wskazówka:
- SQL - analiza danych > Dzień 2 Relacje oraz JOIN > JOIN
- SQL - analiza danych > Dzień 3 - Analiza danych > Grupowanie
- SQL - analiza danych > Dzień 1 Podstawy SQL > Aliasowanie
- SQL - analiza danych > Dzień 1 Podstawy SQL > Podzapytania
*/
CREATE OR REPLACE VIEW reporting.top_reliability_roads AS
With top10 as(
WITH CTE AS
(select
 	origin_airport_id,
 	dest_airport_id,
 	count(*) as cnt,
 	ROUND(SUM(is_delayed)::numeric / count(*),2) as delayed_ratio_reliability, 
 	year
from reporting.flight
group by origin_airport_id, dest_airport_id, year)
SELECT  origin_airport_id, dest_airport_id, cnt, delayed_ratio_reliability, year FROM CTE
WHERE CTE.cnt > 10000
ORDER BY CTE.delayed_ratio_reliability DESC)
SELECT
	top10.origin_airport_id,
	al_dep.display_airport_name as origin_airport_name,
	top10.dest_airport_id,
	al_dest.display_airport_name as dest_airport_name,
	top10.cnt,
	top10.delayed_ratio_reliability,
	top10.year,
	DENSE_RANK() OVER (ORDER BY top10.delayed_ratio_reliability DESC) as nb
FROM top10
LEFT JOIN airport_list AS al_dep USING(origin_airport_id)
LEFT JOIN airport_list AS al_dest ON al_dest.origin_airport_id = top10.dest_airport_id;
/*
Tutaj napisz definicję widoku reporting.year_to_year_comparision, która będzie zawierał następujące kolumny:
- `year`
- `month`,
- `flights_amount`
- `reliability`
*/
CREATE OR REPLACE VIEW reporting.year_to_year_comparision AS
SELECT
    year,
    month,
    SUM(is_delayed) AS flights_amount,
    count(*) as total,
	ROUND(SUM(is_delayed)::numeric / count(*), 2) as not_reliable_ratio
FROM reporting.flight
GROUP BY year, month
ORDER BY year, month;
/*
Tutaj napisz definicję widoku reporting.day_to_day_comparision, który będzie zawierał następujące kolumny:
- `year`
- `day_of_week`
- `flights_amount`
*/
CREATE OR REPLACE VIEW reporting.day_to_day_comparision AS
SELECT
    year,
    day_of_week,
    SUM(is_delayed) AS flights_amount,
    count(*) as total,
	ROUND(SUM(is_delayed)::numeric / count(*), 2) as not_reliable_ratio
FROM reporting.flight
GROUP BY year, day_of_week
ORDER BY year, day_of_week;
/*
Tutaj napisz definicję widoku reporting.day_by_day_reliability, ktory będzie zawierał następujące kolumny:
- `date` jako złożenie kolumn `year`, `month`, `day`, powinna być typu `date`
- `reliability` jako odsetek opóźnień danego dnia

Wskazówki:
- formaty dat w postgresql: [klik](https://www.postgresql.org/docs/13/functions-formatting.html),
- jeśli chcesz dodać zera na początek liczby np. `1` > `01`, posłuż się metodą `LPAD`: [przykład](https://stackoverflow.com/questions/26379446/padding-zeros-to-the-left-in-postgresql),
- do konwertowania ciągu znaków na datę najwygodniej w Postgres użyć `to_date`: [przykład](https://www.postgresqltutorial.com/postgresql-date-functions/postgresql-to_date/)
- do złączenia kilku kolumn / wartości typu string, używa się operatora `||`, przykładowo: SELECT 'a' || 'b' as example

Uwaga: Nie dodawaj tutaj na końcu srednika - przy używaniu split, pojawi się pusta kwerenda, co będzie skutkowało późniejszym błędem przy próbie wykonania skryptu z poziomu notatnika.
*/
DROP VIEW IF EXISTS reporting.day_by_day_reliability;
CREATE OR REPLACE VIEW reporting.day_by_day_reliability AS
SELECT
    to_date(year || '-' || month || '-' || day_of_month, 'YYYY-MM-DD') as date_column,
	ROUND(SUM(is_delayed)::numeric / count(*), 2) as not_reliable_ratio
FROM reporting.flight
GROUP BY date_column
order by not_reliable_ratio desc