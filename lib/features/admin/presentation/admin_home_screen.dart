import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/home_tab.dart';
import '../../home/role_home_scaffold.dart';
import '../../home/role_shell.dart';
import '../../profile/profile_screen.dart';
import '../../referrals/data/referral_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import 'admin_dashboard.dart';
import '../../packages/presentation/admin/categories_screen.dart';
import '../../packages/presentation/admin/definitions_screen.dart';
import '../../packages/presentation/admin/members_screen.dart';
import '../../profile/profile.dart';
import '../../referrals/presentation/admin_referrals_screen.dart';
import '../../reports/presentation/admin_reports_screen.dart';
import '../../schedule/presentation/admin/admin_schedule_screen.dart';
import '../../wallet/presentation/admin/products_screen.dart';
import 'audit_screen.dart';
import 'deletion_requests_screen.dart';
import 'users_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        ShellTab(
          label: 'Ana sayfa',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          page: _AdminHomeTab(profile: profile),
        ),
        const ShellTab(
          label: 'Ders programı',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note_rounded,
          page: AdminScheduleScreen(),
        ),
        const ShellTab(
          label: 'Üyeler',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          page: MembersScreen(),
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
}

class _AdminHomeTab extends ConsumerWidget {
  const _AdminHomeTab({required this.profile});

  final Profile profile;

  void _go(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goTab(int i) => ref.read(homeTabProvider.notifier).set(i);
    return RoleHomeScaffold(
      profile: profile,
      dashboard: const AdminDashboard(),
      onRefresh: () {
        ref.invalidate(classesProvider);
        ref.invalidate(classDaysProvider);
        ref.invalidate(adminReferralsProvider);
        ref.invalidate(deletionRequestsProvider);
      },
      modules: [
        ComingModule(
          'Üyeler ve paketleri',
          Icons.groups_outlined,
          onTap: () => goTab(HomeTabs.third),
        ),
        ComingModule(
          'Paket tanımları',
          Icons.inventory_2_outlined,
          onTap: () => _go(context, const DefinitionsScreen()),
        ),
        ComingModule(
          'Kategoriler',
          Icons.category_outlined,
          onTap: () => _go(context, const CategoriesScreen()),
        ),
        ComingModule(
          'Referanslar',
          Icons.group_add_outlined,
          onTap: () => _go(context, const AdminReferralsScreen()),
        ),
        ComingModule(
          'Kullanıcı ve rol yönetimi',
          Icons.manage_accounts_outlined,
          onTap: () => _go(context, const UsersScreen()),
        ),
        ComingModule(
          'Ürünler ve fiyatlar',
          Icons.sell_outlined,
          onTap: () => _go(context, const ProductsScreen()),
        ),
        ComingModule(
          'Ders ve Rezervasyon Yönetimi',
          Icons.event_note_outlined,
          onTap: () => goTab(HomeTabs.second),
        ),
        ComingModule(
          'İşlem geçmişi',
          Icons.history_outlined,
          onTap: () => _go(context, const AuditScreen()),
        ),
        ComingModule(
          'Hesap silme talepleri',
          Icons.person_remove_outlined,
          onTap: () => _go(context, const DeletionRequestsScreen()),
        ),
        ComingModule(
          'Raporlar',
          Icons.bar_chart_outlined,
          onTap: () => _go(context, const AdminReportsScreen()),
        ),
      ],
    );
  }
}
