import '../models/recipe.dart';
import '../text/arabic_normalizer.dart';

/// معيار استعلام البحث — نص حر + فلاتر وفق PRD §4.2.
class RecipeQuery {
  const RecipeQuery({
    this.text = '',
    this.category,
    this.difficulty,
    this.maxPrepMinutes,
  });

  final String text;
  final RecipeCategory? category;
  final RecipeDifficulty? difficulty;
  final int? maxPrepMinutes;

  bool get hasText => text.trim().isNotEmpty;
}

/// مواضع الإصابة المحتملة داخل الوصفة.
enum HitField { title, ingredient, step }

/// نتيجة مطابقة واحدة: الوصفة + درجتها + حقلها لكل كلمة استعلامية.
class RecipeHit {
  const RecipeHit({required this.recipe, required this.score, required this.tokenFields});

  final Recipe recipe;
  final double score;

  /// لكل كلمة استعلامية موضع الإصابة الذي أثبتها.
  final Map<String, List<HitField>> tokenFields;
}

/// محرك البحث النصي المحلي (فق ADR-0008): يعمل داخل التطبيق فوق
/// التطبيع المعياري (PRD §4.2)، وهو مصدر الحقيقة للاختبارات على
/// الـ20 وصفة النموذجية.
///
/// قواعد التطابق:
/// 1. كل كلمات الاستعلام **كلها** يجب أن تصيب الوصفة في أي حقل (AND).
/// 2. الاستعلام الفارغ (بلا كلمات) يعني «كل الوصفات» بعد الفلاتر.
/// 3. الفلاتر (التصنيف، الصعوبة، أقصى وقت) تطبق قبل المطابقة اللغوية.
/// 4. الترتيب: أعلى درجة أولًا، وتعادل الدرجة ينصرف لوصفة محدثة أحدث.
class SearchEngine {
  const SearchEngine();

  SearchResult search(List<Recipe> recipes, RecipeQuery query) {
    final filteredByMeta = recipes.where((r) {
      if (query.category != null && r.category != query.category) return false;
      if (query.difficulty != null && r.difficulty != query.difficulty) {
        return false;
      }
      if (query.maxPrepMinutes != null &&
          r.prepTimeMinutes > query.maxPrepMinutes!) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (!query.hasText) return SearchResult(_newestAsHits(filteredByMeta));

    final queryNorm = normalizeArabic(query.text);
    if (queryNorm.isEmpty) {
      return SearchResult(_newestAsHits(filteredByMeta));
    }
    final tokens =
        queryNorm.split(' ').where((t) => t.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return SearchResult(_newestAsHits(filteredByMeta));

    final hits = <RecipeHit>[];
    for (final recipe in filteredByMeta) {
      final hit = _match(recipe, tokens);
      if (hit != null) hits.add(hit);
    }

    final sorted = hits.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        // التعادل: الأحدث أولًا.
        return b.recipe.updatedAt.compareTo(a.recipe.updatedAt);
      });
    return SearchResult(sorted);
  }

  /// يعيد null عند فشل أي كلمة من الاستعلام في كل الحقول.
  RecipeHit? _match(Recipe recipe, List<String> tokens) {
    final titleNorm = normalizeArabic(recipe.title);
    final titleWords = titleNorm.split(' ');
    final ingredientsNorm =
        recipe.ingredients.map((i) => normalizeArabic(i.name)).toList();
    final stepsNorm = recipe.steps.map(normalizeArabic).toList();

    double score = 0;
    final tokenFields = <String, List<HitField>>{};

    for (final token in tokens) {
      final fields = <HitField>[];

      final titleWord = titleWords.contains(token);
      final titlePart = titleWord || titleNorm.contains(token);
      if (titlePart) {
        fields.add(HitField.title);
        score += titleWord ? 6 : 4;
      }

      if (ingredientsNorm.any((n) => n.contains(token))) {
        fields.add(HitField.ingredient);
        score += 2;
      }

      if (stepsNorm.any((s) => s.contains(token))) {
        fields.add(HitField.step);
        score += 1;
      }

      if (fields.isEmpty) return null; // كلمة بلا إصابة → لا تطابق.
      tokenFields[token] = fields;
    }

    return RecipeHit(recipe: recipe, score: score, tokenFields: tokenFields);
  }
}

/// نتيجة بحث بنهائية مرتبة.
class SearchResult {
  const SearchResult(this.hits);

  final List<RecipeHit> hits;

  bool get isEmpty => hits.isEmpty;
  bool get isNotEmpty => hits.isNotEmpty;

  /// الوصفات فقط بترتيب النتيجة — للاستخدام المباشر في الواجهة والاختبار.
  List<Recipe> get recipes => hits.map((h) => h.recipe).toList(growable: false);
}

List<Recipe> _sortByNewest(List<Recipe> recipes) {
  final copy = recipes.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return copy;
}

/// مسار «بلا نص» النتائج تُسرد كيعاب صفرية (درجاتها متساوية)،
/// فترتيبها النهائي يؤول للحدث: الأحدث أولًا.
List<RecipeHit> _newestAsHits(List<Recipe> recipes) {
  return _sortByNewest(recipes)
      .map((r) => RecipeHit(recipe: r, score: 0, tokenFields: const {}))
      .toList(growable: false);
}
