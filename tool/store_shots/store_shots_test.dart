// Google Play görselleri: telefon ekran görüntüleri, 1024x500 tanıtım görseli ve 512x512 simge.
//
// Uygulamanın gerçek ekranları sahte (demo) veriyle, gerçek yazı tipleriyle çizilir.
// Çalıştırma (proje kökünden):  flutter test tool/store_shots
// Çıktı: store/play/*.png
//
// CI'da çalışmaz (test/ klasörü dışında).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:caspertrainingstudio/core/theme/app_colors.dart';
import 'package:caspertrainingstudio/core/theme/app_theme.dart';
import 'package:caspertrainingstudio/core/utils/formatters.dart';
import 'package:caspertrainingstudio/core/widgets/brand.dart';
import 'package:caspertrainingstudio/features/home/role_home_scaffold.dart';
import 'package:caspertrainingstudio/features/home/role_shell.dart';
import 'package:caspertrainingstudio/features/member/presentation/member_dashboard.dart';
import 'package:caspertrainingstudio/features/packages/data/package_repository.dart';
import 'package:caspertrainingstudio/features/packages/domain/package_models.dart';
import 'package:caspertrainingstudio/features/packages/presentation/member/my_packages_screen.dart';
import 'package:caspertrainingstudio/features/profile/profile.dart';
import 'package:caspertrainingstudio/features/protocols/data/protocol_repository.dart';
import 'package:caspertrainingstudio/features/protocols/domain/protocol_models.dart';
import 'package:caspertrainingstudio/features/protocols/presentation/price_list_screen.dart';
import 'package:caspertrainingstudio/features/schedule/data/schedule_repository.dart';
import 'package:caspertrainingstudio/features/schedule/domain/schedule_models.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/member/class_calendar_screen.dart';
import 'package:caspertrainingstudio/features/workouts/data/workout_repository.dart';
import 'package:caspertrainingstudio/features/workouts/domain/workout_models.dart';
import 'package:caspertrainingstudio/features/workouts/presentation/my_programs_screen.dart';
import 'package:caspertrainingstudio/features/admin/presentation/admin_dashboard.dart';
import 'package:caspertrainingstudio/features/admin/presentation/deletion_requests_screen.dart';
import 'package:caspertrainingstudio/features/packages/presentation/admin/member_packages_screen.dart';
import 'package:caspertrainingstudio/features/protocols/presentation/admin_protocols_screen.dart';
import 'package:caspertrainingstudio/features/referrals/data/referral_repository.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/admin/admin_schedule_screen.dart';
import 'package:caspertrainingstudio/features/schedule/presentation/trainer/trainer_calendar_screen.dart';
import 'package:caspertrainingstudio/features/trainer/data/trainer_repository.dart';
import 'package:caspertrainingstudio/features/trainer/domain/trainer_models.dart';
import 'package:caspertrainingstudio/features/trainer/presentation/my_members_screen.dart';
import 'package:caspertrainingstudio/features/trainer/presentation/trainer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/packages/fake_repo.dart';
import '../../test/protocols/fake_protocol_repo.dart';
import '../../test/referrals/referrals_test.dart' show FakeReferralRepository;
import '../../test/trainer/fake_trainer_repo.dart';
import '../../test/workouts/fake_workout_repo.dart';

final _out = Directory('store/play');
final _now = DateTime.now();
DateTime _day(int plus, int h, [int m = 0]) =>
    DateTime(_now.year, _now.month, _now.day + plus, h, m);

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      l.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await l.load();
  }

  await family('Barlow', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Barlow-$w.ttf',
  ]);
  await family('BarlowCondensed', [
    for (final w in ['SemiBold', 'Bold', 'ExtraBoldItalic'])
      'assets/fonts/BarlowCondensed-$w.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  await family('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
  // Yazı tipi belirtmeyen Material bileşenleri (Chip vb.) telefonda Roboto kullanır
  await family('Roboto', [
    for (final w in ['regular', 'medium', 'bold'])
      '$root/bin/cache/artifacts/material_fonts/roboto-$w.ttf',
  ]);
}

/// Görsellerin gerçekten çözülüp çizilmesini bekler.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }
}

// ---------------------------------------------------------------------------
// Demo verisi (veritabanındaki inceleme hesabıyla uyumlu)
// ---------------------------------------------------------------------------
const _group = 'Atletik Performans Grup';
const _ozel = 'Özel Ders';

