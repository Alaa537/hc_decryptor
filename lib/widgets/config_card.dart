import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class ConfigCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  const ConfigCard({super.key, required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final fields = <MapEntry<String, String>>[];
    const order = [
      'name', 'protocol', 'mode', 'host', 'port',
      'username', 'password', 'payload',
      'custom_payload_sidecar', 'custom_payload_sidecar_hex',
    ];
    for (final k in order) {
      if (data.containsKey(k) && '${data[k]}'.isNotEmpty && '${data[k]}' != 'null') {
        fields.add(MapEntry(k, '${data[k]}'));
      }
    }
    // extra options
    for (final e in data.entries) {
      if (order.contains(e.key)) continue;
      if ('${e.value}'.isEmpty) continue;
      fields.add(MapEntry(e.key, '${e.value}'));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(color: Colors.black,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${data['name'] ?? 'Config ${index + 1}'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: fields.map((e) => _row(context, e.key, e.value)).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.1);
  }

  Widget _row(BuildContext context, String k, String v) {
    final isSensitive = k == 'password';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(k, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(v,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: k == 'password' || k == 'host' ? 'monospace' : null,
                  color: k == 'payload' ? AppTheme.accent : AppTheme.text,
                )),
          ),
          if (v.length > 4)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 16,
              icon: Icon(Icons.copy_rounded, color: AppTheme.muted),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: v));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$k copied'),
                      duration: const Duration(milliseconds: 800),
                      behavior: SnackBarBehavior.floating),
                );
              },
            ),
        ],
      ),
    );
  }
}
