import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Pastikan path import ini sesuai dengan lokasi vitals_provider Anda
import '../../../shared/providers/vitals_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedCategory = 'Semua';
  EventStatus? _selectedStatusFilter;
  
  late DateTime _selectedMonth;
  late List<DateTime> _availableMonths;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _availableMonths = [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month - 1),
      DateTime(now.year, now.month - 2),
    ];
  }

  // Fungsi Filter
  List<HealthEvent> _applyFilters(List<HealthEvent> allEvents) {
    return allEvents.where((event) {
      
      if (_selectedCategory == 'Oksigen' && event.type != VitalType.oksigen) return false;
      if (_selectedCategory == 'Denyut' && event.type != VitalType.denyut) return false;
      if (_selectedCategory == 'Suhu' && event.type != VitalType.suhu) return false;
      if (_selectedStatusFilter != null && event.status != _selectedStatusFilter) return false;

      return true;
    }).toList();
  }

  // Fungsi Pengelompokan berdasar Tanggal
  Map<String, List<HealthEvent>> _groupEventsByDate(List<HealthEvent> events) {
    final Map<String, List<HealthEvent>> grouped = {};
    for (var event in events) {
      final dateKey = DateFormat('yyyy-MM-dd').format(event.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    // 100% DINAMIS DAN SINKRON: Menarik riwayat yang tercatat di state Dashboard
    final vitalsState = ref.watch(vitalsProvider);
    final allEvents = vitalsState.anomalyHistory; 
    
    final filteredEvents = _applyFilters(allEvents);
    final groupedData = _groupEventsByDate(filteredEvents);

    final today = DateTime.now();
    final isCurrentMonthSelected = _selectedMonth.year == today.year && _selectedMonth.month == today.month;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              const Text('Riwayat Kesehatan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              const Text('Catatan pengukuran anomali dan tindak lanjut.', style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4)),
              const SizedBox(height: 20),

              // DROPDOWN BULAN
              PopupMenuButton<DateTime>(
                onSelected: (date) => setState(() => _selectedMonth = date),
                itemBuilder: (context) {
                  return _availableMonths.map((date) => PopupMenuItem<DateTime>(value: date, child: Text(DateFormat('MMMM yyyy', 'id_ID').format(date)))).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF4A4A4A)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF4A4A4A)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // FILTER KATEGORI
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('Semua'), const SizedBox(width: 8),
                    _buildCategoryChip('Oksigen'), const SizedBox(width: 8),
                    _buildCategoryChip('Denyut'), const SizedBox(width: 8),
                    _buildCategoryChip('Suhu'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // FILTER STATUS
              Row(
                children: [
                  Expanded(child: _buildStatusFilterButton(label: 'Perlu Dicek', status: EventStatus.perluDicek, activeColor: const Color(0xFFD97706))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusFilterButton(label: 'Sedang Ditangani', status: EventStatus.sedangDitangani, activeColor: const Color(0xFF13633F))),
                ],
              ),
              const SizedBox(height: 24),

              // TAMPILKAN HASIL ANOMALI JIKA ADA
              if (groupedData.isNotEmpty) ...[
                ...groupedData.entries.map((entry) {
                  final dateObj = DateTime.parse(entry.key);
                  final formattedDate = _formatDateHeader(dateObj);
                  final events = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateHeader(formattedDate, '${events.length} kejadian'),
                      const SizedBox(height: 12),
                      ...events.map((event) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: _buildAnomalyCard(event))),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
              ],

              // TAMPILKAN NORMAL JIKA KOSONG / BELUM ADA ANOMALI HARI INI
              if (groupedData.isEmpty) ...[
                if (isCurrentMonthSelected && _selectedCategory == 'Semua' && _selectedStatusFilter == null) ...[
                  _buildDateHeader('Hari ini · ${DateFormat('d MMMM yyyy', 'id_ID').format(today)}', 'Tidak ada Kejadian'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF13633F), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Semua Normal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Menunggu data. Saat ini belum ada catatan anomali tanda vital yang terekam sistem.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: const [
                        Icon(Icons.search_off, size: 48, color: Colors.grey), SizedBox(height: 12),
                        Text('Tidak Ada Kejadian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4),
                        Text('Tidak ada catatan riwayat yang sesuai dengan filter yang Anda pilih.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET HELPERS
  Widget _buildStatusFilterButton({required String label, required EventStatus status, required Color activeColor}) {
    final isSelected = _selectedStatusFilter == status;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = isSelected ? null : status),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? activeColor : Colors.white, border: Border.all(color: activeColor, width: 1.5), borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : activeColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF13633F) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isActive ? const Color(0xFF13633F) : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }

  Widget _buildDateHeader(String date, String trailingText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
        Text(trailingText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate == today) return 'Hari ini · ${DateFormat('d MMMM yyyy', 'id_ID').format(date)}';
    if (today.difference(targetDate).inDays == 1) return 'Kemarin · ${DateFormat('d MMMM yyyy', 'id_ID').format(date)}';
    return DateFormat('EEEE · d MMMM yyyy', 'id_ID').format(date);
  }

  Widget _buildAnomalyCard(HealthEvent event) {
    final isWarning = event.status == EventStatus.perluDicek;
    final badgeColor = isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6);
    final badgeTextColor = isWarning ? const Color(0xFFD97706) : const Color(0xFF4A4A4A);
    final badgeIcon = isWarning ? Icons.warning_amber_rounded : Icons.access_time;
    final badgeText = isWarning ? 'Perlu dicek' : 'Sedang ditangani';

    IconData icon = Icons.thermostat_outlined;
    if (event.type == VitalType.oksigen) icon = Icons.water_drop_outlined;
    if (event.type == VitalType.denyut) icon = Icons.favorite_border;
    if (event.type == VitalType.jatuh) icon = Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Icon(badgeIcon, size: 14, color: badgeTextColor), const SizedBox(width: 4), Text(badgeText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeTextColor))]),
              ),
              Text(DateFormat('HH.mm').format(event.timestamp), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFFD97706), size: 26)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(event.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        if (event.valueUnit != null) Text(event.valueUnit!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(event.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}