// path: test/features/inspections/inspection_dto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/inspections/data/inspection_dtos.dart';

/// `toEntity` sorts items by position. It used to sort the list it was handed,
/// which threw `Cannot modify an unmodifiable list` whenever that list was a
/// const — and `list()` passes `overrideItems: const []` for every row, because
/// the list query does not fetch items. The repository's catch reported the
/// failure as "server unavailable", so the inspections screen showed
/// "No inspections yet" rather than an error. It only broke once a company
/// actually had an inspection, which is why it survived.
void main() {
  Map<String, dynamic> json({List<Map<String, dynamic>>? items}) => {
        'id': 'insp-1',
        'company_id': 'company-1',
        'inspection_type': 'housekeeping',
        'inspector_id': 'user-1',
        'status': 'submitted',
        if (items != null) 'inspection_items': items,
      };

  test('survives the const override the list query passes', () {
    final entity = InspectionDto.fromJson(json()).toEntity(overrideItems: const []);
    expect(entity.items, isEmpty);
  });

  test('survives a row with no items key', () {
    final entity = InspectionDto.fromJson(json()).toEntity();
    expect(entity.items, isEmpty);
  });

  test('orders items by position', () {
    final entity = InspectionDto.fromJson(json(items: [
      {'id': 'c', 'company_id': 'company-1', 'inspection_id': 'insp-1', 'position': 3, 'prompt': 'third'},
      {'id': 'a', 'company_id': 'company-1', 'inspection_id': 'insp-1', 'position': 1, 'prompt': 'first'},
      {'id': 'b', 'company_id': 'company-1', 'inspection_id': 'insp-1', 'position': 2, 'prompt': 'second'},
    ],),).toEntity();

    expect(entity.items.map((i) => i.prompt), ['first', 'second', 'third']);
  });

  test('does not sort the caller\'s list in place', () {
    final original = InspectionDto.fromJson(json(items: [
      {'id': 'c', 'company_id': 'company-1', 'inspection_id': 'insp-1', 'position': 3, 'prompt': 'third'},
      {'id': 'a', 'company_id': 'company-1', 'inspection_id': 'insp-1', 'position': 1, 'prompt': 'first'},
    ],),);

    original.toEntity();
    // The DTO's own list must be untouched — callers reuse it.
    expect(original.items!.map((i) => i.position), [3, 1]);
  });
}
