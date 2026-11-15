import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/services/r2_storage_service.dart';
import '../../../core/services/video_compression_service.dart';
import '../../../widgets/glass_nav_button.dart';
import '../../../widgets/glass_toast.dart';
import '../data/feed_service.dart';
import '../models/feed_post_model.dart';

/// FeedCreatePage — Halaman Cipta & Muat Naik Video/Post Ala TikTok Studio.
/// Dilengkapi dengan:
/// - Aliran 2 langkah ala TikTok (1. Pilih & Pratonton Media 9:16 -> 2. Kapsyen, CTA Ngam & Siar/Draf)
/// - Pilihan CTA terus ke fungsi Ngam (Order Now, Booking, Walk-in / Giliran, Tanya Kedai, Promo)
/// - Sokongan Simpan ke Draf & Siar Segera
/// - Kunci Idempotensi Ketat (_isSubmittingLock) supaya menekan butang 10x semasa lag HANYA muat naik 1x ke Cloudflare R2.
class FeedCreatePage extends StatefulWidget {
  final FeedPostModel? existing;
  final String businessCategory;

  const FeedCreatePage({
    super.key,
    this.existing,
    this.businessCategory = 'services',
  });

  @override
  State<FeedCreatePage> createState() => _FeedCreatePageState();
}

class _FeedCreatePageState extends State<FeedCreatePage> {
  final FeedService _feedService = FeedService();
  final R2StorageService _r2Storage = R2StorageService();
  final VideoCompressionService _compressor = VideoCompressionService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _serviceTagController = TextEditingController();
  final _urlController = TextEditingController();

  // Step 0 = Pilih Media, Step 1 = Kapsyen & Tetapan (untuk telefon); Desktop tunjuk sebelah-menyebelah
  int _mobileStep = 0;

  String _mediaType = 'video'; // 'video' or 'image'
  String _ctaType = 'queue';
  String _ctaText = '⚡ AMBIL GILIRAN';
  bool _isPinned = false;

  // Media state
  XFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _existingMediaUrl;
  String? _uploadedR2Url; // Cache URL jika sudah dimuat naik dalam sesi ini
  bool _showUrlInput = false;

  // Video preview controller
  VideoPlayerController? _previewController;
  bool _previewInitialized = false;
  bool _isPreviewPlaying = true;
  bool _isPreviewMuted = false;

  // Strict Upload / Submit Lock (Anti 10x Click Bug!)
  bool _isSubmittingLock = false;
  bool _saving = false;
  bool _isCompressing = false;
  double _compressProgress = 0.0;
  bool _isUploadingToR2 = false;
  double _uploadProgress = 0.0;

  static const List<Map<String, dynamic>> _ngamCtaOptions = [
    {
      'key': 'queue',
      'label': 'Ambil Giliran',
      'ctaText': '⚡ AMBIL GILIRAN',
      'desc': 'Pelanggan terus masuk senarai giliran kedai',
      'icon': HugeIcons.strokeRoundedFlash,
      'color': Color(0xFF00E5FF),
    },
    {
      'key': 'walkin',
      'label': 'Walk-in Sekarang',
      'ctaText': '🚶 WALK-IN SEKARANG',
      'desc': 'Ajak pelanggan terus datang ke lokasi kedai',
      'icon': HugeIcons.strokeRoundedStore01,
      'color': Color(0xFF10B981),
    },
    {
      'key': 'menu',
      'label': 'Order Now',
      'ctaText': '🛒 ORDER NOW',
      'desc': 'Buka menu & bakul untuk pesan terus',
      'icon': HugeIcons.strokeRoundedShoppingBag01,
      'color': Color(0xFFF59E0B),
    },
    {
      'key': 'booking',
      'label': 'Booking Slot',
      'ctaText': '📅 BOOKING SEKARANG',
      'desc': 'Tempah slot tarikh & masa janji temu',
      'icon': HugeIcons.strokeRoundedCalendar03,
      'color': Color(0xFF8B5CF6),
    },
    {
      'key': 'whatsapp',
      'label': 'Tanya Kedai',
      'ctaText': '💬 TANYA KEDAI',
      'desc': 'Hubungi kedai terus untuk pertanyaan',
      'icon': HugeIcons.strokeRoundedMessage01,
      'color': Color(0xFFEC4899),
    },
    {
      'key': 'general',
      'label': 'Lihat Promo',
      'ctaText': '✨ LIHAT PROMO',
      'desc': 'Paparkan profil kedai & promosi aktif',
      'icon': HugeIcons.strokeRoundedSparkles,
      'color': Color(0xFF3B82F6),
    },
  ];

