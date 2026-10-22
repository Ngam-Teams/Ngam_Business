import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../settings/data/business_service.dart';
import '../data/queue_service.dart';
import '../models/queue_ticket_model.dart';

// =============================================================================
// QueueTvDisplayPage — Papan Giliran Kedai Pintar (Smart Adaptive Mode)
// =============================================================================
// Konsep 2 Pintar:
// 1. Mod Siap Sedia (Idle / Tiada Panggilan): Ruang kiri memaparkan Kiosk QR Gergasi (240px+)
//    untuk memudahkan pelanggan mengimbas dari jarak jauh (pintu masuk / tempat duduk).
// 2. Mod Panggilan (Calling Active): Ruang kiri memaparkan Nombor Giliran Gergasi (A001 -> Kerusi),
//    manakala kad sisi kanan memaparkan QR Kod (130px) untuk pelanggan baru yang tiba.
// 3. Mod Kiosk Skrin Penuh (Tap-To-Enlarge Modal): Ketik QR untuk paparan ultra-besar 280px.
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

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _subscription = _queueService.streamQueueTickets().listen((tickets) {
      if (!mounted) return;
      setState(() => _tickets = tickets);
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
      _tickets.where((t) => t.status == 'waiting').take(5).toList();

  List<QueueTicketModel> get _nowServingTickets =>
      _tickets.where((t) => t.status == 'serving').take(4).toList();

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
              // Ultra-Giant QR Container
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

  @override
  Widget build(BuildContext context) {
    final current = _currentCallingTicket;
    final isIdle = current == null;

    return Scaffold(
      backgroundColor: const Color(0xFF080811),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // TV Header Bar
              _buildTvHeader(),
              const SizedBox(height: 14),

              // Main Display Section
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Hero: ADAPTIVE (Giant QR Kiosk when Idle, OR Giant Call Hero when Calling)
                    Expanded(
                      flex: 6,
                      child: isIdle
                          ? _buildIdleCheckInHero()
                          : _buildActiveCallHero(current),
                    ),
                    const SizedBox(width: 18),

                    // Right Side: UP NEXT, NOW SERVING, & ADAPTIVE QR CARD
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Expanded(
                            flex: isIdle ? 1 : 3,
                            child: _buildUpNextPanel(),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            flex: isIdle ? 1 : 3,
                            child: _buildNowServingPanel(),
                          ),
                          // When actively calling someone, display a dedicated QR card on right side!
                          if (!isIdle) ...[
                            const SizedBox(height: 14),
                            Expanded(
                              flex: 3,
                              child: _buildCallingModeQrCard(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              // TV Footer Info Ticker
              _buildTvFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header Bar
  // ---------------------------------------------------------------------------

  Widget _buildTvHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tv_rounded, color: Color(0xFF42A5F5), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAPAN GILIRAN KEDAI (LIVE QUEUE)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '$_businessName · Sistem Panggilan Pintar Ngam OS',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          // Big Clock & Kiosk Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF42A5F5), size: 24),
                tooltip: 'Buka Mod Kiosk QR',
                onPressed: _openFullscreenQrModal,
              ),
              const SizedBox(width: 12),
              Container(
                height: 24,
                width: 1,
                color: Colors.white12,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time_rounded, color: Color(0xFF34D399), size: 18),
              const SizedBox(width: 8),
              Text(
                DateFormat('hh:mm:ss a').format(_now),
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('d MMM yyyy').format(_now),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Hero A: IDLE CHECK-IN HERO (Giant 240px QR Scan Station)
  // ---------------------------------------------------------------------------

  Widget _buildIdleCheckInHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5), size: 15),
                SizedBox(width: 8),
                Text(
                  'SELAMAT DATANG · IMBAS UNTUK AMBIL NOMBOR',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Business Name
          Text(
            _businessName.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Imbas kod QR di bawah dari telefon anda untuk sertai giliran tanpa perlu beratur di kaunter',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // GIANT QR CODE CONTAINER (230px x 230px)
          GestureDetector(
            onTap: _openFullscreenQrModal,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF3B82F6),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrUrl,
                size: 220,
                version: QrVersions.auto,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Short URL Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, color: Color(0xFF34D399), size: 14),
                const SizedBox(width: 6),
                Text(
                  _shortUrlDisplay,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• Boleh ditaip terus di telefon',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3-Step Guide Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepPill('1', 'Buka Kamera'),
              _buildStepArrow(),
              _buildStepPill('2', 'Imbas Kod QR'),
              _buildStepArrow(),
              _buildStepPill('3', 'Pantau di Telefon'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill(String number, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF42A5F5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStepArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 14),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Hero B: ACTIVE CALL HERO (Giant Number Display)
  // ---------------------------------------------------------------------------

  Widget _buildActiveCallHero(QueueTicketModel current) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.45),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF3B82F6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Flashing Calling Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
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
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Giant Ticket Number
          FittedBox(
            child: Text(
              current.ticketNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 110,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                shadows: [
                  Shadow(color: Color(0xFF3B82F6), blurRadius: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Destination Station / Chair
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Text(
              'SILA KE: ${current.stationOrChair ?? "KAUNTER UTAMA"}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Customer Name & Service
          Text(
            current.customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Servis: ${current.serviceName ?? "Servis Am"}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Panels: UP NEXT & NOW SERVING
  // ---------------------------------------------------------------------------

  Widget _buildUpNextPanel() {
    final list = _upNextTickets;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text(
                'GILIRAN SETERUSNYA (UP NEXT)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_tickets.where((t) => t.status == 'waiting').length} menunggu',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Tiada senarai menunggu', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, idx) {
                      final t = list[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
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

  Widget _buildNowServingPanel() {
    final list = _nowServingTickets;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.content_cut_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              const Text(
                'SEDANG DILAYAN (NOW SERVING)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${list.length} aktif',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Tiada servis aktif', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, idx) {
                      final t = list[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
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
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.stationOrChair ?? 'Kerusi',
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

  // ---------------------------------------------------------------------------
  // Right Panel: CALLING MODE QR CARD (Visible during active calling)
  // ---------------------------------------------------------------------------

  Widget _buildCallingModeQrCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Scannable QR Code (115px)
          GestureDetector(
            onTap: _openFullscreenQrModal,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF42A5F5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrUrl,
                size: 110,
                version: QrVersions.auto,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AMBIL NOMBOR BARU',
                    style: TextStyle(
                      color: Color(0xFF42A5F5),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Imbas Untuk Giliran',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shortUrlDisplay,
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Halakan kamera telefon anda ke QR untuk sertai giliran tanpa berdiri.',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TV Footer Info Ticker
  // ---------------------------------------------------------------------------

  Widget _buildTvFooter() {
    final waitingCount = _tickets.where((t) => t.status == 'waiting').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SISTEM GILIRAN PINTAR AKTIF',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(width: 12),
              Container(
                height: 14,
                width: 1,
                color: Colors.white12,
              ),
              const SizedBox(width: 12),
              Text(
                '$waitingCount pelanggan dalam senarai menunggu',
                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Sila perhatikan skrin atau notifikasi telefon anda apabila giliran dipanggil',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: _openFullscreenQrModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fullscreen_rounded, color: Color(0xFF42A5F5), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Kiosk QR',
                        style: TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.bold),
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
