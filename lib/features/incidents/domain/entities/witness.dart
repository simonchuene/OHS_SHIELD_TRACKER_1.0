// path: lib/features/incidents/domain/entities/witness.dart
/// POPIA-minimised witness record. Stored as a JSONB element on `incidents`
/// (D9) — capture only operationally necessary personal information. Visibility
/// is governed by the incident row's RLS.
class Witness {
  const Witness({required this.name, this.contact, this.statement});
  final String name;
  final String? contact;
  final String? statement;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (contact != null && contact!.isNotEmpty) 'contact': contact,
        if (statement != null && statement!.isNotEmpty) 'statement': statement,
      };

  factory Witness.fromJson(Map<String, dynamic> j) => Witness(
        name: (j['name'] ?? '').toString(),
        contact: j['contact']?.toString(),
        statement: j['statement']?.toString(),
      );
}
