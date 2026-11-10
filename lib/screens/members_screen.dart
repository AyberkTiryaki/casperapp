import 'package:flutter/material.dart';

import '../data/studio_store.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'member_detail_screen.dart';
import 'member_form.dart';

enum _Filter { tumu, aktif, bitenler }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _query = '';
  _Filter _filter = _Filter.tumu;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final members = store.members.where((m) {
      final matches = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.phone.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
      final status = switch (_filter) {
        _Filter.tumu => true,
        _Filter.aktif => !m.isExpired,
        _Filter.bitenler => m.daysLeft() <= 7,
      };
      return matches && status;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Üyeler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMemberForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Üye Ekle'),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'İsim veya telefon ile ara',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<_Filter>(
                  segments: const [
                    ButtonSegment(value: _Filter.tumu, label: Text('Tümü')),
                    ButtonSegment(value: _Filter.aktif, label: Text('Aktif')),
                    ButtonSegment(
                        value: _Filter.bitenler, label: Text('Yenilenecek')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: members.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_search,
                      message: 'Eşleşen üye bulunamadı.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _MemberTile(member: members[i], store: store),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.store});

  final Member member;
  final StudioStore store;

  @override
  Widget build(BuildContext context) {
    final trainer = store.trainerById(member.trainerId);
    return ListTile(
      leading: MemberAvatar(member: member),
      title: Text(member.name),
      subtitle: Text(
        [
          member.membership.label,
          'bitiş: ${tarih(member.membershipEnd)}',
          if (trainer != null) trainer.name,
        ].join(' • '),
      ),
      trailing: MembershipStatusChip(member: member),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(memberId: member.id),
        ),
      ),
    );
  }
}
