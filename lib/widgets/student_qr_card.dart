import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mayabela/models/calendar_event.dart';

/// Renders a student gate QR with a safe fallback if generation fails.
class StudentQrCard extends StatelessWidget {
  const StudentQrCard({
    super.key,
    required this.profile,
    this.size = 180,
  });

  final StudentQrProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = profile.qrCode.trim().isNotEmpty
        ? profile.qrCode.trim()
        : 'STUDENT:${profile.id}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              profile.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(profile.className),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                errorStateBuilder: (context, error) {
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Center(
                      child: Text(
                        'Unable to generate QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
