import 'package:intl/intl.dart';

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

  String get formattedDate {
    try {
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min lepas';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} jam lepas';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} hari lepas';
      }
      return DateFormat('dd MMM yyyy').format(createdAt);
    } catch (_) {
      return '';
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
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
