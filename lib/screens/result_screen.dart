import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/config_card.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.result!;
    final configs = (r['config'] as List).cast<Map<String, dynamic>>();
    final version = r['app_version'] ?? '';
    final prot = r['protections'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decrypted Config'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy JSON',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: s.resultJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent.withOpacity(0.15), AppTheme.accent2.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('App Version', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text('$version', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (s.fileName != null) ...[
                  const SizedBox(height: 8),
                  Text('File: ${s.fileName}',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                ],
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.dns_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text('Configurations (${configs.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ...configs.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ConfigCard(data: e.value, index: e.key),
              )),
          if (prot.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.shield_outlined, color: AppTheme.accent2, size: 20),
              const SizedBox(width: 8),
              const Text('Protections',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: prot.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text('${e.key}',
                            style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                      ),
                      Expanded(
                        child: SelectableText('${e.value}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
