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
                    child: _FeedPostCardThumbnail(
                      post: post,
                      height: isPhone ? 160 : 185,
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
              ? 'Post berjaya dikemaskini!'
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
        friendlyMsg = 'Ralat Kebenaran Supabase: Sila kemaskini SQL RLS feed_posts dalam Supabase SQL Editor.';
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
                                  'Media Suapan (Video / Gambar) *',
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
                                  _isAudioMuted ? 'Nyahbisu (Dengar Audio)' : 'Audio Hidup (100%)',
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

  const _PhoneMockupPreviewDialog({
    required this.post,
    this.businessProfile,
  });

  @override
  State<_PhoneMockupPreviewDialog> createState() => _PhoneMockupPreviewDialogState();
}

class _PhoneMockupPreviewDialogState extends State<_PhoneMockupPreviewDialog> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = false;
  bool _hasVideoError = false;

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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_rounded, color: Colors.white70, size: 13),
                            SizedBox(width: 4),
                            Text('Paparan Pelanggan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

                      // Comments Icon
                      const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
                      Text('${widget.post.commentsCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
