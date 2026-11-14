import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'measurement_widgets.dart';

/// Üye: kendi ölçümleri ve ilerlemesi.
class MyMeasurementsScreen extends ConsumerWidget {
  const MyMeasurementsScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Ölçümlerim ve ilerleme')),
    body: MeasurementsBody(
      memberId: memberId,
      isSelf: true,
      emptyTitle: 'Henüz ölçüm yok',
      emptyMessage: 'İlk ölçümünüzü ekleyerek ilerlemenizi takip edin.',
    ),
    floatingActionButton: AddMeasurementFab(memberId: memberId),
  );
}
