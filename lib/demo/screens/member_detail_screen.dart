import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'member_form.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final m = store.memberById(memberId);
    if (m == null) {
      // Üye silindiyse boş ekran göster (sayfa zaten kapanıyor).
      return Scaffold(appBar: AppBar());
    }
    final trainer = store.trainerById(m.trainerId);
    final program = store.programById(m.programId);
    final upcoming = store.upcomingClassesFor(m.id);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit),
            onPressed: () => showMemberForm(context, existing: m),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Üye silinsin mi?',
                message:
                    '${m.name} ve tüm ders rezervasyonları silinecek. Bu işlem geri alınamaz.',
              );
              if (!ok || !context.mounted) return;
              final name = m.name;
              final store = StoreScope.read(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              store.deleteMember(m.id);
              messenger.showSnackBar(SnackBar(content: Text('$name silindi.')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        MemberAvatar(member: m, radius: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: text.titleLarge),
                              const SizedBox(height: 4),
                              Text(m.phone.isEmpty ? 'Telefon yok' : m.phone),
                            ],
                          ),
                        ),
                        MembershipStatusChip(member: m),
                      ],
                    ),
                  ),
                ),
                const SectionHeader('Üyelik'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.card_membership),
                        title: Text(m.membership.label),
                        subtitle: Text(
                          'Bitiş: ${tarih(m.membershipEnd)} '
                          '(${kalanGunMetni(m.daysLeft())})',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            StoreScope.read(context).renewMembership(m.id);
                            showMessage(
                              context,
                              'Üyelik ${m.membership.days} gün uzatıldı.',
                            );
                          },
                          child: const Text('Yenile'),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.sports),
                        title: const Text('Antrenör'),
                        subtitle: Text(
                          trainer == null
                              ? 'Atanmadı'
                              : '${trainer.name} • ${trainer.specialty}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Antrenman Programı'),
                Card(
                  child: program == null
                      ? const EmptyState(
                          icon: Icons.fitness_center,
                          message: 'Program atanmadı. Düzenle düğmesiyle program atayabilirsiniz.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(
                                program.name,
                                style: text.titleMedium,
                              ),
                              subtitle: Text(program.goal),
                            ),
                            for (final (i, e) in program.exercises.indexed)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 12,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                title: Text(e.name),
                                trailing: Text('${e.sets} × ${e.reps}'),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
                const SectionHeader('Yaklaşan Dersleri'),
                Card(
                  child: upcoming.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_available,
                          message: 'Rezervasyonu olan yaklaşan ders yok.',
                        )
                      : Column(
                          children: [
                            for (final c in upcoming)
                              ListTile(
                                leading: const Icon(Icons.event),
                                title: Text(c.title),
                                subtitle: Text(
                                  '${tarihGun(c.start)} • ${saatAraligi(c.start, c.end)}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Rezervasyonu iptal et',
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      StoreScope.read(context)
                                          .toggleBooking(c.id, m.id),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
