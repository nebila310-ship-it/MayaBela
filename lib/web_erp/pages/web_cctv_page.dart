import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// Admin CCTV hub. Camera sites stay on this device / the school NVR.
/// MayaBela does not store or sync footage to the school cloud.
class WebCctvPage extends StatefulWidget {
  const WebCctvPage({super.key});

  @override
  State<WebCctvPage> createState() => _WebCctvPageState();
}

class _WebCctvPageState extends State<WebCctvPage> {
  @override
  void initState() {
    super.initState();
    CctvCatalogService.instance.ensureLoaded();
  }

  bool get _canManage => ModuleAccess.canManage('cctv');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CctvCatalogService.instance,
        AppLocale.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final sites = CctvCatalogService.instance.sitesForSchool(
          AuthService.activeSchoolId,
        );
        final wired = sites.where((site) => site.isWired).length;

        return SingleChildScrollView(
          padding: WebViewport.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, s, siteCount: sites.length, wiredCount: wired),
              const SizedBox(height: 12),
              _localOnlyBanner(context, s),
              const SizedBox(height: 20),
              Text(s.cctvCameraSites, style: WebErpTheme.sectionTitle(context)),
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
                    childAspectRatio: _canManage ? 1.15 : 1.35,
                    children: [
                      for (final site in sites)
                        _CameraTile(
                          site: site,
                          canManage: _canManage,
                          onLink: () => _linkSite(site),
                          onOpen: site.isWired
                              ? () => _openNvrLink(site.streamUrl!)
                              : null,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _connectCard(context, s),
            ],
          ),
        );
      },
    );
  }

  Widget _header(
    BuildContext context,
    AppStrings s, {
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
          Text(
            s.cctvTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.cctvHeaderSubtitle,
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
              _chip(s.cctvSitesMapped(siteCount)),
              _chip(
                wiredCount == 0
                    ? s.cctvReadyToConnect
                    : s.cctvWiredOnDevice(wiredCount),
              ),
              _chip(s.cctvStaffOnly),
              _chip(s.cctvNotInCloudChip),
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

  Widget _localOnlyBanner(BuildContext context, AppStrings s) {
    return Container(
      key: const Key('cctv-local-only-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_off_outlined, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.cctvLocalOnlyBanner,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectCard(BuildContext context, AppStrings s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.cctvHowConnectTitle, style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            s.cctvHowConnectBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WebErpTheme.paperInk.withValues(alpha: 0.75),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(s.cctvHookHik)),
              Chip(label: Text(s.cctvHookRtsp)),
              Chip(label: Text(s.cctvHookHls)),
              Chip(label: Text(s.cctvNotInCloudChip)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _linkSite(CctvCameraSite site) async {
    final s = AppLocale.instance.strings;
    final controller = TextEditingController(text: site.streamUrl ?? '');
    final saved = await showAdminFormDialog(
      context: context,
      title: s.cctvLinkNvrTitle,
      subtitle: site.name,
      accent: ClassroomPalette.navy,
      icon: Icons.videocam_outlined,
      saveLabel: s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.cctvLinkNvrHint,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          adminDialogField(
            TextField(
              controller: controller,
              decoration: adminFieldDecoration(
                label: s.cctvStreamUrlLabel,
                icon: Icons.link_outlined,
                accent: ClassroomPalette.navy,
              ),
            ),
          ),
        ],
      ),
    );
    if (saved) {
      await CctvCatalogService.instance.setLocalStreamUrl(
        siteId: site.id,
        streamUrl: controller.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.cctvSavedLocalOnly),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _openNvrLink(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.hasScheme)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.site,
    required this.canManage,
    required this.onLink,
    this.onOpen,
  });

  final CctvCameraSite site;
  final bool canManage;
  final VoidCallback onLink;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
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
                  wired ? s.cctvWiredOnThisDevice : s.cctvReadyToConnect,
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
          if (canManage) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: onLink,
                  child: Text(s.cctvLinkNvrAction),
                ),
                if (onOpen != null)
                  TextButton(
                    onPressed: onOpen,
                    child: Text(s.cctvOpenNvrLink),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
