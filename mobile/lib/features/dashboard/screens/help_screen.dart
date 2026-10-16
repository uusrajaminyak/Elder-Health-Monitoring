import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Bantuan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Panduan cepat untuk keluarga',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pilih pertanyaan untuk melihat panduannya.\nSaat darurat, segera hubungi orang terdekat.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A4A4A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              const _FaqItem(
                icon: Icons.check_circle_outline,
                iconColor: Color(0xFF13633F),
                iconBgColor: Color(0xFFE8F3ED),
                title: 'Gelang dilepas, internet tersambung',
                content:
                    'Minta pendamping memasangkan gelang kembali. Selama dilepas, pengukuran belum tersedia.\n\nGelang tetap bisa diminta berbunyi. Pastikan baterai gelang tidak habis.',
                isInitiallyExpanded: true,
              ),
              const SizedBox(height: 12),
              const _FaqItem(
                icon: Icons.warning_amber_rounded,
                iconColor: Color(0xFFD97706),
                iconBgColor: Color(0xFFFEF3C7),
                title: 'Gelang belum berbunyi',
                content: 'Pastikan gelang memiliki sisa baterai dan terhubung dengan jaringan internet.',
              ),
              const SizedBox(height: 12),
              const _FaqItem(
                icon: Icons.access_time,
                iconColor: Color(0xFF4A4A4A),
                iconBgColor: Color(0xFFF3F4F6),
                title: 'Gelang tidak terhubung',
                content: 'Periksa koneksi WiFi di sekitar Nenek atau pastikan baterai gelang terisi daya.',
              ),
              const SizedBox(height: 12),
              const _FaqItem(
                icon: Icons.health_and_safety_outlined,
                iconColor: Color(0xFF13633F),
                iconBgColor: Color(0xFFE8F3ED),
                title: 'Apa arti status penanganan?',
                content: 'Status penanganan menunjukkan tindakan medis atau darurat yang sedang berjalan saat ini.',
              ),
              const SizedBox(height: 12),
              const _FaqItem(
                icon: Icons.warning_amber_rounded,
                iconColor: Color(0xFFD97706),
                iconBgColor: Color(0xFFFEF3C7),
                title: 'Kapan memilih alarm palsu?',
                content: 'Pilih alarm palsu jika peringatan berbunyi namun Nenek dalam kondisi aman dan sehat.',
              ),
              const SizedBox(height: 12),
              const _FaqItem(
                icon: Icons.save_outlined,
                iconColor: Color(0xFF4A4A4A),
                iconBgColor: Color(0xFFF3F4F6),
                title: 'Bagaimana mengatur batas aman?',
                content: 'Buka menu Batas Aman di navigasi bawah untuk menyesuaikan ambang batas notifikasi.',
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Ingin melihat kejadian sebelumnya?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Buka Riwayat untuk melihat perubahan oksigen, denyut jantung, suhu, dan tindak lanjutnya.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A4A4A),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Center(
                child: Text(
                  'Jika Ayah membutuhkan pertolongan segera, hubungi layanan\ndarurat setempat. Jangan menunggu respons gelang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String content;
  final bool isInitiallyExpanded;

  const _FaqItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.content,
    this.isInitiallyExpanded = false,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent, // Menghilangkan garis default
        ),
        child: ExpansionTile(
          initiallyExpanded: widget.isInitiallyExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              color: widget.iconColor,
              size: 20,
            ),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
          ),
          // Mengubah ikon panah menjadi + atau -
          trailing: Text(
            _isExpanded ? '—' : '+',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A4A4A),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}