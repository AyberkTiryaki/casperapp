import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import '../shared/package_widgets.dart';

class PackageDetailScreen extends ConsumerWidget {
  const PackageDetailScreen({super.key, required this.package});

  final MemberPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final freezes = ref.watch(freezesProvider(package.id));
    return Scaffold(
      appBar: AppBar(title: Text(package.definitionName ?? 'Paket')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(freezesProvider(package.id));
          ref.invalidate(ledgerProvider(package.id));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PackageCard(package: package),
            const SizedBox(height: 20),
            Text('Dondurmalar', style: t.textTheme.titleLarge),
            const SizedBox(height: 8),
            freezes.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('Dondurma bilgisi yüklenemedi.'),
              data: (items) => items.isEmpty
                  ? const Text('Dondurma kaydı yok.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final f in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${freezeRangeText(f)}${f.note == null ? '' : ' - ${f.note}'}',
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Text('Hak hareketleri', style: t.textTheme.titleLarge),
            const SizedBox(height: 8),
            LedgerList(packageId: package.id),
          ],
        ),
      ),
    );
  }
}