final _packages = [
  MemberPackage(
    id: 'p1',
    memberId: 'u1',
    definitionId: 'd1',
    categoryId: 'cg',
    categoryName: _group,
    definitionName: '$_group · 12 Ders',
    totalCredits: 12,
    remainingCredits: 9,
    pricePaid: 8000,
    activatedAt: _day(-6, 10),
    endsAt: _day(24, 23, 59),
    status: 'active',
  ),
  MemberPackage(
    id: 'p2',
    memberId: 'u1',
    definitionId: 'd2',
    categoryId: 'co',
    categoryName: _ozel,
    definitionName: '$_ozel · 8 Ders',
    totalCredits: 8,
    remainingCredits: 7,
    pricePaid: 12000,
    activatedAt: _day(-6, 10),
    endsAt: _day(24, 23, 59),
    status: 'active',
  ),
];

MyReservation _res(String id, String cat, DateTime start, String trainer) =>
    MyReservation(
      reservationId: id,
      status: 'booked',
      classId: 'c-$id',
      classStatus: 'scheduled',
      classType: cat == _group ? ClassType.group : ClassType.individual,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      categoryName: cat,
      trainerName: trainer,
    );

final _reservations = [
  _res('r1', _ozel, _day(1, 10), 'Mert Kaya'),
  _res('r2', _group, _day(1, 18, 30), 'Ayşe Yılmaz'),
  _res('r3', _group, _day(3, 18, 30), 'Ayşe Yılmaz'),
];

StudioClass _cls(
  String id,
  String cat,
  DateTime start,
  String trainer, {
  int booked = 0,
  bool mine = false,
}) {
  final group = cat == _group;
  return StudioClass(
    id: id,
    trainerId: trainer == 'Ayşe Yılmaz' ? 't1' : 't2',
    trainerName: trainer,
    categoryId: group ? 'cg' : 'co',
    categoryName: cat,
    classType: group ? ClassType.group : ClassType.individual,
    capacity: group ? 6 : 1,
    bookedCount: booked,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    status: 'scheduled',
    myReservationId: mine ? 'r-$id' : null,
  );
}

List<StudioClass> _classesOn(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final plus = d.difference(DateTime(_now.year, _now.month, _now.day)).inDays;
  if (plus < 0) return const [];
  return [
    _cls(
      'a$plus',
      _ozel,
      _day(plus, 10),
      'Mert Kaya',
      booked: plus == 1 ? 1 : 0,
      mine: plus == 1,
    ),
    _cls(
      'b$plus',
      _ozel,
      _day(plus, 17),
      'Ayşe Yılmaz',
      booked: plus.isEven ? 1 : 0,
    ),
    _cls(
      'c$plus',
      _group,
      _day(plus, 18, 30),
      'Ayşe Yılmaz',
      booked: plus == 1 ? 4 : 2,
      mine: plus == 1,
    ),
    _cls('d$plus', _group, _day(plus, 19, 30), 'Mert Kaya', booked: 5),
  ];
}

final _trainerMembers = [
  TrainerMember(
    memberId: 'u1',
    fullName: 'Deniz Arslan',
    lastClassAt: _day(-2, 18, 30),
    nextClassAt: _day(1, 18, 30),
    classCount: 6,
  ),
  TrainerMember(
    memberId: 'u2',
    fullName: 'Ece Demir',
    lastClassAt: _day(-3, 18, 30),
    nextClassAt: _day(1, 18, 30),
    classCount: 4,
  ),
  TrainerMember(
    memberId: 'u4',
    fullName: 'Selin Aydın',
    lastClassAt: _day(-1, 17),
    nextClassAt: _day(2, 17),
    classCount: 9,
  ),
  TrainerMember(
    memberId: 'u5',
    fullName: 'Emre Koç',
    lastClassAt: _day(-5, 10),
    classCount: 3,
  ),
];

final _protocols = [
  Protocol(
    id: 'pr1',
    name: 'Örnek Eğitim Sendikası',
    discountPercent: 15,
    isActive: true,
    validUntil: DateTime(_now.year + 1, 12, 31),
  ),
  const Protocol(
    id: 'pr2',
    name: 'Örnek Sağlık Çalışanları Derneği',
    discountPercent: 10,
    isActive: true,
  ),
];

final _priceList = PublicPriceList(
  categories: [
    for (final (name, type, defs) in [
      (_group, ClassType.group, [(8, 30, 5000.0), (12, 30, 8000.0)]),
      (
        'Atletik Özel Ders',
        ClassType.individual,
        [(8, 30, 15000.0), (12, 30, 18000.0), (16, 40, 22000.0)],
      ),
      (
        _ozel,
        ClassType.individual,
        [
          (8, 30, 12000.0),
          (12, 30, 15000.0),
          (16, 40, 18000.0),
          (20, 40, 20000.0),
        ],
      ),
    ])
      PublicCategory(
        name: name,
        classType: type,
        packages: [
          for (final (n, v, p) in defs)
            PublicPackage(
              name: '$name · $n Ders',
              sessionCount: n,
              validityDays: v,
              price: p,
            ),
        ],
      ),
  ],
  protocols: const [],
);

