import 'package:flutter/material.dart';

import '../data/recipe_repository.dart';
import '../models/recipe.dart';
import '../models/units.dart';
import '../ui/recipe_form_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.strings,
    required this.repository,
    required this.recipeId,
  });

  final dynamic strings;
  final RecipeRepository repository;
  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _loading = true;

  String _s(String key) => widget.strings.get(key) as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.repository.get(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _recipe = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_s('appTitle'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = _recipe;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_s('appTitle'))),
        body: Center(child: Text(_s('recipeNotFound'))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecipeFormScreen(
                    strings: widget.strings,
                    repository: widget.repository,
                    initial: r,
                  ),
                ),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              // الحذف لا يتم إلا بعد تأكيد — نقرة واحدة لا تُلغي بيانات.
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(_s('deleteConfirmTitle')),
                  content: Text(_s('deleteConfirmBody')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(_s('deleteConfirmNo')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(_s('deleteConfirmYes')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await widget.repository.delete(r.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            r.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(_s('category_${r.category.slug}'))),
              Chip(label: Text(_s('difficulty_${r.difficulty.slug}'))),
              Chip(
                label: Text(
                  '${r.prepTimeMinutes} ${_s('minutesUnit')}',
                ),
              ),
              Chip(
                label: Text(
                  '${r.baseServings} ${_s('servingsUnit')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeIngredients'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...r.ingredients.map(
            (i) => ListTile(
              dense: true,
              title: Text(i.name),
              trailing: Text('${i.amount} ${_unitLabel(i.unit)}'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _s('recipeSteps'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...r.steps.asMap().entries.map(
                (e) => ListTile(
                  leading: CircleAvatar(child: Text('${e.key + 1}')),
                  title: Text(e.value),
                ),
              ),
        ],
      ),
    );
  }

  String _unitLabel(RecipeUnit u) => _s('unit_${u.slug}');
}
