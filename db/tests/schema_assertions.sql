-- ============================================================
-- db/tests/schema_assertions.sql
-- تأكيدات على مخطط 20261101_001_recipes_init.sql.
-- تُنفّذ بعد تطبيق المخطط في فحص CI (db-migrations job).
-- كل كتلة DO $$ ... $$ تُثير استثناءً عند الفشل، لذا psql يعيد
-- رمز خروج غير صفر وتُعلّق الوظيفة.
-- ============================================================

-- 1. إدخال وصفة سليمة (الأساس).
INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
VALUES ('t1', 'وصفة تجريبية', 'main', 'easy', 30, 4)
ON CONFLICT (id) DO NOTHING;

INSERT INTO recipe_ingredients (recipe_id, line_no, name, amount, unit)
VALUES ('t1', 1, 'أرز', 2, 'cup')
ON CONFLICT (recipe_id, line_no) DO NOTHING;

INSERT INTO recipe_steps (recipe_id, step_no, text)
VALUES ('t1', 1, 'اطبخ الأرز.')
ON CONFLICT (recipe_id, step_no) DO NOTHING;

-- 2. قيد title فارغ → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
        VALUES ('t2', '   ', 'main', 'easy', 10, 2);
        RAISE EXCEPTION 'expected CHECK failure for empty title (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 3. قيد amount صفر → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_ingredients (recipe_id, line_no, name, amount, unit)
        VALUES ('t1', 2, 'ملح', 0, 'gram');
        RAISE EXCEPTION 'expected CHECK failure for zero amount (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 4. قيد unit مجهول → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_ingredients (recipe_id, line_no, name, amount, unit)
        VALUES ('t1', 3, 'ملح', 1, 'handful');
        RAISE EXCEPTION 'expected CHECK failure for unknown unit (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 5. قيد category مجهول → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
        VALUES ('t3', 'وصفة', 'nonexistent', 'easy', 10, 2);
        RAISE EXCEPTION 'expected CHECK failure for unknown category (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 6. قيد prep_time_minutes > 1440 → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
        VALUES ('t4', 'وصفة', 'main', 'easy', 2000, 2);
        RAISE EXCEPTION 'expected CHECK failure for out-of-range prep time (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 7. cascade delete: حذف الوصفة يحذف مكوناتها وخطواتها.
DELETE FROM recipes WHERE id = 't1';
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM recipe_ingredients WHERE recipe_id = 't1') THEN
        RAISE EXCEPTION 'cascade delete failed for ingredients';
    END IF;
    IF EXISTS (SELECT 1 FROM recipe_steps WHERE recipe_id = 't1') THEN
        RAISE EXCEPTION 'cascade delete failed for steps';
    END IF;
END $$;

-- 8. نص متطرف (4000 حرف) يُقبل — معيار المرحلة 2 رقم 3 على جانب القاعدة.
INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
VALUES ('t5', 'عنوان', 'main', 'easy', 10, 2)
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE big_text TEXT := repeat('س', 4000);
BEGIN
    INSERT INTO recipe_steps (recipe_id, step_no, text)
    VALUES ('t5', 1, big_text)
    ON CONFLICT (recipe_id, step_no) DO NOTHING;
    IF NOT EXISTS (SELECT 1 FROM recipe_steps WHERE recipe_id = 't5') THEN
        RAISE EXCEPTION 'extreme 4000-char step was rejected';
    END IF;
END $$;

-- 9. نص 4001 حرف → يجب أن يُرفض (الحد الأقصى 4000).
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_steps (recipe_id, step_no, text)
        VALUES ('t5', 2, repeat('س', 4001));
        RAISE EXCEPTION 'expected CHECK failure for 4001-char step (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- تنظيف بيانات الاختبار.
DELETE FROM recipes WHERE id IN ('t2','t3','t4','t5');

-- التأكد final: الجداول الثلاثة موجودة.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recipes') THEN
        RAISE EXCEPTION 'recipes table missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recipe_ingredients') THEN
        RAISE EXCEPTION 'recipe_ingredients table missing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recipe_steps') THEN
        RAISE EXCEPTION 'recipe_steps table missing';
    END IF;
END $$;
