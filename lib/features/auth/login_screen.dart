import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Username kiriting');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Parol kiriting');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.login(username, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', res['access_token']);
      await prefs.setInt('user_id', res['user_id']);
      await prefs.setString('username', res['username']);
      await prefs.setString('role', res['role']);
      if (res['full_name'] != null) {
        await prefs.setString('full_name', res['full_name']);
      }
      if (res['department_name'] != null) {
        await prefs.setString('department_name', res['department_name']);
      }
      if (res['department_id'] != null) {
        await prefs.setInt('department_id', res['department_id']);
      }

      widget.onLogin();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        if (status == 401) {
          _error = 'Username yoki parol noto\'g\'ri';
        } else if (status != null) {
          _error = 'Server xatosi ($status)';
        } else {
          _error = 'Serverga ulanib bo\'lmadi. Backend ishga tushganini tekshiring.';
        }
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Kutilmagan xatolik. Qayta urinib ko\'ring.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = BankAIApp.of(context);
    final isDark = root?.isDark ?? false;
    final textPrimary = isDark ? AppColors.darkText : AppColors.textPrimary;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.textSec;
    final textHint = isDark ? AppColors.darkTextSec : AppColors.textHint;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final accentIconColor = isDark ? AppColors.darkAccent : AppColors.accent;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: bgColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkAccent.withOpacity(0.15)
                          : AppColors.accentLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.business_rounded,
                      color: accentIconColor,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isDark
                        ? 'Yorug\' rejimga o\'tish'
                        : 'Tungi rejimga o\'tish',
                    icon: Icon(
                      isDark
                          ? Icons.wb_sunny_outlined
                          : Icons.dark_mode_outlined,
                      color: textSec,
                    ),
                    onPressed: () => BankAIApp.of(context)?.toggleTheme(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Tashkilot AI',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Boshqaruv tizimiga kiring',
                style: TextStyle(fontSize: 15, color: textSec),
              ),
              const SizedBox(height: 40),

              // Username
              _label('Username', textPrimary),
              const SizedBox(height: 8),
              TextField(
                controller: _userCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'admin, manager1, employee1...',
                  hintStyle: TextStyle(color: textHint),
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      size: 20, color: textHint),
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 16),

              // Parol
              _label('Parol', textPrimary),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: TextStyle(color: textHint),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      size: 20, color: textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: textHint,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              // Xato
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Kirish tugmasi
              if (_loading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2))
              else
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Kirish'),
                ),

              const SizedBox(height: 32),

              // Demo hisoblar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: accentIconColor),
                        const SizedBox(width: 6),
                        Text('Demo hisoblar',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentIconColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _demoAccount('👑 Admin', 'admin', 'admin123',
                        AppColors.error, textHint),
                    const SizedBox(height: 6),
                    _demoAccount('🏢 Manager', 'manager1', 'pass123',
                        AppColors.accent, textHint),
                    const SizedBox(height: 6),
                    _demoAccount('👤 Xodim', 'employee1', 'pass123',
                        AppColors.success, textHint),
                    const SizedBox(height: 10),
                    Text(
                      'Server: ${ApiClient.baseUrl}',
                      style: TextStyle(
                        fontSize: 11,
                        color: textHint,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color),
      );

  Widget _demoAccount(
      String role, String username, String pass, Color color, Color hintColor) {
    return GestureDetector(
      onTap: () {
        _userCtrl.text = username;
        _passCtrl.text = pass;
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(role,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const Spacer(),
            Text('$username / $pass',
                style: TextStyle(
                    fontSize: 11,
                    color: hintColor,
                    fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Icon(Icons.touch_app_outlined, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
