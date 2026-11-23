import 'dart:async';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../../settings/data/business_service.dart';
import '../data/merchant_chat_service.dart';
import '../data/merchant_dispute_service.dart';
import 'merchant_dispute_room_page.dart';

// ============================================================
// MerchantInboxPage — Real-Time Two-Way Customer Chat Inbox
// ============================================================

class MerchantInboxPage extends StatefulWidget {
  final String? initialConversationId;
  final String? initialCustomerId;
  final String? initialContextType;
  final String? initialContextId;

  const MerchantInboxPage({
    super.key,
    this.initialConversationId,
    this.initialCustomerId,
    this.initialContextType,
    this.initialContextId,
  });

  @override
  State<MerchantInboxPage> createState() => _MerchantInboxPageState();
}

class _MerchantInboxPageState extends State<MerchantInboxPage> {
  static const List<String> _filterKeys = ['all', 'unread', 'orders', 'bookings'];
  static const List<String> _quickReplyKeys = [
    'inbox.quick_reply_1',
    'inbox.quick_reply_2',
    'inbox.quick_reply_3',
    'inbox.quick_reply_4',
    'inbox.quick_reply_5',
  ];

  int _selectedFilter = 0;
  String _searchQuery = '';
  String _threadSearchQuery = '';
  bool _showThreadSearch = false;
  bool _showQuickReplies = true;
  String? _businessId;
  String _businessName = 'Ngam Business';
  bool _isInitializing = true;

  StreamSubscription<List<MerchantConversation>>? _convSub;
  List<MerchantConversation> _conversations = [];
  String? _activeConversationId;

  // Active thread state
  List<MerchantMessage> _messages = [];
  bool _isLoadingMessages = false;
  bool _isOtherTyping = false;
  bool _isUploadingMedia = false;
  bool _isUpdatingStatus = false;
  MerchantMessage? _replyingTo;
  final Map<String, Uint8List> _failedMediaBytes = {};
  final Map<String, String> _failedMediaNames = {};

