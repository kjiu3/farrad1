-- ============================================================
-- db/migrations/20261102_001_community_init.sql
-- مخطط المجتمع للمرحلة 3 — الملفات الشخصية والتعليق والتقييم
-- (فق ADR-0009 وADR-0004 وIssue #21).
--
-- قابل للتشغيل من الصفر (idempotent). السياسات تُنشأ شرطيًا لأن
-- CREATE POLICY لا يدعم IF NOT EXISTS.
--
-- حماية إقلاع على قاعدة PostgreSQL مجردة (psql محلي وCI): إن لم
-- يوجد مخطط auth (فوقيّة Supabase) يُنشأ هيكل أدنى يكفي سريان
-- القيود سياسياً (auth.users و auth.uid()). على Supabase الحي
-- يوجد المخطط فلا يُلمس شيء هنا — الدوال الحقيقية باقية.
--
-- لا أسرار هنا: بيانات الاتصال تأتي من متغيرات البيئة (AGENTS.md §3).
-- ============================================================

-- ---------- هيكل أدنى لمخطط auth على قاعدة مجردة ----------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'auth' AND table_name = 'users'
    ) THEN
        CREATE SCHEMA auth;
        CREATE TABLE auth.users (id uuid PRIMARY KEY);
        RAISE NOTICE 'vanilla PG: created top-level auth.users stub (Supabase untouched when present)';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'auth' AND p.proname = 'uid'
    ) THEN
        EXECUTE 'CREATE FUNCTION auth.uid() RETURNS uuid
                 LANGUAGE sql STABLE
                 RETURN NULL::uuid';
        -- المصلح على قاعدة مجردة يعيد NULL دائماً: يوضح أن حارس
        -- الكتابة (user_id = auth.uid()) يمنع المجهول. الاختبار
        -- السلوكي الفعلي للسياسات على Supabase الحي (فق ADR-0009
        -- §التبعات: ما لم يُجرَّب حيًا يُوسم «لم يُختبر بعد»).
    END IF;
END $$;

-- ---------- profiles ----------
-- مرآة مصغّرة لمستخدمي auth.users: المفتاح نفسه، واسم العرض
-- ولغة الواجهة (فق ADR-0002 لغة عربية أولًا).
CREATE TABLE IF NOT EXISTS profiles (
    id            uuid PRIMARY KEY
                  REFERENCES auth.users (id) ON DELETE CASCADE,
    display_name  TEXT NOT NULL
                  CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 50),
    language      TEXT NOT NULL DEFAULT 'ar'
                  CHECK (language IN ('ar','en')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- recipe_comments ----------
CREATE TABLE IF NOT EXISTS recipe_comments (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id   TEXT NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    body        TEXT NOT NULL
                CHECK (char_length(btrim(body)) BETWEEN 1 AND 1000),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recipe_comments_recipe_idx
    ON recipe_comments (recipe_id, created_at);
CREATE INDEX IF NOT EXISTS recipe_comments_user_idx
    ON recipe_comments (user_id);

-- ---------- recipe_ratings ----------
-- المفتاح المشترك (recipe_id, user_id) هو ضمان «تقييم واحد لكل
-- مستخدم لكل وصفة» بنيوياً — لا منطق تطبيق يلزمه (فق ADR-0009 §4).
CREATE TABLE IF NOT EXISTS recipe_ratings (
    recipe_id   TEXT NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    score       SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (recipe_id, user_id)
);

CREATE INDEX IF NOT EXISTS recipe_ratings_recipe_idx
    ON recipe_ratings (recipe_id, score);

-- ---------- RLS: القارئ للجميع والكاتب لمالكه (فق ADR-0009 §4) ----------
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ratings  ENABLE ROW LEVEL SECURITY;

-- profiles: البقاء مرئياً للجميع؛ تحديث الذات فقط.
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles'
          AND policyname = 'profiles_select_all'
    ) THEN
        CREATE POLICY profiles_select_all ON profiles
            FOR SELECT USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles'
          AND policyname = 'profiles_update_self'
    ) THEN
        CREATE POLICY profiles_update_self ON profiles
            FOR UPDATE
            USING (auth.uid() = id)
            WITH CHECK (auth.uid() = id);
    END IF;
END $$;

-- recipe_comments: قراءة للجميع؛ كتابة وتعديل وحذف للمالك فقط.
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_comments'
          AND policyname = 'comments_select_all'
    ) THEN
        CREATE POLICY comments_select_all ON recipe_comments
            FOR SELECT USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_comments'
          AND policyname = 'comments_insert_owner'
    ) THEN
        CREATE POLICY comments_insert_owner ON recipe_comments
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_comments'
          AND policyname = 'comments_update_owner'
    ) THEN
        CREATE POLICY comments_update_owner ON recipe_comments
            FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_comments'
          AND policyname = 'comments_delete_owner'
    ) THEN
        CREATE POLICY comments_delete_owner ON recipe_comments
            FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- recipe_ratings: قراءة للجميع؛ تعديل للمالك فقط — والرقعة
-- الواحدة ضمان المفتاح المشترك أعلاه.
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_ratings'
          AND policyname = 'ratings_select_all'
    ) THEN
        CREATE POLICY ratings_select_all ON recipe_ratings
            FOR SELECT USING (true);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_ratings'
          AND policyname = 'ratings_insert_owner'
    ) THEN
        CREATE POLICY ratings_insert_owner ON recipe_ratings
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_ratings'
          AND policyname = 'ratings_update_owner'
    ) THEN
        CREATE POLICY ratings_update_owner ON recipe_ratings
            FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'recipe_ratings'
          AND policyname = 'ratings_delete_owner'
    ) THEN
        CREATE POLICY ratings_delete_owner ON recipe_ratings
            FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- ---------- ملاحظات مستقبلية ----------
-- 1. ملكية الوصفات المزامنة (عمود owner_id على recipes أو جدول
--    user_recipes) يُحسم عند P3-8 (المزامنة) — ليس في هذا المخطط
--    لأن «شيء واحد لكل PR» (AGENTS §1.2) ومزامنة الوصفات بملكيتها
--    قاعدة مراجعة خالصة تحتاج اختبار مزامنة لا مخططاً فقط.
-- 2. قاموس المرادفات وفهرس البحث النصي للوصفات يبقان وصفية في
--    ADR منفصلة عند بدء البحث الحي (ADR-0008 §2.3).
-- ============================================================
-- انتهى الملف. كل سطر أعلاه قابل للتنفيذ على قاعدة فارغة،
-- والتطبيق الثاني (idempotency) لا يُخطئ.
-- ============================================================
