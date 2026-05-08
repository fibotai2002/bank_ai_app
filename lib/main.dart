import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import — WebSocket Tez orada aktivlashtirish uchun tayyor
// import 'package:web_socket_channel/web_socket_channel.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/employees/employees_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';
import 'core/api/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const BankAIApp());
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      size: 52, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Markaziy Bank AI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Farg\'ona viloyati boshqarmasi',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BankAIApp extends StatefulWidget {
  const BankAIApp({super.key});

  static _BankAIAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BankAIAppState>();

  @override
  State<BankAIApp> createState() => _BankAIAppState();
}

class _BankAIAppState extends State<BankAIApp> {
  bool _isLoggedIn = false;
  bool _checking = true;
  bool _showSplash = true;
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveTheme();
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    _saveTheme();
  }

  bool get isDark {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // system
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeMode.name);
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    setState(() {
      _isLoggedIn = prefs.containsKey('access_token');
      _checking = false;
      if (savedTheme == 'dark') _themeMode = ThemeMode.dark;
      else if (savedTheme == 'light') _themeMode = ThemeMode.light;
      else _themeMode = ThemeMode.system;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tashkilot AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _showSplash
          ? SplashScreen(onDone: () => setState(() => _showSplash = false))
          : _checking
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  ),
                )
              : _isLoggedIn
                  ? HomeScreen(
                      onLogout: () => setState(() => _isLoggedIn = false))
                  : LoginScreen(
                      onLogin: () => setState(() => _isLoggedIn = true)),
    );
  }
}

// ── Home Screen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _unreadNotifs = 0;
  int _pendingTasks = 0;
  String _fullName = '';
  final _api = ApiClient();

  // WebSocket — real-time bildirishnomalar
  // TODO: WebSocket real-time bildirishnomalar — Tez orada!
  // WebSocketChannel? _wsChannel;
  // void _connectWebSocket(int userId, String token) {
  //   final wsUrl = ApiClient.baseUrl
  //       .replaceFirst('https://', 'wss://')
  //       .replaceFirst('http://', 'ws://');
  //   try {
  //     _wsChannel = WebSocketChannel.connect(
  //       Uri.parse('$wsUrl/ws/$userId?token=$token'),
  //     );
  //     _wsChannel!.stream.listen(
  //       (msg) {
  //         // Yangi bildirishnoma keldi — badge yangilash
  //         if (mounted) setState(() => _unreadNotifs++);
  //       },
  //       onDone: () {
  //         // Ulanish uzildi — 5 soniyadan keyin qayta ulanish
  //         Future.delayed(const Duration(seconds: 5), () {
  //           if (mounted) _connectWebSocket(userId, token);
  //         });
  //       },
  //       onError: (_) {},
  //       cancelOnError: false,
  //     );
  //   } catch (_) {}
  // }

  // Faqat 5 ta tab - Profile va Notifications AppBar ga ko'chirildi
  static const _tabs = [
    _TabInfo(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Bosh',
      color: AppColors.googleBlue,
    ),
    _TabInfo(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: 'AI Chat',
      color: Color(0xFF7C3AED),
    ),
    _TabInfo(
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt_rounded,
      label: 'Vazifalar',
      color: AppColors.googleGreen,
    ),
    _TabInfo(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Xodimlar',
      color: AppColors.googleYellow,
    ),
    _TabInfo(
      icon: Icons.description_outlined,
      activeIcon: Icons.description_rounded,
      label: 'Hujjatlar',
      color: AppColors.googleBlue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _fullName = prefs.getString('full_name') ?? '';
        });
      }
      final notifs = await _api.getMyNotifications();
      final tasks = await _api.getTasks(status: 'pending');
      if (mounted) {
        setState(() {
          _unreadNotifs = notifs.where((n) => n['is_read'] == false).length;
          _pendingTasks = tasks.length;
        });
      }
    } catch (_) {}
  }

  List<Widget> get _screens => [
        DashboardScreen(
          onNavigateToTasks: () => setState(() => _tab = 2),
          onNavigateToChat: () => setState(() => _tab = 1),
        ),
        const ChatScreen(),
        const TasksScreen(),
        const EmployeesScreen(),
        const DocumentsScreen(),
      ];

  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.isEmpty || _fullName.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    ).then((_) => _loadBadges());
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(onLogout: widget.onLogout),
      ),
    ).then((_) => _loadBadges());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Text(
              'Tashkilot AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Theme toggle
          IconButton(
            tooltip: isDark ? 'Yorug\' rejim' : 'Tungi rejim',
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
              size: 22,
              color: textSecColor,
            ),
            onPressed: () => BankAIApp.of(context)?.toggleTheme(),
          ),
          // Notifications bell with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Bildirishnomalar',
                icon: Icon(
                  _unreadNotifs > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  size: 24,
                  color: _unreadNotifs > 0 ? AppColors.googleRed : textSecColor,
                ),
                onPressed: _openNotifications,
              ),
              if (_unreadNotifs > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: AppColors.googleRed,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: bgColor, width: 1.5),
                    ),
                    child: Text(
                      _unreadNotifs > 99 ? '99+' : '$_unreadNotifs',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Profile avatar
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              margin: const EdgeInsets.only(right: 12, left: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = _tab == i;
                final color = isActive
                    ? tab.color
                    : (isDark ? AppColors.darkTextSec : AppColors.textHint);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _tab = i);
                      if (i == 2) {
                        // Vazifalar tab - badges refresh
                        Future.delayed(
                            const Duration(milliseconds: 500), _loadBadges);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTabIcon(i, isActive, color, tab, isDark, bgColor),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isActive ? 10.5 : 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: color,
                              letterSpacing: 0.1,
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabIcon(int i, bool isActive, Color color, _TabInfo tab,
      bool isDark, Color bgColor) {
    int badge = 0;
    if (i == 2) badge = _pendingTasks;

    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        isActive ? tab.activeIcon : tab.icon,
        key: ValueKey(isActive),
        size: 24,
        color: color,
      ),
    );

    if (badge > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.googleRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bgColor, width: 1.5),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    // Active tab uchun pill background
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class _TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const _TabInfo({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}