final _program = WorkoutProgram(
  id: 'w1',
  memberId: 'u1',
  title: 'Temel Kuvvet — 4 Hafta',
  goal: 'Genel kuvvet ve duruş',
  notes: 'Her setten önce 5 dk ısınma.',
  isActive: true,
  createdAt: _day(-5, 12),
  items: const [
    WorkoutItem(
      dayLabel: 'Gün 1',
      exercise: 'Goblet Squat',
      sets: 3,
      reps: '12',
      restSeconds: 60,
      sortOrder: 0,
    ),
    WorkoutItem(
      dayLabel: 'Gün 1',
      exercise: 'Şınav',
      sets: 3,
      reps: '10',
      restSeconds: 60,
      sortOrder: 1,
    ),
    WorkoutItem(
      dayLabel: 'Gün 1',
      exercise: 'Plank',
      sets: 3,
      reps: '40 sn',
      restSeconds: 45,
      sortOrder: 2,
    ),
    WorkoutItem(
      dayLabel: 'Gün 2',
      exercise: 'Romanian Deadlift',
      sets: 3,
      reps: '10',
      restSeconds: 90,
      sortOrder: 3,
    ),
    WorkoutItem(
      dayLabel: 'Gün 2',
      exercise: 'Lat Pulldown',
      sets: 3,
      reps: '12',
      restSeconds: 60,
      sortOrder: 4,
    ),
    WorkoutItem(
      dayLabel: 'Gün 2',
      exercise: 'Walking Lunge',
      sets: 3,
      reps: '10+10',
      restSeconds: 60,
      sortOrder: 5,
    ),
  ],
);

const _profile = Profile(
  id: 'u1',
  fullName: 'Deniz Arslan',
  role: UserRole.member,
  isActive: true,
);

// ---------------------------------------------------------------------------
// Çizim yardımcıları
// ---------------------------------------------------------------------------
final _boundary = GlobalKey();

