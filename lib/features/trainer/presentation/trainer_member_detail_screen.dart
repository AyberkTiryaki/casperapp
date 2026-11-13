import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../measurements/presentation/member_measurements_screen.dart';
import '../../workouts/presentation/member_programs_screen.dart';
import '../domain/trainer_models.dart';

/// Eğitmen: kendi üyesinin özeti; programlarına ve ölçümlerine geçiş.
/// Profil boy/kilo/doğum tarihi, cüzdan ve paket bilgisi burada gösterilmez (Y-05).
class TrainerMemberDetailScreen extends StatelessWidget {
  const TrainerMemberDetailScreen({super.key, required this.member});

  final TrainerMember member;

  String _when(DateTime? d) =>
      d == null ? '—' : '${formatDate(d)} ${formatTime(d)}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(member.fullName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dersler', style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Son ders: ${_when(member.lastClassAt)}'),
                    Text('Sonraki ders: ${_when(member.nextClassAt)}'),
                    Text('${member.classCount} ders (son 90 gün ve gelecek)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('Antrenman programları'),
                subtitle: const Text('Program hazırla, düzenle, pasife al'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberProgramsScreen(
                      memberId: member.memberId,
                      memberName: member.fullName,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.monitor_weight_outlined),
                title: const Text('Ölçümler'),
                subtitle: const Text('Ölçüm ekle, ilerlemeyi gör'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberMeasurementsScreen(
                      memberId: member.memberId,
                      memberName: member.fullName,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Yalnızca derslerinize kayıtlı üyelerin programlarını ve '
              'ölçümlerini görebilirsiniz.',
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
