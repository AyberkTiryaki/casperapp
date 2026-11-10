import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import '../shared/package_widgets.dart';
import 'package_flows.dart';

class AdminMemberPackagesScreen extends ConsumerWidget {
  const AdminMemberPackagesScreen({super.key, required this.member});
  final MemberSummary member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(memberPackagesProvider(member.id));
    return Scaffold(
      appBar: AppBar(title: Text(member.fullName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => runAssignFlow(context, ref, member),
        icon: const Icon(Icons.add),
        label: const Text('Paket ata'),
      ),
      body: AsyncValueView<List<MemberPackage>>(
        value: async,
        onRetry: () => ref.invalidate(memberPackagesProvider(member.id)),
        data: (items) {
          final now = DateTime.now();
          final sorted = [...items]..sort((a, b) {
              final aa = a.isCurrentlyActive(now) ? 0 : 1;
              final bb = b.isCurrentlyActive(now) ? 0 : 1;
              if (aa != bb) return aa - bb;
              return b.activatedAt.compareTo(a.activatedAt);
            });
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(memberPackagesProvider(member.id)),
            child: sorted.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    EmptyView(
                        title: 'Bu üyenin paketi yok',
                        icon: Icons.confirmation_number_outlined),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final p = sorted[i];
                      return PackageCard(
                        package: p,
                        showPrice: true,
                        actions: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40)),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => LedgerScreen(package: p))),
                            child: const Text('Hak hareketleri'),
                          ),
                          if (p.isCurrentlyActive(now))
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
                              onPressed: () => runFreezeFlow(context, ref, p),
                              child: const Text('Dondur'),
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
