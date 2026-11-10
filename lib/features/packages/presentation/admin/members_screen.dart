import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../data/package_repository.dart';
import '../../domain/package_models.dart';
import 'member_packages_screen.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  AsyncValue<List<MemberSummary>> _result = const AsyncLoading();
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _result = const AsyncLoading());
    try {
      final r = await ref.read(packageRepositoryProvider).searchMembers(q.trim());
      if (mounted && seq == _seq) setState(() => _result = AsyncData(r));
    } catch (e, st) {
      if (mounted && seq == _seq) {
        setState(() => _result = AsyncError(e, st));
      }
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Üyeler')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Üye ara',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<MemberSummary>>(
              value: _result,
              onRetry: () => _search(_controller.text),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      title: 'Üye bulunamadı', icon: Icons.person_search)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(m.fullName),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AdminMemberPackagesScreen(member: m))),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
