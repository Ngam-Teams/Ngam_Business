import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/r2_storage_service.dart';

class MerchantConversation {
  final String id;
  final String customerId;
  final String ownerUserId;
  final String businessId;
  final String customerName;
  final String? customerAvatarUrl;
  final String? customerPhone;
  final String? contextType; // 'general', 'order', 'booking'
  final String? contextId;
  final String? contextRef;
  final String? contextStatus;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final bool lastMessageIsRead;
  final int unreadCount;
  final DateTime updatedAt;

  const MerchantConversation({
    required this.id,
    required this.customerId,
    required this.ownerUserId,
    required this.businessId,
    required this.customerName,
    this.customerAvatarUrl,
    this.customerPhone,
    this.contextType,
    this.contextId,
    this.contextRef,
    this.contextStatus,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageIsRead = false,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  MerchantConversation copyWith({
    String? customerName,
    String? customerAvatarUrl,
    String? customerPhone,
    String? contextType,
    String? contextId,
    String? contextRef,
    String? contextStatus,
    String? lastMessage,
    String? lastMessageSenderId,
    bool? lastMessageIsRead,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return MerchantConversation(
      id: id,
      customerId: customerId,
      ownerUserId: ownerUserId,
      businessId: businessId,
      customerName: customerName ?? this.customerName,
      customerAvatarUrl: customerAvatarUrl ?? this.customerAvatarUrl,
      customerPhone: customerPhone ?? this.customerPhone,
      contextType: contextType ?? this.contextType,
      contextId: contextId ?? this.contextId,
      contextRef: contextRef ?? this.contextRef,
      contextStatus: contextStatus ?? this.contextStatus,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MerchantMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? imageUrl;
  final String messageType;
  final String? fileName;
  final int? fileSize;
  final bool isRead;
  final DateTime createdAt;
  final String status; // 'sending', 'sent', 'failed'
  final Map<String, dynamic>? replyToMessage;

  const MerchantMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.imageUrl,
    this.messageType = 'text',
    this.fileName,
    this.fileSize,
    this.isRead = false,
    required this.createdAt,
    this.status = 'sent',
    this.replyToMessage,
  });

  bool get isVideo {
    if (messageType == 'video') return true;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final lower = imageUrl!.toLowerCase().split('?').first;
      return lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.m4v');
    }
    return false;
  }

  bool get isFile {
    if (messageType == 'file' || messageType == 'document') return true;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final lower = imageUrl!.toLowerCase().split('?').first;
      return lower.endsWith('.pdf') ||
          lower.endsWith('.doc') ||
          lower.endsWith('.docx') ||
          lower.endsWith('.csv') ||
          lower.endsWith('.txt') ||
          lower.endsWith('.xls') ||
          lower.endsWith('.xlsx');
    }
    return false;
  }

  bool get isImage =>
      messageType == 'image' ||
      (imageUrl != null && imageUrl!.isNotEmpty && !isVideo && !isFile);

  String get displayFileName {
    if (fileName != null && fileName!.trim().isNotEmpty) return fileName!.trim();
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    }
    return content.isNotEmpty ? content : 'File';
  }

  String get formattedFileSize {
    final bytes = fileSize;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory MerchantMessage.fromJson(Map<String, dynamic> json) {
    return MerchantMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      messageType: json['message_type']?.toString() ?? 'text',
      fileName: json['file_name']?.toString(),
      fileSize: (json['file_size'] as num?)?.toInt(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'sent',
      replyToMessage: json['reply_to_message'] is Map
          ? Map<String, dynamic>.from(json['reply_to_message'] as Map)
          : null,
    );
  }

  MerchantMessage copyWith({
    String? id,
    String? imageUrl,
    bool? isRead,
    String? status,
  }) {
    return MerchantMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      imageUrl: imageUrl ?? this.imageUrl,
      messageType: messageType,
      fileName: fileName,
      fileSize: fileSize,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      status: status ?? this.status,
      replyToMessage: replyToMessage,
    );
  }
}

