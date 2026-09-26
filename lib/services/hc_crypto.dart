import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cg;

class HCException implements Exception {
  final String message;
  HCException(this.message);
  @override
  String toString() => message;
}

// ==================== CONSTANTS ====================
final Uint8List PKG = Uint8List.fromList(utf8.encode('xyz.easypro.httpcustom'));
final Uint8List OUTER_AAD = Uint8List.fromList(utf8.encode('HCX1|xyz.easypro.httpcustom|1'));
final Uint8List OUTER_SEED = Uint8List.fromList(utf8.encode('hc-envelope-seal-v1 xyz.easypro.httpcustom'));
final Uint8List OUTER_SALT = Uint8List.fromList(utf8.encode('hc-envelope-seal-salt-v1'));
final Uint8List OUTER_INFO = Uint8List.fromList(utf8.encode('hc-envelope-seal-info-v1'));
final Uint8List OUTER_KEY_V3 = _hexToBytes(
    '88702df6ae8c089c9478b8cd2bd3f30961b3574a58063d024bdc50f6b779e26f');
final Uint8List N7_HMAC_KEY = _hexToBytes(
    '9ba7ff3baf33db7aad807a86574b7ca55bef2f048ead51f3a1fe0cff389db3b3');
final Uint8List C0_PREFIX = _hexToBytes(
    '95dd433d7e4a0be02d55cc62553edcfc8f077fe780be5a7da7f861c2558dc181'
    '38cabb40b2f81a5a30b11a97cbcf0fed755aa8c2b5495e9bc0c1902077a4cd92');

Uint8List _hexToBytes(String s) {
  final r = Uint8List(s.length ~/ 2);
  for (var i = 0; i < r.length; i++) {
    r[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return r;
}

Uint8List _c0(Uint8List data) {
  final b = BytesBuilder()..add(C0_PREFIX)..add(data);
  return Uint8List.fromList(sha256.convert(b.toBytes()).bytes);
}

Uint8List _hkdf(Uint8List ikm, Uint8List salt, Uint8List info, [int length = 32]) {
  final prk = Hmac(sha256, salt).convert(ikm).bytes;
  final out = <int>[];
  var prev = <int>[];
  var ctr = 1;
  while (out.length < length) {
    final data = <int>[...prev, ...info, ctr];
    prev = Hmac(sha256, prk).convert(data).bytes;
    out.addAll(prev);
    ctr++;
  }
  return Uint8List.fromList(out.sublist(0, length));
}

// ==================== ChaCha20 / HChaCha20 ====================
int _rotl32(int v, int n) {
  v &= 0xFFFFFFFF;
  return ((v << n) | (v >> (32 - n))) & 0xFFFFFFFF;
}

int _u32(int v) => v & 0xFFFFFFFF;

void _qr(List<int> s, int a, int b, int c, int d) {
  s[a] = _u32(s[a] + s[b]); s[d] = _rotl32(s[d] ^ s[a], 16);
  s[c] = _u32(s[c] + s[d]); s[b] = _rotl32(s[b] ^ s[c], 12);
  s[a] = _u32(s[a] + s[b]); s[d] = _rotl32(s[d] ^ s[a], 8);
  s[c] = _u32(s[c] + s[d]); s[b] = _rotl32(s[b] ^ s[c], 7);
}

List<int> _rounds(List<int> s) {
  for (var i = 0; i < 10; i++) {
    _qr(s, 0, 4, 8, 12); _qr(s, 1, 5, 9, 13);
    _qr(s, 2, 6, 10, 14); _qr(s, 3, 7, 11, 15);
    _qr(s, 0, 5, 10, 15); _qr(s, 1, 6, 11, 12);
    _qr(s, 2, 7, 8, 13); _qr(s, 3, 4, 9, 14);
  }
  return s;
}

Uint8List _hchacha20(Uint8List key, Uint8List nonce16) {
  final sigma = _u32list('expand 32-byte k');
  final k = _leWords(key);
  final n = _leWords(nonce16);
  final s = [...sigma, ...k, ...n];
  _rounds(s);
  return _wordsToLE([s[0], s[1], s[2], s[3], s[12], s[13], s[14], s[15]]);
}

Uint8List _chachaBlock(Uint8List key, Uint8List nonce12, int ctr) {
  final sigma = _u32list('expand 32-byte k');
  final k = _leWords(key);
  final n = _leWords(nonce12);
  final init = <int>[...sigma, ...k, _u32(ctr), ...n];
  final s = List<int>.from(init);
  _rounds(s);
  final out = List<int>.generate(16, (i) => _u32(s[i] + init[i]));
  return _wordsToLE(out);
}

Uint8List _streamXor(Uint8List data, Uint8List key, Uint8List nonce12, [int ctr = 1]) {
  final out = Uint8List(data.length);
  for (var bn = 0; bn * 64 < data.length; bn++) {
    final st = _chachaBlock(key, nonce12, ctr + bn);
    final off = bn * 64;
    final end = (off + 64 > data.length) ? data.length : off + 64;
    for (var i = off; i < end; i++) out[i] = data[i] ^ st[i - off];
  }
  return out;
}

List<int> _u32list(String s) {
  final b = Uint8List.fromList(utf8.encode(s));
  final out = <int>[];
  for (var i = 0; i < b.length; i += 4) {
    out.add(b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24));
  }
  return out;
}

List<int> _leWords(Uint8List b) {
  final out = <int>[];
  for (var i = 0; i < b.length; i += 4) {
    out.add(b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24));
  }
  return out;
}

