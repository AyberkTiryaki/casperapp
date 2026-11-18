import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/supabase.dart';

/// Hareketsizlik sonrası otomatik çıkış (18.11.2026 kararı).
/// Uygulama bu süre boyunca kullanılmazsa (arka planda kalsa, kapatılsa ya da açık
/// bırakılsa) oturum kapanır; tekrar girişte şifre istenir. E-posta "Beni hatırla"
/// ile hatırlanır (bkz. remembered_email.dart).
const sessionIdleTimeout = Duration(hours: 2);

const _prefsLastActiveKey = 'session_last_active_ms';

/// Son kullanıcı etkileşimi (bellekte); arka plana geçerken diske yazılır.
DateTime _lastActive = DateTime.now();
DateTime? _lastPersisted;

/// Zaman aşımıyla çıkış yapıldıysa giriş ekranı bir kez bilgi gösterir.
bool sessionExpiredNotice = false;

bool isSessionExpired(DateTime? lastActive, DateTime now) =>
    lastActive == null || now.difference(lastActive) > sessionIdleTimeout;

Future<void> _persist([DateTime? at]) async {
  final t = at ?? _lastActive;
  _lastPersisted = DateTime.now();
  try {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsLastActiveKey, t.millisecondsSinceEpoch);
  } catch (_) {}
}

Future<void> _expire() async {
  sessionExpiredNotice = true;
  try {
    await supabase.auth.signOut();
  } catch (_) {}
}

/// Uygulama açılışında (runApp'tan önce): kayıtlı oturum eskiyse kapatır.
Future<void> enforceSessionTimeoutOnStartup() async {
  if (supabase.auth.currentSession != null) {
    DateTime? last;
    try {
      final p = await SharedPreferences.getInstance();
      final ms = p.getInt(_prefsLastActiveKey);
      if (ms != null) last = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {}
    if (isSessionExpired(last, DateTime.now())) await _expire();
  }
  _lastActive = DateTime.now();
  await _persist();
}

/// Kullanıcı etkileşimlerini izler ve süre dolunca oturumu kapatır.
class SessionActivityWatcher extends StatefulWidget {
  const SessionActivityWatcher({super.key, required this.child});
  final Widget child;

  @override
  State<SessionActivityWatcher> createState() => _SessionActivityWatcherState();
}

class _SessionActivityWatcherState extends State<SessionActivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _touch();
    return false;
  }

  void _touch() {
    if (_inBackground) return;
    _lastActive = DateTime.now();
    // Diske en fazla dakikada bir yaz.
    final p = _lastPersisted;
    if (p == null || _lastActive.difference(p) > const Duration(minutes: 1)) {
      _persist();
    }
  }

  Future<void> _check() async {
    if (supabase.auth.currentSession == null) return;
    if (isSessionExpired(_lastActive, DateTime.now())) await _expire();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_inBackground) {
          _inBackground = true;
          _persist();
        }
      case AppLifecycleState.resumed:
        _inBackground = false;
        _check().then((_) => _touch());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _touch(),
    onPointerSignal: (_) => _touch(),
    child: widget.child,
  );
}
