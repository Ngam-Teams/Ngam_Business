import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/data/business_service.dart';

class AuditService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final BusinessService _businessService = BusinessService();

  static String? lastError;
  static bool isMissingTableError = false;

  static const Set<String> _defaultIgnoredFields = {
    'id',
    'business_id',
    'created_at',
    'updated_at',
    'owner_user_id',
    'user_id',
    'times_used',
  };

  static const Set<String> _currencyFields = {
    'price',
    'compare_at_price',
    'cost_price',
    'deposit_amount',
    'min_spend',
    'max_discount',
    'max_discount_amount',
    'total',
    'total_price',
    'amount',
    'salary',
    'old_price',
    'new_price',
  };

  static const Set<String> _dateFields = {
    'start_date',
    'end_date',
  };

  static const Set<String> _percentFields = {
    'tax_rate',
    'commission_rate',
  };

  static const Set<String> _minuteFields = {
    'duration_minutes',
    'buffer_minutes',
    'slot_duration',
  };

  static const Set<String> _mediaUrlFields = {
    'image_url',
    'video_url',
    'media_url',
    'business_logo_url',
    'business_cover_url',
    'avatar_url',
  };

  static const Set<String> _sensitiveMaskedFields = {
    'bank_account_number',
    'account_number',
  };

  static final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}');

  static const Map<String, String> fieldLabels = {
    // Products & Services
    'name': 'Nama',
    'item_type': 'Jenis Item',
    'price': 'Harga Jualan',
    'old_price': 'Harga Lama',
    'new_price': 'Harga Baharu',
    'compare_at_price': 'Harga Asal',
    'cost_price': 'Harga Kos',
    'tax_rate': 'Kadar Cukai',
    'category': 'Kategori',
    'sub_category': 'Sub-Kategori',
    'description': 'Penerangan',
    'sku': 'SKU',
    'barcode': 'Kod Bar',
    'stock': 'Stok',
    'track_inventory': 'Jejak Inventori',
    'low_stock_threshold': 'Had Amaran Stok',
    'unit': 'Unit',
    'is_active': 'Status Aktif',
    'is_available': 'Status Tersedia',
    'is_featured': 'Item Pilihan',
    'is_halal': 'Status Halal',
    'variants': 'Varian & Harga',
    'modifiers': 'Add-On / Tambahan',
    'duration_minutes': 'Tempoh Servis',
    'buffer_minutes': 'Masa Rehat',
    'deposit_amount': 'Deposit',
    'service_location': 'Lokasi Servis',
    'max_pax': 'Had Pelanggan',
    'image_url': 'Gambar Utama',
    'image_urls': 'Galeri Gambar',
    'video_url': 'Video Produk',
    'tags': 'Tag',
    // Orders / POS / Bookings / Cash Drawer
    'status': 'Status',
    'payment_status': 'Status Bayaran',
    'payment_method': 'Kaedah Bayaran',
    'total': 'Jumlah',
    'total_price': 'Jumlah',
    'amount': 'Jumlah',
    'items_count': 'Bilangan Item',
    'is_paid': 'Status Bayaran',
    'customer_name': 'Pelanggan',
    'provider_name': 'Staf Bertugas',
    'staff_name': 'Staf Bertugas',
    'cashier': 'Juruwang',
    'type': 'Jenis',
    'notes': 'Nota',
    'reason': 'Sebab',
    'source': 'Saluran',
    // Vouchers
    'code': 'Kod Baucar',
    'title': 'Tajuk',
    'discount_type': 'Jenis Diskaun',
    'discount_value': 'Nilai Diskaun',
    'min_spend': 'Belanja Minimum',
    'max_discount': 'Diskaun Maksimum',
    'max_discount_amount': 'Diskaun Maksimum',
    'usage_limit': 'Had Penggunaan',
    'total_usage_limit': 'Had Penggunaan',
    'per_user_limit': 'Had / Pengguna',
    'usage_limit_per_user': 'Had / Pengguna',
    'start_date': 'Tarikh Mula',
    'end_date': 'Tarikh Tamat',
    'applicable_scope': 'Skop Gunaan',
    'applicable_ids': 'Item Terpilih',
    'customer_eligibility': 'Kelayakan Pelanggan',
    // Feed
    'caption': 'Kapsyen',
    'media_url': 'Media',
    'media_type': 'Jenis Media',
    'service_tag': 'Tag Servis',
    'cta_type': 'Jenis Butang',
    'cta_text': 'Teks Butang',
    'is_pinned': 'Disematkan',
    // Staff & Security
    'staff_code': 'Kod Staf',
    'role': 'Peranan',
    'department': 'Jabatan',
    'designation': 'Jawatan',
    'phone': 'No. Telefon',
    'email': 'E-mel',
    'salary': 'Gaji',
    'commission_rate': 'Kadar Komisen',
    'leave_type': 'Jenis Cuti',
    'leave_status': 'Status Cuti',
    'mfa_status': 'Status 2FA',
    // Business Profile / Settings / Compliance
    'business_name': 'Nama Perniagaan',
    'business_handle': 'Handle Kedai',
    'business_industry': 'Industri',
    'business_email': 'E-mel Kedai',
    'business_phone': 'Telefon Kedai',
    'business_website': 'Laman Web',
    'address_line': 'Alamat',
    'postcode': 'Poskod',
    'business_city': 'Bandar',
    'state': 'Negeri',
    'business_country': 'Negara',
    'latitude': 'Latitud',
    'longitude': 'Longitud',
    'business_logo_url': 'Logo Kedai',
    'business_cover_url': 'Banner Kedai',
    'operating_hours': 'Waktu Operasi',
    'total_chairs': 'Jumlah Stesen / Meja',
    'slot_duration': 'Tempoh Slot',
    'is_open': 'Status Operasi',
    'business_registration_number': 'No. Pendaftaran SSM',
    'ssm_number': 'No. Pendaftaran SSM',
    'sst_number': 'No. SST',
    'bank_name': 'Nama Bank',
    'bank_account_number': 'No. Akaun Bank',
    'bank_account_holder': 'Pemegang Akaun',
    'account_number': 'No. Akaun Bank',
    'account_holder': 'Pemegang Akaun',
  };

  static String labelForField(String key, [Map<String, String>? customLabels]) {
    if (customLabels != null && customLabels.containsKey(key)) {
      return customLabels[key]!;
    }
    if (fieldLabels.containsKey(key)) return fieldLabels[key]!;
    return key
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  static double? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static dynamic _normalizeForCompare(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is List) {
      if (v.isEmpty) return null;
      return v.map(_normalizeForCompare).toList();
    }
    if (v is Map) {
      if (v.isEmpty) return null;
      final out = <String, dynamic>{};
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      for (final k in keys) {
        final norm = _normalizeForCompare(v[k]);
        if (norm != null) out[k] = norm;
      }
      return out.isEmpty ? null : out;
    }
    return v.toString().trim();
  }

  static bool _valuesEqual(dynamic a, dynamic b) {
    final na = _normalizeForCompare(a);
    final nb = _normalizeForCompare(b);
    if (na == null && nb == null) return true;
    if (na == null || nb == null) return false;
    if (na is bool && nb is bool) return na == nb;

    // Compare numbers semantically (e.g. 10 vs 10.0 vs "10.00")
    if (na is num || nb is num) {
      final da = _toNum(na);
      final db = _toNum(nb);
      if (da != null && db != null) {
        return (da - db).abs() < 0.0001;
      }
    }

    if (na is String && nb is String) {
      if (_isoDatePattern.hasMatch(na) && _isoDatePattern.hasMatch(nb)) {
        final dtA = DateTime.tryParse(na);
        final dtB = DateTime.tryParse(nb);
        if (dtA != null && dtB != null) {
          return dtA.toUtc().difference(dtB.toUtc()).inSeconds.abs() <= 1;
        }
      }
      return na == nb;
    }

    if (na is List && nb is List) {
      if (na.length != nb.length) return false;
      for (int i = 0; i < na.length; i++) {
        if (!_valuesEqual(na[i], nb[i])) return false;
      }
      return true;
    }

    if (na is Map && nb is Map) {
      if (na.length != nb.length) return false;
      for (final k in na.keys) {
        if (!nb.containsKey(k)) return false;
        if (!_valuesEqual(na[k], nb[k])) return false;
      }
      return true;
    }

    return na.toString() == nb.toString();
  }

  static String _maskSensitive(String raw) {
    final s = raw.trim();
    if (s.length <= 4) return '****';
    return '****${s.substring(s.length - 4)}';
  }

  static String _formatVariantsOrModifiers(List rawList, {required bool isVariant}) {
    if (rawList.isEmpty) return 'Tiada';
    final parts = <String>[];
    for (final item in rawList.take(4)) {
      if (item is Map) {
        final name = (item['name'] ?? item['label'] ?? item['title'] ?? '').toString().trim();
        final priceNum = _toNum(item['price'] ?? item['extra_price'] ?? item['price_delta']);
        if (name.isNotEmpty) {
          if (priceNum != null) {
            final prefix = isVariant ? 'RM ' : '+RM ';
            parts.add('$name ($prefix${priceNum.toStringAsFixed(2)})');
          } else {
            parts.add(name);
          }
        }
      } else if (item != null && item.toString().trim().isNotEmpty) {
        parts.add(item.toString().trim());
      }
    }
    final extra = rawList.length > 4 ? ' +${rawList.length - 4} lagi' : '';
    final unit = isVariant ? 'varian' : 'add-on';
    if (parts.isEmpty) return '${rawList.length} $unit';
    return '${rawList.length} $unit: ${parts.join(", ")}$extra';
  }

  static String _formatDiscountValue(dynamic raw, dynamic discountType) {
    final norm = _normalizeForCompare(raw);
    if (norm == null) return 'Kosong';
    final n = _toNum(norm);
    if (n == null) return norm.toString();
    final t = (discountType ?? '').toString().toLowerCase();
    if (t == 'percentage' || t == 'percent') {
      final str = (n == n.roundToDouble()) ? n.toInt().toString() : n.toStringAsFixed(1);
      return '$str%';
    }
    return 'RM ${n.toStringAsFixed(2)}';
  }

  static String formatFieldValue(String field, dynamic raw) {
    final norm = _normalizeForCompare(raw);
    if (norm == null) {
      if (field == 'image_urls') return '0 gambar';
      if (field == 'video_url') return 'Tiada video';
      if (field == 'image_url' || field == 'business_logo_url' || field == 'business_cover_url') {
        return 'Tiada gambar';
      }
      return 'Kosong';
    }

    if (_sensitiveMaskedFields.contains(field)) {
      return _maskSensitive(norm.toString());
    }

    if (norm is bool) {
      if (field == 'is_active' || field == 'is_available' || field == 'is_open') {
        return norm ? 'Aktif' : 'Tidak Aktif';
      }
      if (field == 'is_paid') {
        return norm ? 'Sudah Dibayar' : 'Belum Dibayar';
      }
      return norm ? 'Ya' : 'Tidak';
    }

    if (_dateFields.contains(field) && norm is String && _isoDatePattern.hasMatch(norm)) {
      final dt = DateTime.tryParse(norm)?.toLocal();
      if (dt != null) {
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final y = dt.year.toString();
        if (dt.hour != 0 || dt.minute != 0) {
          final hh = dt.hour.toString().padLeft(2, '0');
          final mm = dt.minute.toString().padLeft(2, '0');
          return '$d/$m/$y $hh:$mm';
        }
        return '$d/$m/$y';
      }
    }

    if (_currencyFields.contains(field)) {
      final n = _toNum(norm);
      if (n != null) return 'RM ${n.toStringAsFixed(2)}';
    }

    if (_percentFields.contains(field)) {
      final n = _toNum(norm);
      if (n != null) {
        final str = (n == n.roundToDouble()) ? n.toInt().toString() : n.toStringAsFixed(1);
        return '$str%';
      }
    }

    if (_minuteFields.contains(field)) {
      final n = _toNum(norm);
      if (n != null) return '${n.round()} min';
    }

    if (field == 'stock' || field == 'low_stock_threshold') {
      final n = _toNum(norm);
      if (n != null) return '${n.round()} unit';
    }

    if (field == 'image_urls' && norm is List) {
      return '${norm.length} gambar';
    }

    if (field == 'variants' && norm is List) {
      return _formatVariantsOrModifiers(norm, isVariant: true);
    }

    if (field == 'modifiers' && norm is List) {
      return _formatVariantsOrModifiers(norm, isVariant: false);
    }

    if (field == 'tags' && norm is List) {
      return norm.map((e) => e.toString()).join(', ');
    }

    if (_mediaUrlFields.contains(field)) {
      final s = norm.toString();
      if (s.startsWith('http') || s.startsWith('[')) {
        if (field == 'video_url') return 'Ada video';
        return 'Ada gambar';
      }
    }

    if (field == 'operating_hours' && norm is Map) {
      final open = norm['open_time']?.toString();
      final close = norm['close_time']?.toString();
      final days = norm['days'] is List ? (norm['days'] as List).length : null;
      if (open != null && close != null) {
        return days != null ? '$open - $close ($days hari)' : '$open - $close';
      }
      return '${norm.length} tetapan jadual';
    }

    if (field == 'status' ||
        field == 'payment_status' ||
        field == 'payment_method' ||
        field == 'role' ||
        field == 'leave_status') {
      return norm.toString().toUpperCase().replaceAll('_', ' ');
    }

    if (norm is List) {
      final joined = norm.map((e) => e.toString()).take(5).join(', ');
      return norm.length > 5 ? '$joined +${norm.length - 5}' : joined;
    }

    if (norm is Map) {
      return '${norm.length} medan';
    }

    final text = norm.toString();
    if (text.length > 80) {
      return '${text.substring(0, 77)}...';
    }
    return text;
  }

  /// Computes true semantic field-level Before -> After diff between [before] and [after].
  /// Only fields whose actual values changed are included.
  static List<Map<String, String>> computeDiff(
    Map<String, dynamic>? before,
    Map<String, dynamic> after, {
    Set<String> ignoreFields = const {},
    Map<String, String>? customLabels,
  }) {
    final changes = <Map<String, String>>[];
    final ignored = {..._defaultIgnoredFields, ...ignoreFields};

    for (final entry in after.entries) {
      final key = entry.key;
      if (ignored.contains(key)) continue;

      final oldVal = before?[key];
      final newVal = entry.value;
      if (_valuesEqual(oldVal, newVal)) continue;

      var fromStr = key == 'discount_value'
          ? _formatDiscountValue(oldVal, before?['discount_type'] ?? after['discount_type'])
          : formatFieldValue(key, oldVal);
      var toStr = key == 'discount_value'
          ? _formatDiscountValue(newVal, after['discount_type'] ?? before?['discount_type'])
          : formatFieldValue(key, newVal);

      // Ensure visually identical formatted labels for swapped URLs/same-count galleries remain crystal clear
      if (fromStr == toStr) {
        if (key == 'image_urls') {
          toStr = '$toStr (susunan/gambar ditukar)';
        } else if (key == 'video_url') {
          fromStr = 'Video lama';
          toStr = 'Video baharu';
        } else if (_mediaUrlFields.contains(key)) {
          fromStr = 'Media lama';
          toStr = 'Media baharu';
        } else if (key == 'operating_hours') {
          fromStr = 'Jadual lama';
          toStr = 'Jadual baharu';
        } else {
          toStr = '$toStr (dikemas kini)';
        }
      }

      changes.add({
        'field': key,
        'label': labelForField(key, customLabels),
        'from': fromStr,
        'to': toStr,
      });
    }

    return changes;
  }

  /// Convenience builder for a single explicit Before -> After change entry.
  static Map<String, String> singleChange({
    required String field,
    String? label,
    required dynamic from,
    required dynamic to,
  }) {
    return {
      'field': field,
      'label': label ?? labelForField(field),
      'from': formatFieldValue(field, from),
      'to': formatFieldValue(field, to),
    };
  }

  /// Concise human-readable summary of changed fields for the audit headline.
  static String summarizeChanges(
    List<Map<String, String>> changes, {
    int maxInline = 3,
  }) {
    if (changes.isEmpty) return '';
    final preview = changes
        .take(maxInline)
        .map((c) => '${c['label']} (${c['from']} → ${c['to']})')
        .join(', ');
    if (changes.length > maxInline) {
      return '$preview +${changes.length - maxInline} lagi';
    }
    return preview;
  }

  static bool _looksLikeMissingTable(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('pgrst205') ||
        msg.contains('42p01') ||
        msg.contains('audit_logs') &&
            (msg.contains('does not exist') ||
                msg.contains('could not find the table') ||
                msg.contains('schema cache'));
  }

  /// Log a security or operational event to the tamper-resistant audit trail.
  /// Returns `true` if inserted successfully, `false` otherwise.
  static Future<bool> log({
    required String action,
    required String description,
    String severity = 'info', // 'info', 'warning', 'critical'
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final business = BusinessService.cachedProfile ??
          await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return false;

      final actorName = (user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@').first ??
              'Staff')
          .toString()
          .trim();

      final isOwner = business?['owner_user_id'] == user.id;
      final actorRole = isOwner
          ? 'tenant_admin'
          : (business?['_user_role'] ?? user.userMetadata?['role'] ?? 'staff')
              .toString();

      await _client.from('audit_logs').insert({
        'business_id': businessId,
        'actor_user_id': user.id,
        'actor_name': actorName.isNotEmpty ? actorName : 'Staff',
        'actor_email': user.email,
        'actor_role': actorRole,
        'action': action.toUpperCase(),
        'severity': severity,
        'target_type': targetType,
        'target_id': targetId,
        'description': description,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      lastError = null;
      isMissingTableError = false;
      return true;
    } catch (e) {
      lastError = e.toString();
      isMissingTableError = _looksLikeMissingTable(e);
      if (kDebugMode) {
        print('AuditService error: $e');
      }
      return false;
    }
  }

  /// Retrieve audit logs for the current business.
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? severity,
    String? searchQuery,
    int limit = 100,
  }) async {
    lastError = null;
    isMissingTableError = false;
    try {
      final business = BusinessService.cachedProfile ??
          await _businessService.getBusinessProfile();
      final businessId = business?['id'];
      if (businessId == null) return [];

      var query = _client
          .from('audit_logs')
          .select()
          .eq('business_id', businessId);

      if (severity != null && severity.isNotEmpty && severity != 'all') {
        query = query.eq('severity', severity);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);
      final logs = List<Map<String, dynamic>>.from(response);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return logs.where((l) {
          final desc = (l['description'] ?? '').toString().toLowerCase();
          final action = (l['action'] ?? '').toString().toLowerCase();
          final actor = (l['actor_name'] ?? '').toString().toLowerCase();
          final targetId = (l['target_id'] ?? '').toString().toLowerCase();
          final metaStr = (l['metadata'] ?? '').toString().toLowerCase();
          return desc.contains(q) ||
              action.contains(q) ||
              actor.contains(q) ||
              targetId.contains(q) ||
              metaStr.contains(q);
        }).toList();
      }

      return logs;
    } catch (e) {
      lastError = e.toString();
      isMissingTableError = _looksLikeMissingTable(e);
      if (kDebugMode) {
        print('Error fetching audit logs: $e');
      }
      return [];
    }
  }

  /// Extracts normalized change rows `[{field, label, from, to}]` from a log's metadata.
  /// Also gracefully upgrades legacy `old_*` / `new_*` metadata pairs when `changes` is absent.
  static List<Map<String, String>> extractChanges(Map<String, dynamic>? metadata) {
    if (metadata == null) return const [];
    final raw = metadata['changes'];
    if (raw is List) {
      final out = <Map<String, String>>[];
      for (final item in raw) {
        if (item is Map) {
          final label = (item['label'] ?? labelForField((item['field'] ?? '').toString())).toString();
          final from = (item['from'] ?? 'Kosong').toString();
          final to = (item['to'] ?? 'Kosong').toString();
          out.add({
            'field': (item['field'] ?? '').toString(),
            'label': label,
            'from': from,
            'to': to,
          });
        }
      }
      return out;
    }

    // Backwards-compatible fallback for older trigger logs with old_* / new_* keys
    const legacyPairs = [
      ('price', 'old_price', 'new_price'),
      ('status', 'old_status', 'new_status'),
      ('payment_status', 'old_payment_status', 'new_payment_status'),
      ('stock', 'old_stock', 'new_stock'),
    ];
    final legacyOut = <Map<String, String>>[];
    for (final (field, oldKey, newKey) in legacyPairs) {
      if (metadata.containsKey(oldKey) && metadata.containsKey(newKey)) {
        final oldVal = metadata[oldKey];
        final newVal = metadata[newKey];
        if (!_valuesEqual(oldVal, newVal)) {
          legacyOut.add(singleChange(field: field, from: oldVal, to: newVal));
        }
      }
    }
    return legacyOut;
  }

  /// Builds a clean RFC-4180 CSV export string from audit log rows, including exact Before -> After diffs.
  static String buildCsv(List<Map<String, dynamic>> logs) {
    String esc(dynamic v) {
      final s = (v ?? '').toString().replaceAll('"', '""');
      return '"$s"';
    }

    final buf = StringBuffer();
    buf.writeln(
      'Timestamp,Severity,Action,Actor,Role,Email,TargetType,TargetRef,Description,Changes',
    );
    for (final l in logs) {
      final meta = l['metadata'] is Map ? Map<String, dynamic>.from(l['metadata'] as Map) : null;
      final changes = extractChanges(meta);
      final changesText = changes.isNotEmpty
          ? changes.map((c) => '${c['label']}: ${c['from']} -> ${c['to']}').join(' | ')
          : '';
      final targetRef = (meta?['target_label'] ??
              meta?['order_ref'] ??
              meta?['pos_ref'] ??
              meta?['booking_ref'] ??
              l['target_id'] ??
              '')
          .toString();

      buf.writeln([
        esc(l['created_at']),
        esc(l['severity']),
        esc(l['action']),
        esc(l['actor_name']),
        esc(l['actor_role']),
        esc(l['actor_email']),
        esc(l['target_type']),
        esc(targetRef),
        esc(l['description']),
        esc(changesText),
      ].join(','));
    }
    return buf.toString();
  }
}
