import 'dart:async';
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

  Future<void> _selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId && _threadChannel != null) {
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape || media.size.width > media.size.height;
    final isDesktop = media.size.width >= 768 || isLandscape;
    final active = _activeConversation;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: active != null && !isDesktop ? active.customerName : 'inbox.title'.tr(),
      subtitle: active != null && !isDesktop
          ? (_isOtherTyping
              ? 'inbox.typing'.tr()
              : (active.contextRef ?? 'inbox.customer_chat_subtitle'.tr()))
          : 'inbox.subtitle'.tr(),
      onBack: () {
        if (active != null && !isDesktop) {
          _threadChannel?.unsubscribe();
          _threadChannel = null;
          setState(() {
            _activeConversationId = null;
            _messages = [];
            _replyingTo = null;
            _isOtherTyping = false;
            _showThreadSearch = false;
            _threadSearchQuery = '';
          });
        } else {
          Navigator.pop(context);
        }
      },
      actionItems: [
        if (active != null) ...[
          GlassNavPillItem(
            icon: Icons.search_rounded,
            tooltip: 'inbox.search_in_chat'.tr(),
            onTap: () => setState(() {
              _showThreadSearch = !_showThreadSearch;
              if (!_showThreadSearch) {
                _threadSearchQuery = '';
                _threadSearchController.clear();
              }
            }),
          ),
          if (active.customerPhone != null && active.customerPhone!.isNotEmpty)
            GlassNavPillItem(
              icon: Icons.chat_rounded,
              tooltip: 'inbox.whatsapp_customer'.tr(),
              onTap: () => _whatsappCustomer(active.customerPhone),
            ),
          GlassNavPillItem(
            icon: Icons.phone_rounded,
            tooltip: 'inbox.call_customer'.tr(),
            onTap: () => _callCustomer(active.customerPhone),
          ),
          GlassNavPillItem(
            icon: Icons.delete_outline_rounded,
            tooltip: 'inbox.delete_chat_title'.tr(),
            onTap: () => _confirmDeleteConversation(active),
          ),
        ],
      ],
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
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'inbox.search_chats'.tr(),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.45), size: 19),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.45), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
              ),
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

    return ListView.builder(
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

    return Column(
      children: [
        if (showDesktopHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121220),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  backgroundImage: conv.customerAvatarUrl != null && conv.customerAvatarUrl!.isNotEmpty
                      ? NetworkImage(conv.customerAvatarUrl!)
                      : null,
                  child: conv.customerAvatarUrl == null || conv.customerAvatarUrl!.isEmpty
                      ? Text(
                          conv.customerName.isNotEmpty ? conv.customerName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.customerName,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (_isOtherTyping)
                        Text(
                          'inbox.typing'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (conv.customerPhone != null && conv.customerPhone!.isNotEmpty)
                        Text(
                          conv.customerPhone!,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'inbox.search_in_chat'.tr(),
                  icon: Icon(
                    Icons.search_rounded,
                    color: _showThreadSearch ? const Color(0xFF42A5F5) : Colors.white70,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    _showThreadSearch = !_showThreadSearch;
                    if (!_showThreadSearch) {
                      _threadSearchQuery = '';
                      _threadSearchController.clear();
                    }
                  }),
                ),
                if (conv.customerPhone != null && conv.customerPhone!.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'inbox.whatsapp_customer'.tr(),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedWhatsapp,
                      color: Color(0xFF25D366),
                      size: 20,
                    ),
                    onPressed: () => _whatsappCustomer(conv.customerPhone),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () => _callCustomer(conv.customerPhone),
                    icon: const Icon(Icons.phone_rounded, size: 15),
                    label: Text('inbox.call_customer'.tr(), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'inbox.delete_chat_title'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteConversation(conv),
                ),
              ],
            ),
          ),

        // In-Thread Message Search Bar
        if (_showThreadSearch)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141426),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: TextField(
              controller: _threadSearchController,
              autofocus: true,
              onChanged: (v) => setState(() => _threadSearchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'inbox.search_in_chat'.tr(),
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF42A5F5), size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () => setState(() {
                    _showThreadSearch = false;
                    _threadSearchQuery = '';
                    _threadSearchController.clear();
                  }),
                ),
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                ),
              ),
            ),
          ),

        // Pinned Order / Booking Context Banner
        if (hasContext && conv.contextRef != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF141426),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (isBooking ? const Color(0xFF10B981) : const Color(0xFFF9C80E))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBooking ? Icons.calendar_month_rounded : Icons.receipt_long_rounded,
                    color: isBooking ? const Color(0xFF10B981) : const Color(0xFFF9C80E),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conv.contextRef!,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAlreadyConfirmed ? Colors.white54 : const Color(0xFF44CF6C),
                    side: BorderSide(
                      color: isAlreadyConfirmed ? Colors.white24 : const Color(0xFF44CF6C),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (isAlreadyConfirmed || _isUpdatingStatus)
                      ? null
                      : () => _confirmContextAction(conv),
                  icon: Icon(
                    isAlreadyConfirmed ? Icons.verified_rounded : Icons.check_rounded,
                    size: 14,
                  ),
                  label: Text(actionLabel, style: const TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),

        // Message List
        Expanded(
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: visibleMessages.length + (_isOtherTyping ? 1 : 0),
                      itemBuilder: (ctx, idx) {
                        if (_isOtherTyping) {
                          if (idx == 0) {
                            return _buildTypingBubble();
                          }
                          idx--;
                        }

                        final msg = visibleMessages[idx];
                        final isMerchant = msg.senderId != conv.customerId;
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

                        final bubble = _buildMessageBubble(msg, isMerchant);
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

        // Quick Reply Chips
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickReplyKeys.length,
            itemBuilder: (ctx, idx) {
              final chipText = _quickReplyKeys[idx].tr();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(chipText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  backgroundColor: const Color(0xFF151526),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () => _sendMessage(chipText),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Reply Preview Banner
        if (_replyingTo != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF192033),
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: Color(0xFF42A5F5), width: 3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingTo!.senderId == _currentUserId
                            ? 'inbox.you_label'.tr()
                            : conv.customerName,
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

        // Input Bar
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF121220),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'inbox.attach_media_tooltip'.tr(),
                icon: _isUploadingMedia
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)),
                      )
                    : Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                onPressed: _isUploadingMedia ? null : _showAttachmentSheet,
              ),
              IconButton(
                tooltip: 'inbox.attach_gallery'.tr(),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  color: Colors.white60,
                  size: 21,
                ),
                onPressed: _isUploadingMedia ? null : _pickAndSendMultiImages,
              ),
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
                    hintText: 'inbox.type_message'.tr(),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _sendMessage(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF2563EB)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Text(
          'inbox.typing'.tr(),
          style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MerchantMessage msg, bool isMerchant) {
    final timeStr = DateFormat('HH:mm').format(msg.createdAt);
    final isMedia = msg.isImage || msg.isVideo;

    return GestureDetector(
      onLongPress: () => _showMessageActions(msg, isMerchant),
      child: Align(
        alignment: isMerchant ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMerchant ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(bottom: msg.status == 'failed' ? 4 : 10),
              padding: isMedia
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                gradient: isMerchant
                    ? const LinearGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMerchant ? null : const Color(0xFF1B1B2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMerchant ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMerchant ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isMerchant ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMerchant ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.replyToMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: isMerchant ? Colors.white70 : const Color(0xFF42A5F5),
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (msg.replyToMessage!['sender_name'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (msg.replyToMessage!['content'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
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
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 270),
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
                            color: isMerchant ? Colors.white70 : Colors.white38,
                            fontSize: 10,
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
                padding: const EdgeInsets.only(bottom: 8),
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
