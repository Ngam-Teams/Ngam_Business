import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_update_service.dart';
import '../../../core/services/r2_storage_service.dart';
import '../../../core/utils/ngam_ref.dart';
import '../../settings/data/business_service.dart';

class MerchantSupportTicket {
  final String id;
  final String ticketCode;
  final String? userId;
  final String? businessId;
  final String sourceApp;
  final String reporterName;
  final String reporterEmail;
  final String? reporterPhone;
  final String category;
  final String priority;
  final String subject;
  final String description;
  final List<String> attachmentUrls;
  final String? appVersion;
  final String? platform;
  final String status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  const MerchantSupportTicket({
    required this.id,
    required this.ticketCode,
    this.userId,
    this.businessId,
    required this.sourceApp,
    required this.reporterName,
    required this.reporterEmail,
    this.reporterPhone,
    required this.category,
    required this.priority,
    required this.subject,
    required this.description,
    required this.attachmentUrls,
    this.appVersion,
    this.platform,
    required this.status,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
  });

  factory MerchantSupportTicket.fromJson(Map<String, dynamic> json) {
    final List<String> urls = [];
    final rawUrls = json['attachment_urls'];
    if (rawUrls is List) {
      for (final item in rawUrls) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty) urls.add(s);
      }
    }

    DateTime? parseOpt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    return MerchantSupportTicket(
      id: json['id']?.toString() ?? '',
      ticketCode: json['ticket_code']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      businessId: json['business_id']?.toString(),
      sourceApp: json['source_app']?.toString() ?? 'ngam_business',
      reporterName: json['reporter_name']?.toString() ?? '',
      reporterEmail: json['reporter_email']?.toString() ?? '',
      reporterPhone: json['reporter_phone']?.toString(),
      category: json['category']?.toString() ?? 'bug',
      priority: json['priority']?.toString() ?? 'normal',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrls: urls,
      appVersion: json['app_version']?.toString(),
      platform: json['platform']?.toString(),
      status: json['status']?.toString() ?? 'open',
      adminReply: json['admin_reply']?.toString(),
      repliedAt: parseOpt(json['replied_at']),
      createdAt: parseOpt(json['created_at']) ?? DateTime.now(),
    );
  }
}

class MerchantSupportService {
  static final MerchantSupportService _instance = MerchantSupportService._internal();
  factory MerchantSupportService() => _instance;
  MerchantSupportService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final R2StorageService _r2 = R2StorageService();

  static String get detectedPlatform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static String get detectedDeviceInfo {
    final platform = kIsWeb ? 'Web/PWA' : defaultTargetPlatform.name;
    return 'Ngam Business • $platform • v${AppUpdateService.currentVersion}';
  }

  String _generateTicketCode() => NgamRef.support();

  String _inferMimeType(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<List<String>> uploadAttachments(List<XFile> files) async {
    final List<String> urls = [];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final url = await _r2.uploadMedia(
        bytes: bytes,
        fileName: file.name,
        folder: 'support-tickets',
        mimeType: _inferMimeType(file),
      );
      urls.add(url);
    }
    return urls;
  }

  Future<String> submitTicket({
    required String category,
    required String priority,
    required String subject,
    required String description,
    required String reporterName,
    required String reporterEmail,
    String? reporterPhone,
    List<XFile> attachments = const [],
  }) async {
    final user = _client.auth.currentUser;
    final profile = BusinessService.cachedProfile ??
        await BusinessService().getBusinessProfile(autoCreate: false);
    final businessId = profile?['id']?.toString();

    final ticketCode = _generateTicketCode();
    final uploadedUrls = attachments.isNotEmpty
        ? await uploadAttachments(attachments)
        : <String>[];

    await _client.from('support_tickets').insert({
      'ticket_code': ticketCode,
      'user_id': user?.id,
      'business_id': businessId,
      'source_app': 'ngam_business',
      'reporter_name': reporterName.trim(),
      'reporter_email': reporterEmail.trim(),
      'reporter_phone': (reporterPhone ?? '').trim().isEmpty ? null : reporterPhone!.trim(),
      'category': category,
      'priority': priority,
      'subject': subject.trim(),
      'description': description.trim(),
      'attachment_urls': uploadedUrls,
      'app_version': AppUpdateService.currentVersion,
      'platform': detectedPlatform,
      'device_info': detectedDeviceInfo,
      'status': 'open',
    });

    return ticketCode;
  }

  Stream<List<MerchantSupportTicket>> watchMyTickets() {
    final uid = _client.auth.currentUser?.id;
    final businessId = BusinessService.cachedProfile?['id']?.toString();
    if (uid == null && businessId == null) {
      return Stream.value(const []);
    }

    if (businessId != null && businessId.isNotEmpty) {
      return _client
          .from('support_tickets')
          .stream(primaryKey: ['id'])
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map((r) => MerchantSupportTicket.fromJson(r)).toList());
    }

    return _client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid!)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => MerchantSupportTicket.fromJson(r)).toList());
  }
}
