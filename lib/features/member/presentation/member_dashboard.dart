import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../home/dashboard_widgets.dart';
import '../../home/home_tab.dart';
import '../../packages/data/package_repository.dart';
import '../../packages/domain/package_models.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/schedule_models.dart';
import '../../home/studio_card.dart';

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// Üye ana sayfasındaki canlı bölümler: sıradaki ders ve paketler.
class MemberDashboard extends StatelessWidget {
  const MemberDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Sıradaki dersin'),
        SizedBox(height: 12),
        NextClassSection(),
        SizedBox(height: 24),
        SectionLabel('Paketlerim'),
        SizedBox(height: 12),
        PackagesSection(),
      ],
    );
  }
}

class NextClassSection extends ConsumerWidget {
  const NextClassSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReservationsProvider);
    return async.when(
      loading: () => const DashLoading(),
      error: (e, _) => DashError(
        error: e,
        onRetry: () => ref.invalidate(myReservationsProvider),
      ),
      data: (all) {
        final now = DateTime.now();
        final upcoming = all.where((r) => r.isUpcoming(now)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        if (upcoming.isEmpty) return const _NoClassCard();
        return _NextClassCard(reservation: upcoming.first);
      },
    );
  }
}

class _NoClassCard extends ConsumerWidget {
  const _NoClassCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashCard(
      child: Row(
        children: [
          const GradientIconBadge(Icons.event_available_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Henüz planlı dersin yok', style: dashTitleStyle()),
                const SizedBox(height: 4),
                const Text('Takvimden sana uygun bir ders seç.'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () =>
                      ref.read(homeTabProvider.notifier).set(HomeTabs.second),
                  child: const Text('Ders bul'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextClassCard extends ConsumerWidget {
  const _NextClassCard({required this.reservation});
  final MyReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reservation;
    final start = r.startsAt.toLocal();
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIconBadge(Icons.fitness_center_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weekdays[start.weekday - 1]}, ${formatDate(start)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(formatTime(start), style: dashNumberStyle()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.categoryName.isEmpty ? 'Ders' : r.categoryName,
            style: dashTitleStyle(),
          ),
          if (r.trainerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Eğitmen: ${r.trainerName}'),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ref.read(homeTabProvider.notifier).set(HomeTabs.third),
            child: const Text('Rezervasyonlarım'),
          ),
        ],
      ),
    );
  }
}

class PackagesSection extends ConsumerWidget {
  const PackagesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPackagesProvider);
    return async.when(
      loading: () => const DashLoading(),
      error: (e, _) => DashError(
        error: e,
        onRetry: () => ref.invalidate(myPackagesProvider),
      ),
      data: (all) {
        final now = DateTime.now();
        final current = all.where((p) => p.isCurrentlyActive(now)).toList();
        if (current.isEmpty) return const NoPackageCard();
        return Column(
          children: [
            for (final p in current)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PackageProgressCard(package: p, now: now),
              ),
          ],
        );
      },
    );
  }
}

/// Aktif paket: kalan hak çubuğu ve kalan gün; azalınca amber uyarı.
class PackageProgressCard extends StatelessWidget {
  const PackageProgressCard({super.key, required this.package, this.now});
  final MemberPackage package;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final p = package;
    final frozen = p.displayStatus(now) == PackageDisplayStatus.frozen;
    final days = p.daysLeft(now);
    final low = !frozen && (days <= 3 || p.remainingCredits <= 1);
    final tone = low ? AppColors.warning : AppColors.cyan;
    final name = p.categoryName ?? p.definitionName ?? 'Paket';
    final progress = p.totalCredits == 0
        ? 0.0
        : (p.remainingCredits / p.totalCredits).clamp(0.0, 1.0);
    return DashCard(
      borderColor: low ? AppColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                low
                    ? Icons.warning_amber_rounded
                    : Icons.confirmation_number_outlined,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashTitleStyle(),
                ),
              ),
              if (frozen)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text('Donduruldu'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'kalan '),
                TextSpan(
                  text: '${p.remainingCredits}',
                  style: dashNumberStyle(size: 22, color: tone),
                ),
                TextSpan(text: ' / ${p.totalCredits} ders'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: tone,
            backgroundColor: AppColors.nightRaised,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            frozen ? 'Dondurulmuş · $days gün kaldı' : '$days gün kaldı',
            style: TextStyle(
              color: low ? AppColors.warning : AppColors.nightMuted,
              fontWeight: low ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aktif paketi olmayan üye için iletişim kartı.
class NoPackageCard extends StatelessWidget {
  const NoPackageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashCard(
      borderColor: AppColors.electricBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradientIconBadge(Icons.confirmation_number_outlined),
          const SizedBox(height: 14),
          Text('Ders almak için paket gerekli', style: dashTitleStyle()),
          const SizedBox(height: 8),
          const Text(
            'Paketinizi stüdyoda alabilirsiniz. Bize ulaşın, size uygun paketi birlikte seçelim.',
          ),
          const SizedBox(height: 14),
          const StudioCard(),
        ],
      ),
    );
  }
}
