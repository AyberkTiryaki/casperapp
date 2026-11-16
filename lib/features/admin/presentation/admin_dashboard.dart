import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/brand.dart';
import '../../home/dashboard_widgets.dart';
import '../../home/home_tab.dart';
import '../../profile/deletion_request.dart';
import '../../referrals/data/referral_repository.dart';
import '../../referrals/presentation/admin_referrals_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import 'deletion_requests_screen.dart';

/// Yönetici ana sayfası: bugünkü ders, bekleyen referans ve silme talebi sayıları.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = (
      day: dayStart(DateTime.now()),
      categoryId: null,
      trainerId: null,
      includeCancelled: false,
    );
    final classes = ref.watch(classesProvider(today));
    final referrals = ref.watch(adminReferralsProvider('pending'));
    final deletions = ref.watch(deletionRequestsProvider);

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Bugün'),
        const SizedBox(height: 12),
        // Kaydırılabilir sayfada stretch sonsuz yükseklik ister; IntrinsicHeight
        // kutuları en uzununa eşitler.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.event_note_outlined,
                  label: 'Bugünkü ders',
                  value: classes.whenData(
                    (l) => l.where((c) => !c.isCancelled).length,
                  ),
                  onTap: () =>
                      ref.read(homeTabProvider.notifier).set(HomeTabs.second),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.group_add_outlined,
                  label: 'Bekleyen referans',
                  value: referrals.whenData((l) => l.length),
                  onTap: () => open(const AdminReferralsScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.person_remove_outlined,
                  label: 'Silme talebi',
                  value: deletions.whenData(
                    (l) => l
                        .where(
                          (i) => i.request.status == DeletionStatus.pending,
                        )
                        .length,
                  ),
                  onTap: () => open(const DeletionRequestsScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientIconBadge(icon, size: 36),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: value.when(
              loading: () => const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Tooltip(
                message: friendlyError(e),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
              data: (n) => Text('$n', style: dashNumberStyle()),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: context.palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
