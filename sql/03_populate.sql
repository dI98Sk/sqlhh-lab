-- =====================================================================
-- 3. Наполнение (из raw_vacancies)
-- =====================================================================
BEGIN;

-- --- Справочники ------------------------------------------------------
INSERT INTO areas (area_id, name)
SELECT DISTINCT ON (area_id::int) area_id::int, area_name
FROM raw_vacancies
WHERE NULLIF(area_id, '') IS NOT NULL
ORDER BY area_id::int, published_at DESC
ON CONFLICT (area_id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO experience_levels (experience_id, name, sort_order)
SELECT DISTINCT experience_id, experience_name,
       CASE experience_id WHEN 'noExperience' THEN 1 WHEN 'between1And3' THEN 2
                          WHEN 'between3And6' THEN 3 WHEN 'moreThan6'    THEN 4 END
FROM raw_vacancies
WHERE NULLIF(experience_id, '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO schedules (schedule_id, name)
SELECT DISTINCT ON (schedule_id) schedule_id, schedule_name
FROM raw_vacancies WHERE NULLIF(schedule_id, '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO employment_types (employment_id, name)
SELECT DISTINCT ON (employment_id) employment_id, employment_name
FROM raw_vacancies WHERE NULLIF(employment_id, '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO billing_types (billing_type_id, name)
SELECT DISTINCT ON (billing_type_id) billing_type_id, billing_type_name
FROM raw_vacancies WHERE NULLIF(billing_type_id, '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO currencies (currency_code)
SELECT DISTINCT salary_currency
FROM raw_vacancies WHERE NULLIF(salary_currency, '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- Специализации: '1.221 Программирование, Разработка 1 Информационные технологии, интернет, телеком'
-- \1 — обратная ссылка на номер профобласти, отделяет название специализации от названия области.
CREATE TEMP TABLE tmp_spec ON COMMIT DROP AS
SELECT r.id::bigint AS vacancy_id,
       m[1]::int    AS prof_area_id,
       m[1] || '.' || m[2] AS specialization_id,
       m[3]         AS spec_name,
       m[4]         AS prof_area_name
FROM raw_vacancies r
CROSS JOIN LATERAL regexp_split_to_table(r.specializations, '\r?\n') AS line
CROSS JOIN LATERAL regexp_match(btrim(line), '^(\d+)\.(\d+) (.+?) \1 (.+)$') AS m
WHERE m IS NOT NULL;

INSERT INTO prof_areas (prof_area_id, name)
SELECT DISTINCT ON (prof_area_id) prof_area_id, prof_area_name FROM tmp_spec
ON CONFLICT DO NOTHING;

INSERT INTO specializations (specialization_id, prof_area_id, name)
SELECT DISTINCT ON (specialization_id) specialization_id, prof_area_id, spec_name FROM tmp_spec
ON CONFLICT DO NOTHING;

-- Навыки (элементы через перевод строки)
CREATE TEMP TABLE tmp_skill ON COMMIT DROP AS
SELECT DISTINCT r.id::bigint AS vacancy_id, btrim(s) AS skill
FROM raw_vacancies r
CROSS JOIN LATERAL regexp_split_to_table(r.key_skills, '\r?\n') AS s
WHERE btrim(s) <> '';

INSERT INTO skills (name)
SELECT DISTINCT skill FROM tmp_skill
ON CONFLICT (name) DO NOTHING;

-- Классы профессий (через пробел)
CREATE TEMP TABLE tmp_pc ON COMMIT DROP AS
SELECT DISTINCT r.id::bigint AS vacancy_id, pc
FROM raw_vacancies r
CROSS JOIN LATERAL regexp_split_to_table(btrim(r.prof_classes_found), '\s+') AS pc
WHERE pc <> '';

INSERT INTO prof_classes (prof_class)
SELECT DISTINCT pc FROM tmp_pc
ON CONFLICT DO NOTHING;

-- --- Работодатели -----------------------------------------------------
-- Берём самое свежее название/статус работодателя
INSERT INTO employers (employer_id, name, trusted, alternate_url)
SELECT DISTINCT ON (employer_id::int)
       employer_id::int, employer_name, employer_trusted::boolean, NULLIF(employer_alternate_url, '')
FROM raw_vacancies
WHERE NULLIF(employer_id, '') IS NOT NULL
ORDER BY employer_id::int, published_at DESC
ON CONFLICT (employer_id) DO UPDATE
    SET name = EXCLUDED.name, trusted = EXCLUDED.trusted, alternate_url = EXCLUDED.alternate_url;

CREATE TEMP TABLE tmp_ind ON COMMIT DROP AS
SELECT DISTINCT r.employer_id::int AS employer_id, btrim(i) AS industry
FROM raw_vacancies r
CROSS JOIN LATERAL regexp_split_to_table(r.employer_industries, '\r?\n') AS i
WHERE NULLIF(r.employer_id, '') IS NOT NULL AND btrim(i) <> '';

INSERT INTO industries (name)
SELECT DISTINCT industry FROM tmp_ind
ON CONFLICT (name) DO NOTHING;

INSERT INTO employer_industries (employer_id, industry_id)
SELECT t.employer_id, i.industry_id
FROM tmp_ind t JOIN industries i ON i.name = t.industry
ON CONFLICT DO NOTHING;

-- --- Вакансии ---------------------------------------------------------
INSERT INTO vacancies (
    vacancy_id, name, employer_id, area_id, experience_id, schedule_id, employment_id,
    billing_type_id, salary_from, salary_to, salary_currency, salary_gross, is_anonymous,
    premium, has_test, response_letter_required, accept_handicapped, accept_kids, archived,
    address_city, address_lat, address_lng, created_at, published_at)
SELECT
    id::bigint,
    name,
    NULLIF(employer_id, '')::int,
    area_id::int,
    NULLIF(experience_id, ''),
    NULLIF(schedule_id, ''),
    NULLIF(employment_id, ''),
    NULLIF(billing_type_id, ''),
    -- «от» больше «до» — ошибка ввода, такие пары обнуляем, чтобы не нарушать CHECK
    CASE WHEN NULLIF(salary_to, '')::numeric < NULLIF(salary_from, '')::numeric THEN NULL
         ELSE round(NULLIF(salary_from, '')::numeric)::int END,
    CASE WHEN NULLIF(salary_to, '')::numeric < NULLIF(salary_from, '')::numeric THEN NULL
         ELSE round(NULLIF(salary_to, '')::numeric)::int END,
    NULLIF(salary_currency, ''),
    NULLIF(salary_gross, '')::boolean,
    type_id = 'anonymous',
    NULLIF(premium, '')::boolean,
    NULLIF(has_test, '')::boolean,
    NULLIF(response_letter_required, '')::boolean,
    NULLIF(accept_handicapped, '')::boolean,
    NULLIF(accept_kids, '')::boolean,
    NULLIF(archived, '')::boolean,
    NULLIF(address_city, ''),
    NULLIF(address_lat, '')::numeric,
    NULLIF(address_lng, '')::numeric,
    NULLIF(created_at, '')::timestamptz,
    published_at::timestamptz
FROM raw_vacancies
ON CONFLICT (vacancy_id) DO NOTHING;

INSERT INTO vacancy_descriptions (vacancy_id, description)
SELECT id::bigint, description
FROM raw_vacancies
WHERE NULLIF(description, '') IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO vacancy_skills (vacancy_id, skill_id)
SELECT t.vacancy_id, s.skill_id
FROM tmp_skill t JOIN skills s ON s.name = t.skill
ON CONFLICT DO NOTHING;

INSERT INTO vacancy_specializations (vacancy_id, specialization_id)
SELECT DISTINCT vacancy_id, specialization_id FROM tmp_spec
ON CONFLICT DO NOTHING;

INSERT INTO vacancy_prof_classes (vacancy_id, prof_class)
SELECT vacancy_id, pc FROM tmp_pc
ON CONFLICT DO NOTHING;

COMMIT;
