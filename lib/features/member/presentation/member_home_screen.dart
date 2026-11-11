import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../packages/presentation/member/my_packages_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/my_referrals_screen.dart';
import '../../schedule/presentation/member/class_calendar_screen.dart';
import '../../schedule/presentation/member/my_reservations_screen.dart';
import '../../wallet/presentation/member/my_wallet_screen.dart';

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
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
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyWalletScreen())),
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
        const ComingModule('Antrenman programım', Icons.fitness_center),
        const ComingModule(
          'Ölçümlerim ve ilerleme',
          Icons.monitor_weight_outlined,
        ),
      ],
    );
  }
}