  RealtimeChannel? _threadChannel;
  Timer? _typingSendTimer;
  Timer? _typingDisplayTimer;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _threadSearchController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _msgScrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  MerchantConversation? get _activeConversation {
    if (_activeConversationId == null) return null;
    for (final c in _conversations) {
      if (c.id == _activeConversationId) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initInbox();
  }

  Future<void> _initInbox() async {
    try {
      final profile = BusinessService.cachedProfile ?? await BusinessService().getBusinessProfile();
      final businessId = profile?['id']?.toString();
      if (businessId == null || businessId.isEmpty) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }

      _businessId = businessId;
      _businessName = (profile?['business_name'] ?? 'Ngam Business').toString();

      await MerchantChatService.ensureCurrentMerchantInUsers(
        businessId: businessId,
        businessName: _businessName,
        businessLogoUrl: profile?['business_logo_url']?.toString(),
        businessPhone: profile?['business_phone']?.toString(),
      );

      String? targetConvId = widget.initialConversationId;
      if (targetConvId == null &&
          widget.initialCustomerId != null &&
          widget.initialCustomerId!.isNotEmpty) {
        try {
          targetConvId = await MerchantChatService.openOrCreateCustomerConversation(
            businessId: businessId,
            customerId: widget.initialCustomerId!,
            contextType: widget.initialContextType,
            contextId: widget.initialContextId,
          );
        } catch (e) {
          debugPrint('[MerchantInboxPage] openOrCreateCustomerConversation error: $e');
        }
      }

      _convSub = MerchantChatService.streamBusinessConversations(businessId).listen(
        (list) {
          if (!mounted) return;
          setState(() {
            _conversations = list;
            _isInitializing = false;
          });

          if (targetConvId != null && list.any((c) => c.id == targetConvId)) {
            final idToOpen = targetConvId!;
            targetConvId = null;
            _selectConversation(idToOpen);
          } else if (_activeConversationId == null && list.isNotEmpty) {
            final media = MediaQuery.of(context);
            final isDesktop = media.size.width >= 768 ||
                media.orientation == Orientation.landscape ||
                media.size.width > media.size.height;
            if (isDesktop) {
              _selectConversation(list.first.id);
            }
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isInitializing = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _selectConversation(String conversationId, {bool forceReload = false}) async {
    if (!forceReload && _activeConversationId == conversationId && _threadChannel != null) {
      await MerchantChatService.markAsRead(conversationId);
      return;
    }

    _typingDisplayTimer?.cancel();
    await _threadChannel?.unsubscribe();
    _threadChannel = null;

    setState(() {
      _activeConversationId = conversationId;
      _messages = [];
      _isLoadingMessages = true;
      _isOtherTyping = false;
      _replyingTo = null;
      _showThreadSearch = false;
      _threadSearchQuery = '';
      _threadSearchController.clear();
    });

    // Restore draft if any
    SharedPreferences.getInstance().then((prefs) {
      final draft = prefs.getString('merchant_draft_$conversationId') ?? '';
      if (mounted && _activeConversationId == conversationId) {
        _msgController.text = draft;
      }
    });

    await MerchantChatService.markAsRead(conversationId);

    try {
      final msgs = await MerchantChatService.getMessages(conversationId);
      if (mounted && _activeConversationId == conversationId) {
        setState(() {
          _messages = msgs;
          _isLoadingMessages = false;
        });
      }
    } catch (_) {
      if (mounted && _activeConversationId == conversationId) {
        setState(() => _isLoadingMessages = false);
      }
    }

    _threadChannel = MerchantChatService.subscribeToThread(
      conversationId,
      onNewMessage: (newMsg) {
        if (!mounted || _activeConversationId != conversationId) return;
        setState(() {
          final existingIdx = _messages.indexWhere(
            (m) => m.id == newMsg.id || (m.status == 'sending' && m.content == newMsg.content),
          );
          if (existingIdx != -1) {
            _messages[existingIdx] = newMsg;
          } else {
            _messages.insert(0, newMsg);
          }
        });
        if (newMsg.senderId != _currentUserId) {
          MerchantChatService.markAsRead(conversationId);
        }
      },
      onMessageUpdated: (updated) {
        if (!mounted || _activeConversationId != conversationId) return;
        final idx = _messages.indexWhere((m) => m.id == updated.id);
        if (idx != -1) {
          setState(() => _messages[idx] = updated);
        }
      },
      onMessageDeleted: (deletedId) {
        if (!mounted || _activeConversationId != conversationId) return;
        setState(() {
          _messages.removeWhere((m) => m.id == deletedId);
        });
      },
      onTypingStatus: (uid, isTyping) {
        if (!mounted || _activeConversationId != conversationId) return;
        if (uid == _currentUserId) return;
        setState(() => _isOtherTyping = isTyping);
        if (isTyping) {
          _typingDisplayTimer?.cancel();
          _typingDisplayTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isOtherTyping = false);
          });
        }
      },
    );
  }

  void _onInputChanged(String text) {
    final convId = _activeConversationId;
    if (convId != null) {
      SharedPreferences.getInstance().then((prefs) {
        if (text.trim().isEmpty) {
          prefs.remove('merchant_draft_$convId');
        } else {
          prefs.setString('merchant_draft_$convId', text);
        }
      });
    }
    if (_threadChannel == null || convId == null) return;
    _typingSendTimer?.cancel();
    _threadChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _currentUserId, 'is_typing': true},
    );
    _typingSendTimer = Timer(const Duration(seconds: 2), () {
      _threadChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': _currentUserId, 'is_typing': false},
      );
    });
  }

  Map<String, dynamic>? _buildReplyPayload(MerchantConversation conv) {
    if (_replyingTo == null) return null;
    final isMe = _replyingTo!.senderId == _currentUserId;
    return {
      'id': _replyingTo!.id,
      'content': _replyingTo!.content,
      'sender_name': isMe ? 'inbox.you_label'.tr() : conv.customerName,
    };
  }

  Future<void> _sendMessage([String? quickText]) async {
    final conv = _activeConversation;
    final text = (quickText ?? _msgController.text).trim();
    if (text.isEmpty || conv == null) return;

    final replyPayload = quickText == null ? _buildReplyPayload(conv) : null;

    if (quickText == null) {
      _msgController.clear();
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('merchant_draft_${conv.id}');
      });
    }
    setState(() => _replyingTo = null);

    final pending = MerchantMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conv.id,
      senderId: _currentUserId,
      content: text,
      createdAt: DateTime.now(),
      status: 'sending',
      replyToMessage: replyPayload,
    );

    setState(() => _messages.insert(0, pending));
    if (_msgScrollController.hasClients) {
      _msgScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    try {
      final actual = await MerchantChatService.sendTextMessage(
        conversationId: conv.id,
        content: text,
        replyToMessage: replyPayload,
      );
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == pending.id);
          if (idx != -1) _messages[idx] = actual;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == pending.id);
          if (idx != -1) _messages[idx] = pending.copyWith(status: 'failed');
        });
        showGlassToast(context, 'inbox.send_failed'.tr(), isError: true);
      }
    }
  }

  Future<void> _sendSingleImageBytes(
    MerchantConversation conv,
    Uint8List bytes,
    String fileName, {
    Map<String, dynamic>? replyPayload,
  }) async {
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final pending = MerchantMessage(
      id: tempId,
      conversationId: conv.id,
      senderId: _currentUserId,
      content: 'Photo',
      messageType: 'image',
      fileName: fileName,
      fileSize: bytes.lengthInBytes,
      createdAt: DateTime.now(),
      status: 'sending',
      replyToMessage: replyPayload,
    );
    setState(() => _messages.insert(0, pending));

    try {
      final actual = await MerchantChatService.sendImageMessage(
        conversationId: conv.id,
        bytes: bytes,
        fileName: fileName,
        replyToMessage: replyPayload,
      );
      _failedMediaBytes.remove(tempId);
      _failedMediaNames.remove(tempId);
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == pending.id);
          if (idx != -1) _messages[idx] = actual;
        });
      }
    } catch (_) {
      _failedMediaBytes[tempId] = bytes;
      _failedMediaNames[tempId] = fileName;
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == pending.id);
          if (idx != -1) _messages[idx] = pending.copyWith(status: 'failed');
        });
        showGlassToast(context, 'inbox.image_send_failed'.tr(), isError: true);
      }
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final conv = _activeConversation;
    if (conv == null || _isUploadingMedia) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 78,
      );
      if (picked == null) return;

      final replyPayload = _buildReplyPayload(conv);
      setState(() {
        _isUploadingMedia = true;
        _replyingTo = null;
      });
      final bytes = await picked.readAsBytes();
      await _sendSingleImageBytes(conv, bytes, picked.name, replyPayload: replyPayload);
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'inbox.image_send_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendMultiImages() async {
    final conv = _activeConversation;
    if (conv == null || _isUploadingMedia) return;

    try {
      final pickedList = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 78,
      );
      if (pickedList.isEmpty) return;

      final replyPayload = _buildReplyPayload(conv);
      setState(() {
        _isUploadingMedia = true;
        _replyingTo = null;
      });

      for (int i = 0; i < pickedList.length; i++) {
        final item = pickedList[i];
        final bytes = await item.readAsBytes();
        await _sendSingleImageBytes(
          conv,
          bytes,
          item.name,
          replyPayload: i == 0 ? replyPayload : null,
        );
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'inbox.image_send_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    final conv = _activeConversation;
    if (conv == null || _isUploadingMedia) return;

    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked == null) return;

      final replyPayload = _buildReplyPayload(conv);
      setState(() {
        _isUploadingMedia = true;
        _replyingTo = null;
      });
      final bytes = await picked.readAsBytes();
      final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';

      final pending = MerchantMessage(
        id: tempId,
        conversationId: conv.id,
        senderId: _currentUserId,
        content: 'Video',
        messageType: 'video',
        fileName: picked.name,
        fileSize: bytes.lengthInBytes,
        createdAt: DateTime.now(),
        status: 'sending',
        replyToMessage: replyPayload,
      );
      setState(() => _messages.insert(0, pending));

      try {
        final actual = await MerchantChatService.sendVideoMessage(
          conversationId: conv.id,
          bytes: bytes,
          fileName: picked.name,
          replyToMessage: replyPayload,
        );
        _failedMediaBytes.remove(tempId);
        _failedMediaNames.remove(tempId);
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == pending.id);
            if (idx != -1) _messages[idx] = actual;
          });
        }
      } catch (_) {
        _failedMediaBytes[tempId] = bytes;
        _failedMediaNames[tempId] = picked.name;
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == pending.id);
            if (idx != -1) _messages[idx] = pending.copyWith(status: 'failed');
          });
          showGlassToast(context, 'inbox.video_send_failed'.tr(), isError: true);
        }
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'inbox.video_send_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _retryMessage(MerchantMessage msg) async {
    final conv = _activeConversation;
    if (conv == null) return;

    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) _messages[idx] = msg.copyWith(status: 'sending');
    });

    try {
      MerchantMessage actual;
      if (msg.isVideo && _failedMediaBytes.containsKey(msg.id)) {
        actual = await MerchantChatService.sendVideoMessage(
          conversationId: conv.id,
          bytes: _failedMediaBytes[msg.id]!,
          fileName: _failedMediaNames[msg.id] ?? 'video.mp4',
          replyToMessage: msg.replyToMessage,
        );
        _failedMediaBytes.remove(msg.id);
        _failedMediaNames.remove(msg.id);
      } else if (msg.isImage && _failedMediaBytes.containsKey(msg.id)) {
        actual = await MerchantChatService.sendImageMessage(
          conversationId: conv.id,
          bytes: _failedMediaBytes[msg.id]!,
          fileName: _failedMediaNames[msg.id] ?? 'photo.jpg',
          replyToMessage: msg.replyToMessage,
        );
        _failedMediaBytes.remove(msg.id);
        _failedMediaNames.remove(msg.id);
      } else if (msg.isFile && _failedMediaBytes.containsKey(msg.id)) {
        actual = await MerchantChatService.sendFileMessage(
          conversationId: conv.id,
          bytes: _failedMediaBytes[msg.id]!,
          fileName: _failedMediaNames[msg.id] ?? 'document.pdf',
          replyToMessage: msg.replyToMessage,
        );
        _failedMediaBytes.remove(msg.id);
        _failedMediaNames.remove(msg.id);
      } else {
        actual = await MerchantChatService.sendTextMessage(
          conversationId: conv.id,
          content: msg.content,
          replyToMessage: msg.replyToMessage,
        );
      }

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) _messages[idx] = actual;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) _messages[idx] = msg.copyWith(status: 'failed');
        });
        showGlassToast(context, 'inbox.send_failed'.tr(), isError: true);
      }
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera01,
                    color: Color(0xFF42A5F5),
                    size: 22,
                  ),
                ),
                title: Text(
                  'inbox.attach_camera'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedImage01,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                title: Text(
                  'inbox.attach_gallery'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendMultiImages();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedVideo01,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                title: Text(
                  'inbox.attach_video'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedVideoReplay,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                title: Text(
                  'inbox.attach_record_video'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendVideo(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(MerchantMessage msg, bool isMerchant) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xFF42A5F5)),
                title: Text(
                  'inbox.action_reply'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = msg);
                },
              ),
              if (!msg.isImage && !msg.isVideo && !msg.isFile && msg.content.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: Text(
                    'inbox.action_copy'.tr(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: msg.content));
                    showGlassToast(context, 'inbox.copied_toast'.tr());
                  },
                ),
              if (msg.status == 'failed')
                ListTile(
                  leading: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                  title: Text(
                    'inbox.action_retry'.tr(),
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _retryMessage(msg);
                  },
                ),
              if (isMerchant)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: Text(
                    'inbox.action_delete_msg'.tr(),
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.removeWhere((m) => m.id == msg.id);
                    });
                    if (!msg.id.startsWith('temp_')) {
                      try {
                        await MerchantChatService.deleteMessage(msg.id);
                      } catch (_) {}
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(MerchantConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'inbox.delete_chat_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'inbox.delete_chat_desc'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await MerchantChatService.deleteConversation(conv.id);
      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.id == conv.id);
          if (_activeConversationId == conv.id) {
            _activeConversationId = null;
            _messages = [];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmContextAction(MerchantConversation conv) async {
    if (_isUpdatingStatus || conv.contextId == null || conv.contextType == null) return;
    if (conv.contextType != 'order' && conv.contextType != 'booking') return;

    setState(() => _isUpdatingStatus = true);
    try {
      final isBooking = conv.contextType == 'booking';
      final newStatus = await MerchantChatService.confirmOrderOrBooking(
        sourceType: conv.contextType!,
        rawId: conv.contextId!,
        businessId: conv.businessId,
        businessName: _businessName,
        customerId: conv.customerId,
        notifTitle: 'inbox.reply_notif_title'.tr(args: [_businessName]),
        notifMessage: isBooking
            ? 'inbox.booking_confirmed_toast'.tr()
            : 'inbox.order_preparing_toast'.tr(),
      );

      if (mounted) {
        setState(() {
          final idx = _conversations.indexWhere((c) => c.id == conv.id);
          if (idx != -1) {
            _conversations[idx] = _conversations[idx].copyWith(contextStatus: newStatus);
          }
        });
        showGlassToast(
          context,
          isBooking
              ? 'inbox.booking_confirmed_toast'.tr()
              : 'inbox.order_preparing_toast'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'inbox.status_update_failed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _callCustomer(String? phone) async {
    final clean = (phone ?? '').replaceAll(RegExp(r'\s+'), '').trim();
    if (clean.isEmpty) {
      if (mounted) showGlassToast(context, 'inbox.no_phone_number'.tr(), isError: true);
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) showGlassToast(context, 'inbox.dialer_error'.tr(), isError: true);
    }
  }

  Future<void> _whatsappCustomer(String? phone) async {
    var clean = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (clean.isEmpty) {
      if (mounted) showGlassToast(context, 'inbox.no_phone_number'.tr(), isError: true);
      return;
    }
    if (clean.startsWith('0')) {
      clean = '60${clean.substring(1)}';
    } else if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showGlassToast(context, 'inbox.dialer_error'.tr(), isError: true);
    }
  }

  Future<void> _telegramCustomer(String? phone) async {
    var clean = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (clean.isEmpty) {
      if (mounted) showGlassToast(context, 'inbox.no_phone_number'.tr(), isError: true);
      return;
    }
    if (clean.startsWith('0')) {
      clean = '+60${clean.substring(1)}';
    } else if (!clean.startsWith('+')) {
      clean = '+$clean';
    }
    final uri = Uri.parse('https://t.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showGlassToast(context, 'inbox.telegram_error'.tr(), isError: true);
    }
  }

  Future<void> _showGlassDropdown({
    required BuildContext anchorContext,
    required List<_GlassDropdownOption> options,
  }) async {
    final RenderBox? box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final Size screen = MediaQuery.of(context).size;

    const double menuWidth = 220;
    final double rightSpace = screen.width - (offset.dx + size.width);
    final double rightPos = rightSpace.clamp(12.0, screen.width - menuWidth - 12.0);
    final double topPos = offset.dy + size.height + 10;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dropdown',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, _, __) {
        return Stack(
          children: [
            Positioned(
              top: topPos,
              right: rightPos,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      width: menuWidth,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141826).withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.42),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(options.length, (i) {
                          final opt = options[i];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (opt.showDividerBefore && i > 0)
                                Divider(
                                  height: 1,
                                  indent: 14,
                                  endIndent: 14,
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(dialogCtx);
                                  opt.onTap();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: opt.color.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: opt.materialIcon != null
                                              ? Icon(
                                                  opt.materialIcon,
                                                  color: opt.color,
                                                  size: 16,
                                                )
                                              : HugeIcon(
                                                  icon: opt.hugeIcon!,
                                                  color: opt.color,
                                                  size: 16,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          opt.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: opt.isDestructive
                                                ? Colors.redAccent
                                                : Colors.white.withValues(alpha: 0.94),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  void _openContactDropdown(BuildContext anchorContext, MerchantConversation conv) {
    _showGlassDropdown(
      anchorContext: anchorContext,
      options: [
        _GlassDropdownOption(
          label: 'inbox.call_customer'.tr(),
          hugeIcon: HugeIcons.strokeRoundedCall02,
          color: const Color(0xFF42A5F5),
          onTap: () => _callCustomer(conv.customerPhone),
        ),
        _GlassDropdownOption(
          label: 'inbox.whatsapp_customer'.tr(),
          hugeIcon: HugeIcons.strokeRoundedWhatsapp,
          color: const Color(0xFF25D366),
          onTap: () => _whatsappCustomer(conv.customerPhone),
        ),
        _GlassDropdownOption(
          label: 'inbox.telegram_customer'.tr(),
          hugeIcon: HugeIcons.strokeRoundedTelegram,
          color: const Color(0xFF229ED9),
          onTap: () => _telegramCustomer(conv.customerPhone),
        ),
      ],
    );
  }

  void _openMoreActionsDropdown(BuildContext anchorContext, MerchantConversation conv) {
    _showGlassDropdown(
      anchorContext: anchorContext,
      options: [
        _GlassDropdownOption(
          label: 'inbox.search_in_chat'.tr(),
          hugeIcon: HugeIcons.strokeRoundedSearch01,
          color: const Color(0xFF42A5F5),
          onTap: () => setState(() {
            _showThreadSearch = !_showThreadSearch;
            if (!_showThreadSearch) {
              _threadSearchQuery = '';
              _threadSearchController.clear();
            }
          }),
        ),
        _GlassDropdownOption(
          label: 'inbox.toggle_quick_replies'.tr(),
          hugeIcon: HugeIcons.strokeRoundedMessage01,
          color: const Color(0xFF38BDF8),
          onTap: () => setState(() => _showQuickReplies = !_showQuickReplies),
        ),
        if (conv.customerPhone != null && conv.customerPhone!.isNotEmpty)
          _GlassDropdownOption(
            label: 'inbox.copy_phone'.tr(),
            hugeIcon: HugeIcons.strokeRoundedCopy01,
            color: const Color(0xFF10B981),
            onTap: () {
              Clipboard.setData(ClipboardData(text: conv.customerPhone!));
              if (mounted) showGlassToast(context, 'inbox.phone_copied_toast'.tr());
            },
          ),
        _GlassDropdownOption(
          label: 'inbox.refresh_chat'.tr(),
          materialIcon: Icons.refresh_rounded,
          color: const Color(0xFFA78BFA),
          onTap: () => _selectConversation(conv.id, forceReload: true),
        ),
        _GlassDropdownOption(
          label: 'inbox.delete_chat_title'.tr(),
          hugeIcon: HugeIcons.strokeRoundedDelete02,
          color: Colors.redAccent,
          isDestructive: true,
          showDividerBefore: true,
          onTap: () => _confirmDeleteConversation(conv),
        ),
      ],
    );
  }

  List<MerchantConversation> get _filteredConversations {
    final q = _searchQuery.trim().toLowerCase();
    return _conversations.where((c) {
      if (_selectedFilter == 1 && c.unreadCount <= 0) return false;
      if (_selectedFilter == 2 && c.contextType != 'order') return false;
      if (_selectedFilter == 3 && c.contextType != 'booking') return false;

      if (q.isNotEmpty) {
        final nameMatch = c.customerName.toLowerCase().contains(q);
        final msgMatch = (c.lastMessage ?? '').toLowerCase().contains(q);
        final refMatch = (c.contextRef ?? '').toLowerCase().contains(q);
        return nameMatch || msgMatch || refMatch;
      }
      return true;
    }).toList();
  }

  List<MerchantMessage> get _filteredMessages {
    final q = _threadSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return _messages;
    return _messages.where((m) {
      return m.content.toLowerCase().contains(q) ||
          (m.fileName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _filterLabel(String key) {
    switch (key) {
      case 'unread':
        return 'inbox.filter_unread'.tr();
      case 'orders':
        return 'inbox.filter_orders'.tr();
      case 'bookings':
        return 'inbox.filter_bookings'.tr();
      default:
        return 'inbox.filter_all'.tr();
    }
  }

  String _formatConvTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'inbox.yesterday'.tr();
    }
    return DateFormat('dd/MM').format(dt);
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'inbox.today'.tr();
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'inbox.yesterday'.tr();
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _typingSendTimer?.cancel();
    _typingDisplayTimer?.cancel();
    _threadChannel?.unsubscribe();
    _searchController.dispose();
    _threadSearchController.dispose();
    _msgController.dispose();
    _msgScrollController.dispose();
    super.dispose();
  }

  void _closeActiveThread() {
    _threadChannel?.unsubscribe();
    _threadChannel = null;
    setState(() {
      _activeConversationId = null;
      _messages = [];
      _replyingTo = null;
      _isOtherTyping = false;
      _showThreadSearch = false;
      _threadSearchQuery = '';
      _threadSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape || media.size.width > media.size.height;
    final isDesktop = media.size.width >= 768 || isLandscape;
    final active = _activeConversation;

    // On mobile inside an active chat, match Ngam's full-bleed floating glass chat UI
    if (active != null && !isDesktop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _closeActiveThread();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A14),
          resizeToAvoidBottomInset: true,
          body: _buildChatDetail(active, showDesktopHeader: false),
        ),
      );
    }

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: 'inbox.title'.tr(),
      subtitle: 'inbox.subtitle'.tr(),
      onBack: () => Navigator.pop(context),
      body: Padding(
        padding: const EdgeInsets.only(top: 68),
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final active = _activeConversation;
    return Row(
      children: [
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E1A),
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(child: _buildThreadList()),
            ],
          ),
        ),
        Expanded(
          child: active != null ? _buildChatDetail(active, showDesktopHeader: true) : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final active = _activeConversation;
    if (active != null) {
      return _buildChatDetail(active, showDesktopHeader: false);
    }
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(child: _buildThreadList()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    final totalUnread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.54), size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'inbox.search_chats'.tr(),
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.45), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _filterKeys.length,
            itemBuilder: (ctx, idx) {
              final isSel = idx == _selectedFilter;
              final key = _filterKeys[idx];
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF2563EB)])
                        : null,
                    color: isSel ? null : const Color(0xFF151526),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? Colors.transparent : Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _filterLabel(key),
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (key == 'unread' && totalUnread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF42A5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalUnread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThreadList() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
    }

    final list = _filteredConversations;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedChatting01,
                  color: Color(0xFF42A5F5),
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'inbox.no_chats'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'inbox.no_messages_desc'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_businessId != null && _businessId!.isNotEmpty)
          StreamBuilder<List<MerchantDisputeCase>>(
            stream: MerchantDisputeService.watchBusinessDisputes(_businessId!),
            builder: (ctx, snap) {
              final active = (snap.data ?? const <MerchantDisputeCase>[])
                  .where((d) => !d.isResolved)
                  .toList();
              if (active.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  if (active.length == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MerchantDisputeRoomPage(
                          initialDispute: active.first,
                          businessName: _businessName,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MerchantDisputesListPage(
                          businessId: _businessId!,
                          businessName: _businessName,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedShield01,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'dispute.active_disputes_banner'.tr(args: [active.length.toString()]),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFFFBBF24)),
                    ],
                  ),
                ),
              );
            },
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            itemCount: list.length,
            itemBuilder: (ctx, idx) {
        final conv = list[idx];
        final isSel = conv.id == _activeConversationId;
        final unread = conv.unreadCount;
        final initial = conv.customerName.isNotEmpty
            ? conv.customerName.substring(0, 1).toUpperCase()
            : '?';
        final sentByMe = conv.lastMessageSenderId != null &&
            conv.lastMessageSenderId != conv.customerId;

        return GestureDetector(
          onTap: () => _selectConversation(conv.id),
          onLongPress: () => _confirmDeleteConversation(conv),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isSel
                  ? const Color(0xFF1A253A)
                  : (unread > 0 ? const Color(0xFF15182B) : const Color(0xFF131322)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSel
                    ? const Color(0xFF42A5F5)
                    : (unread > 0
                        ? const Color(0xFF42A5F5).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06)),
                width: isSel ? 1.4 : 1.0,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF6C5CE7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        image: conv.customerAvatarUrl != null && conv.customerAvatarUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(conv.customerAvatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: conv.customerAvatarUrl == null || conv.customerAvatarUrl!.isEmpty
                          ? Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (conv.contextType == 'order' || conv.contextType == 'booking')
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: conv.contextType == 'order'
                                ? const Color(0xFFF9C80E)
                                : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF131322), width: 2),
                          ),
                          child: Icon(
                            conv.contextType == 'order'
                                ? Icons.shopping_cart_rounded
                                : Icons.calendar_today_rounded,
                            size: 10,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatConvTime(conv.updatedAt),
                            style: TextStyle(
                              color: unread > 0
                                  ? const Color(0xFF42A5F5)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      if (conv.contextRef != null && conv.contextRef!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          conv.contextRef!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conv.contextType == 'booking'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF9C80E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (sentByMe && conv.lastMessage != null) ...[
                            Icon(
                              conv.lastMessageIsRead ? Icons.done_all_rounded : Icons.done_rounded,
                              size: 14,
                              color: conv.lastMessageIsRead
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conv.lastMessage ?? 'inbox.start_conversation_hint'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread > 0 ? Colors.white : Colors.white60,
                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF42A5F5), Color(0xFF2563EB)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF42A5F5).withValues(alpha: 0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
          ),
        ),
      ],
    );
  }

  Widget _buildChatDetail(MerchantConversation conv, {required bool showDesktopHeader}) {
    final hasContext = conv.contextId != null &&
        conv.contextId!.isNotEmpty &&
        (conv.contextType == 'order' || conv.contextType == 'booking');
    final isBooking = conv.contextType == 'booking';
    final status = (conv.contextStatus ?? 'pending').toLowerCase();
    final isAlreadyConfirmed = isBooking
        ? (status == 'confirmed' || status == 'completed' || status == 'serving')
        : (status == 'preparing' || status == 'ready' || status == 'completed');
    final actionLabel = isBooking
        ? (isAlreadyConfirmed ? 'inbox.slot_confirmed_badge'.tr() : 'inbox.confirm_slot'.tr())
        : (isAlreadyConfirmed ? 'inbox.order_preparing_badge'.tr() : 'inbox.confirm_order'.tr());
    final visibleMessages = _filteredMessages;

    final double topInset = showDesktopHeader ? 0.0 : MediaQuery.of(context).padding.top;
    final double headerClearance = topInset + 72 + (hasContext && conv.contextRef != null ? 58 : 0) + (_showThreadSearch ? 56 : 0);
    final double bottomClearance = (_showQuickReplies ? 136 : 88) + (_replyingTo != null ? 58 : 0);

    return Stack(
      children: [
        // ─── 1. Full-Bleed Message List (scrolls behind floating glass header & input) ───
        Positioned.fill(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
              : visibleMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.waving_hand_rounded, color: Colors.white.withValues(alpha: 0.25), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            'inbox.start_conversation_hint'.tr(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _msgScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(12, headerClearance, 12, bottomClearance),
                      itemCount: visibleMessages.length + (_isOtherTyping ? 1 : 0),
                      itemBuilder: (ctx, idx) {
                        if (_isOtherTyping) {
                          if (idx == 0) {
                            return _buildTypingBubble(conv);
                          }
                          idx--;
                        }

                        final msg = visibleMessages[idx];
                        final isMerchant = msg.senderId != conv.customerId;

                        // Show avatar on last message of an incoming customer group (matching Ngam)
                        bool showAvatar = true;
                        if (idx > 0) {
                          final newer = visibleMessages[idx - 1];
                          if (newer.senderId == msg.senderId) {
                            showAvatar = false;
                          }
                        }

                        bool showDateDivider = false;
                        if (idx == visibleMessages.length - 1) {
                          showDateDivider = true;
                        } else {
                          final older = visibleMessages[idx + 1];
                          if (msg.createdAt.year != older.createdAt.year ||
                              msg.createdAt.month != older.createdAt.month ||
                              msg.createdAt.day != older.createdAt.day) {
                            showDateDivider = true;
                          }
                        }

                        final bubble = _MerchantSwipeToReply(
                          isMe: isMerchant,
                          onSwipe: () {
                            HapticFeedback.lightImpact();
                            setState(() => _replyingTo = msg);
                          },
                          child: _buildMessageBubble(msg, isMerchant, conv, showAvatar: showAvatar),
                        );

                        if (showDateDivider) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Text(
                                    _formatDateDivider(msg.createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              bubble,
                            ],
                          );
                        }
                        return bubble;
                      },
                    ),
        ),

        // ─── 2. Floating Glass Top Header (Exact Ngam Style + Contact & More Glass Dropdowns) ───
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: !showDesktopHeader,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Expanded Glass Pill: [Back] + [Avatar] + [Customer Name]
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.24),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    if (!showDesktopHeader)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _closeActiveThread,
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 10.0),
                                          child: HugeIcon(
                                            icon: HugeIcons.strokeRoundedArrowLeft01,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.22),
                                      backgroundImage: conv.customerAvatarUrl != null && conv.customerAvatarUrl!.isNotEmpty
                                          ? NetworkImage(conv.customerAvatarUrl!)
                                          : null,
                                      child: conv.customerAvatarUrl == null || conv.customerAvatarUrl!.isEmpty
                                          ? Text(
                                              conv.customerName.isNotEmpty ? conv.customerName[0].toUpperCase() : '?',
                                              style: const TextStyle(
                                                color: Color(0xFF42A5F5),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            conv.customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_isOtherTyping)
                                            Text(
                                              'inbox.typing'.tr(),
                                              style: const TextStyle(
                                                color: Color(0xFF42A5F5),
                                                fontSize: 10.5,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right 2-Icon Glass Pill: [Phone/Contact Dropdown | Three-Dot Advanced Dropdown]
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.24),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Builder(
                                    builder: (btnCtx) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _openContactDropdown(btnCtx, conv),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedCall02,
                                          color: Color(0xFF42A5F5),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Builder(
                                    builder: (btnCtx) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _openMoreActionsDropdown(btnCtx, conv),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(
                                          Icons.more_vert_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Glass In-Thread Search Bar (when toggled from 3-dot dropdown)
                if (_showThreadSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.only(left: 16, right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141826).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedSearch01,
                                color: Color(0xFF42A5F5),
                                size: 19,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _threadSearchController,
                                  autofocus: true,
                                  onChanged: (v) => setState(() => _threadSearchQuery = v),
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    hintText: 'inbox.search_in_chat'.tr(),
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13.5),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                onPressed: () => setState(() {
                                  _showThreadSearch = false;
                                  _threadSearchQuery = '';
                                  _threadSearchController.clear();
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Floating Glass Order / Booking Context Banner
                if (hasContext && conv.contextRef != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141826).withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (isBooking ? const Color(0xFF10B981) : const Color(0xFFF9C80E))
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isBooking ? Icons.calendar_month_rounded : Icons.receipt_long_rounded,
                                  color: isBooking ? const Color(0xFF10B981) : const Color(0xFFF9C80E),
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  conv.contextRef!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isAlreadyConfirmed ? Colors.white54 : const Color(0xFF44CF6C),
                                  side: BorderSide(
                                    color: isAlreadyConfirmed ? Colors.white24 : const Color(0xFF44CF6C),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: (isAlreadyConfirmed || _isUpdatingStatus)
                                    ? null
                                    : () => _confirmContextAction(conv),
                                icon: Icon(
                                  isAlreadyConfirmed ? Icons.verified_rounded : Icons.check_rounded,
                                  size: 13,
                                ),
                                label: Text(actionLabel, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ─── 3. Floating Bottom Section (Quick Replies + Reply Preview + Ngam Glass Input Pill) ───
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Glass Quick-Reply Pills (Exact Ngam Style)
                  if (_showQuickReplies) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _quickReplyKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final chipText = _quickReplyKeys[idx].tr();
                          return GestureDetector(
                            onTap: () => _sendMessage(chipText),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.48),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      chipText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Floating Glass Reply Preview Banner
                  if (_replyingTo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141826).withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF42A5F5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'inbox.replying_to'.tr(args: [
                                        _replyingTo!.senderId == _currentUserId
                                            ? 'inbox.you_label'.tr()
                                            : conv.customerName,
                                      ]),
                                      style: const TextStyle(
                                        color: Color(0xFF42A5F5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _replyingTo!.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                onPressed: () => setState(() => _replyingTo = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Floating Glass Input Pill + Floating Blue Glass Send Button (Exact Ngam Style)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.24),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _isUploadingMedia ? null : _showAttachmentSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedAttachment01,
                                        color: Colors.grey.shade400,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextField(
                                      controller: _msgController,
                                      onChanged: _onInputChanged,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      maxLines: 4,
                                      minLines: 1,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      decoration: InputDecoration(
                                        filled: false,
                                        hintText: 'inbox.type_message'.tr(),
                                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isUploadingMedia ? null : () => _sendMessage(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.65),
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: _isUploadingMedia
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const HugeIcon(
                                        icon: HugeIcons.strokeRoundedSent02,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingBubble(MerchantConversation conv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF42A5F5),
            backgroundImage: conv.customerAvatarUrl != null && conv.customerAvatarUrl!.isNotEmpty
                ? NetworkImage(conv.customerAvatarUrl!)
                : null,
            child: conv.customerAvatarUrl == null || conv.customerAvatarUrl!.isEmpty
                ? Text(
                    conv.customerName.isNotEmpty ? conv.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(
              'inbox.typing'.tr(),
              style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    MerchantMessage msg,
    bool isMerchant,
    MerchantConversation conv, {
    bool showAvatar = true,
  }) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);
    final isMedia = msg.isImage || msg.isVideo;

    return GestureDetector(
      onLongPress: () => _showMessageActions(msg, isMerchant),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMerchant ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMerchant && showAvatar) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF42A5F5),
                backgroundImage: conv.customerAvatarUrl != null && conv.customerAvatarUrl!.isNotEmpty
                    ? NetworkImage(conv.customerAvatarUrl!)
                    : null,
                child: conv.customerAvatarUrl == null || conv.customerAvatarUrl!.isEmpty
                    ? Text(
                        conv.customerName.isNotEmpty ? conv.customerName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ] else if (!isMerchant) ...[
              const SizedBox(width: 36),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMerchant ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: msg.status == 'failed' ? 4 : 2),
                    padding: isMedia
                        ? const EdgeInsets.all(6)
                        : const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: isMerchant ? const Color(0xFF42A5F5) : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMerchant || !showAvatar ? 20 : 4),
                        bottomRight: Radius.circular(isMerchant && showAvatar ? 4 : 20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMerchant ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (msg.replyToMessage != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: isMerchant ? Colors.white : const Color(0xFF42A5F5),
                                  width: 3.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (msg.replyToMessage!['sender_name'] ?? '').toString(),
                                  style: TextStyle(
                                    color: isMerchant ? Colors.white : const Color(0xFF42A5F5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  (msg.replyToMessage!['content'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (msg.isVideo && msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
                          _MerchantChatVideoPlayer(videoUrl: msg.imageUrl!)
                        else if (msg.isImage && msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _openImageLightbox(msg.imageUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 280, maxWidth: 270),
                                child: Image.network(
                                  msg.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Icon(Icons.broken_image_rounded, color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (msg.isFile && msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.tryParse(msg.imageUrl!);
                              if (uri != null) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedFile01,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.displayFileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                        if (msg.formattedFileSize.isNotEmpty)
                                          Text(
                                            msg.formattedFileSize,
                                            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            msg.content,
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                          ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: isMedia ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isMerchant ? Colors.white70 : Colors.white54,
                                  fontSize: 10.5,
                                ),
                              ),
                              if (isMerchant) ...[
                                const SizedBox(width: 4),
                                if (msg.status == 'sending')
                                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.white70)
                                else if (msg.status == 'failed')
                                  const Icon(Icons.error_outline_rounded, size: 12, color: Colors.redAccent)
                                else
                                  Icon(
                                    msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                    size: 13,
                                    color: msg.isRead ? const Color(0xFF00E5FF) : Colors.white70,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (msg.status == 'failed')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _retryMessage(msg),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 13, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              'inbox.action_retry'.tr(),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageLightbox(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedChatting01,
              color: Color(0xFF42A5F5),
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'inbox.select_conversation'.tr(),
            style: const TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MerchantChatVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _MerchantChatVideoPlayer({required this.videoUrl});

  @override
  State<_MerchantChatVideoPlayer> createState() => _MerchantChatVideoPlayerState();
}

class _MerchantChatVideoPlayerState extends State<_MerchantChatVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _controller = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(true);
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.videoUrl), mode: LaunchMode.externalApplication),
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Container(
        width: 220,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
    }

    final aspect = _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : (16 / 9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 280),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassDropdownOption {
  final String label;
  final dynamic hugeIcon;
  final IconData? materialIcon;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDividerBefore;

  const _GlassDropdownOption({
    required this.label,
    this.hugeIcon,
    this.materialIcon,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
    this.showDividerBefore = false,
  });
}

class _MerchantSwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isMe;

  const _MerchantSwipeToReply({
    required this.child,
    required this.onSwipe,
    required this.isMe,
  });

  @override
  State<_MerchantSwipeToReply> createState() => _MerchantSwipeToReplyState();
}

class _MerchantSwipeToReplyState extends State<_MerchantSwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  static const double _maxDrag = 60.0;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() => _dragOffset = _anim.value);
      });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _resetDrag() {
    _anim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
          if (widget.isMe) {
            _dragOffset = _dragOffset.clamp(-_maxDrag, 0.0);
          } else {
            _dragOffset = _dragOffset.clamp(0.0, _maxDrag);
          }
        });
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffset.abs() >= _maxDrag * 0.75) {
          widget.onSwipe();
        }
        _resetDrag();
      },
      onHorizontalDragCancel: _resetDrag,
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (_dragOffset.abs() > 10)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedShare01,
                color: Colors.white.withValues(
                  alpha: (_dragOffset.abs() / _maxDrag).clamp(0.0, 0.85),
                ),
                size: 20,
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

