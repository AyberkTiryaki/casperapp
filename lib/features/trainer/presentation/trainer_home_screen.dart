import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/home_tab.dart';
import '../../home/role_home_scaffold.dart';
import '../../home/role_shell.dart';
import '../../profile/profile_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import 'trainer_dashboard.dart';
import '../../measurements/presentation/member_measurements_screen.dart';
import '../../profile/profile.dart';
import '../../schedule/presentation/trainer/trainer_calendar_screen.dart';
import '../../wallet/presentation/trainer/trainer_sales_screens.dart';
import '../../workouts/presentation/member_programs_screen.dart';
import 'my_members_screen.dart';
import 'trainer_member_detail_screen.dart';

class TrainerHomeScreen extends StatelessWidget {
  const TrainerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        ShellTab(
          label: 'Ana sayfa',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          page: _TrainerHomeTab(profile: profile),
        ),
        ShellTab(
          label: 'Takvim',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          page: TrainerCalendarScreen(trainerId: profile.id),
        ),
        ShellTab(
          label: 'Üyelerim',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          page: _membersScreen(),
        ),
        const ShellTab(
          label: 'Profil',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          page: ProfileScreen(),
        ),
      ],
    );
  }

  Widget _membersScreen() => MyMembersScreen(
    onMemberTap: (ctx, m) => Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => TrainerMemberDetailScreen(member: m)),
    ),
  );
}

class _TrainerHomeTab extends ConsumerWidget {
  const _TrainerHomeTab({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goTab(int i) => ref.read(homeTabProvider.notifier).set(i);
    return RoleHomeScaffold(
      profile: profile,
      dashboard: TrainerDashboard(trainerId: profile.id),
      onRefresh: () => ref.invalidate(classesProvider),
      modules: [
        ComingModule(
          'Takvimim',
          Icons.calendar_month_outlined,
          onTap: () => goTab(HomeTabs.second),
        ),
        ComingModule(
          'Ürün satışı',
          Icons.shopping_cart_outlined,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SellProductScreen())),
        ),
        ComingModule(
          'Satışlarım',
          Icons.receipt_long_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MySalesScreen(sellerId: profile.id),
            ),
          ),
        ),
        ComingModule(
          'Üyelerim',
          Icons.groups_outlined,
          onTap: () => goTab(HomeTabs.third),
        ),
        ComingModule(
          'Antrenman programı hazırlama',
          Icons.fitness_center,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyMembersScreen(
                title: 'Antrenman programı hazırlama',
                hint: 'Program hazırlamak için üye seçin',
                trailingIcon: Icons.fitness_center,
                onMemberTap: (ctx, m) => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => MemberProgramsScreen(
                      memberId: m.memberId,
                      memberName: m.fullName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ComingModule(
          'Üye ölçümleri',
          Icons.monitor_weight_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyMembersScreen(
                title: 'Üye ölçümleri',
                hint: 'Ölçüm girmek için üye seçin',
                trailingIcon: Icons.monitor_weight_outlined,
                onMemberTap: (ctx, m) => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => MemberMeasurementsScreen(
                      memberId: m.memberId,
                      memberName: m.fullName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
