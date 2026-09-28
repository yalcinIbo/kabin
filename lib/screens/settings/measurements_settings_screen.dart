import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import '../../providers/user/user_providers.dart';

class MeasurementsSettingsScreen extends ConsumerStatefulWidget {
  const MeasurementsSettingsScreen({super.key});

  @override
  ConsumerState<MeasurementsSettingsScreen> createState() => _MeasurementsSettingsScreenState();
}

class _MeasurementsSettingsScreenState extends ConsumerState<MeasurementsSettingsScreen> {
  late final _name = TextEditingController(text: ref.read(measurementsNotifierProvider).displayName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(measurementsNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) AppFeedback.showError(context, next.error!);
      if (next.saved && !(prev?.saved ?? false)) AppFeedback.showSuccess(context, 'Kaydedildi.');
    });
    final state = ref.watch(measurementsNotifierProvider);
    final notifier = ref.read(measurementsNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Ölçülerim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppTextField(
            controller: _name,
            label: 'Adın',
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            onChanged: notifier.setDisplayName,
          ),
          const SizedBox(height: 16),
          MeasurementsForm(value: state.measurements, onChanged: notifier.setMeasurements, enabled: !state.isSaving),
          const SizedBox(height: 24),
          AppButton(label: 'Kaydet', isLoading: state.isSaving, onPressed: notifier.save),
        ],
      ),
    );
  }
}
