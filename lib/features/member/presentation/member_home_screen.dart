import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../home/role_home_scaffold.dart';
import '../../measurements/presentation/my_measurements_screen.dart';
import '../../packages/presentation/member/my_packages_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/my_referrals_screen.dart';
import '../../schedule/presentation/member/class_calendar_screen.dart';
import '../../schedule/presentation/member/my_reservations_screen.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/presentation/member/my_wallet_screen.dart';
import '../../workouts/presentation/my_programs_screen.dart';

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider(profile.id));
    return RoleHomeScaffold(
      profile: profile,
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
          'Referanslarım',
          Icons.group_add_outlined,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyReferralsScreen())),
        ),
        ComingModule(
          'Ders Takvimi',
          Icons.calendar_month_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClassCalendarScreen()),
          ),
        ),
        ComingModule(
          'Rezervasyonlarım',
          Icons.event_available_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
          ),
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