Uint8List _wordsToLE(List<int> words) {
  final out = Uint8List(words.length * 4);
  for (var i = 0; i < words.length; i++) {
    final w = _u32(words[i]);
    out[i * 4] = w & 0xFF;
    out[i * 4 + 1] = (w >> 8) & 0xFF;
    out[i * 4 + 2] = (w >> 16) & 0xFF;
    out[i * 4 + 3] = (w >> 24) & 0xFF;
  }
  return out;
}

// ==================== XChaCha20-Poly1305 ====================
final _xchacha = cg.Xchacha20.poly1305Aead();

Future<Uint8List> _xdec(Uint8List key, Uint8List nonce, Uint8List aad, Uint8List ctTag) async {
  if (key.length != 32 || nonce.length != 24 || ctTag.length < 16) {
    throw HCException('bad XChaCha20 input');
  }
  final ct = ctTag.sublist(0, ctTag.length - 16);
  final tag = ctTag.sublist(ctTag.length - 16);
  try {
    final box = cg.SecretBox(ct, nonce: nonce, mac: cg.Mac(tag));
    final clear = await _xchacha.decrypt(box, secretKey: cg.SecretKey(key), aad: aad);
    return Uint8List.fromList(clear);
  } catch (e) {
    throw HCException('XChaCha20-Poly1305 auth failed');
  }
}

// ==================== Argon2id ====================
Future<Uint8List> _argon2id(Uint8List pw, Uint8List salt, int ops, int mem, [int length = 32]) async {
  if (salt.length != 16) throw HCException('Argon2 salt must be 16 bytes');
  final algo = cg.Argon2id(
    memory: mem ~/ 1024,
    parallelism: 1,
    iterations: ops,
    hashLength: length,
  );
  final k = await algo.deriveKey(
    secretKey: cg.SecretKey(pw),
    nonce: salt,
  );
  return Uint8List.fromList(await k.extractBytes());
}

// ==================== Outer Envelope ====================
Uint8List _outerKey() => _hkdf(_c0(OUTER_SEED), OUTER_SALT, OUTER_INFO);

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
  return true;
}

Iterable<Uint8List> _carriers(Uint8List data) sync* {
  final seen = <String>{};
  var cur = data;
  for (var i = 0; i < 6; i++) {
    final key = base64.encode(cur);
    if (seen.contains(key)) return;
    seen.add(key);
    if (cur.length >= 40) yield cur;
    String text;
    try {
      text = utf8.decode(cur);
    } on FormatException {
      return;
    }
    final next = Uint8List(text.length);
    for (var j = 0; j < text.length; j++) {
      final cp = text.codeUnitAt(j);
      if (cp > 0xFF) return;
      next[j] = cp;
    }
    if (_eq(next, cur)) return;
    cur = next;
  }
}

