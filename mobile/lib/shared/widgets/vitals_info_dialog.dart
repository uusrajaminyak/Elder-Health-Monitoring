import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart'; 

class VitalsInfoDialog extends StatelessWidget {
  const VitalsInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Judul & Tombol Tutup
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, color: AppColors.forestGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Memahami Tanda Vital',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Konten Teks
            const Text(
              'Saat orang dewasa beristirahat:',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildBulletText('Jantung: umumnya 60–100 kali/menit'),
            _buildBulletText('Oksigen: umumnya 95–100%'),
            _buildBulletText('Suhu: sekitar 36,1–37,2 °C'),
            const SizedBox(height: 16),
            
            // Disclaimer
            const Text(
              'Panduan umum, bukan resep medis. Arahan tim perawatan Nenek lebih utama.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            
            // Tombol Mengerti
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
