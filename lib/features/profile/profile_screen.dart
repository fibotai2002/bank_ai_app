import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

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

      // SharedPreferences ni yangilash
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('full_name', _nameCtrl.text.trim());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Profil yangilandi'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('❌ Xatolik yuz berdi'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _showEditSheet() {
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
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chiqish',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: const Text('Hisobdan chiqishni tasdiqlaysizmi?',
            style: TextStyle(fontSize: 14, color: AppColors.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish',
                style: TextStyle(color: AppColors.textSec)),
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
      case 'admin': return '👑 Admin';
      case 'manager': return '🏢 Manager';
      default: return '👤 Xodim';
    }
  }

  Color get _roleColor {
    switch (_role) {
      case 'admin': return AppColors.error;
      case 'manager': return AppColors.accent;
      default: return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _showEditSheet,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
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
                  _avatarSection(),
                  const SizedBox(height: 20),
                  if (_stats != null) _statsSection(),
                  const SizedBox(height: 16),
                  _infoSection(),
                  const SizedBox(height: 16),
                  _actionsSection(),
                ],
              ),
            ),
    );
  }

  Widget _avatarSection() {
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.accent),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        if (pos.isNotEmpty || dept.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [pos, dept].where((s) => s.isNotEmpty).join(' • '),
            style: const TextStyle(fontSize: 13, color: AppColors.textSec),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        // Rol badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _roleColor.withOpacity(0.3)),
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

  Widget _statsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _statItem('${_stats!['total_tasks'] ?? 0}', 'Jami vazifa',
              Icons.assignment_outlined, AppColors.accent),
          _divider(),
          _statItem('${_stats!['pending'] ?? 0}', 'Kutilmoqda',
              Icons.hourglass_empty_rounded, AppColors.warning),
          _divider(),
          _statItem('${_stats!['completed'] ?? 0}', 'Bajarildi',
              Icons.check_circle_outline, AppColors.success),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) =>
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
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSec),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _divider() => Container(
      width: 1, height: 48, color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _infoSection() {
    final username = _profile?['username'] ?? '—';
    final dept = _profile?['department_name'] ?? '—';
    final pos = _profile?['position'] ?? '—';
    final phone = _profile?['phone'] ?? '—';
    final email = _profile?['email'] ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoTile(Icons.person_outline_rounded, 'Username', username),
          _sep(),
          _infoTile(Icons.business_outlined, 'Bo\'lim', dept),
          _sep(),
          _infoTile(Icons.work_outline, 'Lavozim', pos),
          _sep(),
          _infoTile(Icons.phone_outlined, 'Telefon', phone),
          _sep(),
          _infoTile(Icons.email_outlined, 'Email', email),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sep() =>
      const Divider(height: 1, indent: 46, color: AppColors.border);

  Widget _actionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _actionTile(Icons.edit_outlined, 'Profilni tahrirlash',
              AppColors.accent, _showEditSheet),
          const Divider(height: 1, indent: 46, color: AppColors.border),
          _actionTile(Icons.logout_rounded, 'Chiqish',
              AppColors.error, _confirmLogout),
        ],
      ),
    );
  }

  Widget _actionTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      );
}

// ── Edit Bottom Sheet ─────────────────────────────────────────────────────────
class _EditSheet extends StatelessWidget {
  final TextEditingController nameCtrl, posCtrl, phoneCtrl, emailCtrl;
  final VoidCallback onSave;

  const _EditSheet({
    required this.nameCtrl,
    required this.posCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Profilni tahrirlash',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _field('To\'liq ism', nameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _field('Lavozim', posCtrl, Icons.work_outline),
            const SizedBox(height: 12),
            _field('Telefon', phoneCtrl, Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _field('Email', emailCtrl, Icons.email_outlined,
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
      {TextInputType type = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
        ),
      );
}
