import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_dialog.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final s = context.read<AppState>();
    s.addListener(() {
      if (!mounted) return;
      if (s.needPassword || s.needHwid) {
        _showAuth(s);
      } else if (s.result != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResultScreen()),
        );
      } else if (s.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.error!),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _showAuth(AppState s) async {
    final res = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AuthDialog(
        needPassword: s.needPassword,
        needHwid: s.needHwid,
        hwidCount: s.hwidCount,
        authFailed: s.authFailed,
      ),
    );
    if (res != null) {
      await s.submitAuth(password: res['password'], hwid: res['hwid']);
    } else {
      s.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accent2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.3),
                      blurRadius: 40, spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_open_rounded,
                    size: 60, color: Colors.black),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Text('HC Decryptor',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text('Decrypt .hc HTTP Custom configs',
                  style: TextStyle(color: AppTheme.muted, fontSize: 14))
                  .animate().fadeIn(delay: 300.ms),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: s.loading ? null : () => s.pickAndDecrypt(),
                  icon: s.loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(s.loading ? 'Decrypting...' : 'Select .hc File',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ).animate().slideY(begin: 0.3, delay: 400.ms),
              const SizedBox(height: 12),
              if (s.fileName != null)
                Text('Last: ${s.fileName}',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 24),
              Text('code : @HABIBI_1ST  |  @NullptrO',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
