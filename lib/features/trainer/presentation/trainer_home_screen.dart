import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../profile/profile.dart';
import '../../schedule/presentation/trainer/trainer_calendar_screen.dart';
import '../../wallet/presentation/trainer/trainer_sales_screens.dart';

class TrainerHomeScreen extends StatelessWidget {
  const TrainerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      profile: profile,
      modules: [
        ComingModule(
          'Takvimim',
          Icons.calendar_month_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrainerCalendarScreen(trainerId: profile.id),
            ),
          ),
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
        const ComingModule('Üyelerim', Icons.groups_outlined),
        const ComingModule(
          'Antrenman programı hazırlama',
          Icons.fitness_center,
        ),
        const ComingModule('Üye ölçümleri', Icons.monitor_weight_outlined),
      ],
    );
  }
}
