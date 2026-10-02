import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/glass_toast.dart';
import '../data/business_service.dart';

// ============================================================
// OperatingHoursPage — 7-Day Schedule, Rush Mode & Holiday Management
// ============================================================

class OperatingHoursPage extends StatefulWidget {
  const OperatingHoursPage({super.key});

  @override
  State<OperatingHoursPage> createState() => _OperatingHoursPageState();
}

class _OperatingHoursPageState extends State<OperatingHoursPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _businessId;

  bool _isRushMode = false;
  String _rushModeDuration = '30 minutes';

  late List<Map<String, dynamic>> _schedule;
  List<Map<String, dynamic>> _specialHolidays = [];

  final List<String> _quickHolidayPresets = [
    'Hari Raya Aidilfitri',
    'Tahun Baru Cina',
    'Deepavali',
    'Hari Kebangsaan (31 Ogos)',
    'Hari Malaysia (16 Sept)',
    'Cuti Peristiwa Khas',
  ];

  @override
  void initState() {
    super.initState();
    _initDefaultSchedule();
    _loadLiveSchedule();
  }

  void _initDefaultSchedule() {
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

  Future<void> _loadLiveSchedule() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      if (profile != null && mounted) {
        _businessId = profile['id'];
        final settings = profile['settings'] as Map<String, dynamic>?;

        if (settings != null && settings['operating_hours'] is Map) {
          final op = settings['operating_hours'] as Map<String, dynamic>;

          if (op['is_rush_mode'] != null) {
            _isRushMode = op['is_rush_mode'] == true;
          }
          if (op['rush_mode_duration'] != null) {
            _rushModeDuration = op['rush_mode_duration'].toString();
          }

          // Parse weekly schedule
          final weekly = op['weekly_schedule'] as List?;
          if (weekly != null && weekly.isNotEmpty) {
            final List<Map<String, dynamic>> parsedWeekly = [];
            for (final item in weekly) {
              if (item is Map) {
                final day = item['day']?.toString() ?? 'Monday';
                final isOpen = item['isOpen'] != false;
                final openStr = item['open']?.toString() ?? '09:00';
                final closeStr = item['close']?.toString() ?? '22:00';

                final openParts = openStr.split(':');
                final closeParts = closeStr.split(':');

                parsedWeekly.add({
                  'day': day,
                  'isOpen': isOpen,
                  'open': TimeOfDay(hour: int.tryParse(openParts[0]) ?? 9, minute: openParts.length > 1 ? int.tryParse(openParts[1]) ?? 0 : 0),
                  'close': TimeOfDay(hour: int.tryParse(closeParts[0]) ?? 22, minute: closeParts.length > 1 ? int.tryParse(closeParts[1]) ?? 0 : 0),
                });
              }
            }
            if (parsedWeekly.isNotEmpty) {
              _schedule = parsedWeekly;
            }
          }

          // Parse special holidays
          final holidays = op['special_holidays'] as List?;
          if (holidays != null) {
            _specialHolidays = holidays.map((h) => Map<String, dynamic>.from(h as Map)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading operating hours: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDisplayTime(TimeOfDay tod) {
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

  Future<void> _toggleRushMode() async {
    setState(() {
      _isRushMode = !_isRushMode;
    });

    if (_businessId != null) {
      await _saveScheduleSilently();
    }

    if (!mounted) return;
    if (_isRushMode) {
      showGlassToast(context, 'Store paused for $_rushModeDuration during rush hour');
    } else {
      showGlassToast(context, 'Store is back live on Ngam Explore!');
    }
  }

  Future<void> _saveScheduleSilently() async {
    if (_businessId == null) return;
    try {
      final weeklySerialized = _schedule.map((item) {
        final open = item['open'] as TimeOfDay;
        final close = item['close'] as TimeOfDay;
        return {
          'day': item['day'],
          'isOpen': item['isOpen'],
          'open': _formatTimeOfDay(open),
          'close': _formatTimeOfDay(close),
        };
      }).toList();

      final firstOpen = _schedule.firstWhere((s) => s['isOpen'] == true, orElse: () => _schedule.first);
      final openStr = _formatTimeOfDay(firstOpen['open'] as TimeOfDay);
      final closeStr = _formatTimeOfDay(firstOpen['close'] as TimeOfDay);

      final payload = {
        'operating_hours': {
          'open_time': openStr,
          'close_time': closeStr,
          'is_rush_mode': _isRushMode,
          'rush_mode_duration': _rushModeDuration,
          'weekly_schedule': weeklySerialized,
          'special_holidays': _specialHolidays,
        }
      };

      await BusinessService().saveBusinessSettings(_businessId!, payload);
    } catch (e) {
      debugPrint('Error saving schedule: $e');
    }
  }

  Future<void> _saveSchedule() async {
    if (_businessId == null) {
      showGlassToast(context, 'Business profile not loaded yet', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _saveScheduleSilently();
      if (mounted) {
        showGlassToast(context, 'Jadual operasi & cuti perayaan disimpan!');
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menyimpan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddHolidayModal() {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Tutup Sepanjang Hari');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isClosed = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tambah Cuti Peristiwa / Perayaan',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pelanggan akan nampak makluman cuti ini di Store Information.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Quick Preset Chips
                    const Text('Pilihan Cepat:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickHolidayPresets.map((preset) {
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              nameCtrl.text = preset;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(preset, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Holiday Name Field
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nama Perayaan / Cuti',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: 'Cth: Hari Raya Aidilfitri',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Picker Tile
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, color: Colors.blueAccent, size: 20),
                                SizedBox(width: 10),
                                Text('Tarikh Cuti:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Closed switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tutup Sepanjang Hari', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                          Switch(
                            value: isClosed,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setModalState(() => isClosed = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Note field
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Catatan / Waktu Khas',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: 'Cth: Tutup 2 hari sempena Aidilfitri',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) {
                            showGlassToast(context, 'Sila masukkan nama cuti', isError: true);
                            return;
                          }

                          final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

                          setState(() {
                            _specialHolidays.add({
                              'name': nameCtrl.text.trim(),
                              'date': dateStr,
                              'isClosed': isClosed,
                              'note': noteCtrl.text.trim(),
                            });
                          });

                          Navigator.pop(ctx);
                          _saveScheduleSilently();
                          showGlassToast(context, 'Cuti "${nameCtrl.text.trim()}" ditambah!');
                        },
                        child: const Text('Simpan Cuti Peristiwa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                          'Waktu operasi, sibuk & cuti perayaan',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveSchedule,
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5))))
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  children: [
                    // Rush Hour Mode Banner
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
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
                                ? 'Pesanan & tempahan baharu ditangguhkan. Pelanggan akan melihat status "Temporarily Busy".'
                                : 'Terlalu sibuk di kedai fizikal? Hentikan sementara tempahan online untuk elak kesesakan.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 7-Day Schedule Header
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Jadual Mingguan Tetap (7 Hari)',
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
                              width: 80,
                              child: Text(
                                item['day'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: isOpen
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () => _pickTime(context, item, true),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  _formatDisplayTime(openTime),
                                                  style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4),
                                          child: Text('–', style: TextStyle(color: Colors.white38)),
                                        ),
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () => _pickTime(context, item, false),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  _formatDisplayTime(closeTime),
                                                  style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Center(
                                      child: Text(
                                        'TUTUP / CLOSED',
                                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                            ),
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: isOpen,
                                activeColor: const Color(0xFF44CF6C),
                                onChanged: (val) {
                                  setState(() => item['isOpen'] = val);
                                  showGlassToast(context, '${item['day']} set to ${val ? 'Open' : 'Closed'}');
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Festive & Special Holidays Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cuti Peristiwa & Perayaan',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _showAddHolidayModal,
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF42A5F5), size: 18),
                          label: const Text('Tambah Cuti', style: TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),

                    if (_specialHolidays.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: const Center(
                          child: Text(
                            'Tiada cuti peristiwa atau perayaan ditambah.\nTekan "+ Tambah Cuti" untuk tetapkan cuti khas kedai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                          ),
                        ),
                      )
                    else
                      ..._specialHolidays.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final holiday = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, color: Colors.amber, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      holiday['name'] ?? 'Cuti Peristiwa',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${holiday['date']} • ${holiday['isClosed'] == false ? 'Waktu Terhad' : 'Tutup Penuh'}${holiday['note'] != null && holiday['note'].toString().isNotEmpty ? ' (${holiday['note']})' : ''}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _specialHolidays.removeAt(idx);
                                  });
                                  _saveScheduleSilently();
                                  showGlassToast(context, 'Cuti dibuang');
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
