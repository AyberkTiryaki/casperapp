import '../models/models.dart';
import 'studio_store.dart';

/// Uygulamayı denemek için örnek verilerle dolu bir depo oluşturur.
/// İsimler hayalidir.
StudioStore buildDemoStore([DateTime? now]) {
  final today = DateTime(
    (now ?? DateTime.now()).year,
    (now ?? DateTime.now()).month,
    (now ?? DateTime.now()).day,
  );
  DateTime day(int offset, int hour, [int minute = 0]) =>
      today.add(Duration(days: offset, hours: hour, minutes: minute));

  final trainers = [
    Trainer(id: 't1', name: 'Ece Yıldız', specialty: 'Pilates'),
    Trainer(id: 't2', name: 'Mert Aydın', specialty: 'Fonksiyonel Antrenman'),
    Trainer(id: 't3', name: 'Deniz Kara', specialty: 'Yoga'),
  ];

  final programs = [
    WorkoutProgram(
      id: 'p1',
      name: 'Başlangıç – Tüm Vücut',
      goal: 'Temel kuvvet ve form',
      exercises: [
        Exercise(name: 'Goblet Squat', sets: 3, reps: '12'),
        Exercise(name: 'Şınav (dizden)', sets: 3, reps: '10'),
        Exercise(name: 'Dumbbell Row', sets: 3, reps: '12'),
        Exercise(name: 'Glute Bridge', sets: 3, reps: '15'),
        Exercise(name: 'Plank', sets: 3, reps: '30 sn'),
      ],
    ),
    WorkoutProgram(
      id: 'p2',
      name: 'Kuvvet – Üst/Alt',
      goal: 'Kas kütlesi ve kuvvet',
      exercises: [
        Exercise(name: 'Back Squat', sets: 4, reps: '6-8'),
        Exercise(name: 'Bench Press', sets: 4, reps: '6-8'),
        Exercise(name: 'Romanian Deadlift', sets: 3, reps: '8-10'),
        Exercise(name: 'Barfiks', sets: 3, reps: 'Max'),
        Exercise(name: 'Overhead Press', sets: 3, reps: '8'),
      ],
    ),
    WorkoutProgram(
      id: 'p3',
      name: 'Yağ Yakım – HIIT',
      goal: 'Kondisyon ve kalori yakımı',
      exercises: [
        Exercise(name: 'Kettlebell Swing', sets: 5, reps: '40 sn'),
        Exercise(name: 'Burpee', sets: 5, reps: '30 sn'),
        Exercise(name: 'Mountain Climber', sets: 5, reps: '40 sn'),
        Exercise(name: 'Jump Squat', sets: 5, reps: '30 sn'),
      ],
    ),
  ];

  final members = [
    Member(
      id: 'm1',
      name: 'Ayşe Demir',
      phone: '0532 000 00 01',
      membership: MembershipType.yillik,
      membershipEnd: today.add(const Duration(days: 210)),
      trainerId: 't1',
      programId: 'p1',
    ),
    Member(
      id: 'm2',
      name: 'Burak Şahin',
      phone: '0532 000 00 02',
      membership: MembershipType.aylik,
      membershipEnd: today.add(const Duration(days: 3)),
      trainerId: 't2',
      programId: 'p2',
    ),
    Member(
      id: 'm3',
      name: 'Cansu Öztürk',
      phone: '0532 000 00 03',
      membership: MembershipType.ucAylik,
      membershipEnd: today.add(const Duration(days: 45)),
      trainerId: 't3',
    ),
    Member(
      id: 'm4',
      name: 'Emre Çelik',
      phone: '0532 000 00 04',
      membership: MembershipType.paket10,
      membershipEnd: today.subtract(const Duration(days: 2)),
      trainerId: 't2',
      programId: 'p3',
    ),
    Member(
      id: 'm5',
      name: 'Zeynep Koç',
      phone: '0532 000 00 05',
      membership: MembershipType.aylik,
      membershipEnd: today.add(const Duration(days: 6)),
      trainerId: 't1',
      programId: 'p1',
    ),
    Member(
      id: 'm6',
      name: 'Oğuz Yalçın',
      phone: '0532 000 00 06',
      membership: MembershipType.yillik,
      membershipEnd: today.add(const Duration(days: 300)),
      trainerId: 't2',
      programId: 'p2',
    ),
    Member(
      id: 'm7',
      name: 'Selin Aksoy',
      phone: '0532 000 00 07',
      membership: MembershipType.ucAylik,
      membershipEnd: today.add(const Duration(days: 20)),
      trainerId: 't3',
    ),
    Member(
      id: 'm8',
      name: 'Kaan Polat',
      phone: '0532 000 00 08',
      membership: MembershipType.aylik,
      membershipEnd: today.add(const Duration(days: 12)),
      programId: 'p3',
    ),
  ];

  final classes = <StudioClass>[];
  var n = 1;
  for (var d = 0; d < 7; d++) {
    final weekday = today.add(Duration(days: d)).weekday;
    if (weekday != DateTime.sunday) {
      classes.add(
        StudioClass(
          id: 'c${n++}',
          title: 'Reformer Pilates',
          trainerId: 't1',
          start: day(d, 9),
          duration: const Duration(minutes: 50),
          capacity: 6,
          attendeeIds: d.isEven ? {'m1', 'm5'} : {'m1'},
        ),
      );
      classes.add(
        StudioClass(
          id: 'c${n++}',
          title: 'Fonksiyonel Grup',
          trainerId: 't2',
          start: day(d, 18),
          duration: const Duration(minutes: 60),
          capacity: 12,
          attendeeIds: {'m2', 'm6', if (d.isOdd) 'm8'},
        ),
      );
    }
    if (weekday == DateTime.tuesday ||
        weekday == DateTime.thursday ||
        weekday == DateTime.saturday) {
      classes.add(
        StudioClass(
          id: 'c${n++}',
          title: 'Vinyasa Yoga',
          trainerId: 't3',
          start: day(d, 19, 30),
          duration: const Duration(minutes: 75),
          capacity: 15,
          attendeeIds: {'m3', 'm7'},
        ),
      );
    }
  }

  return StudioStore(
    trainers: trainers,
    members: members,
    classes: classes,
    programs: programs,
  );
}
