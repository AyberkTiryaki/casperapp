import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import '../shared/package_widgets.dart';
import 'package_detail_screen.dart';
import '../../../../core/widgets/home_button.dart';

class MyPackagesScreen extends ConsumerWidget {
  const MyPackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPackagesProvider);
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Paketlerim'),
      ),
      body: AsyncValueView<List<MemberPackage>>(
        value: async,
        onRetry: () => ref.invalidate(myPackagesProvider),
        data: (all) {
          final now = DateTime.now();
          final current = all.where((p) => p.isCurrentlyActive(now)).toList();
          final history = all.where((p) => !p.isCurrentlyActive(now)).toList();
          Widget tile(MemberPackage p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PackageCard(
              package: p,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PackageDetailScreen(package: p),
                ),
              ),
            ),
          );
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myPackagesProvider);
              await ref
                  .read(myPackagesProvider.future)
                  .catchError((_) => <MemberPackage>[]);
            },
            child: all.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyView(
                        title: 'Henüz paketiniz yok',
                        message: 'Paket tanımlandığında burada görünecek. Paket için stüdyo yönetimiyle iletişime geçin.',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (current.isNotEmpty) ...[
                        Text(
                          'Aktif paketler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...current.map(tile),
                      ],
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Geçmiş paketler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...history.map(tile),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}