Widget _app(Widget home, {ThemeMode mode = ThemeMode.light}) {
  final repo = FakeProtocolRepository()
    ..priceList = _priceList
    ..protocols = _protocols
    ..memberProtocols['u1'] = _protocols.first;
  final workouts = FakeWorkoutRepository()..list = [_program];
  return ProviderScope(
    overrides: [
      myPackagesProvider.overrideWith((ref) async => _packages),
      myReservationsProvider.overrideWith((ref) async => _reservations),
      classesProvider.overrideWith(
        (ref, q) async =>
            _classesOn(q.day)
                .where((c) => q.trainerId == null || c.trainerId == q.trainerId)
                .toList(),
      ),
      classDaysProvider.overrideWith(
        (ref, q) async => {
          for (var i = 0; i < q.days; i++)
            DateTime(q.from.year, q.from.month, q.from.day + i),
        },
      ),
      trainersProvider.overrideWith(
        (ref) async => const [
          TrainerSummary(id: 't1', fullName: 'Ayşe Yılmaz'),
          TrainerSummary(id: 't2', fullName: 'Mert Kaya'),
        ],
      ),
      adminReferralsProvider.overrideWith((ref, status) async => const []),
      deletionRequestsProvider.overrideWith((ref) async => const []),
      trainerRepositoryProvider.overrideWithValue(
        FakeTrainerRepository(_trainerMembers),
      ),
      packageRepositoryProvider.overrideWithValue(
        FakePackageRepository()..pkgs = _packages,
      ),
      referralRepositoryProvider.overrideWithValue(FakeReferralRepository()),
      protocolRepositoryProvider.overrideWithValue(repo),
      workoutRepositoryProvider.overrideWithValue(workouts),
    ],
    child: RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  Size logical = const Size(360, 780),
  double ratio = 3,
  ThemeMode mode = ThemeMode.light,
  Future<void> Function()? before,
}) async {
  tester.view.physicalSize = logical * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home, mode: mode));
  await tester.runAsync(() async {
    final ctx = _boundary.currentContext!;
    await precacheImage(const AssetImage('assets/branding/logo.png'), ctx);
  });
  await tester.pumpAndSettle();
  if (before != null) await before();
  await tester.pumpAndSettle();
  await _settleImages(tester);
  // Test ortamı gölgeleri düz siyah çizer; çekim anında gerçek gölgeleri aç
  debugDisableShadows = false;
  for (final e in tester.allElements) {
    e.renderObject?.markNeedsPaint();
  }
  await tester.pump();
  await tester.runAsync(() async {
    final ro =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image img = await ro.toImage(pixelRatio: ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    _out.createSync(recursive: true);
    File('${_out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
  debugDisableShadows = true;
}

Widget _memberShell(Widget firstPage) {
  final modules = [
    ComingModule(
      'Paketlerim',
      Icons.confirmation_number_outlined,
      onTap: _noop,
    ),
    ComingModule(
      'Cüzdanım',
      Icons.account_balance_wallet_outlined,
      subtitle: 'Bakiye: ${formatTl(500)}',
      onTap: _noop,
    ),
    ComingModule('Paketler ve fiyatlar', Icons.sell_outlined, onTap: _noop),
    ComingModule('Referanslarım', Icons.group_add_outlined, onTap: _noop),
    ComingModule('Ders Takvimi', Icons.calendar_month_outlined, onTap: _noop),
    ComingModule('Antrenman programım', Icons.fitness_center, onTap: _noop),
  ];
  return RoleShell(
    tabs: [
      ShellTab(
        label: 'Ana sayfa',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        page: RoleHomeScaffold(
          profile: _profile,
          dashboard: const MemberDashboard(),
          modules: modules,
        ),
      ),
      ShellTab(
        label: 'Takvim',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        page: firstPage,
      ),
      const ShellTab(
        label: 'Rezervasyon',
        icon: Icons.event_available_outlined,
        selectedIcon: Icons.event_available_rounded,
        page: SizedBox(),
      ),
      const ShellTab(
        label: 'Profil',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        page: SizedBox(),
      ),
    ],
  );
}

Profile _staff(String id, String name, UserRole role) =>
    Profile(id: id, fullName: name, role: role, isActive: true);

ShellTab _tab(String label, IconData icon, IconData sel, Widget page) =>
    ShellTab(label: label, icon: icon, selectedIcon: sel, page: page);

Widget _trainerShell({
  Widget second = const SizedBox(),
  Widget third = const SizedBox(),
}) {
  final p = _staff('t1', 'Ayşe Yılmaz', UserRole.trainer);
  return RoleShell(
    tabs: [
      _tab(
        'Ana sayfa',
        Icons.home_outlined,
        Icons.home_rounded,
        RoleHomeScaffold(
          profile: p,
          dashboard: const TrainerDashboard(trainerId: 't1'),
          modules: [
            ComingModule(
              'Takvimim',
              Icons.calendar_month_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Ürün satışı',
              Icons.shopping_cart_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Satışlarım',
              Icons.receipt_long_outlined,
              onTap: _noop,
            ),
            ComingModule('Üyelerim', Icons.groups_outlined, onTap: _noop),
            ComingModule(
              'Antrenman programı hazırlama',
              Icons.fitness_center,
              onTap: _noop,
            ),
            ComingModule(
              'Üye ölçümleri',
              Icons.monitor_weight_outlined,
              onTap: _noop,
            ),
          ],
        ),
      ),
      _tab(
        'Takvim',
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        second,
      ),
      _tab('Üyelerim', Icons.groups_outlined, Icons.groups_rounded, third),
      _tab(
        'Profil',
        Icons.person_outline_rounded,
        Icons.person_rounded,
        const SizedBox(),
      ),
    ],
  );
}

Widget _adminShell({Widget second = const SizedBox()}) {
  final p = _staff('a1', 'Demo Yönetici', UserRole.admin);
  return RoleShell(
    tabs: [
      _tab(
        'Ana sayfa',
        Icons.home_outlined,
        Icons.home_rounded,
        RoleHomeScaffold(
          profile: p,
          dashboard: const AdminDashboard(),
          modules: [
            ComingModule(
              'Üyeler ve paketleri',
              Icons.groups_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Paket tanımları',
              Icons.inventory_2_outlined,
              onTap: _noop,
            ),
            ComingModule('Kategoriler', Icons.category_outlined, onTap: _noop),
            ComingModule(
              'Protokoller (kurum indirimleri)',
              Icons.handshake_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Fiyat listesi (üyelerin gördüğü)',
              Icons.sell_outlined,
              onTap: _noop,
            ),
            ComingModule('Referanslar', Icons.group_add_outlined, onTap: _noop),
            ComingModule(
              'Kullanıcı ve rol yönetimi',
              Icons.manage_accounts_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Ürünler ve fiyatlar',
              Icons.sell_outlined,
              onTap: _noop,
            ),
            ComingModule(
              'Ders ve Rezervasyon Yönetimi',
              Icons.event_note_outlined,
              onTap: _noop,
            ),
            ComingModule('Raporlar', Icons.bar_chart_outlined, onTap: _noop),
          ],
        ),
      ),
      _tab(
        'Ders programı',
        Icons.event_note_outlined,
        Icons.event_note_rounded,
        second,
      ),
      _tab(
        'Üyeler',
        Icons.groups_outlined,
        Icons.groups_rounded,
        const SizedBox(),
      ),
      _tab(
        'Profil',
        Icons.person_outline_rounded,
        Icons.person_rounded,
        const SizedBox(),
      ),
    ],
  );
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: _body());
  }

  Widget _body() {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: Row(
        children: [
          const BrandLogo(size: 260, glow: true),
          const SizedBox(width: 56),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CASPER',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    fontSize: 96,
                    letterSpacing: 10,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'TRAINING STUDIO',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 32,
                    letterSpacing: 9,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Ders rezervasyonu, paketler ve\nantrenman programın tek uygulamada.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 ana sayfa', (t) async {
    await _shot(t, '01_ana_sayfa', _memberShell(const SizedBox()));
  });

  testWidgets('02 ders takvimi', (t) async {
    await _shot(
      t,
      '02_ders_takvimi',
      _memberShell(const ClassCalendarScreen()),
      before: () async {
        await t.tap(find.text('Takvim').last);
        await t.pumpAndSettle();
        await t.tap(find.text('${_day(1, 0).day}').first);
      },
    );
  });

  testWidgets('03 paketlerim', (t) async {
    await _shot(t, '03_paketlerim', const MyPackagesScreen());
  });

  testWidgets('04 antrenman programi', (t) async {
    await _shot(
      t,
      '04_antrenman_programi',
      const MyProgramsScreen(memberId: 'u1'),
    );
  });

  testWidgets('05 paketler ve fiyatlar', (t) async {
    await _shot(t, '05_paketler_ve_fiyatlar', const PriceListScreen());
  });

  testWidgets('06 ana sayfa koyu', (t) async {
    await _shot(
      t,
      '06_ana_sayfa_koyu',
      _memberShell(const SizedBox()),
      mode: ThemeMode.dark,
    );
  });

  testWidgets('tanitim gorseli 1024x500', (t) async {
    await _shot(
      t,
      'tanitim_1024x500',
      const _FeatureGraphic(),
      logical: const Size(1024, 500),
      ratio: 1,
      mode: ThemeMode.dark,
    );
  });

  testWidgets('07 egitmen ana sayfa', (t) async {
    await _shot(t, '07_egitmen_ana_sayfa', _trainerShell());
  });

  testWidgets('08 egitmen takvim', (t) async {
    await _shot(
      t,
      '08_egitmen_takvim',
      _trainerShell(second: const TrainerCalendarScreen(trainerId: 't1')),
      before: () async {
        await t.tap(find.text('Takvim').last);
        await t.pumpAndSettle();
        await t.tap(find.text('${_day(1, 0).day}').first);
      },
    );
  });

  testWidgets('09 egitmen uyelerim', (t) async {
    await _shot(
      t,
      '09_egitmen_uyelerim',
      _trainerShell(
        third: MyMembersScreen(trainerId: 't1', onMemberTap: (_, _) {}),
      ),
      before: () async {
        await t.tap(find.text('Üyelerim').last);
      },
    );
  });

  testWidgets('10 yonetici ana sayfa', (t) async {
    await _shot(t, '10_yonetici_ana_sayfa', _adminShell());
  });

  testWidgets('11 yonetici ders programi', (t) async {
    await _shot(
      t,
      '11_yonetici_ders_programi',
      _adminShell(second: const AdminScheduleScreen()),
      before: () async {
        await t.tap(find.text('Ders programı').last);
        await t.pumpAndSettle();
        await t.tap(find.text('${_day(1, 0).day}').first);
      },
    );
  });

  testWidgets('12 yonetici uye detayi', (t) async {
    await _shot(
      t,
      '12_yonetici_uye_detayi',
      const AdminMemberPackagesScreen(
        member: MemberSummary(id: 'u1', fullName: 'Deniz Arslan'),
      ),
    );
  });

  testWidgets('13 yonetici protokoller', (t) async {
    await _shot(t, '13_yonetici_protokoller', const AdminProtocolsScreen());
  });

  testWidgets('simge 512x512', (t) async {
    await _shot(
      t,
      'simge_512',
      const ColoredBox(
        color: AppColors.logoBackground,
        child: Center(child: BrandLogo(size: 512)),
      ),
      logical: const Size(512, 512),
      ratio: 1,
    );
  });
}