Future<Map<String, dynamic>> _openOuter(Uint8List data) async {
  final key = _outerKey();
  Object? lastErr;
  for (final logical in _carriers(data)) {
    if (logical.length < 40) continue;
    // Standard outer
    try {
      final pt = await _xdec(key, logical.sublist(0, 24), OUTER_AAD, logical.sublist(24));
      final v = jsonDecode(utf8.decode(pt));
      if (v is Map<String, dynamic>) return v;
    } catch (e) { lastErr = e; }
    // V3 outer
    try {
      final nonce = logical.sublist(0, 24);
      final ct = logical.sublist(24, logical.length - 16);
      final sub = _hchacha20(OUTER_KEY_V3, nonce.sublist(0, 16));
      final n12 = Uint8List.fromList([0, 0, 0, 0, ...nonce.sublist(16)]);
      final pt = _streamXor(ct, sub, n12, 1);
      final v = jsonDecode(utf8.decode(pt));
      if (v is Map<String, dynamic> && v['a'] == 'HCCFG') return v;
    } catch (e) { lastErr = e; }
  }
  throw HCException('Not a valid HTTP Custom envelope: $lastErr');
}

// ==================== Env Validation & Derivation ====================
int _validate(Map<String, dynamic> env) {
  if (env['a'] != 'HCCFG') throw HCException("Bad magic: ${env['a']}");
  final schema = int.tryParse('${env['b']}') ?? 0;
  String expC, expK;
  if (schema == 1) { expC = 'XCHACHA20P1305'; expK = 'NATIVE-HKDF-SHA256'; }
  else if (schema == 2 || schema == 5 || schema == 7) { expC = 's1'; expK = 'h1'; }
  else throw HCException('Unsupported schema b=$schema');
  if (env['c'] != expC) throw HCException("Bad cipher: ${env['c']}");
  if (env['d'] != expK) throw HCException("Bad KDF: ${env['d']}");
  final e = env['e'];
  if (e != 'n1' && e != 'n2' && e != 'n7' && e != 'n8') throw HCException("Bad schedule: $e");
  return schema;
}

Uint8List _features(Map<String, dynamic> env) {
  final f = env['f'];
  if (f is! List || !f.every((x) => x is String)) throw HCException('Bad features');
  return Uint8List.fromList(utf8.encode(f.join(',')));
}

Uint8List? _nBytes(Map<String, dynamic> env) {
  final n = env['n'];
  if (n == null) return null;
  final ni = int.tryParse('$n');
  if (ni == null || ni < 0) throw HCException('Bad n value');
  if ('$ni' != '$n') throw HCException('Bad n value');
  return Uint8List.fromList(utf8.encode('$ni'));
}

Uint8List _normHwid(String hwid) {
  final v = hwid.trim();
  if (v.length != 32) throw HCException('HWID must be 32 chars');
  for (final c in v.split('')) {
    if (!'0123456789abcdefABCDEFhH'.contains(c)) throw HCException('Bad HWID chars');
  }
  return Uint8List.fromList(utf8.encode(v.toUpperCase()));
}

Uint8List _envKey(Map<String, dynamic> env) {
  final g = env['g'];
  if (g is! String) throw HCException('Bad inner key');
  final k = _hexToBytes(g);
  if (k.length != 32) throw HCException('Inner key must be 32 bytes');
  return k;
}

Future<(Uint8List, Uint8List)> _pwKdf(Map<String, dynamic> env, String password, Uint8List ekey) async {
  final kdf = env['k'];
  if (kdf != 'ARGON2ID13' && kdf != 'a1') throw HCException('Bad pw KDF: $kdf');
  final ops = int.tryParse('${env['l']}');
  final mem = int.tryParse('${env['m']}');
  if (ops == null || mem == null) throw HCException('Bad Argon2 params');
  final pk = await _argon2id(Uint8List.fromList(utf8.encode(password)), ekey.sublist(0, 16), ops, mem);
  final aad = Uint8List.fromList(utf8.encode('|1|ARGON2ID13|$ops|$mem'));
  return (pk, aad);
}

bool _hFlag(Map<String, dynamic> env) {
  final h = env['h'] ?? 0;
  if (h != 0 && h != 1 && h != false && h != true) throw HCException('Bad h flag: $h');
  return h == 1 || h == true;
}

