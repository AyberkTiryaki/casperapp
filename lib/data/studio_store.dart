import 'package:flutter/widgets.dart';

import '../models/models.dart';

/// Uygulamanın tüm verisini tutan depo.
///
/// Şimdilik veriler bellekte tutuluyor; ileride bu sınıfın içi
/// Supabase çağrılarıyla değiştirilecek, ekranlar aynı kalacak.
class StudioStore extends ChangeNotifier {
  StudioStore({
    List<Trainer>? trainers,
    List<Member>? members,
    List<StudioClass>? classes,
    List<WorkoutProgram>? programs,
  })  : trainers = trainers ?? [],
        members = members ?? [],
        classes = classes ?? [],
        programs = programs ?? [];

  final List<Trainer> trainers;
  final List<Member> members;
  final List<StudioClass> classes;
  final List<WorkoutProgram> programs;

  int _idCounter = 1000;
  String _newId(String prefix) => '$prefix${_idCounter++}';

  // ---------- Sorgular ----------

  Trainer? trainerById(String? id) => _find(trainers, (t) => t.id == id);
  Member? memberById(String? id) => _find(members, (m) => m.id == id);
  WorkoutProgram? programById(String? id) => _find(programs, (p) => p.id == id);

  List<StudioClass> classesOn(DateTime day) {
    final list = classes
        .where((c) =>
            c.start.year == day.year &&
            c.start.month == day.month &&
            c.start.day == day.day)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  List<StudioClass> upcomingClassesFor(String memberId) {
    final now = DateTime.now();
    return classes
        .where((c) => c.attendeeIds.contains(memberId) && c.end.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  int get activeMemberCount => members.where((m) => !m.isExpired).length;

  /// Süresi dolmuş ya da [withinDays] gün içinde dolacak üyeler.
  List<Member> expiringMembers({int withinDays = 7}) {
    return members.where((m) => m.daysLeft() <= withinDays).toList()
      ..sort((a, b) => a.membershipEnd.compareTo(b.membershipEnd));
  }

  int membersOnProgram(String programId) =>
      members.where((m) => m.programId == programId).length;

  // ---------- Üyeler ----------

  Member addMember({
    required String name,
    required String phone,
    required MembershipType membership,
    required DateTime membershipEnd,
    String? trainerId,
    String? programId,
  }) {
    final m = Member(
      id: _newId('m'),
      name: name,
      phone: phone,
      membership: membership,
      membershipEnd: membershipEnd,
      trainerId: trainerId,
      programId: programId,
    );
    members.add(m);
    notifyListeners();
    return m;
  }

  void updateMember(Member member) => notifyListeners();

  void deleteMember(String id) {
    members.removeWhere((m) => m.id == id);
    for (final c in classes) {
      c.attendeeIds.remove(id);
    }
    notifyListeners();
  }

  /// Üyeliği, bugünden ya da mevcut bitiş tarihinden (hangisi sonraysa)
  /// itibaren üyelik süresi kadar uzatır.
  void renewMembership(String memberId) {
    final m = memberById(memberId);
    if (m == null) return;
    final today = DateTime.now();
    final base = m.membershipEnd.isAfter(today) ? m.membershipEnd : today;
    m.membershipEnd = base.add(Duration(days: m.membership.days));
    notifyListeners();
  }

  // ---------- Dersler ----------

  StudioClass addClass({
    required String title,
    required String trainerId,
    required DateTime start,
    required Duration duration,
    required int capacity,
  }) {
    final c = StudioClass(
      id: _newId('c'),
      title: title,
      trainerId: trainerId,
      start: start,
      duration: duration,
      capacity: capacity,
    );
    classes.add(c);
    notifyListeners();
    return c;
  }

  void deleteClass(String id) {
    classes.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Rezervasyonu açar/kapatır. Kontenjan doluysa ya da üyelik bitmişse
  /// yeni rezervasyon yapılmaz ve hata mesajı döner.
  String? toggleBooking(String classId, String memberId) {
    final c = _find(classes, (x) => x.id == classId);
    final m = memberById(memberId);
    if (c == null || m == null) return 'Kayıt bulunamadı.';
    if (c.attendeeIds.contains(memberId)) {
      c.attendeeIds.remove(memberId);
    } else {
      if (c.isFull) return 'Ders kontenjanı dolu.';
      if (m.isExpired) return '${m.name} adlı üyenin üyeliği bitmiş.';
      c.attendeeIds.add(memberId);
    }
    notifyListeners();
    return null;
  }

  // ---------- Programlar ----------

  WorkoutProgram addProgram({
    required String name,
    required String goal,
    required List<Exercise> exercises,
  }) {
    final p = WorkoutProgram(
      id: _newId('p'),
      name: name,
      goal: goal,
      exercises: exercises,
    );
    programs.add(p);
    notifyListeners();
    return p;
  }

  void updateProgram(WorkoutProgram program) => notifyListeners();

  void deleteProgram(String id) {
    programs.removeWhere((p) => p.id == id);
    for (final m in members) {
      if (m.programId == id) m.programId = null;
    }
    notifyListeners();
  }

  static T? _find<T>(List<T> list, bool Function(T) test) {
    for (final x in list) {
      if (test(x)) return x;
    }
    return null;
  }
}

/// Depoyu widget ağacına yerleştirir.
class StoreScope extends InheritedNotifier<StudioStore> {
  const StoreScope({super.key, required StudioStore store, required super.child})
      : super(notifier: store);

  /// Depoyu okur ve değiştiğinde widget'ı yeniden çizer.
  static StudioStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Depoyu sadece okur (buton olayları gibi yerlerde).
  static StudioStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
