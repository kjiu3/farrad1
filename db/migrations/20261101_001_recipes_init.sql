-- ============================================================
-- db/migrations/20261101_001_recipes_init.sql
-- أول مخطط للوصفات — المرحلة 2 (فق ADR-0004 وADR-0008).
--
-- قابل للتشغيل من الصفر (idempotent): كل كيان يُنشأ بـ IF NOT EXISTS،
-- لذا إعادة تطبيقه (كما في فحص idempotency في CI) لا تفشل.
-- لا أسرار هنا: بيانات الاتصال تأتي من متغيرات البيئة (AGENTS.md §3).
-- ============================================================

-- ---------- recipes ----------
CREATE TABLE IF NOT EXISTS recipes (
    id              TEXT PRIMARY KEY,
    title           TEXT NOT NULL
                    CHECK (char_length(btrim(title)) BETWEEN 1 AND 500),
    category        TEXT NOT NULL
                    CHECK (category IN ('main','appetizer','dessert','drink','baked')),
    difficulty      TEXT NOT NULL
                    CHECK (difficulty IN ('easy','medium','hard')),
    prep_time_minutes INTEGER NOT NULL
                    CHECK (prep_time_minutes > 0 AND prep_time_minutes <= 1440),
    base_servings    INTEGER NOT NULL
                    CHECK (base_servings > 0 AND base_servings <= 1000),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recipes_category_idx    ON recipes (category);
CREATE INDEX IF NOT EXISTS recipes_difficulty_idx  ON recipes (difficulty);
CREATE INDEX IF NOT EXISTS recipes_prep_time_idx   ON recipes (prep_time_minutes);

-- ---------- recipe_ingredients ----------
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    recipe_id   TEXT NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    line_no     INTEGER NOT NULL CHECK (line_no > 0),
    name        TEXT NOT NULL
                CHECK (char_length(btrim(name)) BETWEEN 1 AND 200),
    amount      NUMERIC(10, 3) NOT NULL CHECK (amount > 0),
    unit        TEXT NOT NULL
                CHECK (unit IN ('gram','kilogram','milliliter','liter',
                                'cup','tablespoon','teaspoon','piece')),
    PRIMARY KEY (recipe_id, line_no)
);

CREATE INDEX IF NOT EXISTS recipe_ingredients_unit_idx ON recipe_ingredients (unit);

-- ---------- recipe_steps ----------
CREATE TABLE IF NOT EXISTS recipe_steps (
    recipe_id   TEXT NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    step_no     INTEGER NOT NULL CHECK (step_no > 0),
    text        TEXT NOT NULL
                CHECK (char_length(btrim(text)) BETWEEN 1 AND 4000),
    PRIMARY KEY (recipe_id, step_no)
);

-- ---------- ملاحظات مستقبلية ----------
-- 1. التطبيع (تيسير ث/ت/ه/ة/ى/ي/التشكيك) يعمل حاليًا داخل التطبيق
--    (app/lib/text/arabic_normalizer.dart). عندها الاتصال الحي (المرحلة 3)
--    إما يُخزِّن عمودًا «title_normalized» مُحسوبًا أو يُعيد استخدام
--    دالة SQL مماثلة — قرار متروك لـ ADR لاحق (ADR-0007 §3).
-- 2. صور الوصفة (خارج نطاق المرحلة 2) تُضاف جدولًا منفصلاً (recipe_images)
--    مع قيود نوع/حجم (ADR-0004 §4) — PR لاحق.
-- ============================================================
-- انتهى الملف. كل سطر أعلاه قابل للتنفيذ على قاعدة فارغة،
-- والتطبيق الثاني (idempotency) لا يُخطئ.
-- ============================================================
