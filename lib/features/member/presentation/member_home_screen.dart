import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_sync.dart';
import '../../../core/utils/formatters.dart';
import '../../home/home_tab.dart';
import '../../protocols/presentation/price_list_screen.dart';
import '../../home/role_home_scaffold.dart';
import '../../home/role_shell.dart';
import '../../packages/data/package_repository.dart';
import '../../profile/profile_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import 'member_dashboard.dart';
import '../../measurements/presentation/my_measurements_screen.dart';
import '../../packages/presentation/member/my_packages_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/my_referrals_screen.dart';
import '../../schedule/presentation/member/class_calendar_screen.dart';
import '../../schedule/presentation/member/my_reservations_screen.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/presentation/member/my_wallet_screen.dart';
import '../../workouts/presentation/my_programs_screen.dart';

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return NotificationSync(
      child: RoleShell(
        tabs: [
          ShellTab(
            label: 'Ana sayfa',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            page: _MemberHomeTab(profile: profile),
          ),
          const ShellTab(
            label: 'Takvim',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            page: ClassCalendarScreen(),
          ),
          const ShellTab(
            label: 'Rezervasyon',
            icon: Icons.event_available_outlined,
            selectedIcon: Icons.event_available_rounded,
            page: MyReservationsScreen(),
          ),
          const ShellTab(
            label: 'Profil',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            page: ProfileScreen(),
          ),
        ],
      ),
    );
  }
}

class _MemberHomeTab extends ConsumerWidget {
  const _MemberHomeTab({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goTab(int i) => ref.read(homeTabProvider.notifier).set(i);
    final balance = ref.watch(walletBalanceProvider(profile.id));
    return RoleHomeScaffold(
      profile: profile,
      dashboard: const MemberDashboard(),
      onRefresh: () {
        ref.invalidate(myReservationsProvider);
        ref.invalidate(myPackagesProvider);
        ref.invalidate(walletBalanceProvider(profile.id));
      },
      modules: [
        ComingModule(
          'Paketlerim',
          Icons.confirmation_number_outlined,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyPackagesScreen())),
        ),
        ComingModule(
          'Cüzdanım',
          Icons.account_balance_wallet_outlined,
          subtitle: balance.when(
            data: (b) => 'Bakiye: ${formatTl(b)}',
            loading: () => 'Bakiye yükleniyor…',
            error: (_, _) => null,
          ),
          onTap: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyWalletScreen()));
            // Cüzdan ekranından dönünce güncel bakiye
            ref.invalidate(walletBalanceProvider(profile.id));
          },
        ),
        ComingModule(
          'Paketler ve fiyatlar',
          Icons.sell_outlined,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PriceListScreen())),
        ),
        ComingModule(
          'Referanslarım',
          Icons.group_add_outlined,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyReferralsScreen())),
        ),
        ComingModule(
          'Ders Takvimi',
          Icons.calendar_month_outlined,
          onTap: () => goTab(HomeTabs.second),
        ),
        ComingModule(
          'Rezervasyonlarım',
          Icons.event_available_outlined,
          onTap: () => goTab(HomeTabs.third),
        ),
        ComingModule(
          'Antrenman programım',
          Icons.fitness_center,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyProgramsScreen(memberId: profile.id),
            ),
          ),
        ),
        ComingModule(
          'Ölçümlerim ve ilerleme',
          Icons.monitor_weight_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyMeasurementsScreen(memberId: profile.id),
            ),
          ),
        ),
      ],
    );
  }
}
