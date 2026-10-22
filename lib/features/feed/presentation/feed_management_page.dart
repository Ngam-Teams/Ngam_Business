import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../widgets/glass_toast.dart';
import '../data/feed_service.dart';
import '../models/feed_post_model.dart';
import '../../settings/data/business_service.dart';

/// FeedManagementPage — Ngam Feed & Post Studio.
/// Dioptimumkan sepenuhnya untuk responsif telefon pintar (Mobile-Friendly)
/// dan desktop browser.
class FeedManagementPage extends StatefulWidget {
  const FeedManagementPage({super.key});

  @override
  State<FeedManagementPage> createState() => _FeedManagementPageState();
}

class _FeedManagementPageState extends State<FeedManagementPage> {
  final FeedService _feedService = FeedService();
  final BusinessService _businessService = BusinessService();

  bool _loading = true;
  String _selectedFilter = 'all'; // 'all', 'published', 'draft', 'pinned'
  List<FeedPostModel> _posts = [];
  Map<String, int> _stats = {
    'totalPosts': 0,
    'totalViews': 0,
    'totalLikes': 0,
    'totalComments': 0,
  };
  Map<String, dynamic>? _businessProfile;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
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
    final posts = await _feedService.getPosts(filter: _selectedFilter);
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

  void _openCreateOrEditPostDialog({FeedPostModel? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateEditPostDialog(
        existing: existing,
        businessCategory: _businessProfile?['category']?.toString() ?? 'services',
        onSaved: () {
          _loadInitialData();
        },
      ),
    );
  }

