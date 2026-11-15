import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../widgets/glass_toast.dart';
import '../../../core/services/r2_storage_service.dart';
import '../../../core/services/video_compression_service.dart';
import '../data/feed_service.dart';
import '../models/feed_post_model.dart';
import '../../settings/data/business_service.dart';
import '../../../widgets/glass_nav_button.dart';
import 'feed_create_page.dart';

/// FeedManagementPage — Ngam Feed & Post Studio (Gaya TikTok & IG Creator).
/// Top header dikekalkan dengan GlassScaffold; susunan video 9:16, tab Siaran/Draf/Statistik,
/// dan metrik disegerakkan terus dengan aplikasi pelanggan Ngam.
class FeedManagementPage extends StatefulWidget {
  const FeedManagementPage({super.key});

  @override
  State<FeedManagementPage> createState() => _FeedManagementPageState();
}

class _FeedManagementPageState extends State<FeedManagementPage> {
  final FeedService _feedService = FeedService();
  final BusinessService _businessService = BusinessService();

  bool _loading = true;
  String _selectedFilter = 'published'; // 'published', 'pinned', 'draft', 'analytics'
  List<FeedPostModel> _posts = [];
  Map<String, int> _stats = {
    'totalPosts': 0,
    'publishedCount': 0,
    'draftCount': 0,
    'totalViews': 0,
    'totalLikes': 0,
    'totalComments': 0,
    'totalShares': 0,
  };
  Map<String, dynamic>? _businessProfile;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadInitialData(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    await Future.wait([
      _fetchPosts(),
      _fetchStats(),
      _fetchProfile(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPosts() async {
    final effectiveFilter = _selectedFilter == 'analytics' ? 'published' : _selectedFilter;
    final posts = await _feedService.getPosts(filter: effectiveFilter);
    if (_selectedFilter == 'analytics') {
      posts.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    }
    if (mounted) {
      setState(() => _posts = posts);
    }
  }

  Future<void> _fetchStats() async {
    final stats = await _feedService.getSummaryStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  Future<void> _fetchProfile() async {
    final profile = await _businessService.getBusinessProfile();
    if (mounted) {
      setState(() => _businessProfile = profile);
    }
  }

  Future<void> _publishFromDraft(FeedPostModel post) async {
    try {
      await _feedService.updatePost(
        postId: post.id,
        title: post.title,
        caption: post.caption,
        mediaUrl: post.mediaUrl,
        mediaType: post.mediaType,
        category: post.category,
        serviceTag: post.serviceTag,
        ctaType: post.ctaType,
        ctaText: post.ctaText,
        status: 'published',
        isPinned: post.isPinned,
      );
      if (mounted) {
        showGlassToast(context, 'Draf berjaya diterbitkan ke Ngam Feed!', type: GlassToastType.success, color: const Color(0xFF10B981));
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) showGlassToast(context, 'Gagal menerbitkan draf: $e', isError: true);
    }
  }

  Future<void> _togglePin(FeedPostModel post) async {
    final newPinned = !post.isPinned;
    await _feedService.togglePin(post.id, newPinned, post.title);
    if (mounted) {
      showGlassToast(
        context,
        newPinned ? 'Post disematkan ke atas feed!' : 'Sematan post ditanggalkan.',
        customColor: const Color(0xFF8B5CF6),
      );
      _fetchPosts();
    }
  }

  Future<void> _deletePost(FeedPostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Padam Post Feed?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Adakah anda pasti untuk memadam post "${post.title}"? Tindakan ini tidak boleh diundur.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Padam'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _feedService.deletePost(post.id, post.title);
    if (mounted) {
      showGlassToast(context, 'Post berjaya dipadam.');
      _loadInitialData();
    }
  }

  Future<void> _openCreateOrEditPostDialog({FeedPostModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => FeedCreatePage(
          existing: existing,
          businessCategory: _businessProfile?['category']?.toString() ?? 'services',
        ),
      ),
    );
    if (result == true && mounted) {
      _loadInitialData();
    }
  }

  void _showPhonePreview(FeedPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => _PhoneMockupPreviewDialog(
        post: post,
        businessProfile: _businessProfile,
        onCommentsUpdated: () => _loadInitialData(silent: true),
      ),
    );
  }

  void _openCommentsSheet(FeedPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnerPostCommentsSheet(
        post: post,
        businessProfile: _businessProfile,
        onCommentsUpdated: () => _loadInitialData(silent: true),
      ),
    );
  }

  Future<void> _generateSamplePost() async {
    setState(() => _loading = true);
    final category = _businessProfile?['category']?.toString().toLowerCase() ?? 'services';

    String sampleTitle;
    String sampleCaption;
    String sampleImage;
    String sampleTag;
    String sampleCta;

    if (category.contains('barber')) {
      sampleTitle = 'Low Taper Fade + Beard Sculpting 🔥';
      sampleCaption = 'Hasil sentuhan kemas untuk pelanggan tetap kami petang ini. Slot walk-in & giliran dibuka sampai jam 10 malam! #barber #taperfade #ngam';
      sampleImage = 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800';
      sampleTag = '✂️ Potong + Cuci • RM35 · Buka Hingga 10:00 PM';
      sampleCta = '⚡ AMBIL GILIRAN';
    } else if (category.contains('carwash')) {
      sampleTitle = 'Nano Coating & Kilauan Cermin Kristal ✨';
      sampleCaption = 'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark & bau hapak! #detailing #carwash #ngam';
      sampleImage = 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=800';
      sampleTag = '🚗 Nano Coating • RM45 · 3 Bay Cucian Aktif';
      sampleCta = '🚗 MASUK TERUS';
    } else if (category.contains('cafe') || category.contains('food')) {
      sampleTitle = 'Iced Salted Caramel Butter Pecan Latte ☕';
      sampleCaption = 'Port santai untuk buat kerja atau lepak sambil nikmati hidangan panas. Ada high-speed WiFi dan plug di setiap meja! #ngamcafe #kopiroti';
      sampleImage = 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=800';
      sampleTag = '☕ Menu Baru Musim Ini • RM14 · Meja Santai';
      sampleCta = '☕ PESAN MENU';
    } else {
      sampleTitle = 'Promosi Khas Servis Pantas & Berkualiti 🚀';
      sampleCaption = 'Servis berkualiti tinggi dengan jaminan kepuasan pelanggan. Kunjungi cawangan kami hari ini untuk tawaran istimewa! #ngam #promosi';
      sampleImage = 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?q=80&w=800';
      sampleTag = '⭐ Pakej Popular • Harga Berbaloi';
      sampleCta = '⚡ AMBIL GILIRAN';
    }

    try {
      await _feedService.createPost(
        title: sampleTitle,
        caption: sampleCaption,
        mediaUrl: sampleImage,
        category: category,
        serviceTag: sampleTag,
        ctaText: sampleCta,
        status: 'published',
        isPinned: true,
      );
      if (mounted) {
        showGlassToast(context, 'Post sampel berjaya dijana!');
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menjana post sampel: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600;

    return GlassScaffold(
      backgroundColor: const Color(0xFF0A0A14),
      title: isPhone ? 'Feed & Post' : 'Ngam Feed Studio',
      subtitle: 'Video & hantaran promosi',
      actionItems: [
        GlassNavPillItem(
          icon: HugeIcons.strokeRoundedAdd01,
          tooltip: 'Cipta Post',
          onTap: () => _openCreateOrEditPostDialog(),
        ),
      ],
      // Mobile-friendly Floating Action Button for quick thumb tap on phones
      floatingActionButton: isPhone
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateOrEditPostDialog(),
              backgroundColor: const Color(0xFFEC4899),
              elevation: 6,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              label: const Text(
                'Cipta Post',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: const Color(0xFFEC4899),
              backgroundColor: const Color(0xFF161626),
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 68, 16, isPhone ? 90 : 40),
                children: [
                  _buildMetricHeader(),
                  const SizedBox(height: 16),
                  _buildFilterBar(),
                  const SizedBox(height: 16),
                  if (_posts.isEmpty)
                    _buildEmptyState()
                  else
                    _buildPostsLayout(),
                ],
              ),
            ),
    );
  }

  String _formatCompact(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  Widget _buildMetricHeader() {
    final shopName = _businessProfile?['name']?.toString() ?? 'Kedai Ngam Anda';
    final avatarUrl = _businessProfile?['avatar_url']?.toString() ?? '';
    final handle = '@${shopName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEC4899).withValues(alpha: 0.12),
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF00E5FF)]),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.3), blurRadius: 12),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildAvatarFallback(shopName))
                      : _buildAvatarFallback(shopName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      handle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 11),
                          SizedBox(width: 4),
                          Text(
                            'Live Sync Ngam App',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openCreateOrEditPostDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Muat Naik', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTikTokStatCell('Tontonan', _formatCompact(_stats['totalViews'] ?? 0), Icons.play_arrow_rounded, const Color(0xFF00E5FF))),
              _buildStatDivider(),
              Expanded(child: _buildTikTokStatCell('Sukaan', _formatCompact(_stats['totalLikes'] ?? 0), Icons.favorite_rounded, const Color(0xFFEF4444))),
              _buildStatDivider(),
              Expanded(child: _buildTikTokStatCell('Komen', _formatCompact(_stats['totalComments'] ?? 0), Icons.chat_bubble_rounded, const Color(0xFFF59E0B))),
              _buildStatDivider(),
              Expanded(child: _buildTikTokStatCell('Kongsi', _formatCompact(_stats['totalShares'] ?? 0), Icons.share_rounded, const Color(0xFF8B5CF6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String shopName) {
    return Container(
      color: const Color(0xFF161626),
      alignment: Alignment.center,
      child: Text(
        shopName.isNotEmpty ? shopName[0].toUpperCase() : 'N',
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildTikTokStatCell(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final pubCount = _stats['publishedCount'] ?? 0;
    final draftCount = _stats['draftCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          _buildTikTokTab(
            label: 'Siaran ($pubCount)',
            value: 'published',
            icon: Icons.grid_on_rounded,
          ),
          _buildTikTokTab(
            label: 'Disemat',
            value: 'pinned',
            icon: Icons.push_pin_rounded,
          ),
          _buildTikTokTab(
            label: draftCount > 0 ? 'Draf ($draftCount)' : 'Draf',
            value: 'draft',
            icon: Icons.lock_outline_rounded,
          ),
          _buildTikTokTab(
            label: 'Statistik',
            value: 'analytics',
            icon: Icons.bar_chart_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTikTokTab({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedFilter != value) {
            setState(() => _selectedFilter = value);
            _fetchPosts();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFFEC4899) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : Colors.white38),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsLayout() {
    if (_selectedFilter == 'analytics') {
      return _buildAnalyticsList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 1000 ? 5 : (w >= 650 ? 4 : 3);
        final spacing = w >= 650 ? 8.0 : 3.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _posts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 9 / 14,
          ),
          itemBuilder: (context, index) => _buildTikTokGridTile(_posts[index]),
        );
      },
    );
  }

  Widget _buildTikTokGridTile(FeedPostModel post) {
    return GestureDetector(
      onTap: () => _showPhonePreview(post),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141422),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: post.isPinned
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FeedPostCardThumbnail(post: post, height: 240),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.25, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 6,
              left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pinned',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    )
                  else if (post.isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DRAF',
                        style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              top: 2,
              right: 2,
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 15),
                ),
                color: const Color(0xFF1A1A2E),
                onSelected: (val) {
                  if (val == 'comments') {
                    _openCommentsSheet(post);
                  } else if (val == 'edit') {
                    _openCreateOrEditPostDialog(existing: post);
                  } else if (val == 'pin') {
                    _togglePin(post);
                  } else if (val == 'publish') {
                    _publishFromDraft(post);
                  } else if (val == 'delete') {
                    _deletePost(post);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'comments',
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 8),
                        Text('Komen (${post.commentsCount})', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Sunting', style: TextStyle(color: Colors.white, fontSize: 13))),
                  if (post.isDraft)
                    const PopupMenuItem(value: 'publish', child: Text('Siarkan Sekarang', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold))),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(post.isPinned ? 'Buka Sematan' : 'Sematkan (Pin)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Padam', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                ],
              ),
            ),

            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            _formatCompact(post.viewsCount),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (post.likesCount > 0) ...[
                            const Icon(Icons.favorite_rounded, color: Color(0xFFFE2C55), size: 11),
                            const SizedBox(width: 2),
                            Text(
                              _formatCompact(post.likesCount),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                          ],
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openCommentsSheet(post),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00E5FF), size: 10.5),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatCompact(post.commentsCount),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _buildAnalyticsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prestasi sebenar disegerakkan secara langsung daripada tontonan, sukaan & komen pelanggan dalam aplikasi Ngam.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final post = _posts[index];
            final engagement = post.viewsCount > 0
                ? (((post.likesCount + post.commentsCount + post.sharesCount) / post.viewsCount) * 100).toStringAsFixed(1)
                : '0.0';

            return InkWell(
              onTap: () => _showPhonePreview(post),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      height: 76,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _FeedPostCardThumbnail(post: post, height: 76),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post.ctaText} • ${post.formattedDate}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildMetricMini(Icons.play_arrow_rounded, _formatCompact(post.viewsCount), const Color(0xFF00E5FF)),
                              const SizedBox(width: 12),
                              _buildMetricMini(Icons.favorite_rounded, _formatCompact(post.likesCount), const Color(0xFFEF4444)),
                              const SizedBox(width: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openCommentsSheet(post),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _buildMetricMini(
                                    Icons.chat_bubble_rounded,
                                    '${_formatCompact(post.commentsCount)} Balas',
                                    const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '$engagement% ER',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
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
      ],
    );
  }

  Widget _buildMetricMini(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }


  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              color: Color(0xFFEC4899),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tiada Post di Ngam Feed Lagi',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Siarkan gambar & video hasil kerja terbaik kedai anda untuk menarik pelanggan mengambil giliran atau membuat tempahan terus dari feed gaya Reels!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          // Wrap ensures buttons gracefully stack on small phone screens without RenderFlex overflow
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openCreateOrEditPostDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Cipta Post Baharu', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: _generateSamplePost,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00F2FE),
                  side: BorderSide(color: const Color(0xFF00F2FE).withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Jana Post Sampel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget: Thumbnail Post Suapan (Autoplay Poster untuk Video & Foto)
// Menghilangkan masalah thumbnail kosong apabila pos mengandungi video MP4
// =============================================================================
class _FeedPostCardThumbnail extends StatefulWidget {
  final FeedPostModel post;
  final double height;

  const _FeedPostCardThumbnail({
    required this.post,
    required this.height,
  });

  @override
  State<_FeedPostCardThumbnail> createState() => _FeedPostCardThumbnailState();
}

class _FeedPostCardThumbnailState extends State<_FeedPostCardThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  bool get _isVideo =>
      widget.post.mediaType == 'video' ||
      widget.post.mediaUrl.toLowerCase().contains('.mp4') ||
      widget.post.mediaUrl.toLowerCase().contains('.mov') ||
      widget.post.mediaUrl.toLowerCase().contains('.webm');

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    }
  }

  void _initVideo() {
    try {
      final uri = Uri.tryParse(widget.post.mediaUrl);
      if (uri == null) {
        setState(() => _hasError = true);
        return;
      }
      final c = VideoPlayerController.networkUrl(uri);
      _controller = c;
      c.initialize().then((_) async {
        if (mounted) {
          await c.setVolume(0.0);
          await c.setLooping(true);
          // Berhenti di bingkai pertama sebagai poster pratonton
          await c.pause();
          setState(() => _isInitialized = true);
        }
      }).catchError((err) {
        debugPrint('[PostCardThumbnail] Error: $err');
        if (mounted) {
          setState(() => _hasError = true);
        }
      });
    } catch (_) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: const Color(0xFF0F0F1A),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized && _controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                    height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _hasError ? Icons.video_file_rounded : Icons.movie_filter_rounded,
                    color: Colors.white24,
                    size: 38,
                  ),
                ),
              ),

            // Ambient dark vignette
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Centered TikTok Play Badge
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            ),

            // Top right "VIDEO REEL" pill
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 11),
                    SizedBox(width: 4),
                    Text(
                      'VIDEO',
                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Otherwise it's an image
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Image.network(
        widget.post.mediaUrl,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.white.withValues(alpha: 0.05),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEC4899))),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E1E2E),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Dialog: Cipta & Sunting Post Baharu (TikTok Studio Style Uploader)
