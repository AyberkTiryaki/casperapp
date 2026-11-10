/// Uygulamanın temel veri modelleri.
library;

enum MembershipType {
  aylik('Aylık', 30),
  ucAylik('3 Aylık', 90),
  yillik('Yıllık', 365),
  paket10('10 Derslik Paket', 60);

  const MembershipType(this.label, this.days);

  final String label;

  /// Üyelik yenilendiğinde eklenecek gün sayısı.
  final int days;
}

class Trainer {
  Trainer({required this.id, required this.name, required this.specialty});

  final String id;
  String name;
  String specialty;
}

class Member {
  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.membership,
    required this.membershipEnd,
    this.trainerId,
    this.programId,
  });

  final String id;
  String name;
  String phone;
  MembershipType membership;
  DateTime membershipEnd;
  String? trainerId;
  String? programId;

  /// Üyeliğin bitmesine kalan gün (geçmişse negatif).
  int daysLeft([DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    return _dateOnly(membershipEnd).difference(today).inDays;
  }

  bool get isExpired => daysLeft() < 0;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class StudioClass {
  StudioClass({
    required this.id,
    required this.title,
    required this.trainerId,
    required this.start,
    required this.duration,
    required this.capacity,
    Set<String>? attendeeIds,
  }) : attendeeIds = attendeeIds ?? <String>{};

  final String id;
  String title;
  String trainerId;
  DateTime start;
  Duration duration;
  int capacity;
  final Set<String> attendeeIds;

  DateTime get end => start.add(duration);
  bool get isFull => attendeeIds.length >= capacity;
}

class Exercise {
  Exercise({required this.name, required this.sets, required this.reps});

  String name;
  int sets;

  /// Tekrar ya da süre ("10", "12-15", "30 sn").
  String reps;
}

class WorkoutProgram {
  WorkoutProgram({
    required this.id,
    required this.name,
    required this.goal,
    required this.exercises,
  });

  final String id;
  String name;
  String goal;
  List<Exercise> exercises;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
