import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'add_employee_sheet.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _api = ApiClient();
  List<dynamic> _users = [];
  List<dynamic> _filteredList = [];
  bool _loading = true;
  String _search = '';
  String _role = 'employee';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _role = prefs.getString('role') ?? 'employee');
    _load();
  }

  void _showAddEmployeeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEmployeeSheet(
        api: _api,
        onCreated: _load,
      ),
    );
  }

  Future<void> _deleteEmployee(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.bg,
        title: const Text('Xodimni o\'chirish'),
        content: Text('Haqiqatan ham $name ni tizimdan o\'chirmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteUser(id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Xodim o\'chirildi'), backgroundColor: AppColors.textSec),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getUsers();
      setState(() {
        _users = res;
        _applyFilter();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filteredList = List.from(_users);
    } else {
      final q = _search.toLowerCase();
      _filteredList = _users.where((u) {
        final name = (u['full_name'] ?? '').toLowerCase();
        final dept = (u['department_name'] ?? '').toLowerCase();
        final pos = (u['position'] ?? '').toLowerCase();
        return name.contains(q) || dept.contains(q) || pos.contains(q);
      }).toList();
    }
  }

  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final u in _filteredList) {
      final dept = u['department_name'] ?? 'Boshqa';
      map.putIfAbsent(dept, () => []).add(u);
    }
    return map;
  }

  void _showDetail(Map user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        isDark: isDark,
        isAdmin: _role == 'admin',
        onDelete: () {
          Navigator.pop(context);
          _deleteEmployee(user['id'], user['full_name']);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final accentLight =
        isDark ? AppColors.darkAccent.withOpacity(0.15) : AppColors.accentLight;
    final accentText = isDark ? AppColors.darkAccent : AppColors.accent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Row(
          children: [
            const Text('Xodimlar'),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${_users.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentText)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 22),
              onPressed: _showAddEmployeeSheet,
              tooltip: 'Xodim qo\'shish',
            ),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Column(
            children: [
              Divider(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() {
                    _search = v;
                    _applyFilter();
                  }),
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ism, bo\'lim yoki lavozim...',
                    hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.darkTextSec
                            : AppColors.textHint),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface2
                        : AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.accent,
                          width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _filteredList.isEmpty
              ? _empty(isDark)
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8, top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextSec
                                        : AppColors.textSec,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${entry.value.length})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSec
                                          : AppColors.textHint),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value
                              .map((u) => _userTile(u, isDark)),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _userTile(Map u, bool isDark) {
    final name = u['full_name'] ?? 'Noma\'lum';
    final pos = u['position'] ?? '';
    final role = u['role'] ?? 'employee';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final roleColor = role == 'admin'
        ? AppColors.error
        : role == 'manager'
            ? AppColors.accent
            : AppColors.success;
    final roleLabel = role == 'admin'
        ? 'Admin'
        : role == 'manager'
            ? 'Manager'
            : 'Xodim';

    return GestureDetector(
      onTap: () => _showDetail(Map<String, dynamic>.from(u)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.textPrimary)),
                  if (pos.isNotEmpty)
                    Text(pos,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSec
                                : AppColors.textSec)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(roleLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: roleColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(bool isDark) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 52,
                color:
                    isDark ? AppColors.darkTextSec : AppColors.textHint),
            const SizedBox(height: 12),
            Text('Xodimlar topilmadi',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSec
                        : AppColors.textSec)),
          ],
        ),
      );
}

// ── User Detail Sheet ─────────────────────────────────────────────────────────
class _UserDetailSheet extends StatelessWidget {
  final Map user;
  final bool isDark;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _UserDetailSheet({
    required this.user,
    required this.isDark,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] ?? 'Noma\'lum';
    final role = user['role'] ?? 'employee';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final roleColor = role == 'admin'
        ? AppColors.error
        : role == 'manager'
            ? AppColors.accent
            : AppColors.success;
    final roleLabel = role == 'admin'
        ? '👑 Admin'
        : role == 'manager'
            ? '🏢 Manager'
            : '👤 Xodim';

    final bgColor = isDark ? AppColors.darkSurface : AppColors.bg;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkText : AppColors.textPrimary;
    final subColor = isDark ? AppColors.darkTextSec : AppColors.textSec;
    final hintColor = isDark ? AppColors.darkTextSec : AppColors.textHint;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
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
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.accent.withOpacity(0.2)
                  : AppColors.accentLight,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(initials.isEmpty ? '?' : initials,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.accent)),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: roleColor.withOpacity(isDark ? 0.4 : 0.3)),
            ),
            child: Text(roleLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: roleColor)),
          ),
          const SizedBox(height: 20),
          _infoRow(Icons.business_outlined, 'Bo\'lim',
              user['department_name'] ?? '—', hintColor, subColor, textColor),
          _infoRow(Icons.work_outline, 'Lavozim',
              user['position'] ?? '—', hintColor, subColor, textColor),
          _infoRow(Icons.person_outline, 'Username',
              user['username'] ?? '—', hintColor, subColor, textColor),
          if ((user['phone'] ?? '').isNotEmpty)
            _infoRow(Icons.phone_outlined, 'Telefon', user['phone'],
                hintColor, subColor, textColor),
          if ((user['email'] ?? '').isNotEmpty)
            _infoRow(Icons.email_outlined, 'Email', user['email'],
                hintColor, subColor, textColor),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Xodimni o\'chirish'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
          Color hintColor, Color subColor, Color textColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hintColor),
            const SizedBox(width: 12),
            Text('$label: ',
                style: TextStyle(fontSize: 13, color: subColor)),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
            ),
          ],
        ),
      );
}
