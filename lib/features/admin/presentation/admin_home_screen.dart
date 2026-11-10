import 'package:flutter/material.dart';

import '../../home/role_home_scaffold.dart';
import '../../packages/presentation/admin/categories_screen.dart';
import '../../packages/presentation/admin/definitions_screen.dart';
import '../../packages/presentation/admin/members_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/admin_referrals_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.profile});

  final Profile profile;

  void _go(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(profile: profile, modules: [
      ComingModule('Üyeler ve paketleri', Icons.groups_outlined,
          onTap: () => _go(context, const MembersScreen())),
      ComingModule('Paket tanımları', Icons.inventory_2_outlined,
          onTap: () => _go(context, const DefinitionsScreen())),
      ComingModule('Kategoriler', Icons.category_outlined,
          onTap: () => _go(context, const CategoriesScreen())),
      ComingModule('Referanslar', Icons.group_add_outlined,
          onTap: () => _go(context, const AdminReferralsScreen())),
      const ComingModule(
          'Kullanıcı ve rol yönetimi', Icons.manage_accounts_outlined),
      const ComingModule(
          'Antrenör ve takvim yönetimi', Icons.event_note_outlined),
      const ComingModule('Raporlar', Icons.bar_chart_outlined),
    ]);
  }
}
