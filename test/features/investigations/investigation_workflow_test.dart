// path: test/features/investigations/investigation_workflow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/investigation_workflow.dart';

void main() {
  Investigation inv({
    required InvestigationStatus status,
    String? rootCause,
    String? recommendations,
  }) =>
      Investigation(
        id: 'i', companyId: 'c', hazardId: 'h', analysis: InvestigationAnalysis.empty(),
        investigatorId: 'u', status: status, openedAt: DateTime(2026, 8, 1),
        rootCause: rootCause, recommendations: recommendations,
      );

  test('forward chain', () {
    expect(InvestigationWorkflow.next(InvestigationStatus.open), InvestigationStatus.inProgress);
    expect(InvestigationWorkflow.next(InvestigationStatus.inProgress), InvestigationStatus.pendingReview);
    expect(InvestigationWorkflow.next(InvestigationStatus.pendingReview), InvestigationStatus.completed);
    expect(InvestigationWorkflow.next(InvestigationStatus.completed), isNull);
  });

  test('Supervisor+ required', () {
    final c = InvestigationWorkflow.canTransition(
        investigation: inv(status: InvestigationStatus.open), to: InvestigationStatus.inProgress, roleRank: 1,);
    expect(c.allowed, isFalse);
  });

  group('complete guard', () {
    test('blocked without root cause', () {
      final c = InvestigationWorkflow.canTransition(
        investigation: inv(status: InvestigationStatus.pendingReview, recommendations: 'do X'),
        to: InvestigationStatus.completed, roleRank: 3,
      );
      expect(c.allowed, isFalse);
      expect(c.reason, contains('root cause'));
    });
    test('blocked without recommendations', () {
      final c = InvestigationWorkflow.canTransition(
        investigation: inv(status: InvestigationStatus.pendingReview, rootCause: 'guard failed'),
        to: InvestigationStatus.completed, roleRank: 3,
      );
      expect(c.allowed, isFalse);
      expect(c.reason, contains('Recommendations'));
    });
    test('allowed with both', () {
      final c = InvestigationWorkflow.canTransition(
        investigation: inv(status: InvestigationStatus.pendingReview, rootCause: 'guard failed', recommendations: 'add guard'),
        to: InvestigationStatus.completed, roleRank: 2,
      );
      expect(c.allowed, isTrue);
    });
  });
}
