import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/queue_service.dart';
import '../models/queue_ticket_model.dart';

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

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _subscription = _queueService.streamQueueTickets().listen((tickets) {
      if (!mounted) return;
      setState(() => _tickets = tickets);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final current = _currentCallingTicket;

    return Scaffold(
      backgroundColor: const Color(0xFF080811),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // TV Header Bar
              _buildTvHeader(),
              const SizedBox(height: 16),

              // Main Display Section
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Hero: CURRENT CALLED NUMBER
                    Expanded(
                      flex: 6,
                      child: _buildCurrentCallHero(current),
                    ),
                    const SizedBox(width: 20),

                    // Right Side: UP NEXT & NOW SERVING
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Expanded(child: _buildUpNextPanel()),
                          const SizedBox(height: 16),
                          Expanded(child: _buildNowServingPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // TV Footer Ticker & QR prompt
              _buildTvFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAPAN GILIRAN KEDAI (LIVE QUEUE)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Sistem Panggilan Pintar Ngam OS',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          // Big Clock
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Color(0xFF34D399), size: 20),
              const SizedBox(width: 8),
              Text(
                DateFormat('hh:mm:ss a').format(_now),
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 14),
              Text(
                DateFormat('EEEE, d MMM yyyy').format(_now),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCallHero(QueueTicketModel? current) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.4),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: current == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, color: Colors.white24, size: 72),
                  SizedBox(height: 16),
                  Text(
                    'TIADA GILIRAN SEDANG DIPANGGIL',
                    style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sila tunggu giliran anda dipanggil ke kaunter atau kerusi.',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
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
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Giant Ticket Number
                FittedBox(
                  child: Text(
                    current.ticketNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xFF3B82F6), blurRadius: 40),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Destination Station/Chair
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981)),
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
                    fontSize: 20,
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
          const Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'GILIRAN SETERUSNYA (UP NEXT)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
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
          const Row(
            children: [
              Icon(Icons.content_cut_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'SEDANG DILAYAN (NOW SERVING)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
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

  Widget _buildTvFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5), size: 24),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingin ambil nombor dari telefon anda?',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Imbas kod QR di kaunter untuk sertai giliran walk-in tanpa menunggu berdiri.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: 'https://ngam.my/queue',
              size: 40,
              version: QrVersions.auto,
            ),
          ),
        ],
      ),
    );
  }
}
