import 'package:flutter/material.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebSystemHealthPage extends StatefulWidget {
  const WebSystemHealthPage({super.key});

  @override
  State<WebSystemHealthPage> createState() => _WebSystemHealthPageState();
}

class _WebSystemHealthPageState extends State<WebSystemHealthPage> {
  bool? _storageReady;
  String? _storageDetail;

  @override
  void initState() {
    super.initState();
    _checkStorage();
  }

  Future<void> _checkStorage() async {
    if (SupabaseStorageBootstrap.deferred) {
      setState(() {
        _storageReady = false;
        _storageDetail = 'Deferred until Storage bucket is enabled';
      });
      return;
    }
    if (!SupabaseBootstrap.isInitialized) {
      setState(() {
        _storageReady = false;
        _storageDetail = 'Supabase not initialized';
      });
      return;
    }
    final ok = await SupabaseStorageBootstrap.ensureReady(forceRecheck: true);
    if (!mounted) return;
    setState(() {
      _storageReady = ok;
      _storageDetail = ok
          ? 'Bucket ready for uploads'
          : (SupabaseStorageBootstrap.lastError ?? 'Not configured');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloudReady = SupabaseBootstrap.isInitialized;
    final storageOk = _storageReady == true;
    final storageChecking = _storageReady == null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System Health',
                  style: WebErpTheme.sectionTitle(context),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _checkStorage,
                icon: const Icon(Icons.refresh),
                label: const Text('Recheck'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _HealthCard(
                title: 'Supabase',
                status: cloudReady ? 'Connected' : 'Unavailable',
                ok: cloudReady,
                icon: Icons.cloud_done_outlined,
              ),
              _HealthCard(
                title: 'Postgres docs',
                status: cloudReady ? 'Operational' : 'Offline',
                ok: cloudReady,
                icon: Icons.storage_outlined,
              ),
              _HealthCard(
                title: 'Cloud Storage',
                status: SupabaseStorageBootstrap.deferred
                    ? 'Deferred (local files only)'
                    : storageChecking
                        ? 'Checking…'
                        : storageOk
                            ? 'Operational'
                            : 'Not set up',
                ok: SupabaseStorageBootstrap.deferred || storageOk,
                icon: Icons.folder_outlined,
              ),
              _HealthCard(
                title: 'Inventory uploads',
                status: storageOk
                    ? 'Cloud + local fallback'
                    : 'Local only until Storage is enabled',
                ok: storageOk || storageChecking == true,
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: WebErpTheme.cardDecoration(context),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!cloudReady) ...[
                      const Text(
                        'Supabase is not configured. Set SUPABASE_URL and '
                        'SUPABASE_ANON_KEY in lib/supabase_options.dart or via '
                        '--dart-define, then restart the app.',
                      ),
                    ] else if (SupabaseStorageBootstrap.deferred) ...[
                      const Text(
                        'Storage uploads are deferred. Document sync through '
                        'Supabase Postgres is still active.',
                      ),
                    ] else if (!storageOk && !storageChecking) ...[
                      Text(
                        'Supabase Storage is not ready yet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Apply supabase/migrations on your project\n'
                        '2. Confirm the school-files bucket exists\n'
                        '3. Deploy edge functions for school auth\n'
                        '4. Recheck this page',
                      ),
                      if (_storageDetail != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Detail: $_storageDetail',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ] else if (storageOk) ...[
                      const Text(
                        'Supabase Auth, Postgres document store, and Storage '
                        'are connected.',
                      ),
                    ] else ...[
                      const Text('Checking Supabase Storage…'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.title,
    required this.status,
    required this.ok,
    required this.icon,
  });

  final String title;
  final String status;
  final bool ok;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.teal : Colors.orange;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.shade700,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
