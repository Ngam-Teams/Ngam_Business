import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/sound_service.dart';
import '../../settings/data/business_service.dart';
import '../data/queue_service.dart';
import '../models/queue_ticket_model.dart';

// =============================================================================
// TvQueueLayoutMode — 4 Pilihan Susun Atur Paparan TV Papan Giliran
// =============================================================================
enum TvQueueLayoutMode {
  /// 🌟 Mod Lengkap: Kiri QR (1/5) • Tengah Iklan/Promosi • Kanan Giliran (Up Next & Now Serving)
  threeColumn,

  /// ⚡ Mod Giliran + QR (Cadangan): Kiri QR (1/5) • Kanan Giliran Luas Atas & Bawah (4/5)
  queueAndQr,

  /// 📢 Mod Iklan + Giliran: Kiri Iklan Luas • Kanan Status Giliran (Tanpa Kod QR di skrin)
  adsAndQueue,

  /// 🎯 Mod Giliran Sahaja: 100% Papan Giliran Penuh (Fokus Nombor & Panggilan Sahaja)
  queueOnly,
}

// =============================================================================
// QueueTvDisplayPage — Papan Giliran Kedai Pintar & Fleksibel (Smart TV Board)
// =============================================================================

class QueueTvDisplayPage extends StatefulWidget {
  const QueueTvDisplayPage({super.key});

  @override
  State<QueueTvDisplayPage> createState() => _QueueTvDisplayPageState();
}

class _QueueTvDisplayPageState extends State<QueueTvDisplayPage> {
  final QueueService _queueService = QueueService();
  List<QueueTicketModel> _tickets = [];
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  StreamSubscription<List<QueueTicketModel>>? _subscription;

  String _businessName = 'KEDAI ANDA';
  String _businessId = '';
  String _businessSlug = 'kedai';

  // Susun atur & Tetapan TV
  TvQueueLayoutMode _layoutMode = TvQueueLayoutMode.threeColumn;
  bool _soundEnabled = true;
  String? _lastCalledTicketId;

  // Iklan & Promosi Digital Signage (Boleh diubah oleh kedai)
  String _promoTitle = 'TAWARAN & GANJARAN EKSKLUSIF';
  String _promoDesc = 'Imbas kod QR di kaunter untuk sertai program ganjaran & nikmati diskaun istimewa!';
  String _wifiInfo = 'WiFi Kedai Tersedia';

  // Carousel Iklan
  final PageController _promoPageController = PageController();
  int _currentPromoPage = 0;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadBusinessInfo();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _subscription = _queueService.streamQueueTickets().listen((tickets) {
      if (!mounted) return;

      // Pantau jika ada nombor giliran baru dipanggil (calling)
      final callingTickets = tickets.where((t) => t.status == 'calling').toList();
      if (callingTickets.isNotEmpty) {
        callingTickets.sort((a, b) => (b.calledAt ?? b.createdAt).compareTo(a.calledAt ?? a.createdAt));
        final newestId = callingTickets.first.id;
        if (newestId != _lastCalledTicketId) {
          _lastCalledTicketId = newestId;
          if (_soundEnabled) {
            SoundService.instance.playOrderChime();
          }
        }
      }

      setState(() => _tickets = tickets);
    });

