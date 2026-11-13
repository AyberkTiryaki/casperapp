import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../data/trainer_repository.dart';
import '../domain/trainer_models.dart';

String _dt(DateTime? d) =>
    d == null ? '—' : '${formatDate(d)} ${formatTime(d)}';

class MyMembersScreen extends ConsumerStatefulWidget {
  const MyMembersScreen({
    super.key,
    this.title = 'Üyelerim',
    this.hint,
    this.trainerId,
    required this.onMemberTap,
    this.trailingIcon = Icons.chevron_right,
  });

  final String title;
  final String? hint;
  final String? trainerId;
  final void Function(BuildContext context, TrainerMember member) onMemberTap;
  final IconData trailingIcon;

  @override
  ConsumerState<MyMembersScreen> createState() => _MyMembersScreenState();
}

class _MyMembersScreenState extends ConsumerState<MyMembersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(trainerMembersProvider(widget.trainerId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (widget.hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.hint!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Üye ara',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<TrainerMember>>(
              value: members,
              onRetry: () =>
                  ref.invalidate(trainerMembersProvider(widget.trainerId)),
              data: (all) {
                final shown = filterMembers(all, _search.text);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(trainerMembersProvider(widget.trainerId));
                    await ref.read(
                      trainerMembersProvider(widget.trainerId).future,
                    );
                  },
                  child: shown.isEmpty
                      ? LayoutBuilder(
                          builder: (context, c) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: c.maxHeight,
                              child: all.isEmpty
                                  ? const EmptyView(
                                      title: 'Henüz üyeniz yok',
                                      message: 'Derslerinize rezervasyon yapan üyeler burada görünür.',
                                      icon: Icons.groups_outlined,
                                    )
                                  : const EmptyView(
                                      title: 'Üye bulunamadı',
                                      icon: Icons.person_search,
                                    ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final m = shown[i];
                            return Card(
                              child: ListTile(
                                title: Text(m.fullName),
                                subtitle: Text(
                                  'Son ders: ${_dt(m.lastClassAt)}\n'
                                  'Sonraki ders: ${_dt(m.nextClassAt)}\n'
                                  '${m.classCount} ders (son 90 gün ve gelecek)',
                                ),
                                isThreeLine: true,
                                trailing: Icon(widget.trailingIcon),
                                onTap: () => widget.onMemberTap(context, m),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
