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
      return data.map((json) => FeedPostModel.fromJson(Map<String, dynamic>.from(json))).toList();
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
      description: 'Post Feed ID $postId telah dikemaskini: "$title"',
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

  /// Statistik keseluruhan post kedai
  Future<Map<String, int>> getSummaryStats() async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {'totalPosts': 0, 'totalViews': 0, 'totalLikes': 0, 'totalComments': 0};
      }

      final res = await _client
          .from('feed_posts')
          .select('id, views_count, likes_count, comments_count')
          .eq('business_id', businessId);

      final List<dynamic> list = res as List<dynamic>;
      int views = 0;
      int likes = 0;
      int comments = 0;

      for (var item in list) {
        views += (item['views_count'] as num?)?.toInt() ?? 0;
        likes += (item['likes_count'] as num?)?.toInt() ?? 0;
        comments += (item['comments_count'] as num?)?.toInt() ?? 0;
      }

      return {
        'totalPosts': list.length,
        'totalViews': views,
        'totalLikes': likes,
        'totalComments': comments,
      };
    } catch (_) {
      return {'totalPosts': 0, 'totalViews': 0, 'totalLikes': 0, 'totalComments': 0};
    }
  }
}
