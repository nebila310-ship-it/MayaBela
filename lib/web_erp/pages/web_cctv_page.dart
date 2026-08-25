import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Admin CCTV hub. Camera sites are real module UI; live picture attaches
/// later when [CctvCameraSite.streamUrl] is filled from the school NVR.
class WebCctvPage extends StatelessWidget {
  const WebCctvPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = CctvCatalogService.instance.sitesForSchool(
      AuthService.activeSchoolId,
    );
    final wired = sites.where((s) => s.isWired).length;

    return SingleChildScrollView(
      padding: WebViewport.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, siteCount: sites.length, wiredCount: wired),
          const SizedBox(height: 20),
          Text('Camera sites', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              final columns = width >= 1100
                  ? 4
                  : width >= 720
                      ? 2
                      : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final site in sites) _CameraTile(site: site),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _connectCard(context),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required int siteCount,
    required int wiredCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WebErpTheme.classBanner(ClassroomPalette.navy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CCTV',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Campus cameras from the school’s existing recorder. '
            'Live picture appears when the NVR is linked.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('$siteCount sites mapped'),
              _chip(
                wiredCount == 0
                    ? 'Ready to connect'
                    : '$wiredCount live feeds',
              ),
              _chip('Staff only'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _connectCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How live feed connects', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            'The school keeps its current cameras and NVR. MayaBela only '
            'opens the views for signed-in admin and leadership. Supported '
            'hooks: Hik-Connect / DMSS cloud, RTSP, or HLS from the recorder.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WebErpTheme.paperInk.withValues(alpha: 0.75),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('Hik-Connect')),
              Chip(label: Text('RTSP')),
              Chip(label: Text('HLS')),
              Chip(label: Text('Staff roles')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.site});

  final CctvCameraSite site;

  @override
  Widget build(BuildContext context) {
    final wired = site.isWired;
    return Container(
      key: Key('cctv-site-${site.id}'),
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: ClassroomPalette.navy.withValues(alpha: 0.12),
                child: Icon(
                  wired ? Icons.videocam : Icons.videocam_outlined,
                  color: ClassroomPalette.navy,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: wired
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  wired ? 'Live' : 'Ready to connect',
                  style: TextStyle(
                    color: wired
                        ? ClassroomPalette.green
                        : const Color(0xFFE65100),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            site.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: WebErpTheme.paperInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            site.location,
            style: TextStyle(
              color: WebErpTheme.paperInk.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
