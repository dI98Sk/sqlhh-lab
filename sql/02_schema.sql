-- =====================================================================
-- 2. Схема
-- =====================================================================
DROP TABLE IF EXISTS vacancy_prof_classes, vacancy_skills, vacancy_specializations,
                     vacancy_descriptions, vacancies, employer_industries, industries,
                     employers, skills, specializations, prof_areas, prof_classes,
                     areas, experience_levels, schedules, employment_types,
                     billing_types, currencies CASCADE;

-- --- Справочники ------------------------------------------------------
CREATE TABLE areas (
    area_id  integer PRIMARY KEY,
    name     text NOT NULL
);

CREATE TABLE experience_levels (
    experience_id text PRIMARY KEY,          -- noExperience, between1And3, ...
    name          text NOT NULL,
    sort_order    smallint
);

CREATE TABLE schedules (
    schedule_id text PRIMARY KEY,            -- fullDay, remote, flexible, ...
    name        text NOT NULL
);

CREATE TABLE employment_types (
    employment_id text PRIMARY KEY,          -- full, part, project, ...
    name          text NOT NULL
);

CREATE TABLE billing_types (
    billing_type_id text PRIMARY KEY,        -- standard, premium, free, ...
    name            text NOT NULL
);

CREATE TABLE currencies (
    currency_code char(3) PRIMARY KEY        -- RUR, USD, EUR, ...
);

CREATE TABLE prof_areas (                    -- профобласти hh.ru
    prof_area_id integer PRIMARY KEY,
    name         text NOT NULL
);

CREATE TABLE specializations (
    specialization_id text PRIMARY KEY,      -- '1.221'
    prof_area_id      integer NOT NULL REFERENCES prof_areas,
    name              text NOT NULL
);

CREATE TABLE skills (
    skill_id serial PRIMARY KEY,
    name     text NOT NULL UNIQUE
);

CREATE TABLE prof_classes (                  -- классы профессий, размеченные авторами датасета
    prof_class text PRIMARY KEY              -- programmer, tester, devops, ...
);

-- --- Работодатели -----------------------------------------------------
CREATE TABLE employers (
    employer_id   integer PRIMARY KEY,
    name          text NOT NULL,
    trusted       boolean,
    alternate_url text
);

CREATE TABLE industries (
    industry_id serial PRIMARY KEY,
    name        text NOT NULL UNIQUE
);

CREATE TABLE employer_industries (
    employer_id integer REFERENCES employers ON DELETE CASCADE,
    industry_id integer REFERENCES industries,
    PRIMARY KEY (employer_id, industry_id)
);

-- --- Вакансии ---------------------------------------------------------
CREATE TABLE vacancies (
    vacancy_id               bigint PRIMARY KEY,
    name                     text NOT NULL,
    employer_id              integer REFERENCES employers,       -- NULL у анонимных
    area_id                  integer NOT NULL REFERENCES areas,
    experience_id            text REFERENCES experience_levels,
    schedule_id              text REFERENCES schedules,
    employment_id            text REFERENCES employment_types,
    billing_type_id          text REFERENCES billing_types,
    salary_from              integer,
    salary_to                integer,
    salary_currency          char(3) REFERENCES currencies,
    salary_gross             boolean,
    is_anonymous             boolean NOT NULL DEFAULT false,
    premium                  boolean,
    has_test                 boolean,
    response_letter_required boolean,
    accept_handicapped       boolean,
    accept_kids              boolean,
    archived                 boolean,
    address_city             text,
    address_lat              numeric(9,6),
    address_lng              numeric(9,6),
    created_at               timestamptz,
    published_at             timestamptz NOT NULL,
    CHECK (salary_from IS NULL OR salary_to IS NULL OR salary_from <= salary_to)
);

-- Тяжёлые HTML-описания вынесены отдельно, чтобы основная таблица была лёгкой
CREATE TABLE vacancy_descriptions (
    vacancy_id  bigint PRIMARY KEY REFERENCES vacancies ON DELETE CASCADE,
    description text NOT NULL
);

CREATE TABLE vacancy_skills (
    vacancy_id bigint  REFERENCES vacancies ON DELETE CASCADE,
    skill_id   integer REFERENCES skills,
    PRIMARY KEY (vacancy_id, skill_id)
);

CREATE TABLE vacancy_specializations (
    vacancy_id        bigint REFERENCES vacancies ON DELETE CASCADE,
    specialization_id text   REFERENCES specializations,
    PRIMARY KEY (vacancy_id, specialization_id)
);

CREATE TABLE vacancy_prof_classes (
    vacancy_id bigint REFERENCES vacancies ON DELETE CASCADE,
    prof_class text   REFERENCES prof_classes,
    PRIMARY KEY (vacancy_id, prof_class)
);