Uint8List _transcript(Map<String, dynamic> env, Uint8List ekey,
    [Uint8List? hwidB, bool n7Mode = false]) {
  final feats = _features(env);
  final nb = _nBytes(env);
  final vb = Uint8List.fromList(utf8.encode('1'));
  final t = <int>[];
  t.addAll(utf8.encode('HCCFG\x00'));
  t.addAll(PKG); t.add(0);
  t.addAll(vb); t.add(0);
  t.addAll(feats); t.add(0);
  if (nb != null) { t.addAll(nb); t.add(0); }
  if (hwidB != null) { t.addAll(utf8.encode('hwid\x00')); t.addAll(hwidB); t.add(0); }
  t.addAll(ekey);
  if (n7Mode) {
    final data = <int>[0xd3, ...C0_PREFIX.sublist(0, 32), ...t];
    return Uint8List.fromList(Hmac(sha256, N7_HMAC_KEY).convert(data).bytes);
  }
  return _c0(Uint8List.fromList(t));
}

Future<(Uint8List, Uint8List)> _derive(
    Map<String, dynamic> env, String? password, String? hwid) async {
  final sched = env['e'] as String;
  final schema = _validate(env);
  final ekey = _envKey(env);
  final feats = _features(env);
  final nb = _nBytes(env);
  final vb = Uint8List.fromList(utf8.encode('1'));

  final isHwid = sched == 'n2' || sched == 'n8';
  final isN7 = sched == 'n7' || sched == 'n8';

  if (isHwid && hwid == null) {
    final o = env['o'];
    final cnt = (o is List) ? o.length : 0;
    throw HCException('HWID_REQUIRED:$cnt');
  }

  final hwidB = isHwid ? _normHwid(hwid!) : null;
  var ikm = _transcript(env, ekey, hwidB, isN7);
  final protected = _hFlag(env);
  var aadProt = <int>[0x7c, 0x30]; // '|0'

  if (protected) {
    if (password == null) {
      throw HCException(isHwid ? 'HWID_PASSWORD_REQUIRED' : 'PASSWORD_REQUIRED');
    }
    final (pk, prot) = await _pwKdf(env, password, ekey);
    aadProt = prot.toList();
    ikm = Uint8List.fromList([...ikm, ...pk]);
  }

  final schedB = utf8.encode(sched);
  final info = <int>[];
  info.addAll(utf8.encode('app-config|'));
  info.addAll(schedB); info.add(0x7c); // |
  info.addAll(PKG); info.add(0x7c);
  info.addAll(vb); info.add(0x7c);
  info.addAll(feats);
  if (nb != null) { info.add(0x7c); info.addAll(nb); }
  if (hwidB != null) { info.addAll(utf8.encode('|hwid|')); info.addAll(hwidB); }
  final skey = _hkdf(ikm, ekey, Uint8List.fromList(info));

  final aad = <int>[];
  aad.addAll(utf8.encode('HCCFG|$schema|XCHACHA20P1305|NATIVE-HKDF-SHA256|'));
  aad.addAll(schedB); aad.add(0x7c);
  aad.addAll(PKG); aad.add(0x7c);
  aad.addAll(vb); aad.add(0x7c);
  aad.addAll(feats);
  aad.addAll(aadProt);
  if (nb != null) { aad.add(0x7c); aad.addAll(nb); }
  final aadB = Uint8List.fromList(aad);

  if (isHwid) {
    final slots = env['o'];
    if (slots is! List || slots.isEmpty) throw HCException('No HWID key slots');
    for (final slot in slots) {
      if (slot is! Map) continue;
      try {
        final nonce = _hexToBytes(slot['a'] as String);
        final ct = _hexToBytes(slot['b'] as String);
        final aadW = Uint8List.fromList([...aadB, 0, 0x77]); // \x00w
        final sk = await _xdec(skey, nonce, aadW, ct);
        if (sk.length == 32) return (sk, aadB);
      } catch (_) { continue; }
    }
    throw HCException('AUTH_FAILED');
  }
  return (skey, aadB);
}

