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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
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
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: AppColors.accent,
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
                      color: AppColors.textSec,
                    ),
                    onPressed: () => BankAIApp.of(context)?.toggleTheme(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Tashkilot AI',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Boshqaruv tizimiga kiring',
                style: TextStyle(fontSize: 15, color: AppColors.textSec),
              ),
              const SizedBox(height: 40),

              // Username
              _label('Username'),
              const SizedBox(height: 8),
              TextField(
                controller: _userCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'admin, manager1, employee1...',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      size: 20, color: AppColors.textHint),
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 16),

              // Parol
              _label('Parol'),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 20, color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textHint,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text('Demo hisoblar',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _demoAccount('👑 Admin', 'admin', 'admin123',
                        AppColors.error),
                    const SizedBox(height: 6),
                    _demoAccount('🏢 Manager', 'manager1', 'pass123',
                        AppColors.accent),
                    const SizedBox(height: 6),
                    _demoAccount('👤 Xodim', 'employee1', 'pass123',
                        AppColors.success),
                    const SizedBox(height: 10),
                    Text(
                      'Server: ${ApiClient.baseUrl}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      );

  Widget _demoAccount(
      String role, String username, String pass, Color color) {
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
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Icon(Icons.touch_app_outlined, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
