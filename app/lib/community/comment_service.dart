import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/app_backend.dart';

/// تعليق وصفة كما في المخطط (`recipe_comments`).
class RecipeComment {
  const RecipeComment({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.body,
  });

  final String id;
  final String recipeId;
  final String userId;
  final String body;
}

/// نتيجة تعليق/تقييم موحدة — لا استثناءات عبر الواجهة.
class CommunityOutcome {
  const CommunityOutcome({required this.ok, this.errorKey});

  final bool ok;
  final String? errorKey;
}

/// تجريد التعليق بنمط الحقن (AGENTS §2.1) — التنفيذ الحي يُجرَّب
/// بعد مفاتيح المالك وحينها يخرج من «لم يُختبر بعد».
abstract class CommentService {
  /// فشل الشبكة يعيد قائمة فاضية: الواجهة تعرض «لا تعليقات بعد»
  /// بدل انهيار الشاشة — فشل آمن مطابق لبنود ADR-0009.
  Future<List<RecipeComment>> list(String recipeId);

  Future<CommunityOutcome> add(String recipeId, String body);
}

/// التنفيذ الإنتاجي فوق PostgREST.
class SupabaseCommentService implements CommentService {
  const SupabaseCommentService();

  @override
  Future<List<RecipeComment>> list(String recipeId) async {
    final client = AppBackend.clientOrNull;
    if (client == null) return const <RecipeComment>[];
    try {
      final rows = await client
          .from('recipe_comments')
          .select()
          .eq('recipe_id', recipeId)
          .order('created_at', ascending: false)
          .limit(100);
      return rows
          .map<RecipeComment>((row) => RecipeComment(
                id: row['id'] as String,
                recipeId: row['recipe_id'] as String,
                userId: row['user_id'] as String,
                body: row['body'] as String,
              ))
          .toList();
    } on PostgrestException {
      return const <RecipeComment>[];
    }
  }

  @override
  Future<CommunityOutcome> add(String recipeId, String body) async {
    final client = AppBackend.clientOrNull;
    if (client == null) {
      return const CommunityOutcome(
        ok: false,
        errorKey: 'commentRequireAuth',
      );
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const CommunityOutcome(
        ok: false,
        errorKey: 'commentRequireAuth',
      );
    }
    try {
      await client.from('recipe_comments').insert(
        <String, dynamic>{
          'recipe_id': recipeId,
          'user_id': userId,
          'body': body,
        },
      );
      return const CommunityOutcome(ok: true);
    } on PostgrestException {
      return const CommunityOutcome(ok: false, errorKey: 'commentFailed');
    }
  }
}
