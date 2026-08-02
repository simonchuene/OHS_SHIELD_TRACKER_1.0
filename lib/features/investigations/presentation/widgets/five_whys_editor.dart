// path: lib/features/investigations/presentation/widgets/five_whys_editor.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Editable 5-Whys chain — each step drills into the prior answer. Not capped at
/// exactly five; five is the guideline. `onChanged` returns the current list.
class FiveWhysEditor extends StatefulWidget {
  const FiveWhysEditor({required this.value, required this.onChanged, super.key});
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  State<FiveWhysEditor> createState() => _FiveWhysEditorState();
}

class _FiveWhysEditorState extends State<FiveWhysEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final seed = widget.value.isEmpty ? [''] : widget.value;
    _controllers = [for (final w in seed) TextEditingController(text: w)];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final c in _controllers) c.text.trim()]..removeWhere((e) => e.isEmpty));

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < _controllers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            CircleAvatar(radius: 12, backgroundColor: AppColors.infoBlue, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controllers[i],
                decoration: InputDecoration(hintText: i == 0 ? 'Why did it happen?' : 'Why? (drills into #$i)'),
                onChanged: (_) => _emit(),
              ),
            ),
            if (_controllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => setState(() { _controllers.removeAt(i).dispose(); _emit(); }),
              ),
          ],),
        ),
      TextButton.icon(
        onPressed: () => setState(() => _controllers.add(TextEditingController())),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add why'),
      ),
    ],);
  }
}