  static const List<String> _hashtags = [
    '#ngam',
    '#promo',
    '#viral',
    '#sedap',
    '#wajibcuba',
    '#murah',
    '#trending',
    '#walkin',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _captionController.text = e.caption ?? '';
      _serviceTagController.text = e.serviceTag ?? '';
      _mediaType = e.mediaType;
      _ctaType = e.ctaType;
      _ctaText = e.ctaText;
      _isPinned = e.isPinned;
      _existingMediaUrl = e.mediaUrl;
      _urlController.text = e.mediaUrl;
      _mobileStep = 1; // Terus ke halaman butiran jika menyunting
      if (e.mediaType == 'video' && e.mediaUrl.isNotEmpty) {
        _initNetworkVideoPreview(e.mediaUrl);
      }
    } else {
      final cat = widget.businessCategory.toLowerCase();
      if (cat.contains('cafe') || cat.contains('food') || cat.contains('restaurant')) {
        _ctaType = 'menu';
        _ctaText = '🛒 ORDER NOW';
      } else if (cat.contains('salon') || cat.contains('spa') || cat.contains('clinic')) {
        _ctaType = 'booking';
        _ctaText = '📅 BOOKING SEKARANG';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _serviceTagController.dispose();
    _urlController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _initNetworkVideoPreview(String url) async {
    await _previewController?.dispose();
    setState(() {
      _previewController = null;
      _previewInitialized = false;
    });
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() {
          _previewController = ctrl;
          _previewInitialized = true;
          _isPreviewPlaying = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('[FeedCreatePage] Video preview error: $e');
    }
  }

  Future<void> _pickMedia({required bool isVideo, ImageSource source = ImageSource.gallery}) async {
    if (_isSubmittingLock || _saving) return;
    try {
      XFile? picked;
      if (isVideo) {
        picked = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 3),
        );
      } else {
        picked = await _picker.pickImage(
          source: source,
          imageQuality: 88,
          maxWidth: 1440,
        );
      }
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final sizeMb = bytes.length / (1024 * 1024);
      if (sizeMb > 120) {
        if (mounted) {
          showGlassToast(
            context,
            'Saiz fail (${sizeMb.toStringAsFixed(1)} MB) melebihi had 120 MB.',
            isError: true,
          );
        }
        return;
      }

      await _previewController?.dispose();
      _previewController = null;
      _previewInitialized = false;

      setState(() {
        _mediaType = isVideo ? 'video' : 'image';
        _selectedFile = picked;
        _selectedFileBytes = bytes;
        _selectedFileName = picked!.name;
        _uploadedR2Url = null; // Reset cache kerana fail baharu dipilih
        _existingMediaUrl = null;
        _urlController.clear();
      });

      if (isVideo) {
        try {
          final ctrl = kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
              : VideoPlayerController.networkUrl(Uri.file(picked.path));
          await ctrl.initialize();
          await ctrl.setLooping(true);
          await ctrl.play();
          if (mounted) {
            setState(() {
              _previewController = ctrl;
              _previewInitialized = true;
              _isPreviewPlaying = true;
            });
          } else {
            ctrl.dispose();
          }
        } catch (e) {
          debugPrint('[FeedCreatePage] Local video preview error: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memilih media: $e', isError: true);
      }
    }
  }

  void _applyUrlMedia() {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      showGlassToast(context, 'Sila masukkan URL media yang sah (https://...)', isError: true);
      return;
    }
    final lower = url.toLowerCase();
    final isVid = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm') || lower.contains('/video/');
    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _uploadedR2Url = null;
      _existingMediaUrl = url;
      _mediaType = isVid ? 'video' : 'image';
      _showUrlInput = false;
    });
    if (isVid) {
      _initNetworkVideoPreview(url);
    }
  }

  void _appendHashtag(String tag) {
    final cur = _captionController.text;
    final prefix = cur.isEmpty || cur.endsWith(' ') ? '' : ' ';
    _captionController.text = '$cur$prefix$tag ';
    _captionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _captionController.text.length),
    );
    setState(() {});
  }

  bool get _hasMedia =>
      (_selectedFileBytes != null && _selectedFileName != null) ||
      (_existingMediaUrl != null && _existingMediaUrl!.isNotEmpty);

  /// Simpan atau Siar dengan KUNCI IDEMPOTENSI KETAT (_isSubmittingLock).
  /// Walaupun pengguna menekan butang 10 kali ketika lag, ia hanya akan berjalan SEKALI SAHAJA!
  Future<void> _submit(String targetStatus) async {
    // 1. Synchronous Guard — HALANG sebarang klik berganda sebelum frame setState sempat rebuild!
    if (_isSubmittingLock || _saving) return;
    _isSubmittingLock = true;

    try {
      if (!_hasMedia) {
        showGlassToast(context, 'Sila pilih video atau gambar terlebih dahulu!', isError: true);
        _isSubmittingLock = false;
        return;
      }

      final titleText = _titleController.text.trim();
      final captionText = _captionController.text.trim();

      if (titleText.isEmpty && captionText.isEmpty) {
        showGlassToast(context, 'Sila masukkan tajuk atau kapsyen siaran anda.', isError: true);
        _isSubmittingLock = false;
        return;
      }

      final effectiveTitle = titleText.isNotEmpty
          ? titleText
          : (captionText.length > 48 ? '${captionText.substring(0, 48)}...' : captionText);

      setState(() => _saving = true);

      String finalMediaUrl = _uploadedR2Url ?? _existingMediaUrl ?? '';

      // 2. Muat naik ke R2 hanya jika belum pernah dimuat naik dalam sesi ini
      if (_uploadedR2Url == null && _selectedFileBytes != null && _selectedFileName != null) {
        Uint8List bytesToUpload = _selectedFileBytes!;
        final String fileNameToUpload = _selectedFileName!;

        // Mampatkan video jika video
        if (_mediaType == 'video' && _selectedFile != null) {
          if (mounted) {
            setState(() {
              _isCompressing = true;
              _compressProgress = 0.1;
            });
          }

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
          }
        }

        if (mounted) {
          setState(() {
            _isUploadingToR2 = true;
            _uploadProgress = 0.05;
          });
        }

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

        _uploadedR2Url = finalMediaUrl;
        await _compressor.disposeCache();

        if (mounted) {
          setState(() => _isUploadingToR2 = false);
        }
      }

      // Peta ctaType 'walkin' -> 'queue' di backend supaya pelanggan terus ke tab kedai/giliran,
      // manakala ctaText kekal '🚶 WALK-IN SEKARANG'
      final effectiveCtaType = _ctaType == 'walkin' ? 'queue' : _ctaType;

      if (widget.existing != null) {
        await _feedService.updatePost(
          postId: widget.existing!.id,
          title: effectiveTitle,
          caption: captionText.isEmpty ? null : captionText,
          mediaUrl: finalMediaUrl,
          mediaType: _mediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim().isEmpty ? null : _serviceTagController.text.trim(),
          ctaType: effectiveCtaType,
          ctaText: _ctaText,
          status: targetStatus,
          isPinned: _isPinned,
        );
      } else {
        await _feedService.createPost(
          title: effectiveTitle,
          caption: captionText.isEmpty ? null : captionText,
          mediaUrl: finalMediaUrl,
          mediaType: _mediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim().isEmpty ? null : _serviceTagController.text.trim(),
          ctaType: effectiveCtaType,
          ctaText: _ctaText,
          status: targetStatus,
          isPinned: _isPinned,
        );
      }

      if (mounted) {
        showGlassToast(
          context,
          targetStatus == 'draft'
              ? 'Disimpan ke Draf!'
              : (widget.existing != null ? 'Siaran berjaya dikemaskini!' : 'Siaran diterbitkan ke Ngam Feed!'),
          type: GlassToastType.success,
          color: targetStatus == 'draft' ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        );
        Navigator.pop(context, true);
        // Kekalkan _isSubmittingLock = true selepas berjaya pop supaya tiada panggilan susulan
      }
    } catch (e) {
      _isSubmittingLock = false;
      if (mounted) {
        setState(() {
          _saving = false;
          _isCompressing = false;
          _isUploadingToR2 = false;
        });
        showGlassToast(context, 'Gagal menyimpan siaran: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 880;
    final isEdit = widget.existing != null;

    return PopScope(
      canPop: !_saving,
      child: GlassScaffold(
        backgroundColor: const Color(0xFF0A0A14),
        title: isEdit ? 'Sunting Siaran' : 'Cipta Siaran Baru',
        subtitle: isDesktop ? 'TikTok Creator Studio' : (_mobileStep == 0 ? 'Langkah 1/2 • Pilih Media' : 'Langkah 2/2 • Butiran & Siar'),
        actionItems: [
          if (!isDesktop && _mobileStep == 1 && !_saving)
            GlassNavPillItem(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Tukar Media',
              onTap: () => setState(() => _mobileStep = 0),
            ),
        ],
        body: Stack(
          children: [
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kiri: 9:16 TikTok Media Preview Stage
                    SizedBox(
                      width: 340,
                      child: _buildMediaStage(isDesktop: true),
                    ),
                    const SizedBox(width: 24),
                    // Kanan: Borang Kapsyen, Hashtag, CTA Ngam & Butang Siar/Draf
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildDetailsForm(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBottomActionBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Expanded(
                    child: _mobileStep == 0
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 68, 16, 12),
                            child: _buildMediaStage(isDesktop: false),
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 68, 16, 20),
                            child: _buildDetailsForm(),
                          ),
                  ),
                  _buildMobileFooter(),
                ],
              ),

            // Overlay Kunci Muat Naik (Menghalang sebarang interaksi semasa muat naik)
            if (_saving) _buildUploadOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaStage({required bool isDesktop}) {
    return Column(
      mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
      children: [
        // Tab Video / Foto ala TikTok
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildMediaTabChip(
                  label: 'Video (9:16)',
                  icon: HugeIcons.strokeRoundedVideo01,
                  selected: _mediaType == 'video',
                  onTap: () => setState(() => _mediaType = 'video'),
                ),
              ),
              Expanded(
                child: _buildMediaTabChip(
                  label: 'Foto / Poster',
                  icon: HugeIcons.strokeRoundedImage01,
                  selected: _mediaType == 'image',
                  onTap: () => setState(() => _mediaType = 'image'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Kanvas 9:16
        Flexible(
          child: AspectRatio(
            aspectRatio: 9 / 15,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF141422),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasMedia ? const Color(0xFFEC4899).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _hasMedia ? _buildActiveMediaPreview() : _buildEmptyMediaPicker(),
            ),
          ),
        ),

        const SizedBox(height: 10),
        // Pilihan Pantas: Galeri / Kamera / URL
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniActionChip(
              icon: Icons.photo_library_rounded,
              label: 'Galeri',
              onTap: () => _pickMedia(isVideo: _mediaType == 'video', source: ImageSource.gallery),
            ),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              _buildMiniActionChip(
                icon: Icons.videocam_rounded,
                label: _mediaType == 'video' ? 'Rakam' : 'Kamera',
                onTap: () => _pickMedia(isVideo: _mediaType == 'video', source: ImageSource.camera),
              ),
            ],
            const SizedBox(width: 8),
            _buildMiniActionChip(
              icon: Icons.link_rounded,
              label: 'Pautan URL',
              onTap: () => setState(() => _showUrlInput = !_showUrlInput),
            ),
          ],
        ),

        if (_showUrlInput) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'https://.../video.mp4',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyUrlMedia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Guna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMediaTabChip({
    required String label,
    required dynamic icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icon, color: selected ? Colors.white : Colors.white54, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMediaPicker() {
    return InkWell(
      onTap: () => _pickMedia(isVideo: _mediaType == 'video', source: ImageSource.gallery),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFEC4899).withValues(alpha: 0.08),
              const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: HugeIcon(
                icon: _mediaType == 'video' ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedImage01,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _mediaType == 'video' ? 'Pilih Video Menegak (9:16)' : 'Pilih Foto / Poster Promosi',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Ketik di sini untuk muat naik dari galeri. Video akan dimampatkan secara pintar sebelum disimpan ke Cloudflare R2.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMediaPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mediaType == 'video') ...[
          if (_previewInitialized && _previewController != null)
            GestureDetector(
              onTap: () {
                if (_previewController!.value.isPlaying) {
                  _previewController!.pause();
                  setState(() => _isPreviewPlaying = false);
                } else {
                  _previewController!.play();
                  setState(() => _isPreviewPlaying = true);
                }
              },
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _previewController!.value.size.width,
                  height: _previewController!.value.size.height,
                  child: VideoPlayer(_previewController!),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFEC4899), strokeWidth: 2.5),
                  SizedBox(height: 10),
                  Text('Menyediakan pratonton video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
        ] else ...[
          if (_selectedFileBytes != null)
            Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
          else if (_existingMediaUrl != null)
            Image.network(_existingMediaUrl!, fit: BoxFit.cover),
        ],

        // Play/Pause Indicator overlay
        if (_mediaType == 'video' && _previewInitialized && !_isPreviewPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          ),

        // Bottom gradient overlay with TikTok-style CTA preview
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_serviceTagController.text.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _serviceTagController.text.trim(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _ctaText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top controls (Mute & Remove)
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            children: [
              if (_mediaType == 'video' && _previewInitialized)
                _buildCircleIconBtn(
                  icon: _isPreviewMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  onTap: () {
                    final next = !_isPreviewMuted;
                    _previewController?.setVolume(next ? 0.0 : 1.0);
                    setState(() => _isPreviewMuted = next);
                  },
                ),
              const SizedBox(width: 6),
              _buildCircleIconBtn(
                icon: Icons.close_rounded,
                onTap: () async {
                  await _previewController?.dispose();
                  setState(() {
                    _previewController = null;
                    _previewInitialized = false;
                    _selectedFile = null;
                    _selectedFileBytes = null;
                    _selectedFileName = null;
                    _uploadedR2Url = null;
                    _existingMediaUrl = null;
                    _urlController.clear();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleIconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildMiniActionChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Langkah 2: Borang Kapsyen + CTA Ngam ala TikTok
  Widget _buildDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TikTok Top Card: Input Tajuk/Kapsyen + Mini Thumbnail 9:16
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLength: 80,
                      decoration: const InputDecoration(
                        hintText: 'Tajuk menarik (cth: Promo Kopi RM5)...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.only(bottom: 8),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                      maxLines: 4,
                      minLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Tulis kapsyen, cerita & hashtag untuk tarik pelanggan...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Mini 9:16 Thumbnail (TikTok style)
              GestureDetector(
                onTap: () {
                  if (MediaQuery.sizeOf(context).width < 880) {
                    setState(() => _mobileStep = 0);
                  }
                },
                child: Container(
                  width: 78,
                  height: 112,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181828),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_mediaType == 'image' && _selectedFileBytes != null)
                        Image.memory(_selectedFileBytes!, fit: BoxFit.cover)
                      else if (_mediaType == 'image' && _existingMediaUrl != null)
                        Image.network(_existingMediaUrl!, fit: BoxFit.cover)
                      else if (_previewInitialized && _previewController != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _previewController!.value.size.width,
                            height: _previewController!.value.size.height,
                            child: VideoPlayer(_previewController!),
                          ),
                        )
                      else
                        const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 28)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          color: Colors.black54,
                          child: const Text(
                            'Tukar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Hashtags
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _hashtags.map((tag) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => _appendHashtag(tag),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(tag, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Seksyen 2: Butang Tindakan Ngam (Order Now, Booking, Walk-in, Giliran)
        const Row(
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedFlash, color: Color(0xFFEC4899), size: 18),
            SizedBox(width: 8),
            Text(
              'Butang Tindakan Pelanggan (CTA Ngam)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih tindakan terus apabila pelanggan mengetik butang pada video anda di Ngam App.',
          style: TextStyle(color: Colors.white54, fontSize: 11.5),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ngamCtaOptions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 74,
          ),
          itemBuilder: (context, idx) {
            final opt = _ngamCtaOptions[idx];
            final key = opt['key'] as String;
            final color = opt['color'] as Color;
            final isSelected = _ctaType == key;

            return InkWell(
              onTap: () {
                setState(() {
                  _ctaType = key;
                  _ctaText = opt['ctaText'] as String;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(icon: opt['icon'], color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt['desc'] as String,
                            style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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

        const SizedBox(height: 16),

        // Tag Servis / Harga Pilihan
        TextField(
          controller: _serviceTagController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Tag Produk / Servis & Harga (Pilihan)',
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
            hintText: 'Cth: 🍔 Set Burger Special • RM14.90',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: const Icon(Icons.local_offer_outlined, color: Color(0xFF00E5FF), size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Pin Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.push_pin_rounded, color: Color(0xFF8B5CF6), size: 18),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sematkan ke Atas Profil (Pin)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Video ini sentiasa muncul paling atas', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isPinned,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (val) => setState(() => _isPinned = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10101D),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: _mobileStep == 0
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasMedia ? () => setState(() => _mobileStep = 1) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Seterusnya', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            )
          : _buildBottomActionBar(),
    );
  }

  Widget _buildBottomActionBar() {
    final isLocked = _saving || _isSubmittingLock;
    return Row(
      children: [
        // Butang Simpan Draf
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLocked ? null : () => _submit('draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Simpan Draf', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        // Butang Siarkan Sekarang
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isLocked ? null : () => _submit('published'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              disabledBackgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
            label: Text(
              widget.existing != null ? 'Kemaskini & Siar' : 'Siarkan Sekarang',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOverlay() {
    final bool isComp = _isCompressing;
    final double progress = isComp ? _compressProgress : (_isUploadingToR2 ? _uploadProgress : 1.0);
    final String title = isComp
        ? 'Memampatkan Video (720p)...'
        : (_isUploadingToR2 ? 'Memuat Naik ke Cloudflare R2...' : 'Menyimpan Siaran...');

    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: const Color(0xFF161626),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFEC4899), strokeWidth: 3),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).clamp(0, 100).toInt()}% • Jangan tutup halaman ini',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.white12,
                  color: isComp ? const Color(0xFF8B5CF6) : const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
