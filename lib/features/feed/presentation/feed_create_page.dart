import 'package:easy_localization/easy_localization.dart';
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
/// - Pemilihan Media Bersepadu Auto-Kesan (Video & Gambar campur dalam satu siaran)
/// - Susun semula slaid secara seret (Drag & Drop Reorder ala TikTok Carousel)
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

  static const int _maxCtaCount = 3;
  final List<String> _selectedCtaKeys = [];
  bool _isPinned = false;

  // Multi-media Carousel state (supports mixed videos + photos)
  final List<_DraftMediaItem> _mediaItems = [];
  int _mediaUidCounter = 0;
  int _activeMediaIndex = 0;
  final PageController _previewPageController = PageController();
  bool _isPreviewMuted = false;
  bool _showUrlInput = false;

  // Strict Upload / Submit Lock (Anti 10x Click Bug!)
  bool _isSubmittingLock = false;
  bool _saving = false;
  bool _isCompressing = false;
  double _compressProgress = 0.0;
  bool _isUploadingToR2 = false;
  double _uploadProgress = 0.0;

  static const int _maxCarouselItems = 10;

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
      'icon': HugeIcons.strokeRoundedShoppingCart02,
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

  Map<String, dynamic>? _findCtaOption(String key) {
    for (final opt in _ngamCtaOptions) {
      if (opt['key'] == key) return opt;
    }
    return null;
  }

  List<FeedCtaItem> get _selectedCtaItems {
    final items = <FeedCtaItem>[];
    for (final key in _selectedCtaKeys) {
      final opt = _findCtaOption(key);
      if (opt != null) {
        items.add(FeedCtaItem(
          type: key == 'walkin' ? 'queue' : key,
          text: opt['ctaText'] as String,
        ));
      }
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _captionController.text = e.caption ?? '';
      _serviceTagController.text = e.serviceTag ?? '';
      for (final cta in e.ctaItems) {
        String matchedKey = cta.type;
        if (cta.text.toUpperCase().contains('WALK-IN')) {
          matchedKey = 'walkin';
        }
        if (_findCtaOption(matchedKey) != null &&
            !_selectedCtaKeys.contains(matchedKey) &&
            _selectedCtaKeys.length < _maxCtaCount) {
          _selectedCtaKeys.add(matchedKey);
        }
      }
      _isPinned = e.isPinned;
      _mobileStep = 1; // Terus ke halaman butiran jika menyunting
      for (final item in e.mediaItems) {
        final draft = _DraftMediaItem(
          uid: 'm_${_mediaUidCounter++}',
          type: item.type,
          uploadedUrl: item.url,
        );
        _mediaItems.add(draft);
        if (draft.type == 'video' && item.url.isNotEmpty) {
          _initItemVideoPreview(draft, networkUrl: item.url);
        }
      }
      if (_mediaItems.length == 1) {
        _urlController.text = _mediaItems.first.uploadedUrl ?? '';
      }
    } else {
      final cat = widget.businessCategory.toLowerCase();
      if (cat.contains('cafe') || cat.contains('food') || cat.contains('restaurant')) {
        _selectedCtaKeys.add('menu');
      } else if (cat.contains('salon') || cat.contains('spa') || cat.contains('clinic')) {
        _selectedCtaKeys.add('booking');
      } else {
        _selectedCtaKeys.add('queue');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _serviceTagController.dispose();
    _urlController.dispose();
    _previewPageController.dispose();
    for (final item in _mediaItems) {
      item.videoController?.dispose();
    }
    super.dispose();
  }

  Future<void> _initItemVideoPreview(_DraftMediaItem item, {String? networkUrl, XFile? localFile}) async {
    await item.videoController?.dispose();
    item.videoController = null;
    item.videoInitialized = false;
    try {
      final ctrl = networkUrl != null
          ? VideoPlayerController.networkUrl(Uri.parse(networkUrl))
          : (kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(localFile!.path))
              : VideoPlayerController.networkUrl(Uri.file(localFile!.path)));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_isPreviewMuted ? 0.0 : 1.0);
      if (_mediaItems.indexOf(item) == _activeMediaIndex) {
        await ctrl.play();
        item.isPlaying = true;
      } else {
        item.isPlaying = false;
      }
      if (mounted) {
        setState(() {
          item.videoController = ctrl;
          item.videoInitialized = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('[FeedCreatePage] Video preview error: $e');
    }
  }

  bool _isVideoXFile(XFile file) {
    final mime = file.mimeType?.toLowerCase().trim() ?? '';
    if (mime.startsWith('video/')) return true;
    if (mime.startsWith('image/')) return false;
    final name = (file.name.isNotEmpty ? file.name : file.path).toLowerCase().split('?').first;
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.webm') ||
        name.endsWith('.mkv') ||
        name.endsWith('.avi') ||
        name.endsWith('.m4v') ||
        name.endsWith('.3gp');
  }

  Future<void> _pickMixedMedia({bool append = false}) async {
    if (_isSubmittingLock || _saving) return;
    if (append && _mediaItems.length >= _maxCarouselItems) {
      showGlassToast(context, 'Maksimum $_maxCarouselItems media bagi setiap siaran.', isError: true);
      return;
    }

    try {
      final pickedList = await _picker.pickMultipleMedia(
        imageQuality: 88,
        maxWidth: 1440,
        limit: _maxCarouselItems,
      );
      if (pickedList.isEmpty) return;

      final int remainingSlots = append ? (_maxCarouselItems - _mediaItems.length) : _maxCarouselItems;
      final toAdd = pickedList.take(remainingSlots).toList();
      if (pickedList.length > remainingSlots && mounted) {
        showGlassToast(context, 'Hanya $_maxCarouselItems media pertama dipilih.');
      }

      final newDrafts = <_DraftMediaItem>[];
      for (final f in toAdd) {
        final isVideo = _isVideoXFile(f);
        final bytes = await f.readAsBytes();
        final sizeMb = bytes.length / (1024 * 1024);
        final maxMb = isVideo ? 120 : 25;
        if (sizeMb > maxMb) {
          if (mounted) {
            showGlassToast(
              context,
              'Fail ${f.name} (${sizeMb.toStringAsFixed(1)} MB) melebihi had $maxMb MB.',
              isError: true,
            );
          }
          continue;
        }
        newDrafts.add(_DraftMediaItem(
          uid: 'm_${_mediaUidCounter++}',
          file: f,
          bytes: bytes,
          fileName: f.name,
          type: isVideo ? 'video' : 'image',
        ));
      }
      if (newDrafts.isEmpty) return;

      setState(() {
        if (!append) {
          for (final old in _mediaItems) {
            old.videoController?.dispose();
          }
          _mediaItems.clear();
        }
        _mediaItems.addAll(newDrafts);
        _activeMediaIndex = append ? (_mediaItems.length - newDrafts.length) : 0;
        _urlController.clear();
      });

      _jumpPreviewTo(_activeMediaIndex);
      for (final d in newDrafts) {
        if (d.type == 'video' && d.file != null) {
          await _initItemVideoPreview(d, localFile: d.file);
        }
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memilih media: $e', isError: true);
      }
    }
  }

  Future<void> _pickCameraCapture({required bool isVideo, bool append = false}) async {
    if (_isSubmittingLock || _saving) return;
    if (append && _mediaItems.length >= _maxCarouselItems) {
      showGlassToast(context, 'Maksimum $_maxCarouselItems media bagi setiap siaran.', isError: true);
      return;
    }

    try {
      final XFile? picked = isVideo
          ? await _picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(minutes: 3),
            )
          : await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 88,
              maxWidth: 1440,
            );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final sizeMb = bytes.length / (1024 * 1024);
      final maxMb = isVideo ? 120 : 25;
      if (sizeMb > maxMb) {
        if (mounted) {
          showGlassToast(
            context,
            'Saiz fail (${sizeMb.toStringAsFixed(1)} MB) melebihi had $maxMb MB.',
            isError: true,
          );
        }
        return;
      }

      final draft = _DraftMediaItem(
        uid: 'm_${_mediaUidCounter++}',
        file: picked,
        bytes: bytes,
        fileName: picked.name,
        type: isVideo ? 'video' : 'image',
      );

      setState(() {
        if (!append) {
          for (final old in _mediaItems) {
            old.videoController?.dispose();
          }
          _mediaItems.clear();
        }
        _mediaItems.add(draft);
        _activeMediaIndex = _mediaItems.length - 1;
        _urlController.clear();
      });

      _jumpPreviewTo(_activeMediaIndex);
      if (isVideo) {
        await _initItemVideoPreview(draft, localFile: picked);
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal memilih media: $e', isError: true);
      }
    }
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final activeUid = (_activeMediaIndex >= 0 && _activeMediaIndex < _mediaItems.length)
          ? _mediaItems[_activeMediaIndex].uid
          : null;
      final moved = _mediaItems.removeAt(oldIndex);
      _mediaItems.insert(newIndex, moved);
      if (activeUid != null) {
        final newActive = _mediaItems.indexWhere((m) => m.uid == activeUid);
        if (newActive != -1) {
          _activeMediaIndex = newActive;
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_previewPageController.hasClients &&
          _activeMediaIndex >= 0 &&
          _activeMediaIndex < _mediaItems.length) {
        _previewPageController.jumpToPage(_activeMediaIndex);
      }
    });
  }

  void _jumpPreviewTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_previewPageController.hasClients && index >= 0 && index < _mediaItems.length) {
        _previewPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    setState(() {
      final removed = _mediaItems.removeAt(index);
      removed.videoController?.dispose();
      if (_mediaItems.isEmpty) {
        _activeMediaIndex = 0;
      } else if (_activeMediaIndex >= _mediaItems.length) {
        _activeMediaIndex = _mediaItems.length - 1;
      }
    });
    _jumpPreviewTo(_activeMediaIndex);
  }

  void _applyUrlMedia({bool append = false}) {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      showGlassToast(context, 'Sila masukkan URL media yang sah (https://...)', isError: true);
      return;
    }
    if (append && _mediaItems.length >= _maxCarouselItems) {
      showGlassToast(context, 'Maksimum $_maxCarouselItems media bagi setiap siaran.', isError: true);
      return;
    }
    final isVid = FeedMediaItem.isVideoUrl(url);
    final draft = _DraftMediaItem(
      uid: 'm_${_mediaUidCounter++}',
      type: isVid ? 'video' : 'image',
      uploadedUrl: url,
    );
    setState(() {
      if (!append) {
        for (final old in _mediaItems) {
          old.videoController?.dispose();
        }
        _mediaItems.clear();
      }
      _mediaItems.add(draft);
      _activeMediaIndex = _mediaItems.length - 1;
      _showUrlInput = false;
      _urlController.clear();
    });
    _jumpPreviewTo(_activeMediaIndex);
    if (isVid) {
      _initItemVideoPreview(draft, networkUrl: url);
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

  bool get _hasMedia => _mediaItems.isNotEmpty;

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

      // 2. Muat naik setiap item media ke R2 jika belum ada URL
      final List<FeedMediaItem> uploadedItems = [];
      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        if (item.uploadedUrl != null && item.uploadedUrl!.isNotEmpty) {
          uploadedItems.add(FeedMediaItem(url: item.uploadedUrl!, type: item.type));
          continue;
        }
        if (item.bytes != null && item.fileName != null) {
          Uint8List bytesToUpload = item.bytes!;
          final String fileNameToUpload = item.fileName!;

          if (item.type == 'video' && item.file != null) {
            if (mounted) {
              setState(() {
                _isCompressing = true;
                _compressProgress = 0.1;
              });
            }

            final compressResult = await _compressor.compressVideo(
              filePath: item.file!.path,
              originalBytes: item.bytes!,
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
              _uploadProgress = (i / _mediaItems.length).clamp(0.05, 0.95);
            });
          }

          final mimeType = item.type == 'video' ? 'video/mp4' : 'image/jpeg';
          final url = await _r2Storage.uploadMedia(
            bytes: bytesToUpload,
            fileName: fileNameToUpload,
            folder: item.type == 'video' ? 'feed_videos' : 'feed_images',
            mimeType: mimeType,
            onProgress: (p) {
              if (mounted) {
                setState(() {
                  _uploadProgress = (i + p) / _mediaItems.length;
                });
              }
            },
          );

          item.uploadedUrl = url;
          await _compressor.disposeCache();
          uploadedItems.add(FeedMediaItem(url: url, type: item.type));
        }
      }

      if (mounted) {
        setState(() => _isUploadingToR2 = false);
      }

      if (uploadedItems.isEmpty) {
        throw Exception('Tiada media berjaya dimuat naik.');
      }

      final String finalMediaUrl = FeedPostModel.encodeMediaItems(uploadedItems);
      final String primaryMediaType = uploadedItems.first.type;

      final selectedCtas = _selectedCtaItems;
      final effectiveCtaType = FeedPostModel.primaryDbCtaType(selectedCtas);
      final effectiveCtaText = FeedPostModel.encodeCtaText(selectedCtas);

      if (widget.existing != null) {
        await _feedService.updatePost(
          postId: widget.existing!.id,
          title: effectiveTitle,
          caption: captionText.isEmpty ? null : captionText,
          mediaUrl: finalMediaUrl,
          mediaType: primaryMediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim().isEmpty ? null : _serviceTagController.text.trim(),
          ctaType: effectiveCtaType,
          ctaText: effectiveCtaText,
          status: targetStatus,
          isPinned: _isPinned,
        );
      } else {
        await _feedService.createPost(
          title: effectiveTitle,
          caption: captionText.isEmpty ? null : captionText,
          mediaUrl: finalMediaUrl,
          mediaType: primaryMediaType,
          category: widget.businessCategory,
          serviceTag: _serviceTagController.text.trim().isEmpty ? null : _serviceTagController.text.trim(),
          ctaType: effectiveCtaType,
          ctaText: effectiveCtaText,
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
        // Kanvas Pratonton (Sokong Campuran Video + Foto, Portrait & Landscape tanpa potong)
        Flexible(
          child: AspectRatio(
            aspectRatio: 9 / 15,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
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

        // Jalur Thumbnail Carousel Boleh Seret (Drag & Drop Reorder)
        if (_mediaItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (_mediaItems.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.drag_indicator_rounded, color: Color(0xFF00E5FF), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'feed_create.drag_reorder_hint'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 6,
                          shadowColor: const Color(0xFFEC4899).withValues(alpha: 0.4),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 1.0, end: 1.08).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      itemCount: _mediaItems.length,
                      onReorder: _reorderMedia,
                      itemBuilder: (ctx, i) {
                        final item = _mediaItems[i];
                        final isSel = i == _activeMediaIndex;
                        final isVid = item.type == 'video';
                        return ReorderableDragStartListener(
                          key: ValueKey(item.uid),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, top: 4, bottom: 2),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _activeMediaIndex = i);
                                _jumpPreviewTo(i);
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A2E),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFFEC4899) : Colors.white24,
                                        width: isSel ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (isVid)
                                          (item.videoInitialized && item.videoController != null
                                              ? FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: SizedBox(
                                                    width: item.videoController!.value.size.width > 0
                                                        ? item.videoController!.value.size.width
                                                        : 50,
                                                    height: item.videoController!.value.size.height > 0
                                                        ? item.videoController!.value.size.height
                                                        : 54,
                                                    child: VideoPlayer(item.videoController!),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 22),
                                                ))
                                        else if (item.bytes != null)
                                          Image.memory(item.bytes!, fit: BoxFit.cover)
                                        else if (item.uploadedUrl != null)
                                          Image.network(item.uploadedUrl!, fit: BoxFit.cover)
                                        else
                                          const SizedBox.shrink(),

                                        // Lencana Jenis Media (Auto-kesan Video/Foto) + Nombor Urutan
                                        Positioned(
                                          left: 2,
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isVid)
                                                  const Icon(Icons.videocam_rounded, color: Color(0xFF00E5FF), size: 9),
                                                if (isVid) const SizedBox(width: 2),
                                                Text(
                                                  '${i + 1}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () => _removeMediaAt(i),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_mediaItems.length < _maxCarouselItems) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: GestureDetector(
                      onTap: () => _pickMixedMedia(append: true),
                      child: Container(
                        width: 48,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, color: Color(0xFFEC4899), size: 18),
                            Text(
                              'feed_create.add_short'.tr(),
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        // Pilihan Pantas: Galeri Campuran (Auto-Kesan) / Kamera / Rakam / URL
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildMiniActionChip(
              icon: Icons.perm_media_rounded,
              label: _mediaItems.isEmpty
                  ? 'feed_create.btn_pick_media'.tr()
                  : 'feed_create.btn_add_media'.tr(),
              onTap: () => _pickMixedMedia(append: _mediaItems.isNotEmpty),
            ),
            if (!kIsWeb) ...[
              _buildMiniActionChip(
                icon: Icons.camera_alt_rounded,
                label: 'feed_create.btn_camera_photo'.tr(),
                onTap: () => _pickCameraCapture(isVideo: false, append: _mediaItems.isNotEmpty),
              ),
              _buildMiniActionChip(
                icon: Icons.videocam_rounded,
                label: 'feed_create.btn_record_video'.tr(),
                onTap: () => _pickCameraCapture(isVideo: true, append: _mediaItems.isNotEmpty),
              ),
            ],
            _buildMiniActionChip(
              icon: Icons.link_rounded,
              label: 'feed_create.btn_url'.tr(),
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
                    hintText: 'https://.../media.mp4',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _applyUrlMedia(append: _mediaItems.isNotEmpty),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC4899),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Text(_mediaItems.isEmpty ? 'Guna' : 'feed_create.add_short'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyMediaPicker() {
    return InkWell(
      onTap: () => _pickMixedMedia(),
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
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'feed_create.pick_media_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'feed_create.pick_media_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.4),
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
        PageView.builder(
          controller: _previewPageController,
          itemCount: _mediaItems.length,
          onPageChanged: (idx) {
            setState(() => _activeMediaIndex = idx);
            for (int i = 0; i < _mediaItems.length; i++) {
              final vc = _mediaItems[i].videoController;
              if (vc != null && _mediaItems[i].videoInitialized) {
                if (i == idx) {
                  vc.play();
                  _mediaItems[i].isPlaying = true;
                } else {
                  vc.pause();
                  _mediaItems[i].isPlaying = false;
                }
              }
            }
          },
          itemBuilder: (ctx, i) {
            final item = _mediaItems[i];
            if (item.type == 'video') {
              final vc = item.videoController;
              if (item.videoInitialized && vc != null) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (vc.value.isPlaying) {
                        vc.pause();
                        item.isPlaying = false;
                      } else {
                        vc.play();
                        item.isPlaying = true;
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: vc.value.size.width > 0 ? vc.value.size.width : 720,
                            height: vc.value.size.height > 0 ? vc.value.size.height : 1280,
                            child: VideoPlayer(vc),
                          ),
                        ),
                      ),
                      if (!item.isPlaying)
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
                    ],
                  ),
                );
              }
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFEC4899), strokeWidth: 2.5),
                    SizedBox(height: 10),
                    Text('Menyediakan pratonton video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              );
            }

            if (item.bytes != null) {
              return Image.memory(item.bytes!, fit: BoxFit.contain);
            }
            if (item.uploadedUrl != null) {
              return Image.network(item.uploadedUrl!, fit: BoxFit.contain);
            }
            return const SizedBox.shrink();
          },
        ),

        // Badge Carousel Counter (1 / N)
        if (_mediaItems.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                '${_activeMediaIndex + 1} / ${_mediaItems.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
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
                if (_selectedCtaItems.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedCtaItems.asMap().entries.map((entry) {
                      final isPrimary = entry.key == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          gradient: isPrimary
                              ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
                              : null,
                          color: isPrimary ? null : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: isPrimary
                              ? null
                              : Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          entry.value.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),

        // Top controls (Mute & Remove)
        // Butang kecil di penjuru atas (Mute / Padam slide aktif)
        Positioned(
          top: 10,
          left: 10,
          child: Row(
            children: [
              if (_activeMediaIndex < _mediaItems.length &&
                  _mediaItems[_activeMediaIndex].type == 'video' &&
                  _mediaItems[_activeMediaIndex].videoInitialized)
                _buildCircleIconBtn(
                  icon: _isPreviewMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  onTap: () {
                    final next = !_isPreviewMuted;
                    for (final item in _mediaItems) {
                      item.videoController?.setVolume(next ? 0.0 : 1.0);
                    }
                    setState(() => _isPreviewMuted = next);
                  },
                ),
              const SizedBox(width: 6),
              _buildCircleIconBtn(
                icon: Icons.close_rounded,
                onTap: () => _removeMediaAt(_activeMediaIndex),
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
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
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
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
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
                      if (_mediaItems.isNotEmpty && _mediaItems.first.type == 'image' && _mediaItems.first.bytes != null)
                        Image.memory(_mediaItems.first.bytes!, fit: BoxFit.cover)
                      else if (_mediaItems.isNotEmpty && _mediaItems.first.type == 'image' && _mediaItems.first.uploadedUrl != null)
                        Image.network(_mediaItems.first.uploadedUrl!, fit: BoxFit.cover)
                      else if (_mediaItems.isNotEmpty && _mediaItems.first.videoInitialized && _mediaItems.first.videoController != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _mediaItems.first.videoController!.value.size.width,
                            height: _mediaItems.first.videoController!.value.size.height,
                            child: VideoPlayer(_mediaItems.first.videoController!),
                          ),
                        )
                      else
                        const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 28)),
                      if (_mediaItems.length > 1)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_mediaItems.length}x',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
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

        // Seksyen 2: Butang Tindakan Ngam (0 hingga 3 pilihan)
        Row(
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedFlash, color: Color(0xFFEC4899), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Butang Tindakan Pelanggan (CTA Ngam)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _selectedCtaKeys.isEmpty
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFEC4899).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _selectedCtaKeys.isEmpty
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFEC4899).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _selectedCtaKeys.isEmpty
                    ? 'feed_create.cta_none_chip'.tr()
                    : 'feed_create.cta_selected_count'.tr(args: [_selectedCtaKeys.length.toString()]),
                style: TextStyle(
                  color: _selectedCtaKeys.isEmpty ? Colors.white60 : const Color(0xFFF9A8D4),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedCtaKeys.isNotEmpty) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => setState(() => _selectedCtaKeys.clear()),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: Text(
                    'feed_create.cta_clear_all'.tr(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'feed_create.cta_multi_hint'.tr(),
          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
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
            final selectedIndex = _selectedCtaKeys.indexOf(key);
            final isSelected = selectedIndex != -1;

            return InkWell(
              onTap: () {
                if (isSelected) {
                  setState(() => _selectedCtaKeys.remove(key));
                } else if (_selectedCtaKeys.length >= _maxCtaCount) {
                  showGlassToast(context, 'feed_create.cta_max_toast'.tr(), isError: true);
                } else {
                  setState(() => _selectedCtaKeys.add(key));
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  AnimatedContainer(
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
                  if (isSelected)
                    Positioned(
                      top: 5,
                      right: 6,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${selectedIndex + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
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
            filled: false,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEC4899)),
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

class _DraftMediaItem {
  final String uid;
  final XFile? file;
  final Uint8List? bytes;
  final String? fileName;
  final String type; // 'image' or 'video'
  String? uploadedUrl;
  VideoPlayerController? videoController;
  bool videoInitialized = false;
  bool isPlaying = true;

  _DraftMediaItem({
    required this.uid,
    this.file,
    this.bytes,
    this.fileName,
    required this.type,
    this.uploadedUrl,
  });
}