// Tanpa pautan gambar preset manual — khusus untuk muat naik video/media langsung
// dengan pratonton audio penuh & pemampatan pintar.
// =============================================================================
class _CreateEditPostDialog extends StatefulWidget {
  final FeedPostModel? existing;
  final String businessCategory;
  final VoidCallback onSaved;

  const _CreateEditPostDialog({
    this.existing,
    required this.businessCategory,
    required this.onSaved,
  });

  @override
  State<_CreateEditPostDialog> createState() => _CreateEditPostDialogState();
}

class _CreateEditPostDialogState extends State<_CreateEditPostDialog> {
  final _formKey = GlobalKey<FormState>();
  final FeedService _feedService = FeedService();
  final ImagePicker _picker = ImagePicker();
  final R2StorageService _r2Storage = R2StorageService();
  final VideoCompressionService _compressor = VideoCompressionService();

  late TextEditingController _titleController;
  late TextEditingController _captionController;
  late TextEditingController _serviceTagController;

  String _ctaType = 'queue';
  String _ctaText = '⚡ AMBIL GILIRAN';
  String _status = 'published';
  bool _isPinned = false;
  bool _saving = false;

  // Media Upload & Video Preview State (TikTok Studio)
  String _mediaType = 'video';
  XFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _existingMediaUrl;

