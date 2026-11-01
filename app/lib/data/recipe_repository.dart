import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

/// واجهة مستودع الوصفات — تُستخدم من الشاشات (فق ADR-0008: تبديل
/// التنفيذ محلي/حي بلا إعادة كتابة المنطق).
abstract class RecipeRepository {
  Future<List<Recipe>> list();
  Future<Recipe?> get(String id);
  Future<void> save(Recipe recipe);
  Future<void> delete(String id);
}

/// مستودع في الذاكرة — للبحث والاختبارات (بدون تبعية).
class InMemoryRecipeRepository implements RecipeRepository {
  InMemoryRecipeRepository(List<Recipe> seed) : _items = List.of(seed);

  final List<Recipe> _items;

  @override
  Future<List<Recipe>> list() async => List.unmodifiable(_items);

  @override
  Future<Recipe?> get(String id) async {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> save(Recipe recipe) async {
    final idx = _items.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      _items[idx] = recipe;
    } else {
      _items.add(recipe);
    }
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
  }
}

/// مستودع مُثبَّت محليًا (shared_preferences) — يبدأ من بذور (seed)
/// ثم يدمج التعديلات/ال additions/الحذف من التخزين.
class SharedPreferencesRecipeRepository implements RecipeRepository {
  SharedPreferencesRecipeRepository({required this.seed});

  final List<Recipe> seed;

  static const _storageKey = 'farrad.saved_recipes';
  static const _deletedKey = 'farrad.deleted_recipe_ids';

  SharedPreferences? _prefs;
  List<Recipe>? _cache;

  Future<void> _ensure() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _cache = await _load();
  }

  Future<List<Recipe>> _load() async {
    final prefs = _prefs!;
    final deleted = (prefs.getStringList(_deletedKey) ?? const []).toSet();
    final raw = prefs.getString(_storageKey);
    final overrides = <String, Recipe>{};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final r = Recipe.fromJson(item);
            if (r != null) overrides[r.id] = r;
          }
        }
      } catch (_) {
        // بيانات فاسدة — تجاهل وأعد البناء من البذور.
      }
    }
    final result = <Recipe>[];
    for (final s in seed) {
      if (deleted.contains(s.id)) continue;
      result.add(overrides.remove(s.id) ?? s);
    }
    // additions (ids not in seed).
    for (final r in overrides.values) {
      result.add(r);
    }
    return result;
  }

  Future<void> _persist(List<Recipe> items) async {
    final prefs = _prefs!;
    final overrides = <Map<String, dynamic>>[];
    final seedIds = seed.map((s) => s.id).toSet();
    final deleted = <String>[];
    // additions + edits
    for (final r in items) {
      if (seedIds.contains(r.id)) {
        // persist only if changed from seed.
        final original = seed.firstWhere((s) => s.id == r.id);
        if (r.toJson().toString() != original.toJson().toString()) {
          overrides.add(r.toJson());
        }
      } else {
        overrides.add(r.toJson());
      }
    }
    for (final s in seed) {
      if (!items.any((r) => r.id == s.id)) deleted.add(s.id);
    }
    await prefs.setString(_storageKey, json.encode(overrides));
    await prefs.setStringList(_deletedKey, deleted);
  }

  @override
  Future<List<Recipe>> list() async {
    await _ensure();
    _cache ??= await _load();
    return List.unmodifiable(_cache!);
  }

  @override
  Future<Recipe?> get(String id) async {
    final items = await list();
    for (final r in items) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> save(Recipe recipe) async {
    await _ensure();
    final items = List<Recipe>.from(_cache ?? await _load());
    final idx = items.indexWhere((r) => r.id == recipe.id);
    if (idx >= 0) {
      items[idx] = recipe;
    } else {
      items.add(recipe);
    }
    _cache = items;
    await _persist(items);
  }

  @override
  Future<void> delete(String id) async {
    await _ensure();
    final items = List<Recipe>.from(_cache ?? await _load());
    items.removeWhere((r) => r.id == id);
    _cache = items;
    await _persist(items);
  }
}
