import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/audit_service.dart';
import '../../settings/data/business_service.dart';
import '../models/feed_post_model.dart';

class FeedService {
  final SupabaseClient _client = Supabase.instance.client;
  final BusinessService _businessService = BusinessService();

  Future<String?> _getBusinessId() async {
    final profile = await _businessService.getBusinessProfile();
    return profile?['id']?.toString();
  }

  /// Dapatkan senarai post kedai mengikut penapis ('all', 'published', 'draft', 'pinned')
  Future<List<FeedPostModel>> getPosts({String filter = 'all'}) async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) return [];

      var query = _client
          .from('feed_posts')
          .select()
          .eq('business_id', businessId);

      if (filter == 'published') {
        query = query.eq('status', 'published');
      } else if (filter == 'draft') {
        query = query.eq('status', 'draft');
      } else if (filter == 'pinned') {
        query = query.eq('is_pinned', true);
      }

      final res = await query.order('is_pinned', ascending: false).order('created_at', ascending: false);

      final List<dynamic> data = res as List<dynamic>;
      final List<Map<String, dynamic>> rawMaps =
          data.map((json) => Map<String, dynamic>.from(json as Map)).toList();

      // Selaraskan kiraan komen sebenar daripada jadual feed_comments supaya 100% sama dengan aplikasi Ngam
      final postIds = rawMaps.map((m) => m['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      if (postIds.isNotEmpty) {
        try {
          final commentRows = await _client
              .from('feed_comments')
              .select('id, post_id')
              .inFilter('post_id', postIds);
          final Map<String, int> liveCounts = {};
          for (final r in commentRows) {
            final pid = r['post_id']?.toString() ?? '';
            if (pid.isNotEmpty) {
              liveCounts[pid] = (liveCounts[pid] ?? 0) + 1;
            }
          }
          for (final m in rawMaps) {
            final pid = m['id']?.toString() ?? '';
            if (liveCounts.containsKey(pid)) {
              m['comments_count'] = liveCounts[pid];
            } else {
              m['comments_count'] = 0;
            }
          }
        } catch (_) {}
      }

      return rawMaps.map((json) => FeedPostModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[FeedService] Error fetching posts: $e');
      return [];
    }
  }

  /// Cipta post baharu di feed
  Future<FeedPostModel> createPost({
    required String title,
    String? caption,
    required String mediaUrl,
    String mediaType = 'image',
    String? category,
    String? serviceTag,
    String ctaType = 'queue',
    String ctaText = '⚡ AMBIL GILIRAN',
    String status = 'published',
    bool isPinned = false,
  }) async {
    final businessId = await _getBusinessId();
    if (businessId == null) {
      throw Exception('Profil perniagaan tidak dijumpai.');
    }

    final cleanMedia = mediaUrl.trim().toLowerCase();
    final isVideo = cleanMedia.endsWith('.mp4') ||
        cleanMedia.endsWith('.mov') ||
        cleanMedia.endsWith('.webm') ||
        cleanMedia.contains('/video/') ||
        cleanMedia.contains('.mp4?') ||
        mediaType == 'video';
    final effectiveMediaType = isVideo ? 'video' : mediaType;

    final payload = {
      'business_id': businessId,
      'title': title,
      'caption': caption,
      'media_url': mediaUrl,
      'media_type': effectiveMediaType,
      'category': category,
      'service_tag': serviceTag,
      'cta_type': ctaType,
      'cta_text': ctaText,
      'status': status,
      'is_pinned': isPinned,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final res = await _client.from('feed_posts').insert(payload).select().single();
    final newPost = FeedPostModel.fromJson(Map<String, dynamic>.from(res));

    // Rekod ke audit log
    await AuditService.log(
      action: 'FEED_POST_CREATED',
      severity: 'info',
      targetType: 'feed_post',
      targetId: newPost.id,
      description: 'Post baharu diterbitkan di Ngam Feed: "$title"',
      metadata: {'status': status, 'cta': ctaText, 'serviceTag': serviceTag},
    );

    return newPost;
  }

  /// Kemaskini post sedia ada
  Future<FeedPostModel> updatePost({
    required String postId,
    required String title,
    String? caption,
    required String mediaUrl,
    String mediaType = 'image',
    String? category,
    String? serviceTag,
    String ctaType = 'queue',
    String ctaText = '⚡ AMBIL GILIRAN',
    String status = 'published',
    bool? isPinned,
  }) async {
    final Map<String, dynamic> payload = {
      'title': title,
      'caption': caption,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'category': category,
      'service_tag': serviceTag,
      'cta_type': ctaType,
      'cta_text': ctaText,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (isPinned != null) {
      payload['is_pinned'] = isPinned;
    }

    final res = await _client
        .from('feed_posts')
        .update(payload)
        .eq('id', postId)
        .select()
        .single();

    final updated = FeedPostModel.fromJson(Map<String, dynamic>.from(res));

    await AuditService.log(
      action: 'FEED_POST_UPDATED',
      severity: 'info',
      targetType: 'feed_post',
      targetId: postId,
      description: 'Post Feed ID $postId telah dikemas kini: "$title"',
    );

    return updated;
  }

  /// Padam post dari feed
  Future<void> deletePost(String postId, String title) async {
    await _client.from('feed_posts').delete().eq('id', postId);

    await AuditService.log(
      action: 'FEED_POST_DELETED',
      severity: 'warning',
      targetType: 'feed_post',
      targetId: postId,
      description: 'Post dipadam daripada Ngam Feed: "$title"',
    );
  }

  /// Pin atau unpin post
  Future<void> togglePin(String postId, bool isPinned, String title) async {
    await _client.from('feed_posts').update({
      'is_pinned': isPinned,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);

    await AuditService.log(
      action: isPinned ? 'FEED_POST_PINNED' : 'FEED_POST_UNPINNED',
      severity: 'info',
      targetType: 'feed_post',
      targetId: postId,
      description: isPinned
          ? 'Post "$title" disematkan ke bahagian atas feed'
          : 'Sematkan post "$title" ditanggalkan',
    );
  }

  /// Statistik keseluruhan post kedai (disegerakkan terus dengan jadual feed_posts & feed_comments Ngam)
  Future<Map<String, int>> getSummaryStats() async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {
          'totalPosts': 0,
          'publishedCount': 0,
          'draftCount': 0,
          'totalViews': 0,
          'totalLikes': 0,
          'totalComments': 0,
          'totalShares': 0,
        };
      }

      final res = await _client
          .from('feed_posts')
          .select('id, status, views_count, likes_count, comments_count, shares_count')
          .eq('business_id', businessId);

      final List<dynamic> list = res as List<dynamic>;
      final List<String> postIds = [];
      int views = 0;
      int likes = 0;
      int comments = 0;
      int shares = 0;
      int published = 0;
      int draft = 0;

      for (var item in list) {
        final pid = item['id']?.toString() ?? '';
        if (pid.isNotEmpty) postIds.add(pid);
        final st = item['status']?.toString() ?? 'published';
        if (st == 'published') published++;
        if (st == 'draft') draft++;
        views += (item['views_count'] as num?)?.toInt() ?? 0;
        likes += (item['likes_count'] as num?)?.toInt() ?? 0;
        comments += (item['comments_count'] as num?)?.toInt() ?? 0;
        shares += (item['shares_count'] as num?)?.toInt() ?? 0;
      }

      if (postIds.isNotEmpty) {
        try {
          final commentRows = await _client
              .from('feed_comments')
              .select('id')
              .inFilter('post_id', postIds);
          comments = (commentRows as List).length;
        } catch (_) {}
      }

      return {
        'totalPosts': list.length,
        'publishedCount': published,
        'draftCount': draft,
        'totalViews': views,
        'totalLikes': likes,
        'totalComments': comments,
        'totalShares': shares,
      };
    } catch (_) {
      return {
        'totalPosts': 0,
        'publishedCount': 0,
        'draftCount': 0,
        'totalViews': 0,
        'totalLikes': 0,
        'totalComments': 0,
        'totalShares': 0,
      };
    }
  }

  /// Dapatkan senarai komen & balasan (replies) untuk sesuatu post,
  /// lengkap dengan profil sebenar pengguna Ngam (`public.users`) dan lencana Pemilik Kedai.
  Future<List<Map<String, dynamic>>> getPostComments(String postId) async {
    try {
      final profile = await _businessService.getBusinessProfile();
      final String shopName = profile?['name']?.toString().trim() ??
          profile?['business_name']?.toString().trim() ??
          'Kedai Anda';
      final String shopAvatar = profile?['logo_url']?.toString().trim() ??
          profile?['business_logo_url']?.toString().trim() ??
          '';
      final String? ownerUid = _client.auth.currentUser?.id;

      final dbRes = await _client
          .from('feed_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .limit(200);

      final Set<String> userIds = {};
      for (final row in dbRes) {
        final uid = row['user_id']?.toString() ?? '';
        if (uid.length > 20) userIds.add(uid);
      }

      final Map<String, Map<String, String>> appProfilesByUid = {};
      if (userIds.isNotEmpty) {
        try {
          final usersRows = await _client
              .from('users')
              .select('id, user_name, user_avatar_url')
              .inFilter('id', userIds.toList());
          for (final u in usersRows) {
            final uid = u['id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              appProfilesByUid[uid] = {
                'name': u['user_name']?.toString().trim() ?? '',
                'avatar': u['user_avatar_url']?.toString().trim() ?? '',
              };
            }
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> topLevel = [];
      final Map<String, List<Map<String, dynamic>>> repliesByParent = {};
      final replyRegex = RegExp(
        r'^\[\[REPLY:([^|\]]+)\|([^|\]]*)(?:\|([^\]]*))?\]\]\s*(.*)$',
        dotAll: true,
      );

      for (final row in dbRes) {
        final String rowId = row['id']?.toString() ?? '';
        final String rowUserId = row['user_id']?.toString() ?? '';
        String rawText = row['comment_text']?.toString() ?? '';

        bool hasOwnerTag = false;
        if (rawText.startsWith('[[OWNER]]')) {
          hasOwnerTag = true;
          rawText = rawText.replaceFirst(RegExp(r'^\[\[OWNER\]\]\s*'), '');
        }
        final match = replyRegex.firstMatch(rawText);
        if (match != null && (match.group(3)?.toUpperCase().contains('OWNER') ?? false)) {
          hasOwnerTag = true;
        }

        String userName = row['user_name']?.toString().trim() ?? 'Pelanggan Ngam';
        String userAvatar = row['user_avatar']?.toString().trim() ?? '';

        final bool isRowMatchingShop = shopName.isNotEmpty &&
            userName.toLowerCase().trim() == shopName.toLowerCase().trim();
        final bool isRowByOwner =
            ownerUid != null && rowUserId.isNotEmpty && rowUserId == ownerUid;
        final bool isOwnerComment = hasOwnerTag || isRowMatchingShop || isRowByOwner;

        if (!isRowMatchingShop &&
            rowUserId.isNotEmpty &&
            appProfilesByUid.containsKey(rowUserId)) {
          final appProf = appProfilesByUid[rowUserId]!;
          if ((appProf['name'] ?? '').isNotEmpty) {
            userName = appProf['name']!;
          }
          userAvatar = appProf['avatar'] ?? '';
        }

        if (isOwnerComment && userAvatar.isEmpty && shopAvatar.isNotEmpty) {
          userAvatar = shopAvatar;
        }

        final int likes = (row['likes_count'] as num?)?.toInt() ?? 0;
        final String createdAt = row['created_at']?.toString() ?? '';

        if (match != null) {
          final String parentId = match.group(1)!.trim();
          final String replyToUser = match.group(2)!.trim();
          String cleanText = match.group(4)!.trim();
          if (cleanText.startsWith('[[OWNER]]')) {
            cleanText = cleanText.replaceFirst(RegExp(r'^\[\[OWNER\]\]\s*'), '');
          }
          repliesByParent.putIfAbsent(parentId, () => []).add({
            'id': rowId,
            'parentId': parentId,
            'userId': rowUserId,
            'user': userName,
            'replyToUser': replyToUser,
            'avatar': userAvatar,
            'text': cleanText,
            'createdAt': createdAt,
            'likes': likes,
            'isLiked': false,
            'isOwner': isOwnerComment,
          });
        } else {
          topLevel.add({
            'id': rowId,
            'userId': rowUserId,
            'user': userName,
            'avatar': userAvatar,
            'text': rawText,
            'createdAt': createdAt,
            'likes': likes,
            'isLiked': false,
            'isOwner': isOwnerComment,
            'replies': <Map<String, dynamic>>[],
          });
        }
      }

      for (final c in topLevel) {
        final cid = c['id'].toString();
        if (repliesByParent.containsKey(cid)) {
          c['replies'] = repliesByParent[cid]!;
        }
      }

      final matchedParentIds = topLevel.map((c) => c['id'].toString()).toSet();
      for (final entry in repliesByParent.entries) {
        if (!matchedParentIds.contains(entry.key)) {
          for (final orphan in entry.value) {
            topLevel.add({
              ...orphan,
              'replies': <Map<String, dynamic>>[],
            });
          }
        }
      }

      return topLevel.reversed.toList();
    } catch (e) {
      debugPrint('[FeedService] Error fetching post comments: $e');
      return [];
    }
  }

  /// Hantar komen atau balasan rasmi sebagai Pemilik Kedai (Owner)
  Future<Map<String, dynamic>> postOwnerComment({
    required String postId,
    required String text,
    String? parentCommentId,
    String? replyToUser,
  }) async {
    final profile = await _businessService.getBusinessProfile();
    final String shopName = profile?['name']?.toString().trim() ??
        profile?['business_name']?.toString().trim() ??
        'Kedai Ngam';
    final String shopAvatar = profile?['logo_url']?.toString().trim() ??
        profile?['business_logo_url']?.toString().trim() ??
        '';
    final String? ownerUid = _client.auth.currentUser?.id;

    final bool isReply = parentCommentId != null && parentCommentId.isNotEmpty;
    final String payloadText = isReply
        ? '[[REPLY:$parentCommentId|${replyToUser ?? ""}|OWNER]] $text'
        : '[[OWNER]] $text';

    final inserted = await _client
        .from('feed_comments')
        .insert({
          'post_id': postId,
          'user_id': ownerUid,
          'user_name': shopName,
          'user_avatar': shopAvatar,
          'comment_text': payloadText,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(inserted as Map);
  }

  /// Kemas kini kiraan sukaan (like) pada komen
  Future<void> toggleLikeComment(String commentId, int newLikes) async {
    try {
      await _client
          .from('feed_comments')
          .update({'likes_count': newLikes})
          .eq('id', commentId);
    } catch (e) {
      debugPrint('[FeedService] toggleLikeComment error: $e');
    }
  }

  /// Padam komen atau balasan daripada post kedai
  Future<void> deleteComment(String commentId) async {
    await _client.from('feed_comments').delete().eq('id', commentId);
  }
}