// ==================== HPC1 Parser ====================
class _R {
  final Uint8List d; int o = 0;
  _R(this.d);
  Uint8List take(int n) {
    if (o + n > d.length) throw HCException('Truncated HPC1');
    final v = d.sublist(o, o + n); o += n; return v;
  }
  int u32() {
    final b = take(4);
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }
  int u64() {
    final b = take(8);
    var v = 0;
    for (var i = 0; i < 8; i++) v = (v << 8) | b[i];
    return v;
  }
  String txt() {
    final s = u32();
    if (s > 16 * 1024 * 1024) throw HCException('HPC1 string too long');
    return utf8.decode(take(s));
  }
}

Map<String, dynamic> _parseHpc1(Uint8List data, String? label) {
  final r = _R(data);
  if (String.fromCharCodes(r.take(4)) != 'HPC1') throw HCException('Not HPC1');
  if (r.u32() != 11) throw HCException('Bad HPC1 field count');
  final name = r.txt(), proto = r.txt(), host = r.txt();
  final port = r.u32();
  final user = r.txt(), pw = r.txt(), payload = r.txt();
  final optsTxt = r.txt(); final flags = r.u32(); final updated = r.u64(); final mode = r.txt();
  if (r.o != data.length) throw HCException('HPC1 trailing bytes');
  dynamic opts;
  try { opts = optsTxt.isNotEmpty ? jsonDecode(optsTxt) : {}; }
  catch (_) { opts = optsTxt; }
  final res = <String, dynamic>{
    'name': name, 'protocol': proto, 'host': host, 'port': port,
    'username': user, 'password': pw, 'payload': payload,
    'options': opts, 'flags': flags, 'updated_at_ms': updated, 'mode': mode,
  };
  if (label != null) res['label'] = label;
  return res;
}

Future<Uint8List> _decSection(Map<String, dynamic> sec, Uint8List key, Uint8List aadBase) async {
  final label = sec['a'];
  if (label is! String || label.isEmpty) throw HCException('Bad section');
  final nonce = _hexToBytes(sec['b'] as String);
  final ct = _hexToBytes(sec['c'] as String);
  final aad = Uint8List.fromList([...aadBase, 0, ...utf8.encode(label)]);
  return _xdec(key, nonce, aad, ct);
}

Future<Uint8List?> _decSidecar(Map<String, dynamic> sec, Uint8List key, Uint8List aadBase) async {
  final nested = sec['d'];
  if (nested == null) return null;
  if (nested is! Map) throw HCException('Bad sidecar');
  final label = (sec['a'] ?? '') as String;
  final nonce = _hexToBytes(nested['a'] as String);
  final ct = _hexToBytes(nested['b'] as String);
  final aad = Uint8List.fromList([...aadBase, 0, ...utf8.encode('$label:x')]);
  return _xdec(key, nonce, aad, ct);
}

Future<Uint8List> _decHpr1(Uint8List data, Uint8List key, Uint8List aadBase, String? label) async {
  if (data.length < 44 || String.fromCharCodes(data.sublist(0, 4)) != 'HPR1') return data;
  final nonce = data.sublist(4, 28);
  final ctTag = data.sublist(28);
  final tag = utf8.encode(label ?? 's0');
  try {
    final aad = Uint8List.fromList([...aadBase, 0, ...tag, ...utf8.encode(':r')]);
    return await _xdec(key, nonce, aad, ctTag);
  } catch (_) {
    final sub = _hchacha20(key, nonce.sublist(0, 16));
    final n12 = Uint8List.fromList([0, 0, 0, 0, ...nonce.sublist(16)]);
    return _streamXor(ctTag.sublist(0, ctTag.length - 16), sub, n12, 1);
  }
}

List<Map<String, dynamic>> _secList(dynamic v) {
  if (v is List && v.every((x) => x is Map)) {
    return v.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }
  if (v is Map && v.values.every((x) => x is Map)) {
    return v.values.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }
  throw HCException('Bad section collection');
}

