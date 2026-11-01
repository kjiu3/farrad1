import 'package:flutter/material.dart';

import '../data/recipe_repository.dart';
import '../l10n.dart';
import '../models/recipe.dart';
import '../search/search_engine.dart';
import '../ui/recipe_detail_screen.dart';
import '../ui/recipe_form_screen.dart';

/// شاشة البحث + فلاتر + قائمة النتائج (PRD §4.2).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.strings,
    required this.repository,
    this.engine = const SearchEngine(),
    this.onToggleLanguage,
    this.otherLanguageLabel,
  });

  final AppStrings strings; // من l10n.dart — نوع ثابت لا dynamic.
  final RecipeRepository repository;
  final SearchEngine engine;
  final VoidCallback? onToggleLanguage;
  final String? otherLanguageLabel;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _maxPrepController = TextEditingController();

  List<Recipe> _recipes = const [];
  List<Recipe> _results = const [];
  RecipeCategory? _category;
  RecipeDifficulty? _difficulty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.repository.list();
    if (!mounted) return;
    setState(() {
      _recipes = list;
      _loading = false;
    });
    _runSearch();
  }

  void _runSearch() {
    final maxPrep = int.tryParse(_maxPrepController.text.trim());
    final query = RecipeQuery(
      text: _controller.text,
      category: _category,
      difficulty: _difficulty,
      maxPrepMinutes: maxPrep,
    );
    final result = widget.engine.search(_recipes, query);
    setState(() => _results = result.recipes);
  }

  String _s(String key) => widget.strings.get(key);

  @override
  void dispose() {
    _controller.dispose();
    _maxPrepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s('appTitle')),
        actions: [
          if (widget.onToggleLanguage != null)
            TextButton(
              onPressed: widget.onToggleLanguage,
              child: Text(widget.otherLanguageLabel ?? ''),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: _s('searchHint'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => _runSearch(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecipeCategory?>(
                    initialValue: _category,
                    decoration: InputDecoration(labelText: _s('filterCategory')),
                    items: [
                      DropdownMenuItem<RecipeCategory?>(
                        value: null,
                        child: Text(_s('filterAll')),
                      ),
                      ...RecipeCategory.values.map(
                        (c) => DropdownMenuItem<RecipeCategory?>(
                          value: c,
                          child: Text(_s('category_${c.slug}')),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _category = v);
                      _runSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<RecipeDifficulty?>(
                    initialValue: _difficulty,
                    decoration: InputDecoration(labelText: _s('filterDifficulty')),
                    items: [
                      DropdownMenuItem<RecipeDifficulty?>(
                        value: null,
                        child: Text(_s('filterAll')),
                      ),
                      ...RecipeDifficulty.values.map(
                        (d) => DropdownMenuItem<RecipeDifficulty?>(
                          value: d,
                          child: Text(_s('difficulty_${d.slug}')),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _difficulty = v);
                      _runSearch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _maxPrepController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _s('filterMaxPrep')),
                    onChanged: (_) => _runSearch(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(child: Text(_s('noResults')))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return Card(
                            child: ListTile(
                              title: Text(r.title),
                              subtitle: Text(
                                '${_s('category_${r.category.slug}')} • '
                                '${r.prepTimeMinutes} ${_s('minutesUnit')}',
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RecipeDetailScreen(
                                      strings: widget.strings,
                                      repository: widget.repository,
                                      recipeId: r.id,
                                    ),
                                  ),
                                );
                                _reload();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecipeFormScreen(
                strings: widget.strings,
                repository: widget.repository,
              ),
            ),
          );
          _reload();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
