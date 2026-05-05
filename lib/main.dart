import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class BankAIApp extends StatefulWidget {
  const BankAIApp({super.key});
  @override
  State<BankAIApp> createState() => _BankAIAppState();
}

class _BankAIAppState extends State<BankAIApp> {
  bool _isLoggedIn = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.containsKey('access_token');
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tashkilot AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _checking
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
  String _role = 'employee';
  int _userId = 0;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'employee';
      _userId = prefs.getInt('user_id') ?? 0;
    });
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
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
        // 0 - Dashboard
        DashboardScreen(
          onNavigateToTasks: () => setState(() => _tab = 2),
          onNavigateToChat: () => setState(() => _tab = 1),
        ),
        // 1 - Chat
        const ChatScreen(),
        // 2 - Vazifalar
        const TasksScreen(),
        // 3 - Xodimlar
        const EmployeesScreen(),
        // 4 - Hujjatlar
        const DocumentsScreen(),
        // 5 - Bildirishnomalar
        const NotificationsScreen(),
        // 6 - Profil
        ProfileScreen(onLogout: widget.onLogout),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 5) {
              Future.delayed(const Duration(seconds: 1), _loadBadges);
            }
          },
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined, size: 22),
              activeIcon: Icon(Icons.dashboard_rounded, size: 22),
              label: 'Bosh',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined, size: 22),
              activeIcon: Icon(Icons.smart_toy_rounded, size: 22),
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(
              icon: _badgeIcon(Icons.checklist_outlined, _pendingTasks),
              activeIcon:
                  _badgeIcon(Icons.checklist_rounded, _pendingTasks),
              label: 'Vazifalar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded, size: 22),
              activeIcon: Icon(Icons.people_rounded, size: 22),
              label: 'Xodimlar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined, size: 22),
              activeIcon: Icon(Icons.folder_rounded, size: 22),
              label: 'Hujjatlar',
            ),
            BottomNavigationBarItem(
              icon: _badgeIcon(
                  Icons.notifications_none_rounded, _unreadNotifs),
              activeIcon:
                  _badgeIcon(Icons.notifications_rounded, _unreadNotifs),
              label: 'Xabarlar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 22),
              activeIcon: Icon(Icons.person_rounded, size: 22),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22),
        if (count > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
