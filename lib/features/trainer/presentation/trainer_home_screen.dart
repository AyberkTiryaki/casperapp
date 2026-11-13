import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
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
        ComingModule(
          'Üyelerim',
          Icons.groups_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyMembersScreen(
                onMemberTap: (ctx, m) => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => TrainerMemberDetailScreen(member: m),
                  ),
                ),
              ),
            ),
          ),
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