    _startPromoTimer();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('tv_queue_layout_mode');
      if (modeStr != null && mounted) {
        setState(() {
          _layoutMode = TvQueueLayoutMode.values.firstWhere(
            (e) => e.name == modeStr,
            orElse: () => TvQueueLayoutMode.threeColumn,
          );
        });
      }
      if (mounted) {
        setState(() {
          _soundEnabled = prefs.getBool('tv_queue_sound_enabled') ?? true;
          _promoTitle = prefs.getString('tv_custom_promo_title') ?? _promoTitle;
          _promoDesc = prefs.getString('tv_custom_promo_desc') ?? _promoDesc;
          _wifiInfo = prefs.getString('tv_custom_wifi_info') ?? _wifiInfo;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLayoutMode(TvQueueLayoutMode mode) async {
    setState(() => _layoutMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tv_queue_layout_mode', mode.name);
    } catch (_) {}
  }

  Future<void> _toggleSound() async {
    setState(() => _soundEnabled = !_soundEnabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tv_queue_sound_enabled', _soundEnabled);
    } catch (_) {}
  }

  void _startPromoTimer() {
    _promoTimer?.cancel();
    _promoTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_promoPageController.hasClients) return;
      final nextPage = (_currentPromoPage + 1) % 3;
      _promoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadBusinessInfo() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      if (profile != null && mounted) {
        setState(() {
          _businessName = profile['name']?.toString() ?? 'KEDAI ANDA';
          _businessId = profile['id']?.toString() ?? '';
          final rawSlug = _businessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
          _businessSlug = profile['slug']?.toString() ?? rawSlug;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _promoTimer?.cancel();
    _promoPageController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  String get _qrUrl => _businessId.isNotEmpty
      ? 'https://ngam.my/q/$_businessId'
      : 'https://ngam.my/q';

  String get _shortUrlDisplay => 'ngam.my/q/$_businessSlug';

  QueueTicketModel? get _currentCallingTicket {
    final calling = _tickets.where((t) => t.status == 'calling').toList();
    if (calling.isNotEmpty) {
      calling.sort((a, b) => (b.calledAt ?? b.createdAt).compareTo(a.calledAt ?? a.createdAt));
      return calling.first;
    }
    final serving = _tickets.where((t) => t.status == 'serving').toList();
    if (serving.isNotEmpty) return serving.last;
    return null;
  }

  List<QueueTicketModel> get _upNextTickets =>
      _tickets.where((t) => t.status == 'waiting').take(6).toList();

  List<QueueTicketModel> get _nowServingTickets =>
      _tickets.where((t) => t.status == 'serving').take(6).toList();

  String _getLayoutModeShortLabel() {
    switch (_layoutMode) {
      case TvQueueLayoutMode.threeColumn:
        return 'Lengkap (3-Kolum)';
      case TvQueueLayoutMode.queueAndQr:
        return 'Giliran + QR';
      case TvQueueLayoutMode.adsAndQueue:
        return 'Iklan + Giliran';
      case TvQueueLayoutMode.queueOnly:
        return 'Giliran Sahaja';
    }
  }

  // ===========================================================================
  // Dialog: Pilih Susun Atur Paparan TV (Customizable Layouts)
  // ===========================================================================

  void _showLayoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF101322),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF42A5F5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PILIH SUSUN ATUR PAPAN TV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Sesuaikan paparan mengikut kesesuaian operasi kedai anda',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pilihan 1: Lengkap (3-Kolum)
              _buildLayoutOptionCard(
                ctx,
                mode: TvQueueLayoutMode.threeColumn,
                icon: Icons.view_column_rounded,
                badge: 'TERLARIS',
                title: '🌟 Lengkap (3-Kolum: QR + Iklan + Giliran)',
                subtitle: 'Kiri: QR Padat (1/5)  •  Tengah: Iklan & Promosi  •  Kanan: Status Giliran',
                desc: 'Paling popular: Pelanggan boleh imbas QR, lihat promosi semasa, dan pantau senarai giliran serentak.',
              ),
              const SizedBox(height: 10),

              // Pilihan 2: Giliran + QR (Cadangan Pengguna)
              _buildLayoutOptionCard(
                ctx,
                mode: TvQueueLayoutMode.queueAndQr,
                icon: Icons.splitscreen_rounded,
                badge: 'LEGA & BESAR',
                title: '⚡ Giliran + QR (QR 1/5 & Giliran Expand)',
                subtitle: 'Kiri: QR Padat (1/5)  •  Kanan: Kad Giliran Atas & Bawah Diperluas (4/5)',
                desc: 'QR di tepi padat 1/5 skrin, baki 80% skrin membesarkan kad giliran Menunggu & Sedang Dilayan agar nombor mudah dilihat dari jauh.',
              ),
              const SizedBox(height: 10),

              // Pilihan 3: Iklan + Giliran
              _buildLayoutOptionCard(
                ctx,
                mode: TvQueueLayoutMode.adsAndQueue,
                icon: Icons.campaign_rounded,
                badge: 'PROMOSI KEDAI',
                title: '📢 Iklan + Giliran (Digital Signage)',
                subtitle: 'Kiri: Poster & Promosi Luas  •  Kanan: Senarai Giliran',
                desc: 'Sesuai untuk kedai yang sudah meletakkan standee kod QR fizikal di meja/kaunter.',
              ),
              const SizedBox(height: 10),

              // Pilihan 4: Giliran Sahaja
              _buildLayoutOptionCard(
                ctx,
                mode: TvQueueLayoutMode.queueOnly,
                icon: Icons.fullscreen_rounded,
                badge: 'FOKUS PENUH',
                title: '🎯 Giliran Sahaja (Papan Penuh)',
                subtitle: '100% Skrin Penuh Untuk Panggilan & Senarai Nombor',
                desc: 'Format bank / klinik: tiada gangguan iklan atau kod QR di skrin, fokus maksimum kepada nombor giliran.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutOptionCard(
    BuildContext ctx, {
    required TvQueueLayoutMode mode,
    required IconData icon,
    required String badge,
    required String title,
    required String subtitle,
    required String desc,
  }) {
    final isSelected = _layoutMode == mode;

    return InkWell(
      onTap: () {
        _saveLayoutMode(mode);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Susun atur ditukar ke: ${_getLayoutModeShortLabel()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E3A8A),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF60A5FA) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF93C5FD) : Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Dialog: Ubah Teks Iklan & Promosi Kedai
  // ===========================================================================

  void _showEditPromoDialog() {
    final titleController = TextEditingController(text: _promoTitle);
    final descController = TextEditingController(text: _promoDesc);
    final wifiController = TextEditingController(text: _wifiInfo);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF101322),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'UBAH TEKS IKLAN & PROMOSI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tajuk Promosi / Tawaran',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintText: 'cth: DISKAUN 15% HARI INI',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Penerangan / Maklumat Tawaran',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintText: 'cth: Dapatkan potongan harga untuk setiap pesanan...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Info WiFi / Makluman Kedai',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: wifiController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintText: 'cth: WiFi: Kedai Tetamu / Pass: 12345678',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final newTitle = titleController.text.trim();
                    final newDesc = descController.text.trim();
                    final newWifi = wifiController.text.trim();
                    setState(() {
                      if (newTitle.isNotEmpty) _promoTitle = newTitle;
                      if (newDesc.isNotEmpty) _promoDesc = newDesc;
                      if (newWifi.isNotEmpty) _wifiInfo = newWifi;
                    });
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('tv_custom_promo_title', _promoTitle);
                      await prefs.setString('tv_custom_promo_desc', _promoDesc);
                      await prefs.setString('tv_custom_wifi_info', _wifiInfo);
                    } catch (_) {}
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Simpan & Paparkan di TV', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Modal: Fullscreen Kiosk QR Code
  // ===========================================================================

  void _openFullscreenQrModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF10131E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF42A5F5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KIOSK AMBIL NOMBOR GILIRAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            _businessName,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrUrl,
                  size: 270,
                  version: QrVersions.auto,
                  gapless: true,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFF34D399), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _shortUrlDisplay,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Buka kamera telefon pintar anda dan halakan ke kod QR di atas untuk menyertai giliran kedai secara langsung.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Tutup Kiosk', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD METHOD UTAMA
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final current = _currentCallingTicket;

    return Scaffold(
      backgroundColor: const Color(0xFF080811),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. Bar Tajuk Header TV
              _buildTvHeader(),
              const SizedBox(height: 12),

              // 2. Bahagian Paparan Utama (Dinamik mengikut Susun Atur Pilihan)
              Expanded(
                child: _buildLayoutBody(current),
              ),

              const SizedBox(height: 12),
              // 3. Bar Ticker Footer TV
              _buildTvFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ROUTING SUSUN ATUR UTAMA
  // ===========================================================================

  Widget _buildLayoutBody(QueueTicketModel? current) {
    switch (_layoutMode) {
      case TvQueueLayoutMode.threeColumn:
        return _buildThreeColumnLayout(current);
      case TvQueueLayoutMode.queueAndQr:
        return _buildQueueAndQrLayout(current);
      case TvQueueLayoutMode.adsAndQueue:
        return _buildAdsAndQueueLayout(current);
      case TvQueueLayoutMode.queueOnly:
        return _buildQueueOnlyLayout(current);
    }
  }

  // ---------------------------------------------------------------------------
  // SUSUN ATUR 1: LENGKAP (3-Kolum: Kiri QR 1/5 • Tengah Iklan • Kanan Giliran)
  // ---------------------------------------------------------------------------

  Widget _buildThreeColumnLayout(QueueTicketModel? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kolum 1 (Kiri): Kod QR Padat 1/5 (~20% skrin)
        Expanded(
          flex: 2,
          child: _buildCompactQrPanel(),
        ),
        const SizedBox(width: 14),

        // Kolum 2 (Tengah): Iklan & Promosi / Panggilan Aktif Hero (~42% skrin)
        Expanded(
          flex: 4,
          child: current != null
              ? _buildActiveCallHero(current)
              : _buildPromoCarouselPanel(),
        ),
        const SizedBox(width: 14),

        // Kolum 3 (Kanan): Giliran Menunggu & Sedang Dilayan (~38% skrin)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: _buildUpNextPanel(),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 1,
                child: _buildNowServingPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUSUN ATUR 2: GILIRAN + QR (Kiri QR 1/5 • Kanan Expand Giliran Atas Bawah 4/5)
  // Cadangan Utama Pengguna: "qr tu 1/5 balance tu expand card atas bawah queue tu"
  // ---------------------------------------------------------------------------

  Widget _buildQueueAndQrLayout(QueueTicketModel? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kolum 1 (Kiri): Kod QR Padat 1/5 (~20% skrin)
        Expanded(
          flex: 2,
          child: _buildCompactQrPanel(),
        ),
        const SizedBox(width: 16),

        // Kolum 2 (Kanan): Kad Giliran Atas & Bawah Diperluas Luas (~80% skrin)
        Expanded(
          flex: 8,
          child: Column(
            children: [
              // Jika ada panggilan aktif, paparkan banner panggilan di atas
              if (current != null) ...[
                _buildActiveCallBanner(current),
                const SizedBox(height: 12),
              ],

              // Kad Atas: Giliran Seterusnya (Diperluas)
              Expanded(
                flex: 1,
                child: _buildUpNextPanel(isExpanded: true),
              ),
              const SizedBox(height: 12),

              // Kad Bawah: Sedang Dilayan (Diperluas)
              Expanded(
                flex: 1,
                child: _buildNowServingPanel(isExpanded: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUSUN ATUR 3: IKLAN + GILIRAN (Kiri Iklan Luas • Kanan Status Giliran)
  // ---------------------------------------------------------------------------

  Widget _buildAdsAndQueueLayout(QueueTicketModel? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kolum 1 (Kiri): Iklan & Promosi Digital Signage Luas (flex: 6)
        Expanded(
          flex: 6,
          child: current != null
              ? _buildActiveCallHero(current)
              : _buildPromoCarouselPanel(isWide: true),
        ),
        const SizedBox(width: 16),

        // Kolum 2 (Kanan): Status Giliran (flex: 4)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                flex: 1,
                child: _buildUpNextPanel(),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 1,
                child: _buildNowServingPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUSUN ATUR 4: GILIRAN SAHAJA (100% Papan Giliran Penuh Skrin)
  // ---------------------------------------------------------------------------

  Widget _buildQueueOnlyLayout(QueueTicketModel? current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kiri: Panggilan Aktif atau Sedang Dilayan Utama (flex: 5)
        Expanded(
          flex: 5,
          child: current != null
              ? _buildActiveCallHero(current)
              : _buildNowServingPanel(isExpanded: true),
        ),
        const SizedBox(width: 16),

        // Kanan: Giliran Seterusnya Penuh (flex: 5)
        Expanded(
          flex: 5,
          child: _buildUpNextPanel(isExpanded: true),
        ),
      ],
    );
  }

  // ===========================================================================
  // KOMPONEN: BAR HEADER TV
  // ===========================================================================

  Widget _buildTvHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tv_rounded, color: Color(0xFF42A5F5), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAPAN GILIRAN KEDAI (LIVE QUEUE)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '$_businessName · Sistem Panggilan Pintar Ngam OS',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          // Pilihan Susun Atur, Kawalan Bunyi, Kiosk QR, & Jam
          Row(
            children: [
              // Butang Tukar Susun Atur
              InkWell(
                onTap: _showLayoutDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF42A5F5), size: 15),
                      const SizedBox(width: 7),
                      Text(
                        _getLayoutModeShortLabel(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Butang On/Off Audio Chime
              IconButton(
                icon: Icon(
                  _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _soundEnabled ? const Color(0xFF34D399) : Colors.white38,
                  size: 20,
                ),
                tooltip: _soundEnabled ? 'Bunyi Loceng Aktif (Ketik untuk senyap)' : 'Bunyi Senyap (Ketik untuk aktif)',
                onPressed: _toggleSound,
              ),

              // Butang Kiosk QR Penuh
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF42A5F5), size: 22),
                tooltip: 'Buka Mod Kiosk QR Penuh',
                onPressed: _openFullscreenQrModal,
              ),
              const SizedBox(width: 8),

              Container(
                height: 22,
                width: 1,
                color: Colors.white12,
              ),
              const SizedBox(width: 14),

              // Jam & Tarikh
              const Icon(Icons.access_time_rounded, color: Color(0xFF34D399), size: 16),
              const SizedBox(width: 6),
              Text(
                DateFormat('hh:mm:ss a').format(_now),
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('d MMM yyyy').format(_now),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KOMPONEN: KOD QR PADAT 1/5 (Compact QR Panel)
  // ===========================================================================

  Widget _buildCompactQrPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5), size: 13),
                SizedBox(width: 6),
                Text(
                  'IMBAS AMBIL NOMBOR',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Business Name & Tagline
          Column(
            children: [
              Text(
                _businessName.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Sertai giliran dari telefon pintar anda',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 10.5),
              ),
            ],
          ),

          // Compact QR Box (150px)
          GestureDetector(
            onTap: _openFullscreenQrModal,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF3B82F6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrUrl,
                size: 150,
                version: QrVersions.auto,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),

          // Short URL Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, color: Color(0xFF34D399), size: 12),
                const SizedBox(width: 5),
                Text(
                  _shortUrlDisplay,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // 3 Step Guide (Vertikal / Ringkas)
          Column(
            children: [
              _buildStepMiniRow('1', 'Buka Kamera'),
              const SizedBox(height: 4),
              _buildStepMiniRow('2', 'Imbas Kod QR'),
              const SizedBox(height: 4),
              _buildStepMiniRow('3', 'Pantau di Telefon'),
            ],
          ),

          // Tap to Enlarge Hint
          InkWell(
            onTap: _openFullscreenQrModal,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, color: Colors.white.withValues(alpha: 0.4), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Ketik untuk besarkan QR',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepMiniRow(String step, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: const BoxDecoration(
            color: Color(0xFF42A5F5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ===========================================================================
  // KOMPONEN: IKLAN & PROMOSI DIGITAL SIGNAGE (Promo Carousel Panel)
  // ===========================================================================

  Widget _buildPromoCarouselPanel({bool isWide = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          PageView(
            controller: _promoPageController,
            onPageChanged: (idx) => setState(() => _currentPromoPage = idx),
            children: [
              // Slide 1: Sambutan & Info Kedai
              _buildPromoSlide1(),
              // Slide 2: Promosi & Ganjaran Eksklusif (Customizable)
              _buildPromoSlide2(),
              // Slide 3: Pembayaran & Servis Pintar
              _buildPromoSlide3(),
            ],
          ),

          // Butang Ubah Iklan (Top Right)
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: _showEditPromoDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ubah Iklan',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dots Indicator (Bottom Center)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (idx) {
                final isCurrent = _currentPromoPage == idx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF42A5F5) : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 1: Selamat Datang & Profil Kedai
  Widget _buildPromoSlide1() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.6),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFF818CF8), size: 15),
                SizedBox(width: 6),
                Text(
                  'SELAMAT DATANG',
                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _businessName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sila perhatikan skrin atau tunggu notifikasi telefon apabila nombor giliran anda dipanggil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_rounded, color: Color(0xFF34D399), size: 16),
                const SizedBox(width: 8),
                Text(
                  _wifiInfo,
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: Promosi & Ganjaran Kedai (Customizable)
  Widget _buildPromoSlide2() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF78350F).withValues(alpha: 0.5),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_rounded, color: Color(0xFFF59E0B), size: 15),
                SizedBox(width: 6),
                Text(
                  'PROMOSI & TAWARAN KHAS',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _promoTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _promoDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Tanya staf kami atau imbas QR untuk maklumat lanjut',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Pembayaran & Servis Pintar Cashless
  Widget _buildPromoSlide3() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF064E3B).withValues(alpha: 0.5),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contactless_rounded, color: Color(0xFF34D399), size: 18),
              SizedBox(width: 8),
              Text(
                'PEMBAYARAN PANTAS TANPA TUNAI',
                style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            'DuitNow QR & Kad Diterima',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nikmati pengalaman pembayaran mudah dan pantas melalui DuitNow National QR, Kad Debit/Kredit, dan e-Dompet utama.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FeatureChip('⚡ DuitNow QR'),
              SizedBox(width: 8),
              _FeatureChip('💳 Kad / PayWave'),
              SizedBox(width: 8),
              _FeatureChip('📱 e-Dompet'),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KOMPONEN: PANGGILAN AKTIF HERO (Giant Call Hero)
  // ===========================================================================

  Widget _buildActiveCallHero(QueueTicketModel current) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.55),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF3B82F6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tag Nombor Dipanggil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'NOMBOR GILIRAN DIPANGGIL SEKARANG',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Giant Ticket Number
          FittedBox(
            child: Text(
              current.ticketNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                shadows: [
                  Shadow(color: Color(0xFF3B82F6), blurRadius: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Destination Station / Kaunter / Kerusi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Text(
              'SILA KE: ${current.stationOrChair ?? "KAUNTER UTAMA"}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Customer Name & Service
          Text(
            current.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Servis: ${current.serviceName ?? "Servis Am"}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // Banner Panggilan Aktif (Untuk mod horizontal atas Giliran Expand)
  Widget _buildActiveCallBanner(QueueTicketModel current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DIPANGGIL',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                current.ticketNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '•  ${current.customerName}',
                style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Text(
              'SILA KE: ${current.stationOrChair ?? "KAUNTER UTAMA"}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KOMPONEN: GILIRAN SETERUSNYA (UP NEXT)
  // ===========================================================================

  Widget _buildUpNextPanel({bool isExpanded = false}) {
    final list = _upNextTickets;
    final totalWaiting = _tickets.where((t) => t.status == 'waiting').length;

    return Container(
      padding: EdgeInsets.all(isExpanded ? 18 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text(
                'GILIRAN SETERUSNYA (UP NEXT)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isExpanded ? 14 : 12.5,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalWaiting menunggu',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: isExpanded ? 12 : 8),

          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Tiada senarai menunggu', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                : isExpanded
                    ? _buildExpandedUpNextGrid(list)
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (ctx, idx) {
                          final t = list[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      t.ticketNumber,
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  t.customerName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Grid Luas untuk Mod Expand (Bila skrin 80% luas)
  Widget _buildExpandedUpNextGrid(List<QueueTicketModel> list) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final t = list[idx];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${idx + 1}',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.ticketNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      t.customerName,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ===========================================================================
  // KOMPONEN: SEDANG DILAYAN (NOW SERVING)
  // ===========================================================================

  Widget _buildNowServingPanel({bool isExpanded = false}) {
    final list = _nowServingTickets;

    return Container(
      padding: EdgeInsets.all(isExpanded ? 18 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'SEDANG DILAYAN (NOW SERVING)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isExpanded ? 14 : 12.5,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${list.length} aktif',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: isExpanded ? 12 : 8),

          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Tiada servis aktif', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                : isExpanded
                    ? _buildExpandedNowServingGrid(list)
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (ctx, idx) {
                          final t = list[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.ticketNumber,
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      t.stationOrChair ?? 'Kaunter Utama',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  t.customerName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Grid Luas untuk Now Serving
  Widget _buildExpandedNowServingGrid(List<QueueTicketModel> list) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final t = list[idx];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Text(
                t.ticketNumber,
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.stationOrChair ?? 'Kaunter Utama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      t.customerName,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // ===========================================================================
  // KOMPONEN: BAR TICKER FOOTER TV
  // ===========================================================================

  Widget _buildTvFooter() {
    final waitingCount = _tickets.where((t) => t.status == 'waiting').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SISTEM GILIRAN PINTAR AKTIF',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(width: 12),
              Container(
                height: 12,
                width: 1,
                color: Colors.white12,
              ),
              const SizedBox(width: 12),
              Text(
                '$waitingCount pelanggan dalam senarai menunggu',
                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 13),
              const SizedBox(width: 6),
              const Text(
                'Sila perhatikan skrin atau notifikasi telefon anda apabila nombor dipanggil',
                style: TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _openFullscreenQrModal,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fullscreen_rounded, color: Color(0xFF42A5F5), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Kiosk QR',
                        style: TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
