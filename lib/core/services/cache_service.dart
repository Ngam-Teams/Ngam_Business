import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry cache yang mengandungi data dan timestamp luput
class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// CacheService — Sistem Caching 2-Lapisan (RAM L1 + Disk L2)
/// Dilengkapi corak "Stale-While-Revalidate" (SWR) untuk pemuatan 0-saat
/// persis seperti Shopee & Instagram.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // ─── L1 CACHE (Memori / RAM - 0ms Synchronous Lookup) ───
  static final Map<String, _CacheEntry> _memoryCache = {};

  static const String _keyPrefix = 'ngam_cache_v1_';
  static const Duration defaultTtl = Duration(hours: 12);

  // ──────────────────────────────────────────────────────────
  // 1. Simpan Data ke Cache (Memory + Disk)
  // ──────────────────────────────────────────────────────────
  static Future<void> set<T>({
    required String key,
    required T data,
    required dynamic Function(T data) toJson,
    Duration ttl = defaultTtl,
  }) async {
    final expiry = DateTime.now().add(ttl);

    // 1. Simpan dalam L1 Memory serta-merta
    _memoryCache[key] = _CacheEntry(data: data, expiry: expiry);

    // 2. Simpan dalam L2 Disk (SharedPreferences) di latar belakang
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'expiry': expiry.millisecondsSinceEpoch,
        'data': toJson(data),
      });
      await prefs.setString('$_keyPrefix$key', payload);
    } catch (e) {
      debugPrint('[CacheService] Ralat menulis disk cache untuk key "$key": $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 2. Dapatkan Data dari Cache (Semak RAM L1, kemudian Disk L2)
  // ──────────────────────────────────────────────────────────
  static Future<T?> get<T>({
    required String key,
    required T Function(dynamic json) fromJson,
  }) async {
    // 1. Semak L1 Memory dahulu (0 ms)
    final mem = _memoryCache[key];
    if (mem != null && !mem.isExpired) {
      return mem.data as T?;
    }

    // 2. Semak L2 Disk jika tiada di memory
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$key');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final expiryMs = decoded['expiry'] as int? ?? 0;
        final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);

        // Jika tamat tempoh, padam cache lama
        if (DateTime.now().isAfter(expiry)) {
          unawaited(prefs.remove('$_keyPrefix$key'));
          _memoryCache.remove(key);
          return null;
        }

        final parsed = fromJson(decoded['data']);
        // Muat naik semula ke memory L1 untuk akses seterusnya
        _memoryCache[key] = _CacheEntry(data: parsed, expiry: expiry);
        return parsed;
      }
    } catch (e) {
      debugPrint('[CacheService] Ralat membaca disk cache untuk key "$key": $e');
    }

    return null;
  }

  // ──────────────────────────────────────────────────────────
  // 3. Akses Segera L1 Memory Cache (Synchronous - Tiada async)
  // ──────────────────────────────────────────────────────────
  static T? getMemory<T>(String key) {
    final mem = _memoryCache[key];
    if (mem != null && !mem.isExpired) {
      return mem.data as T?;
    }
    return null;
  }

  static void setMemory<T>(String key, T data, {Duration ttl = defaultTtl}) {
    _memoryCache[key] = _CacheEntry(
      data: data,
      expiry: DateTime.now().add(ttl),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 4. Stale-While-Revalidate (SWR) Runner
  //    - Papar data sedia ada serta-merta (0 saat)
  //    - Tarik data baru di latar belakang & kemas kini UI senyap
  // ──────────────────────────────────────────────────────────
  static Future<void> loadStaleWhileRevalidate<T>({
    required String key,
    required T Function(dynamic json) fromJson,
    required dynamic Function(T data) toJson,
    required void Function(T data, bool isStale) onData,
    required Future<T> Function() fetcher,
    Duration ttl = defaultTtl,
    void Function(dynamic error)? onError,
  }) async {
    // 1. Tunjuk data cache dahulu jika ada (L1 Memory atau L2 Disk)
    bool hasCachedData = false;
    final cached = await get<T>(key: key, fromJson: fromJson);
    if (cached != null) {
      hasCachedData = true;
      onData(cached, true); // true = data cache sedia ada
    }

    // 2. Tarik data segar dari server di latar belakang
    try {
      final fresh = await fetcher();
      // Simpan data segar ke cache
      await set<T>(key: key, data: fresh, toJson: toJson, ttl: ttl);
      // Maklumkan UI dengan data paling terkini
      onData(fresh, false); // false = data segar dari server
    } catch (e) {
      debugPrint('[CacheService] Network fetch failed for "$key": $e');
      if (onError != null) {
        onError(e);
      }
      // Jika pengguna sudah ada cache, aplikasi tidak akan crash atau sangkut
      if (!hasCachedData) {
        rethrow;
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // 5. Stream Caching (SWR untuk Realtime Stream Supabase)
  //    - Keluarkan data cache sejurus dibuka (0 saat)
  //    - Sambung stream realtime dan kemas kini cache berterusan
  // ──────────────────────────────────────────────────────────
  static Stream<T> streamWithCache<T>({
    required String key,
    required T Function(dynamic json) fromJson,
    required dynamic Function(T data) toJson,
    required Stream<T> Function() streamFactory,
    Duration ttl = defaultTtl,
  }) async* {
    // 1. Pancarkan data cache serta-merta jika wujud
    final cached = await get<T>(key: key, fromJson: fromJson);
    if (cached != null) {
      yield cached;
    }

    // 2. Dengar stream realtime dari server
    yield* streamFactory().map((fresh) {
      unawaited(set<T>(key: key, data: fresh, toJson: toJson, ttl: ttl));
      return fresh;
    });
  }

  // ──────────────────────────────────────────────────────────
  // 6. Pengurusan & Pembersihan Cache
  // ──────────────────────────────────────────────────────────
  static Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$key');
    } catch (e) {
      debugPrint('[CacheService] Gagal invalidate key "$key": $e');
    }
  }

  static Future<void> clear() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[CacheService] Gagal membersihkan semua cache: $e');
    }
  }
}