class MerchantChatService {
  static final _supabase = Supabase.instance.client;
  static final ValueNotifier<int> totalUnreadNotifier = ValueNotifier<int>(0);
  static final Map<String, Map<String, dynamic>> _userCache = {};
  static final Map<String, Map<String, dynamic>> _contextCache = {};
  static bool _merchantUserVerified = false;
  static final Set<String> _healedBusinesses = {};
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Ensure the currently authenticated merchant/staff user exists in `public.users`
  /// and heal any business conversations so foreign keys and RLS on `conversations`
  /// and `messages` never fail.
  static Future<void> ensureCurrentMerchantInUsers({
    String? businessId,
    String? businessName,
    String? businessLogoUrl,
    String? businessPhone,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (!_merchantUserVerified) {
      try {
        final existing = await _supabase
            .from('users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (existing != null) {
          _merchantUserVerified = true;
        } else {
          final fallbackName = (businessName != null && businessName.trim().isNotEmpty)
              ? businessName.trim()
              : (user.userMetadata?['business_name']?.toString() ??
                  user.userMetadata?['full_name']?.toString() ??
                  user.email?.split('@').first ??
                  'Peniaga Ngam');
          await _supabase.from('users').insert({
            'id': user.id,
            'role': 'business',
            'user_name': fallbackName,
            if (user.email != null) 'user_email': user.email,
            if (businessPhone != null && businessPhone.isNotEmpty) 'user_phone': businessPhone,
            if (businessLogoUrl != null && businessLogoUrl.isNotEmpty) 'user_avatar_url': businessLogoUrl,
          });
          _merchantUserVerified = true;
        }
      } catch (e) {
        debugPrint('[MerchantChatService] ensureCurrentMerchantInUsers error: $e');
      }
    }

    if (businessId != null &&
        businessId.isNotEmpty &&
        !_healedBusinesses.contains(businessId)) {
      _healedBusinesses.add(businessId);
      // 1. Ensure owner is also in team_members so legacy is_active_staff_of(business_id) passes
      try {
        final member = await _supabase
            .from('team_members')
            .select('id, is_active')
            .eq('business_id', businessId)
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();
        if (member == null) {
          await _supabase.from('team_members').insert({
            'business_id': businessId,
            'user_id': user.id,
            'full_name': businessName ?? 'Owner',
            if (user.email != null) 'email': user.email,
            'role': 'owner',
            'is_active': true,
          });
        } else if (member['is_active'] != true) {
          await _supabase
              .from('team_members')
              .update({'is_active': true})
              .eq('id', member['id']);
        }
      } catch (_) {}

      // 2. Heal any conversations where user2_id was temporarily set to customer's user1_id
      try {
        await _supabase
            .from('conversations')
            .update({'user2_id': user.id})
            .eq('business_id', businessId)
            .neq('user2_id', user.id);
      } catch (_) {}
    }
  }

  static Future<void> _syncConversationPreview({
    required String conversationId,
    required String senderId,
    required String lastMessage,
  }) async {
    try {
      await _supabase.from('conversations').update({
        'last_message': lastMessage,
        'last_message_sender_id': senderId,
        'last_message_is_read': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversationId);
    } catch (_) {}
  }

  static Future<void> refreshUnreadCount(String businessId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('business_unread_count')
          .eq('business_id', businessId);
      int total = 0;
      for (final r in (rows as List)) {
        total += (r['business_unread_count'] as num?)?.toInt() ?? 0;
      }
      totalUnreadNotifier.value = total;
    } catch (e) {
      debugPrint('refreshUnreadCount error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getCustomerProfile(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final res = await _supabase
          .from('users')
          .select('id, user_name, user_avatar_url, user_phone')
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        _userCache[userId] = Map<String, dynamic>.from(res);
      }
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getContextDetails(
    String? contextType,
    String? contextId,
  ) async {
    if (contextType == null || contextId == null || contextId.isEmpty) {
      return null;
    }
    final key = '$contextType:$contextId';
    if (_contextCache.containsKey(key)) return _contextCache[key];

    try {
      if (contextType == 'order') {
        final res = await _supabase
            .from('orders')
            .select('id, status, total')
            .eq('id', contextId)
            .maybeSingle();
        if (res != null) {
          final shortId = contextId.length > 6
              ? contextId.substring(0, 6).toUpperCase()
              : contextId.toUpperCase();
          final totalStr = ((res['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
          final data = {
            'ref': 'ORD-$shortId • RM $totalStr',
            'status': (res['status'] ?? 'pending').toString().toLowerCase(),
          };
          _contextCache[key] = data;
          return data;
        }
      } else if (contextType == 'booking') {
        final res = await _supabase
            .from('bookings')
            .select('id, status, service_name, booking_date, booking_metadata')
            .eq('id', contextId)
            .maybeSingle();
        if (res != null) {
          final meta = res['booking_metadata'] is Map
              ? Map<String, dynamic>.from(res['booking_metadata'] as Map)
              : <String, dynamic>{};
          final fallbackCode = contextId.length >= 5
              ? contextId.substring(0, 5).toUpperCase()
              : contextId.toUpperCase();
          final ref = (meta['booking_id'] ?? meta['short_ref'] ?? 'BK-$fallbackCode').toString();
          final svc = (res['service_name'] ?? '').toString().trim();
          final dateStr = (res['booking_date'] ?? '').toString();
          final data = {
            'ref': '$ref${svc.isNotEmpty ? ' • $svc' : ''}${dateStr.isNotEmpty ? ' ($dateStr)' : ''}',
            'status': (res['status'] ?? 'pending').toString().toLowerCase(),
          };
          _contextCache[key] = data;
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  static void invalidateContextCache(String contextType, String contextId) {
    _contextCache.remove('$contextType:$contextId');
  }

  /// Realtime stream of conversations for a business
  static Stream<List<MerchantConversation>> streamBusinessConversations(String businessId) {
    return _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .asyncMap((rows) async {
          final sorted = List<Map<String, dynamic>>.from(rows);
          sorted.sort((a, b) {
            final aTime = DateTime.tryParse(a['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          int totalUnread = 0;
          final List<MerchantConversation> list = [];

          for (final r in sorted) {
            final customerId = r['user1_id']?.toString() ?? '';
            final ownerId = r['user2_id']?.toString() ?? '';
            final ctxType = r['context_type']?.toString();
            final ctxId = r['context_id']?.toString();
            final unread = (r['business_unread_count'] as num?)?.toInt() ?? 0;
            totalUnread += unread;

            final user = customerId.isNotEmpty ? await _getCustomerProfile(customerId) : null;
            final ctxData = await _getContextDetails(ctxType, ctxId);

            final rawName = (user?['user_name'] ?? '').toString().trim();
            final shortCust = customerId.length > 5
                ? customerId.substring(0, 5).toUpperCase()
                : customerId.toUpperCase();

            list.add(MerchantConversation(
              id: r['id'].toString(),
              customerId: customerId,
              ownerUserId: ownerId,
              businessId: businessId,
              customerName: rawName.isNotEmpty ? rawName : 'Pelanggan #$shortCust',
              customerAvatarUrl: user?['user_avatar_url']?.toString(),
              customerPhone: user?['user_phone']?.toString(),
              contextType: ctxType,
              contextId: ctxId,
              contextRef: ctxData?['ref']?.toString(),
              contextStatus: ctxData?['status']?.toString(),
              lastMessage: r['last_message']?.toString(),
              lastMessageSenderId: r['last_message_sender_id']?.toString(),
              lastMessageIsRead: r['last_message_is_read'] == true,
              unreadCount: unread,
              updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? '')?.toLocal() ??
                  DateTime.now(),
            ));
          }

          totalUnreadNotifier.value = totalUnread;
          return list;
        });
  }

  static Future<List<MerchantMessage>> getMessages(
    String conversationId, {
    int limit = 60,
    int offset = 0,
  }) async {
    final res = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List)
        .map((e) => MerchantMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static RealtimeChannel subscribeToThread(
    String conversationId, {
    required void Function(MerchantMessage) onNewMessage,
    required void Function(MerchantMessage) onMessageUpdated,
    void Function(String deletedId)? onMessageDeleted,
    required void Function(String userId, bool isTyping) onTypingStatus,
  }) {
    return _supabase
        .channel('public:chat:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onNewMessage(MerchantMessage.fromJson(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessageUpdated(MerchantMessage.fromJson(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final oldId = payload.oldRecord['id']?.toString();
            if (oldId != null && onMessageDeleted != null) {
              onMessageDeleted(oldId);
            }
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final uid = payload['user_id']?.toString();
            final isTyping = payload['is_typing'] == true;
            if (uid != null) onTypingStatus(uid, isTyping);
          },
        )
        .subscribe();
  }

  static Future<MerchantMessage> sendTextMessage({
    required String conversationId,
    required String content,
    Map<String, dynamic>? replyToMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await ensureCurrentMerchantInUsers();

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': content,
      'message_type': 'text',
      'is_read': false,
      if (replyToMessage != null) 'reply_to_message': replyToMessage,
    };

    final res = await _supabase.from('messages').insert(payload).select().single();
    await _syncConversationPreview(
      conversationId: conversationId,
      senderId: uid,
      lastMessage: content,
    );
    return MerchantMessage.fromJson(Map<String, dynamic>.from(res));
  }

  static Future<MerchantMessage> sendImageMessage({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    Map<String, dynamic>? replyToMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await ensureCurrentMerchantInUsers();

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final mimeType = ext == 'png'
        ? 'image/png'
        : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';
    final folder = 'chat/$conversationId';

    final imageUrl = await R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: safeName,
      folder: folder,
      mimeType: mimeType,
    );

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': 'Photo',
      'image_url': imageUrl,
      'message_type': 'image',
      'file_name': safeName,
      'file_size': bytes.lengthInBytes,
      'is_read': false,
      if (replyToMessage != null) 'reply_to_message': replyToMessage,
    };

    final res = await _supabase.from('messages').insert(payload).select().single();
    await _syncConversationPreview(
      conversationId: conversationId,
      senderId: uid,
      lastMessage: '📷 Photo',
    );
    return MerchantMessage.fromJson(Map<String, dynamic>.from(res));
  }

  static Future<MerchantMessage> sendVideoMessage({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    Map<String, dynamic>? replyToMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await ensureCurrentMerchantInUsers();

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';
    final mimeType = ext == 'mov'
        ? 'video/quicktime'
        : (ext == 'webm' ? 'video/webm' : 'video/mp4');
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';
    final folder = 'chat/$conversationId';

    final videoUrl = await R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: safeName,
      folder: folder,
      mimeType: mimeType,
    );

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': 'Video',
      'image_url': videoUrl,
      'message_type': 'video',
      'file_name': fileName,
      'file_size': bytes.lengthInBytes,
      'is_read': false,
      if (replyToMessage != null) 'reply_to_message': replyToMessage,
    };

    final res = await _supabase.from('messages').insert(payload).select().single();
    await _syncConversationPreview(
      conversationId: conversationId,
      senderId: uid,
      lastMessage: '🎬 Video',
    );
    return MerchantMessage.fromJson(Map<String, dynamic>.from(res));
  }

  static Future<MerchantMessage> sendFileMessage({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    Map<String, dynamic>? replyToMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    await ensureCurrentMerchantInUsers();

    final lower = fileName.toLowerCase();
    final mimeType = lower.endsWith('.pdf')
        ? 'application/pdf'
        : (lower.endsWith('.csv')
            ? 'text/csv'
            : (lower.endsWith('.txt') ? 'text/plain' : 'application/octet-stream'));
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final folder = 'chat/$conversationId';

    final fileUrl = await R2StorageService().uploadMedia(
      bytes: bytes,
      fileName: safeName,
      folder: folder,
      mimeType: mimeType,
    );

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': 'File',
      'image_url': fileUrl,
      'message_type': 'file',
      'file_name': fileName,
      'file_size': bytes.lengthInBytes,
      'is_read': false,
      if (replyToMessage != null) 'reply_to_message': replyToMessage,
    };

    final res = await _supabase.from('messages').insert(payload).select().single();
    await _syncConversationPreview(
      conversationId: conversationId,
      senderId: uid,
      lastMessage: '📎 $fileName',
    );
    return MerchantMessage.fromJson(Map<String, dynamic>.from(res));
  }

  static Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);
  }

  static Future<void> deleteConversation(String conversationId) async {
    await _supabase.from('messages').delete().eq('conversation_id', conversationId);
    await _supabase.from('conversations').delete().eq('id', conversationId);
  }

  static Future<void> markAsRead(String conversationId) async {
    try {
      await _supabase.rpc(
        'mark_business_conversation_read',
        params: {
          'p_conversation_id': conversationId,
          'p_viewer_role': 'business',
        },
      );
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
    try {
      await _supabase
          .from('conversations')
          .update({'business_unread_count': 0})
          .eq('id', conversationId);
    } catch (_) {}
  }

  static Future<String?> openOrCreateCustomerConversation({
    required String businessId,
    required String customerId,
    String? contextType,
    String? contextId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || customerId.trim().isEmpty) return null;

    await ensureCurrentMerchantInUsers(businessId: businessId);

    final validContextId = (contextId != null && _uuidRegex.hasMatch(contextId.trim()))
        ? contextId.trim()
        : null;

    try {
      final res = await _supabase.rpc(
        'merchant_open_conversation',
        params: {
          'p_business_id': businessId,
          'p_customer_id': customerId.trim(),
          if (contextType != null) 'p_context_type': contextType,
          if (validContextId != null) 'p_context_id': validContextId,
        },
      );
      if (res is Map && res['id'] != null) {
        return res['id'].toString();
      }
      if (res is List && res.isNotEmpty && res.first is Map && res.first['id'] != null) {
        return res.first['id'].toString();
      }
    } catch (rpcErr) {
      debugPrint('[MerchantChatService] merchant_open_conversation RPC failed, trying direct fallback: $rpcErr');
    }

    // Direct Fallback: query or insert conversation row directly
    try {
      final existing = await _supabase
          .from('conversations')
          .select('id')
          .eq('user1_id', customerId.trim())
          .eq('business_id', businessId)
          .limit(1)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        return existing['id'].toString();
      }

      final inserted = await _supabase
          .from('conversations')
          .insert({
            'user1_id': customerId.trim(),
            'user2_id': uid,
            'business_id': businessId,
            'context_type': contextType ?? 'general',
            if (validContextId != null) 'context_id': validContextId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      return inserted['id']?.toString();
    } catch (directErr) {
      debugPrint('[MerchantChatService] Direct fallback failed: $directErr');
    }

    return null;
  }

  static Future<String> confirmOrderOrBooking({
    required String sourceType,
    required String rawId,
    required String businessId,
    required String businessName,
    String? customerId,
    required String notifTitle,
    required String notifMessage,
  }) async {
    final targetStatus = sourceType == 'booking' ? 'confirmed' : 'preparing';
    final table = sourceType == 'booking' ? 'bookings' : 'orders';

    await _supabase.from(table).update({'status': targetStatus}).eq('id', rawId);
    invalidateContextCache(sourceType, rawId);

    if (customerId != null && customerId.isNotEmpty) {
      try {
        await _supabase.from('notifications').insert({
          'user_id': customerId,
          'business_id': businessId,
          'title': notifTitle,
          'message': notifMessage,
          'type': sourceType == 'booking' ? 'tempahan' : 'pesanan',
          'reference_id': rawId,
          'is_read': false,
        });
      } catch (_) {}
    }
    return targetStatus;
  }
}
