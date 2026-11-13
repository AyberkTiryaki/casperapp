class TrainerMember {
  const TrainerMember({
    required this.memberId,
    required this.fullName,
    this.lastClassAt,
    this.nextClassAt,
    this.classCount = 0,
  });

  final String memberId;
  final String fullName;
  final DateTime? lastClassAt;
  final DateTime? nextClassAt;
  final int classCount;

  factory TrainerMember.fromJson(Map<String, dynamic> j) => TrainerMember(
    memberId: j['member_id'] as String,
    fullName: (j['full_name'] as String?) ?? '-',
    lastClassAt: j['last_class_at'] == null
        ? null
        : DateTime.parse(j['last_class_at'] as String),
    nextClassAt: j['next_class_at'] == null
        ? null
        : DateTime.parse(j['next_class_at'] as String),
    classCount: (j['class_count'] as num?)?.toInt() ?? 0,
  );
}

/// Türkçe İ/I harflerini doğru küçültür (İ->i, I->ı).
String trLower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Ada göre büyük/küçük harf duyarsız süzme; boş sorgu tümünü döndürür.
List<TrainerMember> filterMembers(List<TrainerMember> all, String query) {
  final q = trLower(query.trim());
  if (q.isEmpty) return all;
  return all.where((m) => trLower(m.fullName).contains(q)).toList();
}
