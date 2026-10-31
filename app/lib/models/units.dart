/// وحدات القياس المعيارية — المستوى الابتدائي وفق ADR-0005 (المعتمدة).
///
/// المُعرِّف (slug) ثابت بالإنجليزية ليكون مفتاح تخزين واختبار مستقرًا،
/// وعرضه باللغة يمر عبر ملفات الترجمة (فق ADR-0002) وليس عبر نص مضمّن.
library;

enum RecipeUnit {
  gram('gram'),
  kilogram('kilogram'),
  milliliter('milliliter'),
  liter('liter'),
  cup('cup'),
  tablespoon('tablespoon'),
  teaspoon('teaspoon'),
  piece('piece');

  const RecipeUnit(this.slug);

  final String slug;

  /// العودة null عند قيمة مجهولة — المتصل يقرر (رفض/تنبيه) لا إجهاض.
  static RecipeUnit? fromSlug(String? slug) {
    for (final unit in RecipeUnit.values) {
      if (unit.slug == slug) return unit;
    }
    return null;
  }
}
