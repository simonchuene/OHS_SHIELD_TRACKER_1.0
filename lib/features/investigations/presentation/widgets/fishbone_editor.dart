// path: lib/features/investigations/presentation/widgets/fishbone_editor.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';

/// Fishbone (Ishikawa) editor — causes grouped by the standard 6M categories.
class FishboneEditor extends StatefulWidget {
  const FishboneEditor({required this.value, required this.onChanged, super.key});
  final Map<String, List<String>> value;
  final ValueChanged<Map<String, List<String>>> onChanged;

  @override
  State<FishboneEditor> createState() => _FishboneEditorState();
}

class _FishboneEditorState extends State<FishboneEditor> {
  late Map<String, List<String>> _data;

  @override
  void initState() {
    super.initState();
    _data = {
      for (final c in InvestigationAnalysis.fishboneCategories) c: List<String>.from(widget.value[c] ?? const []),
    };
  }

  void _emit() => widget.onChanged({for (final e in _data.entries) e.key: List<String>.from(e.value)});

  Future<void> _addCause(String category) async {
    final controller = TextEditingController();
    final cause = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add cause · $category'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Contributing cause')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (cause != null && cause.isNotEmpty) {
      setState(() => _data[category] = [..._data[category]!, cause]);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final category in InvestigationAnalysis.fishboneCategories)
        ExpansionTile(
          title: Text(category),
          subtitle: Text('${_data[category]!.length} cause(s)', style: Theme.of(context).textTheme.labelSmall),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < _data[category]!.length; i++)
                Chip(
                  label: Text(_data[category]![i]),
                  onDeleted: () { setState(() => _data[category]!.removeAt(i)); _emit(); },
                ),
              ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Add'), onPressed: () => _addCause(category)),
            ],),
          ],
        ),
    ],);
  }
}
