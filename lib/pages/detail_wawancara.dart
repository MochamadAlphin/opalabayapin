import 'package:flutter/material.dart';

class DetailWawancaraPopup extends StatelessWidget {
  final Map<String, dynamic> pendaftar;

  const DetailWawancaraPopup({super.key, required this.pendaftar});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF102E5A);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Popup
              Container(
                padding: const EdgeInsets.all(16.0),
                color: primaryColor,
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_ind_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Detail Antrean Wawancara',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
              ),

              // 2. Konten Informasi Pendaftar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Pendaftar
                    _buildDetailItem(
                      label: 'Nama Calon Penghuni',
                      value: pendaftar['nama'] ?? '-',
                      icon: Icons.person_outline,
                      iconColor: primaryColor,
                    ),
                    const Divider(height: 24),

                    // Tanggal Wawancara
                    _buildDetailItem(
                      label: 'Tanggal Wawancara',
                      value: pendaftar['tgl_wawancara'] ?? '-',
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.blue,
                    ),
                    const Divider(height: 24),

                    // Lokasi Tujuan
                    _buildDetailItem(
                      label: 'Rusunawa Tujuan',
                      value: pendaftar['lokasi_tujuan'] ?? '-',
                      icon: Icons.domain_outlined,
                      iconColor: Colors.orange,
                    ),
                    const Divider(height: 24),

                    // Informasi Tambahan
                    _buildDetailItem(
                      label: 'Status Alokasi Data',
                      value: 'Menunggu Wawancara Tim Lapangan',
                      icon: Icons.info_outline,
                      iconColor: Colors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}