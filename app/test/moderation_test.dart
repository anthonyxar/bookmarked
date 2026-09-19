import 'dart:io';

import 'package:bookmarked/providers/moderation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// The client and firestore.rules have to agree on report ids, field names and
// the allowed enum values, or every report is silently refused. These tests pin
// the client's side to the rules file itself.
void main() {
  final rules = File('../firestore.rules').readAsStringSync();

  test('report ids follow the reporter__type__target format the rules require', () {
    expect(ModerationService.reportId('bob', ReportType.note, 'n1'), 'bob__note__n1');
    expect(ModerationService.reportId('bob', ReportType.club, 'club9'), 'bob__club__club9');
  });

  test('every report type and reason is one the rules allow', () {
    for (final type in ReportType.values) {
      expect(rules, contains("'${type.name}'"), reason: 'type ${type.name} missing from the reports rules');
    }
    for (final reason in ReportReason.values) {
      expect(rules, contains("'${reason.name}'"), reason: 'reason ${reason.name} missing from the reports rules');
    }
  });

  test('a report carries exactly the fields the rules require, and no others', () {
    final data = ModerationService.reportData(
      reporterId: 'bob',
      type: ReportType.note,
      clubId: 'club1',
      targetId: 'n1',
      targetUserId: 'alice',
      bookId: 'book1',
      reason: ReportReason.spam,
    );
    final required = [
      'reporterId', 'type', 'targetId', 'clubId', 'targetUserId', 'bookId', 'reason', 'details', 'snapshot', 'status', 'createdAt',
    ];
    expect(data.keys.toSet(), required.toSet());
    for (final field in required) {
      expect(rules, contains("'$field'"), reason: 'field $field missing from the reports rules');
    }
    expect(data['status'], 'open');
  });

  test('details and the content snapshot are trimmed and clipped to the rules\' limits', () {
    final data = ModerationService.reportData(
      reporterId: 'bob',
      type: ReportType.note,
      clubId: 'club1',
      targetId: 'n1',
      reason: ReportReason.abuse,
      details: '  ${'d' * 600}  ',
      snapshot: 's' * 2000,
    );
    expect((data['details'] as String).length, ModerationService.maxDetails);
    expect((data['snapshot'] as String).length, ModerationService.maxSnapshot);
    expect(rules, contains('size() <= ${ModerationService.maxDetails}'));
    expect(rules, contains('size() <= ${ModerationService.maxSnapshot}'));
  });

  test('reasons have readable labels', () {
    for (final reason in ReportReason.values) {
      expect(reason.label, isNotEmpty);
    }
  });
}