// ==================== Main Decrypt ====================
const Map<String, String> PKM = {
  'a': 'accessMode', 'c': 'expiryEnabled', 'd': 'expiryTime',
  'e': 'noteEnabled', 'f': 'hwidLockEnabled', 'g': 'hwids',
  'h': 'loginHwidEnabled', 'j': 'loginHwidAuthorizationRequired',
  'l': 'mobileDataOnly', 'm': 'blockRoot', 'o': 'providerLockEnabled',
  'p': 'providerCodes', 'v': 'note',
};

const Map<int, String> HC_VERSIONS = {
  756: '7.9.21', 759: '7.9.24', 766: '7.9.28', 789: '7.10.7',
  810: '7.10.12', 831: '7.10.19', 848: '7.10.25', 859: '7.11.1', 864: '7.11.8',
};

String _ver(dynamic n) {
  final i = int.tryParse('$n');
  if (i == null) return 'build-$n';
  return HC_VERSIONS[i] != null ? '${HC_VERSIONS[i]} ($i)' : 'build-$i';
}

Map<String, dynamic> _normProt(dynamic p) {
  if (p is! Map) return {};
  return p.map((k, v) => MapEntry(PKM['$k'] ?? '$k', v));
}

Future<Map<String, dynamic>> decryptHC(Uint8List data,
    {String? password, String? hwid}) async {
  final env = await _openOuter(data);
  final (skey, aadBase) = await _derive(env, password, hwid);

  final mainSec = env['i'];
  if (mainSec is! Map) throw HCException('Missing main section');
  final mainPt = await _decSection(mainSec.cast<String, dynamic>(), skey, aadBase);
  dynamic mainCfg;
  try {
    mainCfg = jsonDecode(utf8.decode(mainPt));
  } catch (_) {
    throw HCException('Main section not JSON');
  }

  final profiles = <Map<String, dynamic>>[];
  final others = <Map<String, dynamic>>[];

  final jList = env['j'];
  if (jList != null) {
    for (final sec in _secList(jList)) {
      var pt = await _decSection(sec, skey, aadBase);
      final label = sec['a'] as String?;
      if (pt.length >= 4 && String.fromCharCodes(pt.sublist(0, 4)) == 'HPR1') {
        pt = await _decHpr1(pt, skey, aadBase, label);
      }
      final sidecar = await _decSidecar(sec, skey, aadBase);
      if (pt.length >= 4 && String.fromCharCodes(pt.sublist(0, 4)) == 'HPC1') {
        final prof = _parseHpc1(pt, label);
        if (sidecar != null) {
          try { prof['custom_payload_sidecar'] = utf8.decode(sidecar); }
          catch (_) { prof['custom_payload_sidecar_hex'] = sidecar.map((b) => b.toRadixString(16).padLeft(2, '0')).join(); }
        }
        profiles.add(prof);
      } else {
        dynamic dec;
        try {
          final s = utf8.decode(pt);
          if (s.startsWith('{') || s.startsWith('[')) dec = jsonDecode(s);
          else dec = s;
        } catch (_) {
          dec = {'hex': pt.map((b) => b.toRadixString(16).padLeft(2, '0')).join()};
        }
        others.add({'label': label, 'content': dec});
      }
    }
  }

  final clean = <Map<String, dynamic>>[];
  for (final p in profiles) {
    final cp = <String, dynamic>{
      'name': p['name'] ?? '', 'protocol': p['protocol'] ?? '',
      'host': p['host'] ?? '', 'port': p['port'] ?? 0,
      'username': p['username'] ?? '', 'password': p['password'] ?? '',
      'mode': p['mode'] ?? '',
    };
    final opts = p['options'];
    if (opts is Map) opts.forEach((k, v) => cp['$k'] = v);
    if (p['payload'] != null && '${p['payload']}'.isNotEmpty) cp['payload'] = p['payload'];
    if (p['custom_payload_sidecar'] != null) cp['custom_payload_sidecar'] = p['custom_payload_sidecar'];
    if (p['custom_payload_sidecar_hex'] != null) cp['custom_payload_sidecar_hex'] = p['custom_payload_sidecar_hex'];
    clean.add(cp);
  }

  final result = <String, dynamic>{
    'app_version': _ver(env['n']),
    'config': clean,
    'protections': _normProt(mainCfg is Map ? mainCfg['g'] : null),
  };
  if (others.isNotEmpty) result['other_sections'] = others;
  return result;
}
