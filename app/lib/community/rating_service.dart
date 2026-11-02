import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/app_backend.dart';
import 'comment_service.dart' show CommunityOutcome;

/// ملخص تقييم وصفة — قاعدة الحساب الوحيدة الجديدة للتقييم،
/// مُختبرة صريحًا في test/rating_test.dart (فق AGENTS §2.3:
/// قاعدة بلا اختبار لا تُعدّل جوابًا هشًا).
class RatingSummary {
  const RatingSummary({required this.count, this.average});

  final int count;

  /// 0.0..5.0 — فارغة عند صفر تقييمات فلا رقم كاذب يعرض.
  final double? average;

  factory RatingSummary.fromScores(List<int> scores) {
    if (scores.isEmpty) return const RatingSummary(count: 0);
    var total = 0;
    for (final s in scores) {
      if (s < 1 || s > 5) {
        return const RatingSummary(count: 0); // قطع بيانات مخالفة: لا متوسط.
      }
      total += s;
    }
    final avg = total / scores.length;
    return RatingSummary(
      count: scores.length,
      average: double.parse(avg.toStringAsFixed(1)),
    );
  }
}

/// تجريد التقييم بنمط الحقن (AGENTS §2.1).
/// المخطط خلفه: recipe_ratings بعمودين مفتاحيين (recipe_id, user_id) —
/// رقعة واحدة لكل مستخدم بنيويًا (فق ADR-0009 §4).
abstract class RatingService {
  /// درجات الجميع لحساب المتوسط محليًا — فشل الشبكة قائمة فاضية.
  Future<List<int>> listScores(String recipeId);

  /// تقييم المستخدم الحالي للوصفة أو null.
  Future<int?> getMyRating(String recipeId);

  Future<CommunityOutcome> rate(String recipeId, int score);
}

/// التنفيذ الإنتاجي فوق PostgREST. المسار الحي «لم يُختبر بعد»
/// تربيعًا لـ AGENTS §4.1 حتى مفاتيح المالك.
class SupabaseRatingService implements RatingService {
  const SupabaseRatingService();

  static const int _maxRows = 1000; // سقف سلوكي في هذه المرحلة: يوسم تحت.

  @override
  Future<List<int>> listScores(String recipeId) async {
    final client = AppBackend.clientOrNull;
    if (client == null) return const <int>[];
    try {
      final rows = await client
          .from('recipe_ratings')
          .select('score')
          .eq('recipe_id', recipeId)
          .limit(_maxRows);
      return rows.map<int>((row) => (row as Map)['score'] as int).toList();
    } on PostgrestException {
      return const <int>[];
    }
  }

  @override
  Future<int?> getMyRating(String recipeId) async {
    final client = AppBackend.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    try {
      final rows = await client
          .from('recipe_ratings')
          .select('score')
          .eq('recipe_id', recipeId)
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) return null;
      return (rows.first as Map)['score'] as int;
    } on PostgrestException {
      return null;
    }
  }

  @override
  Future<CommunityOutcome> rate(String recipeId, int score) async {
    if (score < 1 || score > 5) {
      return const CommunityOutcome(ok: false, errorKey: 'ratingFailed');
    }
    final client = AppBackend.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return const CommunityOutcome(ok: false, errorKey: 'ratingRequireAuth');
    }
    try {
      // upsert بالمفتاح المشترك (recipe_id, user_id): تقييم واحد
      // لكل مستخدم يُستبدل لا يتكاثر — وفق ADR-0009 §4.
      await client.from('recipe_ratings').upsert(
        <String, dynamic>{
          'recipe_id': recipeId,
          'user_id': userId,
          'score': score,
        },
        onConflict: 'recipe_id,user_id',
      );
      return const CommunityOutcome(ok: true);
    } on PostgrestException {
      return const CommunityOutcome(ok: false, errorKey: 'ratingFailed');
    }
  }
}
