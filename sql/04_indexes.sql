-- =====================================================================
-- 4. Индексы и статистика
-- =====================================================================
CREATE INDEX IF NOT EXISTS ix_vacancies_employer     ON vacancies (employer_id);
CREATE INDEX IF NOT EXISTS ix_vacancies_area         ON vacancies (area_id);
CREATE INDEX IF NOT EXISTS ix_vacancies_published    ON vacancies (published_at);
CREATE INDEX IF NOT EXISTS ix_vacancies_experience   ON vacancies (experience_id);
CREATE INDEX IF NOT EXISTS ix_vacancy_skills_skill   ON vacancy_skills (skill_id);
CREATE INDEX IF NOT EXISTS ix_vacancy_spec_spec      ON vacancy_specializations (specialization_id);
CREATE INDEX IF NOT EXISTS ix_vacancy_pc_class       ON vacancy_prof_classes (prof_class);
CREATE INDEX IF NOT EXISTS ix_employer_ind_industry  ON employer_industries (industry_id);

ANALYZE;

-- После проверки сырую таблицу можно очистить, чтобы освободить место:
-- TRUNCATE raw_vacancies;
