import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'measurement_widgets.dart';
import '../../../core/widgets/home_button.dart';

/// Eğitmen/yönetici: bir üyenin ölçümleri.
class MemberMeasurementsScreen extends ConsumerWidget {
  const MemberMeasurementsScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });
  final String memberId;
  final String memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(memberName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Ölçümler', style: t.textTheme.bodySmall),
          ],
        ),
      ),
      body: MeasurementsBody(
        memberId: memberId,
        emptyTitle: 'Bu üyenin ölçümü yok',
        emptyMessage: 'Ölçüm ekleyerek üyenin ilerlemesini takip edin.',
      ),
      floatingActionButton: AddMeasurementFab(memberId: memberId),
    );
  }
}
