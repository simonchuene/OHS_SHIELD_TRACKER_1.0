// path: lib/shared/widgets/select_one_dialog.dart
import 'package:flutter/material.dart';

/// One option in a [showSelectOneDialog] list.
typedef SelectOption<T> = ({T value, String label});

/// Pick one item from a list, committing **only** when the user confirms.
///
/// Replaces the `SimpleDialog` + `SimpleDialogOption` shape, which pops on tap:
/// touching a name was the same as agreeing to it, so a mis-tap wrote a change
/// immediately with no chance to reconsider. Here a tap only selects; the change
/// happens on the confirm button, which stays disabled until something is
/// chosen.
///
/// Returns the chosen value, or null if dismissed or cancelled — so callers keep
/// the existing "null means do nothing" contract.
Future<T?> showSelectOneDialog<T>({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  required List<SelectOption<T>> options,
  T? initialValue,
  String emptyMessage = 'Nothing available',
}) {
  return showDialog<T?>(
    context: context,
    builder: (dialogContext) {
      var selected = initialValue;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: options.isEmpty
              ? Text(emptyMessage)
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final o in options)
                        ListTile(
                          // Deliberately not RadioListTile: its groupValue /
                          // onChanged are deprecated in this Flutter version.
                          leading: Icon(
                            selected == o.value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(
                            o.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: selected == o.value,
                          onTap: () => setState(() => selected = o.value),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              // Disabled until a choice exists, so the confirm button cannot
              // commit nothing.
              onPressed: selected == null ? null : () => Navigator.pop(dialogContext, selected),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );
}
