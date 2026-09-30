import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/glass_toast.dart';

// ============================================================
// OperatingHoursPage — 7-Day Schedule & Rush Mode Management
// ============================================================

class OperatingHoursPage extends StatefulWidget {
  const OperatingHoursPage({super.key});

  @override
  State<OperatingHoursPage> createState() => _OperatingHoursPageState();
}

class _OperatingHoursPageState extends State<OperatingHoursPage> {
  bool _isRushMode = false;
  final String _rushModeDuration = '30 minutes';

  late List<Map<String, dynamic>> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = [
      {'day': 'Monday', 'isOpen': true, 'open': const TimeOfDay(hour: 9, minute: 0), 'close': const TimeOfDay(hour: 22, minute: 0)},
      {'day': 'Tuesday', 'isOpen': true, 'open': const TimeOfDay(hour: 9, minute: 0), 'close': const TimeOfDay(hour: 22, minute: 0)},
      {'day': 'Wednesday', 'isOpen': true, 'open': const TimeOfDay(hour: 9, minute: 0), 'close': const TimeOfDay(hour: 22, minute: 0)},
      {'day': 'Thursday', 'isOpen': true, 'open': const TimeOfDay(hour: 9, minute: 0), 'close': const TimeOfDay(hour: 22, minute: 0)},
      {'day': 'Friday', 'isOpen': true, 'open': const TimeOfDay(hour: 9, minute: 0), 'close': const TimeOfDay(hour: 23, minute: 0)},
      {'day': 'Saturday', 'isOpen': true, 'open': const TimeOfDay(hour: 10, minute: 0), 'close': const TimeOfDay(hour: 23, minute: 0)},
      {'day': 'Sunday', 'isOpen': true, 'open': const TimeOfDay(hour: 10, minute: 0), 'close': const TimeOfDay(hour: 21, minute: 0)},
    ];
  }

  String _formatTime(TimeOfDay tod) {
    final period = tod.period == DayPeriod.pm ? 'PM' : 'AM';
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Future<void> _pickTime(BuildContext context, Map<String, dynamic> item, bool isOpenTime) async {
    final initial = (isOpenTime ? item['open'] : item['close']) as TimeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      if (!context.mounted) return;
      setState(() {
        if (isOpenTime) {
          item['open'] = picked;
        } else {
          item['close'] = picked;
        }
      });
      showGlassToast(context, 'Updated ${item['day']} ${isOpenTime ? 'opening' : 'closing'} time');
    }
  }

  void _toggleRushMode() {
    setState(() {
      _isRushMode = !_isRushMode;
    });
    if (_isRushMode) {
      showGlassToast(context, 'Store paused for $_rushModeDuration during rush hour');
    } else {
      showGlassToast(context, 'Store is back live on Ngam Explore!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hours & Store Status',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Waktu operasi & kawalan waktu sibuk',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rush Hour Mode Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _isRushMode
                    ? Colors.redAccent.withValues(alpha: 0.12)
                    : const Color(0xFF42A5F5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRushMode
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : const Color(0xFF42A5F5).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isRushMode ? Icons.pause_circle_filled_rounded : Icons.flash_on_rounded,
                            color: _isRushMode ? Colors.redAccent : const Color(0xFF42A5F5),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isRushMode ? 'Store Temporarily Paused' : 'Rush Hour / Pause Orders',
                            style: TextStyle(
                              color: _isRushMode ? Colors.redAccent : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isRushMode,
                        activeColor: Colors.redAccent,
                        onChanged: (val) => _toggleRushMode(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRushMode
                        ? 'New customer orders and bookings are paused on Explore. Customers will see "Temporarily Busy".'
                        : 'Overwhelmed with in-store queue? Pause incoming online bookings & orders temporarily.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 7-Day Schedule List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Regular Weekly Schedule',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._schedule.map((item) {
                    final bool isOpen = item['isOpen'] as bool;
                    final TimeOfDay openTime = item['open'] as TimeOfDay;
                    final TimeOfDay closeTime = item['close'] as TimeOfDay;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              item['day'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: isOpen
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _pickTime(context, item, true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _formatTime(openTime),
                                            style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('–', style: TextStyle(color: Colors.white38)),
                                      ),
                                      GestureDetector(
                                        onTap: () => _pickTime(context, item, false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _formatTime(closeTime),
                                            style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: Text(
                                      'CLOSED',
                                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                          ),
                          Switch(
                            value: isOpen,
                            activeColor: const Color(0xFF44CF6C),
                            onChanged: (val) {
                              setState(() => item['isOpen'] = val);
                              showGlassToast(context, '${item['day']} set to ${val ? 'Open' : 'Closed'}');
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
