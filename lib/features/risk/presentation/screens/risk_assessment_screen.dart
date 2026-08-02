// path: lib/features/risk/presentation/screens/risk_assessment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/widgets/hazard_ui.dart' show hazardRiskColor;
import 'package:ohs_shield_tracker/features/risk/domain/repositories/risk_assessment_repository.dart';
import 'package:ohs_shield_tracker/features/risk/domain/risk_calculator.dart';
import 'package:ohs_shield_tracker/features/risk/presentation/providers/risk_providers.dart';
import 'package:ohs_shield_tracker/features/risk/presentation/widgets/risk_matrix.dart';

/// Live risk calculator + matrix + residual risk (Master Prompt RISK ASSESSMENT).
class RiskAssessmentScreen extends ConsumerStatefulWidget {
  const RiskAssessmentScreen({required this.hazardId, super.key});
  final String hazardId;
  @override
  ConsumerState<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends ConsumerState<RiskAssessmentScreen> {
  final _current = TextEditingController();
  final _required = TextEditingController();
  DateTime? _reviewDate;
  bool _showResidual = false;

  @override
  void dispose() {
    _current.dispose();
    _required.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calc = ref.read(riskCalculatorControllerProvider);
    final params = SaveRiskParams(
      hazardId: widget.hazardId,
      likelihood: calc.likelihood,
      severity: calc.severity,
      currentControls: _current.text.trim().isEmpty ? null : _current.text.trim(),
      requiredControls: _required.text.trim().isEmpty ? null : _required.text.trim(),
      residualLikelihood: _showResidual ? calc.residualLikelihood : null,
      residualSeverity: _showResidual ? calc.residualSeverity : null,
      reviewDate: _reviewDate,
    );
    final ok = await ref.read(saveRiskControllerProvider.notifier).submit(params);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Risk assessment saved')));
      context.pop();
    } else {
      final f = ref.read(saveRiskControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Save failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = ref.watch(riskCalculatorControllerProvider);
    final ctrl = ref.read(riskCalculatorControllerProvider.notifier);
    final busy = ref.watch(saveRiskControllerProvider).isLoading;
    final score = RiskCalculator.score(calc.likelihood, calc.severity);
    final band = RiskCalculator.band(score);
    final color = hazardRiskColor(band);

    return Scaffold(
      appBar: AppBar(title: const Text('Risk assessment')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _factorRow('Likelihood', calc.likelihood, ctrl.setLikelihood),
          const SizedBox(height: 12),
          _factorRow('Severity', calc.severity, ctrl.setSeverity),
          const SizedBox(height: 16),
          // Live score chip.
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('$score',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: color, fontFeatures: const [FontFeature.tabularFigures()]),),
                Text(band.label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
              ],),
            ),
          ),
          const SizedBox(height: 16),
          RiskMatrix(
            likelihood: calc.likelihood,
            severity: calc.severity,
            onSelect: (l, s) {
              ctrl.setLikelihood(l);
              ctrl.setSeverity(s);
            },
          ),
          const SizedBox(height: 16),
          TextField(controller: _current, maxLines: 3, decoration: const InputDecoration(labelText: 'Current controls')),
          const SizedBox(height: 12),
          TextField(controller: _required, maxLines: 3, decoration: const InputDecoration(labelText: 'Required controls')),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Review date'),
            subtitle: Text(_reviewDate == null ? 'Not set' : DateFormat.yMMMd().format(_reviewDate!)),
            trailing: const Icon(Icons.event_outlined),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
              if (d != null) setState(() => _reviewDate = d);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Record residual risk (after controls)'),
            value: _showResidual,
            onChanged: (v) => setState(() => _showResidual = v),
          ),
          if (_showResidual) ...[
            _factorRow('Residual likelihood', calc.residualLikelihood ?? 1, ctrl.setResidualLikelihood),
            const SizedBox(height: 12),
            _factorRow('Residual severity', calc.residualSeverity ?? 1, ctrl.setResidualSeverity),
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final rb = RiskCalculator.residualBand(calc.residualLikelihood ?? 1, calc.residualSeverity ?? 1);
              return Text('Residual: ${(calc.residualLikelihood ?? 1) * (calc.residualSeverity ?? 1)} · ${rb?.label ?? '-'}',
                  style: TextStyle(color: hazardRiskColor(rb), fontWeight: FontWeight.w600),);
            },),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy ? null : _save,
            child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save assessment'),
          ),
        ],),
      ),
    );
  }

  Widget _factorRow(String label, int value, void Function(int) onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.secondaryText)),
      const SizedBox(height: 6),
      Row(children: [
        for (var v = 1; v <= 5; v++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: SizedBox(width: double.infinity, child: Center(child: Text('$v'))),
                selected: value == v,
                onSelected: (_) => onSelect(v),
              ),
            ),
          ),
      ],),
    ],);
  }
}
