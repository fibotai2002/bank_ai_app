import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String _role = 'employee';

  final _nameCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _posCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('role') ?? 'employee';
    await Future.wait([_loadProfile(), _loadStats()]);
  }

  Future<void> _loadProfile() async {
    try {
      final res = await _api.getMe();
      setState(() {
        _profile = res;
        _nameCtrl.text = res['full_name'] ?? '';
        _posCtrl.text = res['position'] ?? '';
        _phoneCtrl.text = res['phone'] ?? '';
        _emailCtrl.text = res['email'] ?? '';
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    try {
      final res = await _api.getStats();
      setState(() => _stats = res);
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    try {
      final res = await _api.updateMe({
        'full_name': _nameCtrl.text.trim(),
        'position': _posCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      setState(() => _profile = res);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('full_name', _nameCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Profil yangilandi'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('❌ Xatolik yuz berdi'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _showChangePasswordSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
          final borderColor =
              isDark ? AppColors.darkBorder : AppColors.border;
          final textColor =
              isDark ? AppColors.darkText : AppColors.textPrimary;
          final hintColor =
              isDark ? AppColors.darkTextSec : AppColors.textHint;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Parol o\'zgartirish',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Joriy parol',
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon:
                          Icon(Icons.lock_outline, size: 18, color: hintColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Yangi parol',
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon: Icon(Icons.lock_reset_outlined,
                          size: 18, color: hintColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Yangi parolni tasdiqlang',
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon: Icon(Icons.check_circle_outline,
                          size: 18, color: hintColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (oldPassCtrl.text.trim().isEmpty ||
                                newPassCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Barcha maydonlarni to\'ldiring'),
                                backgroundColor: AppColors.error,
                              ));
                              return;
                            }
                            if (newPassCtrl.text != confirmCtrl.text) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('Parollar mos kelmadi'),
                                backgroundColor: AppColors.error,
                              ));
                              return;
                            }
                            setModalState(() => saving = true);
                            try {
                              await _api.updateMe({
                                'old_password': oldPassCtrl.text.trim(),
                                'password': newPassCtrl.text.trim(),
                              });
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content:
                                      const Text('✅ Parol muvaffaqiyatli o\'zgartirildi'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            } catch (_) {
                              setModalState(() => saving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: const Text(
                                      '❌ Xatolik: joriy parol noto\'g\'ri bo\'lishi mumkin'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Saqlash'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        nameCtrl: _nameCtrl,
        posCtrl: _posCtrl,
        phoneCtrl: _phoneCtrl,
        emailCtrl: _emailCtrl,
        onSave: _saveProfile,
        isDark: isDark,
      ),
    );
  }

  void _confirmLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Chiqish',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.textPrimary)),
        content: Text('Hisobdan chiqishni tasdiqlaysizmi?',
            style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? AppColors.darkTextSec : AppColors.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish',
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              widget.onLogout();
            },
            child: const Text('Chiqish',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String get _roleLabel {
    switch (_role) {
      case 'admin':
        return '👑 Admin';
      case 'manager':
        return '🏢 Manager';
      default:
        return '👤 Xodim';
    }
  }

  Color get _roleColor {
    switch (_role) {
      case 'admin':
        return AppColors.error;
      case 'manager':
        return AppColors.accent;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _showEditSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _avatarSection(isDark),
                  const SizedBox(height: 20),
                  if (_stats != null) _statsSection(isDark),
                  const SizedBox(height: 16),
                  _infoSection(isDark),
                  const SizedBox(height: 16),
                  _actionsSection(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _avatarSection(bool isDark) {
    final name = _profile?['full_name'] ?? 'Foydalanuvchi';
    final dept = _profile?['department_name'] ?? '';
    final pos = _profile?['position'] ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.accent.withOpacity(0.2)
                : AppColors.accentLight,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: AppColors.accent.withOpacity(0.3), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.textPrimary),
        ),
        if (pos.isNotEmpty || dept.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [pos, dept].where((s) => s.isNotEmpty).join(' • '),
            style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? AppColors.darkTextSec : AppColors.textSec),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _roleColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: _roleColor.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Text(
            _roleLabel,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _roleColor),
          ),
        ),
      ],
    );
  }

  Widget _statsSection(bool isDark) {
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _statItem('${_stats!['total_tasks'] ?? 0}', 'Jami vazifa',
              Icons.assignment_outlined, AppColors.accent, isDark),
          _divider(isDark),
          _statItem('${_stats!['pending'] ?? 0}', 'Kutilmoqda',
              Icons.hourglass_empty_rounded, AppColors.warning, isDark),
          _divider(isDark),
          _statItem('${_stats!['completed'] ?? 0}', 'Bajarildi',
              Icons.check_circle_outline, AppColors.success, isDark),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color,
          bool isDark) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _divider(bool isDark) => Container(
      width: 1,
      height: 48,
      color: isDark ? AppColors.darkBorder : AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _infoSection(bool isDark) {
    final username = _profile?['username'] ?? '—';
    final dept = _profile?['department_name'] ?? '—';
    final pos = _profile?['position'] ?? '—';
    final phone = _profile?['phone'] ?? '—';
    final email = _profile?['email'] ?? '—';
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _infoTile(Icons.person_outline_rounded, 'Username', username,
              isDark),
          _sep(isDark),
          _infoTile(Icons.business_outlined, 'Bo\'lim', dept, isDark),
          _sep(isDark),
          _infoTile(Icons.work_outline, 'Lavozim', pos, isDark),
          _sep(isDark),
          _infoTile(Icons.phone_outlined, 'Telefon', phone, isDark),
          _sep(isDark),
          _infoTile(Icons.email_outlined, 'Email', email, isDark),
        ],
      ),
    );
  }

  Widget _infoTile(
          IconData icon, String label, String value, bool isDark) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSec
                    : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sep(bool isDark) => Divider(
      height: 1,
      indent: 46,
      color: isDark ? AppColors.darkBorder : AppColors.border);

  Widget _actionsSection(bool isDark) {
    final appState = BankAIApp.of(context);
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _actionTile(Icons.edit_outlined, 'Profilni tahrirlash',
              AppColors.accent, _showEditSheet, isDark),
          Divider(height: 1, indent: 46, color: borderColor),
          _actionTile(Icons.lock_outline_rounded, 'Parol o\'zgartirish',
              AppColors.warning, _showChangePasswordSheet, isDark),
          Divider(height: 1, indent: 46, color: borderColor),
          _themeTile(appState, isDark),
          Divider(height: 1, indent: 46, color: borderColor),
          _actionTile(Icons.logout_rounded, 'Chiqish', AppColors.error,
              _confirmLogout, isDark),
        ],
      ),
    );
  }

  Widget _themeTile(dynamic appState, bool isDark) {
    final ThemeMode mode =
        (appState?.themeMode as ThemeMode?) ?? ThemeMode.system;
    String label;
    if (mode == ThemeMode.dark) {
      label = 'Qorong\'u (Dark)';
    } else if (mode == ThemeMode.light) {
      label = 'Yorug\' (Light)';
    } else {
      label = 'Tizim bo\'yicha';
    }

    return InkWell(
      onTap: () => _showThemePicker(appState),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.palette_outlined,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSec
                    : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSec
                              : AppColors.textSec)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? AppColors.darkTextSec
                    : AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(dynamic appState) {
    if (appState == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor =
            isDark ? AppColors.darkSurface : AppColors.bg;
        final border =
            isDark ? AppColors.darkBorder : AppColors.border;
        final text =
            isDark ? AppColors.darkText : AppColors.textPrimary;
        final sub =
            isDark ? AppColors.darkTextSec : AppColors.textSec;
        final current = appState.themeMode;

        Widget option(ThemeMode mode, String title, String subtitle,
            IconData icon) {
          final selected = current == mode;
          return ListTile(
            leading: Icon(icon,
                color: selected ? AppColors.accent : sub),
            title: Text(title,
                style: TextStyle(
                    color: text, fontWeight: FontWeight.w600)),
            subtitle:
                Text(subtitle, style: TextStyle(color: sub)),
            trailing: selected
                ? const Icon(Icons.check_rounded,
                    color: AppColors.accent)
                : null,
            onTap: () {
              Navigator.pop(context);
              appState.setThemeMode(mode);
            },
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: border),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Theme tanlang',
                    style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                option(
                  ThemeMode.system,
                  'Tizim bo\'yicha',
                  'Telefon sozlamasiga moslashadi',
                  Icons.settings_suggest_outlined,
                ),
                option(
                  ThemeMode.light,
                  'Yorug\' (Light)',
                  'Doim light rejim',
                  Icons.wb_sunny_outlined,
                ),
                option(
                  ThemeMode.dark,
                  'Qorong\'u (Dark)',
                  'Doim dark rejim',
                  Icons.dark_mode_outlined,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile(IconData icon, String label, Color color,
          VoidCallback onTap, bool isDark) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkTextSec
                      : AppColors.textHint),
            ],
          ),
        ),
      );
}

// ── Edit Bottom Sheet ─────────────────────────────────────────────────────────
class _EditSheet extends StatelessWidget {
  final TextEditingController nameCtrl, posCtrl, phoneCtrl, emailCtrl;
  final VoidCallback onSave;
  final bool isDark;

  const _EditSheet({
    required this.nameCtrl,
    required this.posCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.onSave,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor =
        isDark ? AppColors.darkText : AppColors.textPrimary;
    final hintColor =
        isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Profilni tahrirlash',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 20),
            _field('To\'liq ism', nameCtrl, Icons.person_outline,
                textColor, hintColor),
            const SizedBox(height: 12),
            _field('Lavozim', posCtrl, Icons.work_outline, textColor,
                hintColor),
            const SizedBox(height: 12),
            _field('Telefon', phoneCtrl, Icons.phone_outlined, textColor,
                hintColor,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _field('Email', emailCtrl, Icons.email_outlined, textColor,
                hintColor,
                type: TextInputType.emailAddress),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onSave,
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl, IconData icon,
          Color textColor, Color hintColor,
          {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(icon, size: 18, color: hintColor),
        ),
      );
}
