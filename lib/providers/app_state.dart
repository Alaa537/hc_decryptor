import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/hc_crypto.dart';

class AppState extends ChangeNotifier {
  Uint8List? fileBytes;
  String? fileName;
  Map<String, dynamic>? result;
  String? error;
  bool loading = false;
  bool needPassword = false;
  bool needHwid = false;
  bool authFailed = false;
  int hwidCount = 0;

  String? _password;
  String? _hwid;

  String get resultJson =>
      result == null ? '' : const JsonEncoder.withIndent('  ').convert(result);

  Future<void> pickAndDecrypt() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    if (f.bytes == null) {
      error = 'Failed to read file';
      notifyListeners();
      return;
    }
    fileBytes = f.bytes;
    fileName = f.name;
    _password = null;
    _hwid = null;
    await _attempt();
  }

  Future<void> submitAuth({String? password, String? hwid}) async {
    if (password != null) _password = password;
    if (hwid != null) _hwid = hwid;
    await _attempt();
  }

  Future<void> _attempt() async {
    if (fileBytes == null) return;
    loading = true;
    error = null;
    needPassword = false;
    needHwid = false;
    authFailed = false;
    result = null;
    notifyListeners();

    try {
      final r = await decryptHC(fileBytes!, password: _password, hwid: _hwid);
      result = r;
    } on HCException catch (e) {
      final msg = e.message;
      if (msg == 'PASSWORD_REQUIRED') {
        needPassword = true;
      } else if (msg.startsWith('HWID_REQUIRED')) {
        needHwid = true;
        hwidCount = int.tryParse(msg.split(':').last) ?? 0;
      } else if (msg == 'HWID_PASSWORD_REQUIRED') {
        needPassword = true;
        needHwid = true;
      } else if (msg == 'AUTH_FAILED') {
        authFailed = true;
        needPassword = true;
        needHwid = true;
      } else {
        error = msg;
      }
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    fileBytes = null;
    fileName = null;
    result = null;
    error = null;
    needPassword = false;
    needHwid = false;
    authFailed = false;
    _password = null;
    _hwid = null;
    notifyListeners();
  }
}
