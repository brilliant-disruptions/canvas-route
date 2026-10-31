import 'package:canvas_route/core/logic/crm_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits US addresses, with or without zip and country', () {
    expect(splitUsAddress('213 N Bishop Ave, Dallas, TX 75208'),
        (street: '213 N Bishop Ave', city: 'Dallas', state: 'TX', zip: '75208'));
    expect(splitUsAddress('Suite 4, 100 Main St, Plano, TX 75024-1234, USA'),
        (street: 'Suite 4, 100 Main St', city: 'Plano', state: 'TX', zip: '75024-1234'));
    expect(splitUsAddress('2911 Turtle Creek Blvd, Dallas, TX').state, 'TX');
    expect(splitUsAddress('Somewhere odd'), (street: 'Somewhere odd', city: '', state: '', zip: ''));
  });

  test('splits names, dropping titles and parentheticals', () {
    expect(splitName('Dr. Priya Shah'), (first: 'Priya', last: 'Shah'));
    expect(splitName('Marco (owner)'), (first: 'Marco', last: ''));
    expect(splitName('Ana de la Cruz'), (first: 'Ana', last: 'de la Cruz'));
    expect(splitName(null), (first: '', last: ''));
  });

  test('maps default outcomes to each CRM status, custom ones to blank', () {
    expect(crmStatus(CrmFormat.hubspot, 'No Answer'), 'ATTEMPTED_TO_CONTACT');
    expect(crmStatus(CrmFormat.salesforce, 'Interested'), 'Working - Contacted');
    expect(crmStatus(CrmFormat.salesforce, 'Left brochure'), '');
  });

  test('Salesforce rows always have a last name', () {
    final csv = buildCrmCsv(CrmFormat.salesforce, const [
      CrmLead(company: 'Taco y Vino', address: '213 N Bishop Ave, Dallas, TX 75208', outcome: 'No Answer'),
    ]);
    final lines = csv.split('\n');
    expect(lines.first, startsWith('Company,First Name,Last Name'));
    expect(lines[1], startsWith('Taco y Vino,,Taco y Vino,'));
    expect(lines[1], contains('Open - Not Contacted'));
  });

  test('HubSpot rows carry notes with outcome and follow-up date', () {
    final csv = buildCrmCsv(CrmFormat.hubspot, [
      CrmLead(
        company: 'Uptown Smiles',
        address: '2911 Turtle Creek Blvd, Dallas, TX 75219',
        contactName: 'Dana Lee',
        outcome: 'Interested',
        notes: 'Wants pricing, "soon"',
        followUp: DateTime(2026, 11, 3),
      ),
    ]);
    expect(csv, contains('Uptown Smiles,Dana,Lee,'));
    expect(csv, contains('IN_PROGRESS'));
    expect(csv, contains('"Outcome: Interested · Follow up 2026-11-03 · Wants pricing, ""soon"""'));
  });

  test('Salesforce puts a one-word contact in Last Name, which it requires', () {
    final csv = buildCrmCsv(CrmFormat.salesforce, const [
      CrmLead(company: 'Taco y Vino', address: '213 N Bishop Ave, Dallas, TX 75208', contactName: 'Marco (owner)'),
    ]);
    expect(csv.split('\n')[1], startsWith('Taco y Vino,,Marco,'));
  });
}
