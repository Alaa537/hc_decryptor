import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AuthDialog extends StatefulWidget {
  final bool needPassword;
  final bool needHwid;
  final int hwidCount;
  final bool authFailed;
  const AuthDialog({
    super.key,
    required this.needPassword,
    required this.needHwid,
    required this.hwidCount,
    required this.authFailed,
  });
  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _pw = TextEditingController();
  final _hwid = TextEditingController();
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(widget.authFailed ? Icons.error_outline : Icons.lock_outline,
              color: widget.authFailed ? AppTheme.danger : AppTheme.accent),
          const SizedBox(width: 10),
          Text(widget.authFailed ? 'Authentication Failed' : 'Protected File'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.authFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Wrong credentials. Try again.',
                    style: TextStyle(color: AppTheme.danger, fontSize: 13)),
              ),
            if (widget.needPassword) ...[
              TextField(
                controller: _pw,
                obscureText: !_show,
                style: const TextStyle(color: AppTheme.text),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.muted),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.muted),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.needHwid) ...[
              if (widget.hwidCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${widget.hwidCount} authorized HWID(s)',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                ),
              TextField(
                controller: _hwid,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FhH]')),
                  LengthLimitingTextInputFormatter(32),
                ],
                style: const TextStyle(color: AppTheme.text, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'HWID (32 hex chars)',
                  labelStyle: TextStyle(color: AppTheme.muted),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
        ElevatedButton(
          onPressed: () {
            final out = <String, String>{};
            if (widget.needPassword && _pw.text.isNotEmpty) out['password'] = _pw.text;
            if (widget.needHwid && _hwid.text.isNotEmpty) out['hwid'] = _hwid.text;
            Navigator.pop(context, out);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
