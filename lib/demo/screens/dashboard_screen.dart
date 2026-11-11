import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'member_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Menüde başka bir sekmeye geçmek için (1: Üyeler, 2: Ders Programı...).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final todayClasses = store.classesOn(now);
    final expiring = store.expiringMembers();
    final todayBookings = todayClasses.fold<int>(
      0,
      (sum, c) => sum + c.attendeeIds.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(tarihGun(now))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      icon: Icons.people,
                      label: 'Aktif üye',
                      value: '${store.activeMemberCount}',
                      onTap: () => onNavigate(1),
                    ),
                    _StatCard(
                      icon: Icons.event,
                      label: 'Bugünkü ders',
                      value: '${todayClasses.length}',
                      onTap: () => onNavigate(2),
                    ),
                    _StatCard(
                      icon: Icons.how_to_reg,
                      label: 'Bugünkü rezervasyon',
                      value: '$todayBookings',
                      onTap: () => onNavigate(2),
                    ),
                    _StatCard(
                      icon: Icons.warning_amber,
                      label: 'Yenilenecek üyelik',
                      value: '${expiring.length}',
                      highlight: expiring.isNotEmpty,
                      onTap: () => onNavigate(1),
                    ),
                  ],
                ),
                const SectionHeader('Bugünkü Dersler'),
                if (todayClasses.isEmpty)
                  const Card(
                    child: EmptyState(
                      icon: Icons.event_busy,
                      message: 'Bugün planlanmış ders yok.',
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final c in todayClasses)
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(c.title),
                            subtitle: Text(
                              '${saatAraligi(c.start, c.end)} • '
                              '${store.trainerById(c.trainerId)?.name ?? '-'}',
                            ),
                            trailing: Text(
                              '${c.attendeeIds.length}/${c.capacity}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            onTap: () => onNavigate(2),
                          ),
                      ],
                    ),
                  ),
                const SectionHeader('Üyeliği Biten / Bitmek Üzere'),
                if (expiring.isEmpty)
                  const Card(
                    child: EmptyState(
                      icon: Icons.verified,
                      message: 'Önümüzdeki 7 gün içinde biten üyelik yok.',
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final m in expiring)
                          ListTile(
                            leading: MemberAvatar(member: m),
                            title: Text(m.name),
                            subtitle: Text(
                              '${m.membership.label} • bitiş: ${tarih(m.membershipEnd)}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                MembershipStatusChip(member: m),
                                TextButton(
                                  onPressed: () {
                                    StoreScope.read(context)
                                        .renewMembership(m.id);
                                    showMessage(
                                      context,
                                      '${m.name} üyeliği yenilendi.',
                                    );
                                  },
                                  child: const Text('Yenile'),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MemberDetailScreen(memberId: m.id),
                              ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 200,
      child: Card(
        color: highlight ? scheme.tertiaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(height: 12),
                Text(value, style: text.headlineMedium),
                Text(label, style: text.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
