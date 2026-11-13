int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

String? _toStr(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

class WorkoutItem {
  const WorkoutItem({
    this.id,
    required this.dayLabel,
    required this.exercise,
    this.sets,
    this.reps,
    this.restSeconds,
    this.note,
    this.sortOrder = 0,
  });

  final String? id;
  final String dayLabel;
  final String exercise;
  final int? sets;
  final String? reps;
  final int? restSeconds;
  final String? note;
  final int sortOrder;

  factory WorkoutItem.fromJson(Map<String, dynamic> j) => WorkoutItem(
    id: j['id']?.toString(),
    dayLabel: (j['day_label'] as String?) ?? '',
    exercise: (j['exercise'] as String?) ?? '',
    sets: _toInt(j['sets']),
    reps: _toStr(j['reps']),
    restSeconds: _toInt(j['rest_seconds']),
    note: _toStr(j['note']),
    sortOrder: _toInt(j['sort_order']) ?? 0,
  );

  /// `save_workout_program` p_items öğesi.
  Map<String, dynamic> toJson() => {
    'day_label': dayLabel,
    'exercise': exercise,
    'sets': sets,
    'reps': reps,
    'rest_seconds': restSeconds,
    'note': note,
  };
}

class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.memberId,
    required this.title,
    this.goal,
    this.notes,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String memberId;
  final String title;
  final String? goal;
  final String? notes;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final List<WorkoutItem> items;

  factory WorkoutProgram.fromJson(Map<String, dynamic> j) {
    final raw = j['workout_program_items'];
    final items = raw is List
        ? raw
              .map(
                (e) =>
                    WorkoutItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList()
        : <WorkoutItem>[];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return WorkoutProgram(
      id: j['id'].toString(),
      memberId: j['member_id'].toString(),
      title: (j['title'] as String?) ?? '',
      goal: _toStr(j['goal']),
      notes: _toStr(j['notes']),
      isActive: (j['is_active'] as bool?) ?? false,
      createdBy: j['created_by']?.toString(),
      createdAt:
          DateTime.tryParse((j['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
    );
  }
}

/// Egzersizleri gün etiketine göre, ilk görünüş sırasını koruyarak gruplar.
List<MapEntry<String, List<WorkoutItem>>> groupItemsByDay(
  List<WorkoutItem> items,
) {
  final map = <String, List<WorkoutItem>>{};
  for (final i in items) {
    map.putIfAbsent(i.dayLabel, () => []).add(i);
  }
  return map.entries.toList();
}

/// Aktif program önce, sonra yeniden eskiye.
List<WorkoutProgram> sortPrograms(List<WorkoutProgram> programs) {
  final l = [...programs];
  l.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return l;
}

/// 90 -> "1 dk 30 sn", 60 -> "1 dk", 45 -> "45 sn".
String formatRest(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '$s sn';
  if (s == 0) return '$m dk';
  return '$m dk $s sn';
}
