import 'dart:convert';
import 'package:intl/intl.dart';

class FeedMediaItem {
  final String url;
  final String type; // 'image' or 'video'

  const FeedMediaItem({
    required this.url,
    required this.type,
  });

  bool get isVideo => type == 'video';

  factory FeedMediaItem.fromJson(Map<String, dynamic> json) {
    final u = json['url']?.toString().trim() ?? '';
    final t = json['type']?.toString().trim().toLowerCase();
    final inferredVideo = t == 'video' || isVideoUrl(u);
    return FeedMediaItem(url: u, type: inferredVideo ? 'video' : 'image');
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
      };

  static bool isVideoUrl(String url) {
    final clean = url.trim().toLowerCase().split('?').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.m4v') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.3gp') ||
        clean.contains('/video/') ||
        clean.contains('/feed_videos/') ||
        url.trim().toLowerCase().contains('.mp4?');
  }
}

class FeedCtaItem {
  final String type; // 'queue', 'booking', 'menu', 'whatsapp', 'general', 'walkin'
  final String text;

  const FeedCtaItem({
    required this.type,
    required this.text,
  });

  factory FeedCtaItem.fromJson(Map<String, dynamic> json) {
    return FeedCtaItem(
      type: json['type']?.toString().trim() ?? 'general',
      text: json['text']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
      };
}

class FeedPostModel {
  final String id;
  final String businessId;
  final String title;
  final String? caption;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? category;
  final String? serviceTag;
  final String ctaType; // 'queue', 'booking', 'menu', 'whatsapp', 'general'
  final String ctaText;
  final String status; // 'published', 'draft', 'archived'
  final bool isPinned;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedPostModel({
    required this.id,
    required this.businessId,
    required this.title,
    this.caption,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.category,
    this.serviceTag,
    this.ctaType = 'queue',
    this.ctaText = '⚡ AMBIL GILIRAN',
    this.status = 'published',
    this.isPinned = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isArchived => status == 'archived';

  List<FeedMediaItem> get mediaItems => parseMediaItems(mediaUrl, mediaType);
  String get primaryMediaUrl => mediaItems.isNotEmpty ? mediaItems.first.url : mediaUrl;
  bool get isCarousel => mediaItems.length > 1;

  List<FeedCtaItem> get ctaItems => parseCtaItems(ctaType, ctaText);
  String get ctaSummary => ctaItems.isEmpty
      ? 'Tanpa CTA'
      : ctaItems.map((e) => e.text).join(' • ');

  static List<FeedCtaItem> parseCtaItems(String rawCtaType, String rawCtaText) {
    final trimmedText = rawCtaText.trim();
    if (trimmedText.isEmpty) return const [];
    if (trimmedText.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmedText);
        if (decoded is List) {
          final items = <FeedCtaItem>[];
          for (final entry in decoded) {
            if (entry is Map) {
              final item = FeedCtaItem.fromJson(Map<String, dynamic>.from(entry));
              if (item.text.isNotEmpty) items.add(item);
            }
            if (items.length >= 3) break;
          }
          return items;
        }
      } catch (_) {}
    }
    return [
      FeedCtaItem(
        type: rawCtaType.trim().isEmpty ? 'general' : rawCtaType.trim(),
        text: trimmedText,
      ),
    ];
  }

  static String encodeCtaText(List<FeedCtaItem> items) {
    final valid = items.where((e) => e.text.trim().isNotEmpty).take(3).toList();
    if (valid.isEmpty) return '';
    if (valid.length == 1) return valid.first.text.trim();
    return jsonEncode(valid.map((e) => e.toJson()).toList());
  }

  static String primaryDbCtaType(List<FeedCtaItem> items) {
    if (items.isEmpty) return 'general';
    final raw = items.first.type.trim().toLowerCase();
    final mapped = raw == 'walkin' ? 'queue' : raw;
    const allowed = {'queue', 'booking', 'menu', 'whatsapp', 'general'};
    return allowed.contains(mapped) ? mapped : 'general';
  }

  static List<FeedMediaItem> parseMediaItems(String rawMediaUrl, [String fallbackMediaType = 'image']) {
    final trimmed = rawMediaUrl.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final items = <FeedMediaItem>[];
          for (final entry in decoded) {
            if (entry is Map) {
              final item = FeedMediaItem.fromJson(Map<String, dynamic>.from(entry));
              if (item.url.isNotEmpty) items.add(item);
            } else if (entry is String && entry.trim().isNotEmpty) {
              final u = entry.trim();
              items.add(FeedMediaItem(url: u, type: FeedMediaItem.isVideoUrl(u) ? 'video' : 'image'));
            }
          }
          if (items.isNotEmpty) return items;
        }
      } catch (_) {}
    }
    final isVid = fallbackMediaType.toLowerCase() == 'video' || FeedMediaItem.isVideoUrl(trimmed);
    return [FeedMediaItem(url: trimmed, type: isVid ? 'video' : 'image')];
  }

  static String encodeMediaItems(List<FeedMediaItem> items) {
    final valid = items.where((e) => e.url.trim().isNotEmpty).toList();
    if (valid.isEmpty) return '';
    if (valid.length == 1) return valid.first.url.trim();
    return jsonEncode(valid.map((e) => e.toJson()).toList());
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    final str = val.toString().trim();
    if (str.isEmpty) return DateTime.now();

    // If string has no timezone indicator ('Z' or '+'), treat as UTC
    final normalized = (!str.endsWith('Z') && !str.contains('+') && str.contains('T'))
        ? '${str}Z'
        : (!str.endsWith('Z') && !str.contains('+') && !str.contains('T'))
            ? '${str.replaceAll(' ', 'T')}Z'
            : str;

    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(str) ?? DateTime.now();
    return parsed.toLocal();
  }

  String get formattedDate {
    try {
      final now = DateTime.now();
      final localCreated = createdAt.toLocal();
      final difference = now.difference(localCreated);

      if (difference.isNegative || difference.inSeconds < 60) {
        return 'Baru saja';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min lepas';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lepas';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari lepas';
      }
      return DateFormat('dd MMM yyyy, h:mm a').format(localCreated);
    } catch (_) {
      return 'Baru saja';
    }
  }

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      caption: json['caption']?.toString(),
      mediaUrl: json['media_url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      category: json['category']?.toString(),
      serviceTag: json['service_tag']?.toString(),
      ctaType: json['cta_type']?.toString() ?? 'queue',
      ctaText: json['cta_text']?.toString() ?? '⚡ AMBIL GILIRAN',
      status: json['status']?.toString() ?? 'published',
      isPinned: json['is_pinned'] == true,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'title': title,
      'caption': caption,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'category': category,
      'service_tag': serviceTag,
      'cta_type': ctaType,
      'cta_text': ctaText,
      'status': status,
      'is_pinned': isPinned,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeedPostModel copyWith({
    String? id,
    String? businessId,
    String? title,
    String? caption,
    String? mediaUrl,
    String? mediaType,
    String? category,
    String? serviceTag,
    String? ctaType,
    String? ctaText,
    String? status,
    bool? isPinned,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeedPostModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      category: category ?? this.category,
      serviceTag: serviceTag ?? this.serviceTag,
      ctaType: ctaType ?? this.ctaType,
      ctaText: ctaText ?? this.ctaText,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