  void _showPhonePreview(FeedPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => _PhoneMockupPreviewDialog(
        post: post,
        businessProfile: _businessProfile,
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              color: Color(0xFFEC4899),
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isPhone ? 'Feed & Post' : 'Ngam Feed & Post Studio',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Muat Semula',
            onPressed: _loadInitialData,
          ),
          if (!isPhone) ...[
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => _openCreateOrEditPostDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Cipta Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 16),
          ] else
            const SizedBox(width: 8),
        ],
      ),
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
                padding: EdgeInsets.fromLTRB(16, 8, 16, isPhone ? 90 : 40),
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

  Widget _buildMetricHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                color: Color(0xFF42A5F5),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prestasi Jangkauan Feed Pelanggan',
                  style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final isPhone = constraints.maxWidth < 600;

              final items = [
                _buildStatItem('Jumlah Post', '${_stats['totalPosts'] ?? _posts.length}', Icons.grid_view_rounded, const Color(0xFF8B5CF6), isPhone),
                _buildStatItem('Tontonan', '${_stats['totalViews'] ?? 0}', Icons.remove_red_eye_rounded, const Color(0xFF42A5F5), isPhone),
                _buildStatItem('Sukaan', '${_stats['totalLikes'] ?? 0}', Icons.favorite_rounded, const Color(0xFFEF4444), isPhone),
                _buildStatItem('Komen', '${_stats['totalComments'] ?? 0}', Icons.chat_bubble_rounded, const Color(0xFFF59E0B), isPhone),
              ];

              if (isWide) {
                return Row(
                  children: items.map((w) => Expanded(child: w)).toList(),
                );
              } else {
                return Column(
                  children: [
                    Row(children: [Expanded(child: items[0]), const SizedBox(width: 8), Expanded(child: items[1])]),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: items[2]), const SizedBox(width: 8), Expanded(child: items[3])]),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isPhone) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 10 : 14, vertical: isPhone ? 9 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isPhone ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isPhone ? 16 : 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isPhone ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: isPhone ? 10.5 : 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('Semua (${_stats['totalPosts'] ?? _posts.length})', 'all', const Color(0xFFEC4899)),
          const SizedBox(width: 8),
          _buildFilterChip('Diterbitkan', 'published', const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildFilterChip('Draf', 'draft', const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildFilterChip('Disematkan 📌', 'pinned', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.85),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      side: BorderSide(color: isSelected ? color : Colors.white.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
          _fetchPosts();
        }
      },
    );
  }

  Widget _buildPostsLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isGrid = constraints.maxWidth >= 720;

        if (isGrid) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 420,
            ),
            itemBuilder: (context, index) => _buildPostCard(_posts[index]),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildPostCard(_posts[index]),
        );
      },
    );
  }

  Widget _buildPostCard(FeedPostModel post) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 450;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: post.isPinned
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.12),
              width: post.isPinned ? 1.6 : 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Thumbnail Banner
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: isPhone ? 160 : 185,
                      width: double.infinity,
                      child: Image.network(
                        post.mediaUrl,
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
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Badges
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: post.isPublished
                                ? const Color(0xFF10B981).withValues(alpha: 0.9)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.isPublished ? 'DITERBITKAN' : 'DRAF',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (post.isPinned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('PIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Date in Top Right
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        post.formattedDate,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),

                  // Bottom of Image: CTA Tag Badge
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F2FE).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.ctaText,
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (post.serviceTag != null && post.serviceTag!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                post.serviceTag!,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Content Section
              Padding(
                padding: EdgeInsets.all(isPhone ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isPhone ? 14.5 : 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    if (post.caption != null && post.caption!.isNotEmpty)
                      Text(
                        post.caption!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 10),

                    // Engagement Metrics Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricMini(Icons.remove_red_eye_rounded, '${post.viewsCount}', const Color(0xFF42A5F5)),
                          _buildMetricMini(Icons.favorite_rounded, '${post.likesCount}', const Color(0xFFEF4444)),
                          _buildMetricMini(Icons.chat_bubble_rounded, '${post.commentsCount}', const Color(0xFFF59E0B)),
                          _buildMetricMini(Icons.share_rounded, '${post.sharesCount}', const Color(0xFF10B981)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Action Buttons Bar (Responsive for Phone Screens)
                    Row(
                      children: [
                        // Preview Button (Mockup Reels)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showPhonePreview(post),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00F2FE),
                              side: BorderSide(color: const Color(0xFF00F2FE).withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.phone_iphone_rounded, size: 15),
                            label: Text(
                              isPhone ? 'Pratonton' : 'Pratonton Feed',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Pin Button
                        IconButton(
                          padding: const EdgeInsets.all(7),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: Icon(
                            post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            color: post.isPinned ? const Color(0xFF8B5CF6) : Colors.white60,
                            size: 19,
                          ),
                          tooltip: post.isPinned ? 'Tanggalkan Pin' : 'Sematkan ke Atas',
                          onPressed: () => _togglePin(post),
                        ),

                        // Edit Button
                        IconButton(
                          padding: const EdgeInsets.all(7),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF42A5F5), size: 21),
                          tooltip: 'Sunting Post',
                          onPressed: () => _openCreateOrEditPostDialog(existing: post),
                        ),

                        // Delete Button
                        IconButton(
                          padding: const EdgeInsets.all(7),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                          tooltip: 'Padam Post',
                          onPressed: () => _deletePost(post),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricMini(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
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
// Dialog: Cipta & Sunting Post Baharu (Responsive Modal)
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

  late TextEditingController _titleController;
  late TextEditingController _captionController;
  late TextEditingController _mediaUrlController;
  late TextEditingController _serviceTagController;

  String _ctaType = 'queue';
  String _ctaText = '⚡ AMBIL GILIRAN';
  String _status = 'published';
  bool _isPinned = false;
  bool _saving = false;

  static const _presetImages = [
    (label: 'Rambut Fade', url: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800'),
    (label: 'Cuci Kereta Wax', url: 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=800'),
    (label: 'Kopi & Roti', url: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=800'),
    (label: 'Servis Bengkel', url: 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=800'),
    (label: 'Kedai Retail/Butik', url: 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?q=80&w=800'),
  ];

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
    _mediaUrlController = TextEditingController(
      text: p?.mediaUrl ?? _presetImages[0].url,
    );
    _serviceTagController = TextEditingController(text: p?.serviceTag ?? '');

    if (p != null) {
      _ctaType = p.ctaType;
      _ctaText = p.ctaText;
      _status = p.status;
      _isPinned = p.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _mediaUrlController.dispose();
    _serviceTagController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await _feedService.updatePost(
          postId: widget.existing!.id,
          title: _titleController.text.trim(),
          caption: _captionController.text.trim(),
          mediaUrl: _mediaUrlController.text.trim(),
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
          mediaUrl: _mediaUrlController.text.trim(),
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
          widget.existing != null ? 'Post berjaya dikemaskini!' : 'Post berjaya diterbitkan di Ngam Feed!',
          customColor: const Color(0xFF10B981),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Ralat: $e', isError: true);
        setState(() => _saving = false);
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
          maxHeight: isPhone ? screenHeight * 0.92 : 760,
        ),
        child: Padding(
          padding: EdgeInsets.all(isPhone ? 16 : 22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: Color(0xFFEC4899), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Kemaskini Post' : 'Cipta Post Baharu',
                            style: TextStyle(color: Colors.white, fontSize: isPhone ? 15.5 : 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Dipaparkan secara langsung kepada pelanggan',
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

                        // URL Gambar & Preset
                        const Text('Gambar / Media URL *', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _mediaUrlController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('https://...').copyWith(
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                              onPressed: () => _mediaUrlController.clear(),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Sila masukkan URL media' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),

                        // Preset chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _presetImages.map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(p.label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onPressed: () {
                                    _mediaUrlController.text = p.url;
                                    setState(() {});
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
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
                        const Text('Butang Tindakan Pintas (CTA)', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
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

                        // Status & Pin Toggles (Responsive for Phone Screens)
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
// =============================================================================
class _PhoneMockupPreviewDialog extends StatelessWidget {
  final FeedPostModel post;
  final Map<String, dynamic>? businessProfile;

  const _PhoneMockupPreviewDialog({
    required this.post,
    this.businessProfile,
  });

  @override
  Widget build(BuildContext context) {
    final shopName = businessProfile?['name']?.toString() ?? 'Kedai Anda';
    final shopHandle = businessProfile?['handle']?.toString() ?? '@${shopName.replaceAll(' ', '').toLowerCase()}';
    final logoUrl = businessProfile?['logo_url']?.toString();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600;

    // Dynamically calculate mockup height and width to prevent vertical overflow on any phone screen
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
                // Background Media Image
                Positioned.fill(
                  child: Image.network(
                    post.mediaUrl,
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, color: Colors.white70, size: 13),
                            SizedBox(width: 4),
                            Text('Paparan Pelanggan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
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
                      Text('${post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Comments Icon
                      const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
                      Text('${post.commentsCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        post.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.caption != null && post.caption!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.caption!,
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
                                post.ctaText,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
