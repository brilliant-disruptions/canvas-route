// Visit logs as CRM import files (HubSpot, Salesforce). Pure; no Flutter.
import 'csv_export.dart';

enum CrmFormat { hubspot, salesforce }

class CrmLead {
  const CrmLead({
    required this.company,
    required this.address,
    this.contactName,
    this.phone,
    this.email,
    this.outcome,
    this.notes,
    this.followUp,
    this.visitedAt,
  });
  final String company;
  final String address;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? outcome;
  final String? notes;
  final DateTime? followUp;
  final DateTime? visitedAt;
}

/// "213 N Bishop Ave, Dallas, TX 75208[, USA]" → street, city, state, zip.
({String street, String city, String state, String zip}) splitUsAddress(String address) {
  final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isNotEmpty && RegExp(r'^(USA|United States)$', caseSensitive: false).hasMatch(parts.last)) {
    parts.removeLast();
  }
  if (parts.length < 3) return (street: address.trim(), city: '', state: '', zip: '');
  final m = RegExp(r'^([A-Za-z]{2})\s*(\d{5}(?:-\d{4})?)?$').firstMatch(parts.last);
  if (m == null) return (street: address.trim(), city: '', state: '', zip: '');
  return (
    street: parts.sublist(0, parts.length - 2).join(', '),
    city: parts[parts.length - 2],
    state: m.group(1)!.toUpperCase(),
    zip: m.group(2) ?? '',
  );
}

/// "Dr. Priya Shah" → (Priya, Shah); "Marco (owner)" → (Marco, ''). Titles and
/// parentheticals are dropped.
({String first, String last}) splitName(String? name) {
  final cleaned = (name ?? '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'^(dr|mr|mrs|ms|mx)\.?\s+', caseSensitive: false), '')
      .trim();
  if (cleaned.isEmpty) return (first: '', last: '');
  final words = cleaned.split(RegExp(r'\s+'));
  return words.length == 1 ? (first: words.first, last: '') : (first: words.first, last: words.sublist(1).join(' '));
}

/// The CRM's lead status for our default outcomes; custom outcomes stay blank
/// (they still appear in the notes column).
String crmStatus(CrmFormat f, String? outcome) => switch ((f, outcome)) {
  (CrmFormat.hubspot, 'Contacted') => 'CONNECTED',
  (CrmFormat.hubspot, 'No Answer') => 'ATTEMPTED_TO_CONTACT',
  (CrmFormat.hubspot, 'Not Interested') => 'UNQUALIFIED',
  (CrmFormat.hubspot, 'Interested') => 'IN_PROGRESS',
  (CrmFormat.salesforce, 'Contacted' || 'Interested') => 'Working - Contacted',
  (CrmFormat.salesforce, 'No Answer') => 'Open - Not Contacted',
  (CrmFormat.salesforce, 'Not Interested') => 'Closed - Not Converted',
  _ => '',
};

String _date(DateTime? d) =>
    d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A CSV the CRM's import wizard maps without edits: HubSpot's contact+company
/// columns, or Salesforce's Lead columns (Last Name and Company are required
/// there, so a lead with no contact gets the company as its last name).
String buildCrmCsv(CrmFormat f, List<CrmLead> leads) {
  final rows = <CsvRow>[];
  for (final l in leads) {
    final a = splitUsAddress(l.address);
    final n = splitName(l.contactName);
    final description = [
      if (l.outcome != null) 'Outcome: ${l.outcome}',
      if (l.visitedAt != null) 'Visited ${_date(l.visitedAt)}',
      if (l.followUp != null) 'Follow up ${_date(l.followUp)}',
      if (l.notes != null && l.notes!.trim().isNotEmpty) l.notes!.trim(),
    ].join(' · ');
    rows.add(CsvRow({
      'company': l.company,
      'first': n.first,
      'last': f == CrmFormat.salesforce && n.last.isEmpty && n.first.isEmpty ? l.company : n.last,
      'email': l.email ?? '',
      'phone': l.phone ?? '',
      'street': a.street,
      'city': a.city,
      'state': a.state,
      'zip': a.zip,
      'status': crmStatus(f, l.outcome),
      'notes': description,
    }));
  }
  const fields = ['company', 'first', 'last', 'email', 'phone', 'street', 'city', 'state', 'zip', 'status', 'notes'];
  final headers = switch (f) {
    CrmFormat.hubspot => const {
      'company': 'Company name',
      'first': 'First Name',
      'last': 'Last Name',
      'email': 'Email',
      'phone': 'Phone Number',
      'street': 'Street Address',
      'city': 'City',
      'state': 'State/Region',
      'zip': 'Postal Code',
      'status': 'Lead Status',
      'notes': 'Notes',
    },
    CrmFormat.salesforce => const {
      'company': 'Company',
      'first': 'First Name',
      'last': 'Last Name',
      'email': 'Email',
      'phone': 'Phone',
      'street': 'Street',
      'city': 'City',
      'state': 'State/Province',
      'zip': 'Zip/Postal Code',
      'status': 'Lead Status',
      'notes': 'Description',
    },
  };
  return buildCsv(meta: const [], fields: fields, headers: headers, rows: rows);
}