  VideoPlayerController? _videoPreviewController;
  bool _isVideoInitializing = false;
  bool _isAudioMuted = false;
  bool _isCompressing = false;
  double _compressProgress = 0.0;
  bool _isUploadingToR2 = false;
  double _uploadProgress = 0.0;

  static const _ctaOptions = [
    (type: 'queue', text: '⚡ AMBIL GILIRAN', icon: Icons.confirmation_number_rounded),
    (type: 'booking', text: '📅 TEMPAH SLOT', icon: Icons.calendar_month_rounded),
    (type: 'menu', text: '☕ PESAN MENU', icon: Icons.restaurant_menu_rounded),
    (type: 'whatsapp', text: '💬 WHATSAPP KEDAI', icon: Icons.chat_rounded),
    (type: 'general', text: '⭐ LAWATI KEDAI', icon: Icons.storefront_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _titleController = TextEditingController(text: p?.title ?? '');
    _captionController = TextEditingController(text: p?.caption ?? '');
    _serviceTagController = TextEditingController(text: p?.serviceTag ?? '');

    if (p != null) {
      _ctaType = p.ctaType;
      _ctaText = p.ctaText;
      _status = p.status;
      _isPinned = p.isPinned;
      _mediaType = p.mediaType;
      _existingMediaUrl = p.mediaUrl;
      if (p.mediaType == 'video') {
        _initExistingVideo(p.mediaUrl);
      }
    }
  }

  void _initExistingVideo(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      setState(() => _isVideoInitializing = true);
      final controller = VideoPlayerController.networkUrl(uri);
      controller.initialize().then((_) async {
        if (mounted) {
          await controller.setLooping(true);
          await controller.setVolume(_isAudioMuted ? 0.0 : 1.0);
          try {
            await controller.play();
          } catch (_) {
            await controller.setVolume(0.0);
            _isAudioMuted = true;
            await controller.play();
          }
          setState(() {
            _videoPreviewController = controller;
            _isVideoInitializing = false;
          });
        }
      }).catchError((e) {
        debugPrint('[CreateEditPost] Existing video init error: $e');
        if (mounted) {
          setState(() => _isVideoInitializing = false);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isVideoInitializing = false);
    }
  }

  @override
  void dispose() {
    _videoPreviewController?.dispose();
    _titleController.dispose();
    _captionController.dispose();
    _serviceTagController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (video == null) return;

      final bytes = await video.readAsBytes();
      final size = bytes.lengthInBytes;

      if (size > 50 * 1024 * 1024) {
        if (mounted) {
          showGlassToast(
            context,
            'Video terlalu besar (${(size / (1024 * 1024)).toStringAsFixed(1)} MB). Sila pilih video bawah 50 MB.',
            isError: true,
          );
        }
        return;
      }

      await _videoPreviewController?.dispose();
      _videoPreviewController = null;

      setState(() {
        _selectedFile = video;
        _selectedFileBytes = bytes;
        _selectedFileName = video.name;
        _selectedFileSize = size;
        _mediaType = 'video';
        _isVideoInitializing = true;
      });

      try {
        final VideoPlayerController controller = kIsWeb
            ? VideoPlayerController.networkUrl(Uri.parse(video.path))
            : VideoPlayerController.networkUrl(Uri.file(video.path));

        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(_isAudioMuted ? 0.0 : 1.0);

        try {
          await controller.play();
        } catch (playErr) {
          debugPrint('[FeedManagement] Web autoplay prevented unmuted, falling back to muted: $playErr');
          await controller.setVolume(0.0);
          _isAudioMuted = true;
          await controller.play();
        }

        if (mounted) {
          setState(() {
            _videoPreviewController = controller;
            _isVideoInitializing = false;
          });
        }
      } catch (err) {
        debugPrint('[FeedManagement] Video preview player init fallback: $err');
        if (mounted) {
          setState(() {
            _isVideoInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[FeedManagement] Error picking video: $e');
      if (mounted) {
        showGlassToast(context, 'Ralat memilih video: $e', isError: true);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 75,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final size = bytes.lengthInBytes;

      await _videoPreviewController?.dispose();
      _videoPreviewController = null;

      setState(() {
        _selectedFile = image;
        _selectedFileBytes = bytes;
        _selectedFileName = image.name;
        _selectedFileSize = size;
        _mediaType = 'image';
      });
    } catch (e) {
      debugPrint('[FeedManagement] Error picking image: $e');
      if (mounted) {
        showGlassToast(context, 'Ralat memilih gambar: $e', isError: true);
      }
    }
  }

  void _clearSelectedMedia() {
    _videoPreviewController?.dispose();
    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _videoPreviewController = null;
      _isVideoInitializing = false;
      _existingMediaUrl = null;
    });
  }

  void _addHashtag(String tag) {
    final current = _captionController.text;
    if (current.contains(tag)) return;
    final prefix = current.isEmpty || current.endsWith(' ') ? '' : ' ';
    _captionController.text = '$current$prefix$tag';
    _captionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _captionController.text.length),
    );
    setState(() {});
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final hasNewFile = _selectedFileBytes != null && _selectedFileName != null;
    final hasExisting = _existingMediaUrl != null && _existingMediaUrl!.isNotEmpty;

    if (!hasNewFile && !hasExisting) {
      showGlassToast(context, 'Sila muat naik video atau pilih gambar untuk siaran ini!', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      String finalMediaUrl = _existingMediaUrl ?? '';

      // Jika fail tempatan dipilih, mampatkan dahulu kemudian muat naik ke Cloudflare R2!
      if (hasNewFile) {
        Uint8List bytesToUpload = _selectedFileBytes!;
        String fileNameToUpload = _selectedFileName!;

        // 1. Pemampatan Video Pintar (720p H.264)
        if (_mediaType == 'video' && _selectedFile != null) {
          setState(() {
            _isCompressing = true;
            _compressProgress = 0.1;
          });

          final compressResult = await _compressor.compressVideo(
            filePath: _selectedFile!.path,
            originalBytes: _selectedFileBytes!,
            onProgress: (p) {
              if (mounted) setState(() => _compressProgress = p);
            },
          );

          bytesToUpload = compressResult.bytes;
          if (mounted) {
            setState(() => _isCompressing = false);
            if (compressResult.reductionPercent > 5) {
              final savedMb = ((compressResult.originalSize - compressResult.compressedSize) / (1024 * 1024)).toStringAsFixed(1);
              showGlassToast(
                context,
                'Video berjaya dimampatkan! Jimat $savedMb MB (${compressResult.reductionPercent.toStringAsFixed(0)}% penjimatan)',
                type: GlassToastType.success,
                color: const Color(0xFF10B981),
              );
            }
          }
        }

        // 2. Muat Naik ke Cloudflare R2
        setState(() {
          _isUploadingToR2 = true;
          _uploadProgress = 0.05;
        });

        final mimeType = _mediaType == 'video' ? 'video/mp4' : 'image/jpeg';
        finalMediaUrl = await _r2Storage.uploadMedia(
          bytes: bytesToUpload,
          fileName: fileNameToUpload,
          folder: _mediaType == 'video' ? 'feed_videos' : 'feed_images',
          mimeType: mimeType,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );

        await _compressor.disposeCache();
      }

      if (widget.existing != null) {
        await _feedService.updatePost(
          postId: widget.existing!.id,
          title: _titleController.text.trim(),
          caption: _captionController.text.trim(),
          mediaUrl: finalMediaUrl,
          mediaType: _mediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim(),
          ctaType: _ctaType,
          ctaText: _ctaText,
          status: _status,
          isPinned: _isPinned,
        );
      } else {
        await _feedService.createPost(
          title: _titleController.text.trim(),
          caption: _captionController.text.trim(),
          mediaUrl: finalMediaUrl,
          mediaType: _mediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim(),
          ctaType: _ctaType,
          ctaText: _ctaText,
          status: _status,
          isPinned: _isPinned,
        );
      }

      if (mounted) {
        showGlassToast(
          context,
          widget.existing != null
              ? 'Post berjaya dikemas kini!'
              : 'Post berjaya dimuat naik & diterbitkan di Ngam Feed!',
          customColor: const Color(0xFF10B981),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      final errStr = e.toString();
      String friendlyMsg = 'Ralat: $errStr';
      if (errStr.contains('XMLHttpRequest') || errStr.contains('CORS')) {
        friendlyMsg = 'Ralat CORS Cloudflare R2: Sila pastikan CORS Policy telah disimpan di dashboard Cloudflare R2.';
      } else if (errStr.contains('42501') || errStr.contains('permission denied')) {
        friendlyMsg = 'Ralat Kebenaran Supabase: Sila kemas kini SQL RLS feed_posts dalam Supabase SQL Editor.';
      }
      if (mounted) {
        showGlassToast(context, friendlyMsg, isError: true);
        setState(() {
          _saving = false;
          _isUploadingToR2 = false;
          _isCompressing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600;

    return Dialog(
      backgroundColor: const Color(0xFF131320),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 24,
        vertical: isPhone ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isPhone ? 20 : 24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: isPhone ? screenHeight * 0.92 : 780,
        ),
        child: Padding(
          padding: EdgeInsets.all(isPhone ? 16 : 22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header TikTok Studio
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF00F2FE)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Kemaskini Post Feed' : 'TikTok Studio: Cipta Post',
                            style: TextStyle(color: Colors.white, fontSize: isPhone ? 15.5 : 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Muat naik video pendek untuk suapan pelanggan gaya Reels',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: isPhone ? 18 : 24, color: const Color(0x1AFFFFFF)),

                // Form Content Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tajuk Post
                        const Text('Tajuk Post *', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          decoration: _inputDecoration('Contoh: Fade Rambut Kemas / Cuci Salji Mega 🔥'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Sila masukkan tajuk post' : null,
                        ),
                        const SizedBox(height: 14),

                        // SEKSYEN MEDIA: TIKTOK STYLE STUDIO
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: Color(0xFFEC4899), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Media Suapan Video atau Gambar *',
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (_selectedFile != null || _existingMediaUrl != null)
                              GestureDetector(
                                onTap: _clearSelectedMedia,
                                child: const Text(
                                  'Tukar Media',
                                  style: TextStyle(color: Color(0xFF00F2FE), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // PRATONTON ATAU KOTAK MUAT NAIK TIKTOK
                        if (_selectedFileBytes != null || _existingMediaUrl != null) ...[
                          _buildMediaPreviewCard(),
                        ] else ...[
                          _buildTikTokDropzone(),
                        ],
                        const SizedBox(height: 14),

                        // Kapsyen Post
                        const Text('Kapsyen & Penerangan', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _captionController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Tulis kapsyen menarik tentang servis / hidangan ini...'),
                        ),
                        const SizedBox(height: 6),

                        // Hashtag Helpers
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: ['#ngam', '#promosi', '#viral', '#diskaun', '#terbaik', '#bangi'].map((tag) {
                            return InkWell(
                              onTap: () => _addHashtag(tag),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.2)),
                                ),
                                child: Text(tag, style: const TextStyle(color: Color(0xFF00F2FE), fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Tag Servis & Harga
                        const Text('Tag Servis & Harga', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _serviceTagController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Contoh: ✂️ Potong Rambut • RM35 · Buka Hingga 10 PM'),
                        ),
                        const SizedBox(height: 14),

                        // Pilihan Butang Tindakan Khas (CTA)
                        const Text('Butang Tindakan Pintas CTA', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _ctaOptions.map((opt) {
                            final selected = _ctaType == opt.type;
                            return ChoiceChip(
                              avatar: Icon(opt.icon, size: 15, color: selected ? Colors.black : const Color(0xFF00F2FE)),
                              label: Text(
                                opt.text,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFF00F2FE),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              side: BorderSide(color: selected ? const Color(0xFF00F2FE) : Colors.white.withValues(alpha: 0.12)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _ctaType = opt.type;
                                    _ctaText = opt.text;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Status & Pin Toggles (Responsive)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Siar Segera',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.85,
                                      child: Switch(
                                        value: _status == 'published',
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (val) {
                                          setState(() => _status = val ? 'published' : 'draft');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Pin ke Atas',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.85,
                                      child: Switch(
                                        value: _isPinned,
                                        activeColor: const Color(0xFF8B5CF6),
                                        onChanged: (val) {
                                          setState(() => _isPinned = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Penunjuk Kemajuan Pemampatan Video
                if (_isCompressing)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Memampatkan video (720p H.264)...',
                                  style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '${(_compressProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _compressProgress > 0 ? _compressProgress : null,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),

                // Penunjuk Kemajuan Muat Naik ke Cloudflare R2
                if (_isUploadingToR2)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEC4899)),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Memuat naik ke Cloudflare R2...',
                                  style: TextStyle(color: Color(0xFFEC4899), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFEC4899),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),

                Divider(height: isPhone ? 16 : 24, color: const Color(0x1AFFFFFF)),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'Kemaskini' : 'Siarkan Post', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTikTokDropzone() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEC4899).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEC4899).withValues(alpha: 0.25),
                  const Color(0xFF00F2FE).withValues(alpha: 0.25),
                ],
              ),
              border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.5)),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              color: Color(0xFFEC4899),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pilih Video atau Foto untuk Dimuat Naik',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Format menegak (9:16) disyorkan • MP4, MOV, WebM atau Gambar',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _pickVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.videocam_rounded, size: 19),
                label: const Text('Muat Naik Video 🎬', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              OutlinedButton.icon(
                onPressed: _pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00F2FE),
                  side: BorderSide(color: const Color(0xFF00F2FE).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_library_rounded, size: 19),
                label: const Text('Pilih Gambar 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewCard() {
    final isVideo = _mediaType == 'video';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVideo ? const Color(0xFFEC4899) : const Color(0xFF00F2FE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isVideo ? const Color(0xFFEC4899) : const Color(0xFF00F2FE)).withValues(alpha: 0.15),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isVideo) ...[
            if (_isVideoInitializing)
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0D18),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFEC4899)),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Menyediakan video & audio...',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            else if (_videoPreviewController != null && _videoPreviewController!.value.isInitialized)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: _videoPreviewController!.value.aspectRatio > 0
                      ? _videoPreviewController!.value.aspectRatio
                      : (16 / 9),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video View
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoPreviewController!.value.isPlaying) {
                              _videoPreviewController!.pause();
                            } else {
                              _videoPreviewController!.play();
                            }
                          });
                        },
                        child: SizedBox.expand(
                          child: VideoPlayer(_videoPreviewController!),
                        ),
                      ),

                      // Play/Pause Center Overlay Button
                      if (!_videoPreviewController!.value.isPlaying)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                        ),

                      // Top-Right Audio Mute/Unmute Floating Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isAudioMuted = !_isAudioMuted;
                              _videoPreviewController?.setVolume(_isAudioMuted ? 0.0 : 1.0);
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isAudioMuted ? Colors.black87 : const Color(0xFF10B981).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isAudioMuted ? Colors.white30 : const Color(0xFF10B981),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isAudioMuted ? Colors.black : const Color(0xFF10B981)).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAudioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isAudioMuted ? 'Nyahbisu Dengar Audio' : 'Audio Hidup Penuh',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom progress line
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: VideoProgressIndicator(
                          _videoPreviewController!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFFEC4899),
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Fallback preview
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.movie_rounded, color: Color(0xFFEC4899), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName ?? 'Video Dipilih',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${((_selectedFileSize ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB • Sedia untuk dimuat naik',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            // Image Preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: _selectedFileBytes != null
                    ? Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
                    : (_existingMediaUrl != null
                        ? Image.network(_existingMediaUrl!, fit: BoxFit.cover)
                        : const SizedBox()),
              ),
            ),
          ],

          // Media Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131320),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                  color: isVideo ? const Color(0xFFEC4899) : const Color(0xFF00F2FE),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFileName ?? (_existingMediaUrl != null ? 'Media Sedia Ada' : 'Fail Media'),
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedFileSize != null)
                        Text(
                          '${(_selectedFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB • Sedia ke Cloudflare R2',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: isVideo ? _pickVideo : _pickImage,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00F2FE),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.cached_rounded, size: 14),
                  label: const Text('Tukar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Buang Media',
                  onPressed: _clearSelectedMedia,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFEC4899), width: 1.2)),
    );
  }
}

// =============================================================================
// Dialog: Pratonton Gaya Skrin Telefon Pelanggan (Adaptive 9:16 Mockup)
// Menyokong penstriman video live dengan audio & kawalan interaktif
// =============================================================================
class _PhoneMockupPreviewDialog extends StatefulWidget {
  final FeedPostModel post;
  final Map<String, dynamic>? businessProfile;
  final VoidCallback? onCommentsUpdated;

  const _PhoneMockupPreviewDialog({
    required this.post,
    this.businessProfile,
    this.onCommentsUpdated,
  });

  @override
  State<_PhoneMockupPreviewDialog> createState() => _PhoneMockupPreviewDialogState();
}

class _PhoneMockupPreviewDialogState extends State<_PhoneMockupPreviewDialog> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = false;
  bool _hasVideoError = false;
  late int _liveCommentsCount;

  bool get _isVideo =>
      widget.post.mediaType == 'video' ||
      widget.post.mediaUrl.toLowerCase().contains('.mp4') ||
      widget.post.mediaUrl.toLowerCase().contains('.mov') ||
      widget.post.mediaUrl.toLowerCase().contains('.webm');

  @override
  void initState() {
    super.initState();
    _liveCommentsCount = widget.post.commentsCount;
    if (_isVideo) {
      _initVideo();
    }
  }

  void _openOwnerCommentsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnerPostCommentsSheet(
        post: widget.post,
        businessProfile: widget.businessProfile,
        onCountChanged: (newCount) {
          if (mounted) {
            setState(() => _liveCommentsCount = newCount);
          }
          widget.onCommentsUpdated?.call();
        },
        onCommentsUpdated: widget.onCommentsUpdated,
      ),
    );
  }

  void _initVideo() {
    try {
      final uri = Uri.tryParse(widget.post.mediaUrl);
      if (uri == null) {
        setState(() => _hasVideoError = true);
        return;
      }
      final controller = VideoPlayerController.networkUrl(uri);
      _videoController = controller;
      controller.initialize().then((_) async {
        if (mounted) {
          await controller.setLooping(true);
          await controller.setVolume(_isMuted ? 0.0 : 1.0);
          try {
            await controller.play();
          } catch (e) {
            debugPrint('[PhoneMockup] Autoplay blocked, muted retry: $e');
            await controller.setVolume(0.0);
            _isMuted = true;
            await controller.play();
          }
          setState(() => _isVideoInitialized = true);
        }
      }).catchError((err) {
        debugPrint('[PhoneMockup] Video error: $err');
        if (mounted) {
          setState(() => _hasVideoError = true);
        }
      });
    } catch (e) {
      debugPrint('[PhoneMockup] Init exception: $e');
      setState(() => _hasVideoError = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopName = widget.businessProfile?['name']?.toString() ?? 'Kedai Anda';
    final shopHandle = widget.businessProfile?['handle']?.toString() ?? '@${shopName.replaceAll(' ', '').toLowerCase()}';
    final logoUrl = widget.businessProfile?['logo_url']?.toString();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600;

    final mockupHeight = math.min(screenHeight * (isPhone ? 0.86 : 0.80), 620.0);
    final mockupWidth = math.min(screenWidth - (isPhone ? 24 : 64), mockupHeight * (9 / 16));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isPhone ? 12 : 24, vertical: isPhone ? 16 : 24),
      child: Center(
        child: Container(
          width: mockupWidth,
          height: mockupHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(isPhone ? 28 : 36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isPhone ? 25 : 33),
            child: Stack(
              children: [
                // Media Layer: Video atau Gambar
                Positioned.fill(
                  child: _isVideo
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isVideoInitialized && _videoController != null)
                              IgnorePointer(
                                child: SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: SizedBox(
                                      width: _videoController!.value.size.width > 0
                                          ? _videoController!.value.size.width
                                          : 16,
                                      height: _videoController!.value.size.height > 0
                                          ? _videoController!.value.size.height
                                          : 9,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  ),
                                ),
                              )
                              else if (_hasVideoError)
                                Container(
                                  color: const Color(0xFF1E1B4B),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline_rounded, color: Colors.white38, size: 40),
                                        SizedBox(height: 8),
                                        Text('Gagal memuat video', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  color: const Color(0xFF0F172A),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Color(0xFFEC4899)),
                                  ),
                                ),

                              // Interactive tap capture overlay
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _togglePlayPause,
                                ),
                              ),

                              // Animated pause indicator
                              if (_isVideoInitialized && _videoController != null && !_videoController!.value.isPlaying)
                                IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white38),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
                                  ),
                                ),
                            ],
                          )
                      : Image.network(
                          widget.post.mediaUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(color: const Color(0xFF1E1E2E));
                          },
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                        ),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Bar Mockup
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Color(0xFF00E5FF), size: 14),
                            const SizedBox(width: 3),
                            Text('${widget.post.viewsCount} Tontonan', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isVideo) ...[
                            InkWell(
                              onTap: _toggleMute,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isMuted ? Colors.black87 : const Color(0xFF10B981).withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right Action Sidebar (TikTok/Reels Style)
                Positioned(
                  right: 10,
                  bottom: isPhone ? 90 : 110,
                  child: Column(
                    children: [
                      // Shop Avatar
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEC4899)),
                                )
                              : Container(
                                  color: const Color(0xFFEC4899),
                                  child: Center(
                                    child: Text(shopName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Heart Icon
                      const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 26),
                      Text('${widget.post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Comments Icon (Interactive — Opens Owner Comments & Reply Drawer)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openOwnerCommentsDrawer,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(height: 2),
                            Text('$_liveCommentsCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            const Text('Balas', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 8.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Share Icon
                      const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                      const Text('Kongsi', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),

                // Bottom Content (Shop Info, Caption, CTA Button)
                Positioned(
                  left: 14,
                  right: 64,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shop Handle
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shopHandle,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Color(0xFF42A5F5), size: 14),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Title & Caption
                      Text(
                        widget.post.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.post.caption != null && widget.post.caption!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.post.caption!,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),

                      // CTA Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.black, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.post.ctaText,
                                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Video Progress Bar at Bottom
                if (_isVideo && _videoController != null && _isVideoInitialized)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF00E5FF),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sheet: Pengurusan Komen & Balasan Pemilik Kedai (Gaya TikTok / IG Reels)
// Membolehkan pemilik kedai melihat semua komen pelanggan (dengan profil Ngam sebenar)
// dan membalas terus dengan lencana "Pemilik Kedai" (Owner Tag).
// =============================================================================
class _OwnerPostCommentsSheet extends StatefulWidget {
  final FeedPostModel post;
  final Map<String, dynamic>? businessProfile;
  final VoidCallback? onCommentsUpdated;
  final ValueChanged<int>? onCountChanged;

  const _OwnerPostCommentsSheet({
    required this.post,
    this.businessProfile,
    this.onCommentsUpdated,
    this.onCountChanged,
  });

  @override
  State<_OwnerPostCommentsSheet> createState() => _OwnerPostCommentsSheetState();
}

class _OwnerPostCommentsSheetState extends State<_OwnerPostCommentsSheet> {
  final FeedService _feedService = FeedService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _replyingToCommentId;
  String? _replyingToUser;

  static const List<String> _quickReplies = [
    'Terima kasih! Jemput singgah lagi 🙏🔥',
    'Slot walk-in & tempahan masih dibuka hari ini! ⚡',
    'Boleh tekan butang di bawah video untuk tempah terus ya 😊',
  ];

  int get _totalCommentsCount {
    int count = 0;
    for (final c in _comments) {
      count += 1;
      final replies = c['replies'];
      if (replies is List) count += replies.length;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    final list = await _feedService.getPostComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _loading = false;
      });
      widget.onCountChanged?.call(_totalCommentsCount);
    }
  }

  String _formatTimeAgo(String raw) {
    if (raw.isEmpty) return 'Baru saja';
    DateTime? dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null && !raw.endsWith('Z') && raw.contains('T')) {
      dt = DateTime.tryParse('${raw}Z')?.toLocal();
    }
    if (dt == null) return 'Baru saja';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${dt.day}/${dt.month}';
  }

  Future<void> _sendOwnerComment({String? presetText}) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final parentId = _replyingToCommentId;
    final replyUser = _replyingToUser;

    try {
      await _feedService.postOwnerComment(
        postId: widget.post.id,
        text: text,
        parentCommentId: parentId,
        replyToUser: replyUser,
      );
      _controller.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUser = null;
      });
      await _loadComments();
      widget.onCommentsUpdated?.call();
      if (mounted) {
        showGlassToast(
          context,
          parentId != null
              ? 'Balasan Pemilik Kedai dihantar!'
              : 'Komen Pemilik Kedai disiarkan!',
          type: GlassToastType.success,
          color: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menghantar balasan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteItem(String commentId) async {
    if (commentId.isEmpty) return;
    try {
      await _feedService.deleteComment(commentId);
      await _loadComments();
      widget.onCommentsUpdated?.call();
      if (mounted) {
        showGlassToast(context, 'Komen telah dipadam.');
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memadam komen: $e', isError: true);
      }
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final String cid = item['id']?.toString() ?? '';
    final bool wasLiked = item['isLiked'] == true;
    final int currentLikes = (item['likes'] as num?)?.toInt() ?? 0;
    final bool nowLiked = !wasLiked;
    final int newLikes = nowLiked ? currentLikes + 1 : math.max(0, currentLikes - 1);

    setState(() {
      item['isLiked'] = nowLiked;
      item['likes'] = newLikes;
    });

    if (cid.isNotEmpty) {
      await _feedService.toggleLikeComment(cid, newLikes);
    }
  }

  Widget _buildAvatar(String name, String? url, {double size = 34, bool isOwner = false}) {
    final cleanUrl = (url ?? '').trim();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'N';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isOwner ? const Color(0xFFFE2C55) : Colors.white24,
          width: isOwner ? 1.5 : 1.0,
        ),
      ),
      child: ClipOval(
        child: cleanUrl.isNotEmpty
            ? Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1E293B),
                  child: Center(
                    child: Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            : Container(
                color: isOwner ? const Color(0xFFFE2C55) : const Color(0xFF1E293B),
                child: Center(
                  child: Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.bold)),
                ),
              ),
      ),
    );
  }

  Widget _buildOwnerBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFE2C55).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFFE2C55).withValues(alpha: 0.45), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_rounded, size: 10, color: Color(0xFFFE2C55)),
          SizedBox(width: 3),
          Text(
            'Pemilik Kedai',
            style: TextStyle(color: Color(0xFFFE2C55), fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String shopName = widget.businessProfile?['name']?.toString() ??
        widget.businessProfile?['business_name']?.toString() ??
        'Kedai Anda';
    final String? shopLogo = widget.businessProfile?['logo_url']?.toString() ??
        widget.businessProfile?['business_logo_url']?.toString();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF11131F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded, color: Color(0xFF00E5FF), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Komen & Balasan Pelanggan',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalCommentsCount',
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadComments,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Muat Semula',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Comments List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, color: Colors.white.withValues(alpha: 0.25), size: 42),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada komen pada video ini',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Mulakan perbualan sebagai Pemilik Kedai atau tunggu komen pelanggan daripada aplikasi Ngam!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (ctx, idx) {
                            final c = _comments[idx];
                            final String cid = c['id']?.toString() ?? '';
                            final String user = c['user']?.toString() ?? 'Pelanggan Ngam';
                            final String? avatar = c['avatar']?.toString();
                            final String text = c['text']?.toString() ?? '';
                            final String time = _formatTimeAgo(c['createdAt']?.toString() ?? '');
                            final int likes = (c['likes'] as num?)?.toInt() ?? 0;
                            final bool isLiked = c['isLiked'] == true;
                            final bool isOwner = c['isOwner'] == true;
                            final List<Map<String, dynamic>> replies =
                                (c['replies'] as List?)
                                        ?.map((e) => Map<String, dynamic>.from(e as Map))
                                        .toList() ??
                                    [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAvatar(user, avatar, size: 36, isOwner: isOwner),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  user,
                                                  style: TextStyle(
                                                    color: isOwner ? const Color(0xFFFE2C55) : Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isOwner) _buildOwnerBadge(),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            text,
                                            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _replyingToCommentId = cid;
                                                    _replyingToUser = user;
                                                  });
                                                  _focusNode.requestFocus();
                                                },
                                                child: const Text(
                                                  'Balas sebagai Pemilik',
                                                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5, fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _deleteItem(cid),
                                                child: Text(
                                                  'Padam',
                                                  style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _toggleLike(c),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Column(
                                          children: [
                                            Icon(
                                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              size: 17,
                                              color: isLiked ? const Color(0xFFFE2C55) : Colors.white38,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$likes',
                                              style: TextStyle(
                                                color: isLiked ? const Color(0xFFFE2C55) : Colors.white38,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Nested Replies
                                if (replies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 46, top: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: replies.map((r) {
                                        final String rid = r['id']?.toString() ?? '';
                                        final String rUser = r['user']?.toString() ?? 'Pelanggan';
                                        final String rTarget = r['replyToUser']?.toString() ?? '';
                                        final bool rIsOwner = r['isOwner'] == true;
                                        final int rLikes = (r['likes'] as num?)?.toInt() ?? 0;
                                        final bool rLiked = r['isLiked'] == true;

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildAvatar(rUser, r['avatar']?.toString(), size: 26, isOwner: rIsOwner),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Wrap(
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        Text(
                                                          rUser,
                                                          style: TextStyle(
                                                            color: rIsOwner ? const Color(0xFFFE2C55) : Colors.white70,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                        if (rIsOwner) _buildOwnerBadge(),
                                                        if (rTarget.isNotEmpty) ...[
                                                          const Padding(
                                                            padding: EdgeInsets.symmetric(horizontal: 3),
                                                            child: Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white38),
                                                          ),
                                                          Text(
                                                            rTarget,
                                                            style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w700),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      r['text']?.toString() ?? '',
                                                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          _formatTimeAgo(r['createdAt']?.toString() ?? ''),
                                                          style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                                                        ),
                                                        const SizedBox(width: 14),
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _replyingToCommentId = cid;
                                                              _replyingToUser = rUser;
                                                            });
                                                            _focusNode.requestFocus();
                                                          },
                                                          child: const Text(
                                                            'Balas',
                                                            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w700),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 14),
                                                        GestureDetector(
                                                          onTap: () => _deleteItem(rid),
                                                          child: Text(
                                                            'Padam',
                                                            style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _toggleLike(r),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        rLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                        size: 14,
                                                        color: rLiked ? const Color(0xFFFE2C55) : Colors.white38,
                                                      ),
                                                      Text('$rLikes', style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
            ),

            // Quick Owner Reply Templates + Input Bar
            Container(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0D16),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Reply Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: _quickReplies
                          .map(
                            (preset) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                label: Text(preset, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                onPressed: () => _sendOwnerComment(presetText: preset),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  if (_replyingToUser != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 6),
                          const Text('Membalas sebagai Pemilik kepada ', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          Expanded(
                            child: Text(
                              '@$_replyingToUser',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _replyingToCommentId = null;
                              _replyingToUser = null;
                            }),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      _buildAvatar(shopName, shopLogo, size: 34, isOwner: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFFE2C55).withValues(alpha: 0.4)),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onSubmitted: (_) => _sendOwnerComment(),
                            decoration: InputDecoration(
                              hintText: _replyingToUser != null
                                  ? 'Balas @$_replyingToUser sebagai $shopName (Pemilik)...'
                                  : 'Tulis komen sebagai $shopName (Pemilik Kedai)...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _sendOwnerComment(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFE2C55), Color(0xFFEC4899)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
  }
}

