import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../measurements/presentation/member_measurements_screen.dart';
import '../../../protocols/data/protocol_repository.dart';
import '../../../protocols/presentation/admin_protocols_screen.dart';
import '../../../referrals/data/referral_repository.dart';
import '../../../wallet/presentation/admin/member_wallet_screen.dart';
import '../../../workouts/presentation/member_programs_screen.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import '../shared/package_widgets.dart';
import 'package_flows.dart';
import '../../../../core/widgets/home_button.dart';

class AdminMemberPackagesScreen extends ConsumerWidget {
  const AdminMemberPackagesScreen({super.key, required this.member});
  final MemberSummary member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberPackagesProvider(member.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          const HomeButton(),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminMemberWalletScreen(
                  memberId: member.id,
                  memberName: member.fullName,
                ),
              ),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Cüzdan'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Program ve ölçümler',
            onSelected: (v) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => v == 'program'
                    ? MemberProgramsScreen(
                        memberId: member.id,
                        memberName: member.fullName,
                      )
                    : MemberMeasurementsScreen(
                        memberId: member.id,
                        memberName: member.fullName,
                      ),
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'program',
                child: Text('Antrenman programları'),
              ),
              PopupMenuItem(value: 'olcum', child: Text('Ölçümler')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => runAssignFlow(context, ref, member),
        icon: const Icon(Icons.add),
        label: const Text('Paket ata'),
      ),
      body: AsyncValueView<List<MemberPackage>>(
        value: async,
        onRetry: () => ref.invalidate(memberPackagesProvider(member.id)),
        data: (items) {
          final now = DateTime.now();
          final sorted = [...items]
            ..sort((a, b) {
              final aa = a.isCurrentlyActive(now) ? 0 : 1;
              final bb = b.isCurrentlyActive(now) ? 0 : 1;
              if (aa != bb) return aa - bb;
              return b.activatedAt.compareTo(a.activatedAt);
            });
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(memberPackagesProvider(member.id)),
            child: sorted.isEmpty
                ? ListView(
                    children: [
                      _ProtocolHeader(member: member),
                      const SizedBox(height: 120),
                      const EmptyView(
                        title: 'Bu üyenin paketi yok',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: sorted.length + 2,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == 0) return _ReferralHeader(memberId: member.id);
                      if (i == 1) return _ProtocolHeader(member: member);
                      final p = sorted[i - 2];
                      return PackageCard(
                        package: p,
                        showPrice: true,
                        actions: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LedgerScreen(package: p),
                              ),
                            ),
                            child: const Text('Hak hareketleri'),
                          ),
                          if (p.isCurrentlyActive(now))
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () => runFreezeFlow(context, ref, p),
                              child: const Text('Dondur'),
                            ),
                          if (p.isCurrentlyActive(now))
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () =>
                                  runAdjustCreditsFlow(context, ref, p),
                              child: const Text('Hak düzelt'),
                            ),
                          if (p.status == 'active' && p.freezes.isNotEmpty)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () =>
                                  showFreezesSheet(context, ref, p),
                              child: const Text('Dondurmalar'),
                            ),
                        ],
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _ReferralHeader extends ConsumerWidget {
  const _ReferralHeader({required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(referralSummaryProvider(memberId)).value;
    if (s == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.group_add_outlined),
        title: Text('Referans kodu: ${s.referralCode ?? '-'}'),
        subtitle: Text(
          'Güncel indirim hakkı: %${s.discountPercent} (${s.activeCount} aktif referans)',
        ),
      ),
    );
  }
}

class _ProtocolHeader extends ConsumerWidget {
  const _ProtocolHeader({required this.member});
  final MemberSummary member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberProtocolProvider(member.id));
    final p = async.value;
    final now = DateTime.now();
    final String subtitle;
    if (async.isLoading && p == null) {
      subtitle = 'Yükleniyor…';
    } else if (async.hasError && p == null) {
      subtitle = 'Protokol bilgisi alınamadı.';
    } else if (p == null) {
      subtitle = 'Bağlı protokol yok';
    } else if (!p.isValidOn(now)) {
      subtitle = '${p.name}: ${protocolStatusText(p, now)}, indirim uygulanmaz';
    } else {
      subtitle =
          '${p.name}: %${p.discountPercent}, paket atamada otomatik uygulanır';
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.handshake_outlined),
        title: const Text('Kurum protokolü'),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: async.isLoading && p == null
              ? null
              : () => runSetMemberProtocolFlow(
                  context,
                  ref,
                  memberId: member.id,
                  memberName: member.fullName,
                  current: p,
                ),
          child: Text(p == null ? 'Bağla' : 'Değiştir'),
        ),
      ),
    );
  }
}
