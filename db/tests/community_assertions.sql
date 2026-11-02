-- ============================================================
-- db/tests/community_assertions.sql
-- تأكيدات على مخطط 20261102_001_community_init.sql (المرحلة 3).
-- تُنفّذ بعد تطبيق المخططين في فحص CI (db-migrations job) —
-- CI الآن يمر على كل ملفات db/tests/*.sql.
-- كل كتلة DO $$ ... $$ تُثير استثناءً عند الفشل، لذا psql يعيد
-- رمز خروج غير صفر وتُعلّق الوظيفة.
-- ============================================================

-- 0. بذور: وصفة + مستخدم + ملف شخصي (أساس الفحوص).
INSERT INTO recipes (id, title, category, difficulty, prep_time_minutes, base_servings)
VALUES ('t1', 'وصفة تجريبية', 'main', 'easy', 30, 4)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id)
VALUES ('11111111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, display_name)
VALUES ('11111111-1111-1111-1111-111111111111', 'طباخ تجريبي')
ON CONFLICT (id) DO NOTHING;

-- 1. تعليق سليم يُقبل، وتفاصيله صحيحة.
INSERT INTO recipe_comments (recipe_id, user_id, body)
VALUES ('t1', '11111111-1111-1111-1111-111111111111', 'سليمة ولذيذة!')
ON CONFLICT DO NOTHING;

DO $$
DECLARE
    n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM recipe_comments
    WHERE recipe_id = 't1'
      AND user_id = '11111111-1111-1111-1111-111111111111'
      AND body = 'سليمة ولذيذة!';
    IF n <> 1 THEN
        RAISE EXCEPTION 'expected exactly 1 valid comment (got %)', n;
    END IF;
END $$;

-- 2. تعليق جسمه فراغات → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_comments (recipe_id, user_id, body)
        VALUES ('t1', '11111111-1111-1111-1111-111111111111', '   ');
        RAISE EXCEPTION 'expected CHECK failure for blank comment body (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 3. تعليق أطول من 1000 حرف → يجب أن يُرفض (حد الواجهة نفسه).
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_comments (recipe_id, user_id, body)
        VALUES ('t1', '11111111-1111-1111-1111-111111111111', repeat('م', 1001));
        RAISE EXCEPTION 'expected CHECK failure for >1000-char comment (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 4. تعليق على وصفة غير موجودة → يجب أن يُرفض (FK).
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_comments (recipe_id, user_id, body)
        VALUES ('no-such-recipe', '11111111-1111-1111-1111-111111111111', 'نص');
        RAISE EXCEPTION 'expected FK failure for unknown recipe_id (got success)';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END $$;

-- 5. تعليق من مستخدم غير موجود → يجب أن يُرفض (FK).
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_comments (recipe_id, user_id, body)
        VALUES ('t1', '99999999-9999-9999-9999-999999999999', 'نص');
        RAISE EXCEPTION 'expected FK failure for unknown user_id (got success)';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END $$;

-- 6. تقييم سليم (3/5) يُقبل.
INSERT INTO recipe_ratings (recipe_id, user_id, score)
VALUES ('t1', '11111111-1111-1111-1111-111111111111', 3)
ON CONFLICT (recipe_id, user_id) DO NOTHING;

DO $$
DECLARE
    n bigint;
BEGIN
    SELECT count(*) INTO n
    FROM recipe_ratings
    WHERE recipe_id = 't1'
      AND score = 3;
    IF n <> 1 THEN
        RAISE EXCEPTION 'expected exactly 1 valid rating (got %)', n;
    END IF;
END $$;

-- 7. تقييم بصفر → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_ratings (recipe_id, user_id, score)
        VALUES ('t1', '11111111-1111-1111-1111-111111111111', 0);
        RAISE EXCEPTION 'expected CHECK failure for zero score (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 8. تقييم بستة → يجب أن يُرفض.
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_ratings (recipe_id, user_id, score)
        VALUES ('t1', '11111111-1111-1111-1111-111111111111', 6);
        RAISE EXCEPTION 'expected CHECK failure for score >5 (got success)';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END $$;

-- 9. مفتاح (recipe_id, user_id) يمنع تقييمين لنفس المستخدم على
--    نفس الوصفة — ضمان الرقعة الواحدة بنيوياً (فق ADR-0009 §4).
DO $$
BEGIN
    BEGIN
        INSERT INTO recipe_ratings (recipe_id, user_id, score)
        VALUES ('t1', '11111111-1111-1111-1111-111111111111', 4);
        RAISE EXCEPTION 'expected unique failure for duplicate rating (got success)';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;
END $$;

-- 10. RLS مفعّل على الجداول الثلاثة (بنيوياً؛ الاختبار السلوكي
--     الحقيقي يجرى على Supabase الحي — فق ADR-0009 §التبعات).
DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(c.relname, ', ')
    INTO bad
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('profiles', 'recipe_comments', 'recipe_ratings')
      AND NOT c.relrowsecurity;
    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'RLS not enabled on: %', bad;
    END IF;
END $$;

-- 11. السياسات المطلوبة كلها موجودة بأسمائها (بنيوياً).
DO $$
DECLARE
    missing text;
BEGIN
    WITH expected(name, tablename) AS (
        VALUES
            ('profiles_select_all',   'profiles'),
            ('profiles_update_self',  'profiles'),
            ('comments_select_all',   'recipe_comments'),
            ('comments_insert_owner', 'recipe_comments'),
            ('comments_update_owner', 'recipe_comments'),
            ('comments_delete_owner', 'recipe_comments'),
            ('ratings_select_all',    'recipe_ratings'),
            ('ratings_insert_owner',  'recipe_ratings'),
            ('ratings_update_owner',  'recipe_ratings'),
            ('ratings_delete_owner',  'recipe_ratings')
    )
    SELECT string_agg(e.name || ' on ' || e.tablename, ', ')
    INTO missing
    FROM expected e
    LEFT JOIN pg_policies p
        ON p.schemaname = 'public'
       AND p.tablename = e.tablename
       AND p.policyname = e.name
    WHERE p.policyname IS NULL;
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'missing RLS policies: %', missing;
    END IF;
END $$;

-- 12. حارس الكتابة المجهول (auth.uid() = user_id يعيد NULL
--     فليس TRUE) يُفحص سلوكياً على Supabase الحي فقط — على
--     القاعدة المجردة لا توجد أدوار anon/authenticated لجلستها،
--     لذا لا تأكيد سلوكي محلي هنا (فق ADR-0009 §التبعات).
-- ============================================================
-- انتهى الملف. كل سطر أعلاه قابل للتنفيذ بعد المخططين،
-- والتطبيق الثاني (idempotency) لا يُخطئ إذ ON CONFLICT
-- يغمض كل سجل أدخله السابق.
-- ============================================================
