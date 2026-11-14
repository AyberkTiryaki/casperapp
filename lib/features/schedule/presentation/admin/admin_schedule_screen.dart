import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/schedule_repository.dart';
import '../shared/create_class_screen.dart';
import '../shared/schedule_widgets.dart';
import 'admin_class_detail_screen.dart';
import '../../../../core/widgets/home_button.dart';

class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() =>
      _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  DateTime _day = dayStart(DateTime.now());
  String? _trainerId;
  bool _includeCancelled = false;

  @override
  Widget build(BuildContext context) {
    final trainers = ref.watch(trainersProvider).value ?? const [];
    final query = (
      day: _day,
      categoryId: null,
      trainerId: _trainerId,
      includeCancelled: _includeCancelled,
    );
    return Scaffold(
      appBar: AppBar(
        actions: const [HomeButton()],
        title: const Text('Ders ve Rezervasyon Yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateClassScreen(asAdmin: true, initialDay: _day),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ders aç'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          DayStrip(
            selected: _day,
            onSelected: (d) => setState(() => _day = d),
            startOffset: -7,
            days: 28,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _trainerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Antrenör'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tümü'),
                      ),
                      for (final t in trainers)
                        DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.fullName),
                        ),
                    ],
                    onChanged: (v) => setState(() => _trainerId = v),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('İptaller', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _includeCancelled,
                      onChanged: (v) => setState(() => _includeCancelled = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClassListView(
              query: query,
              onTap: (c) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminClassDetailScreen(item: c),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
