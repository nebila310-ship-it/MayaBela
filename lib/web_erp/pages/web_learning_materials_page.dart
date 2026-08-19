import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/material_access_dialog.dart';
import 'package:mayabela/widgets/material_purchase_queue_panel.dart';

/// Admin books & learning materials with + Add Books.
class WebLearningMaterialsPage extends StatefulWidget {
  const WebLearningMaterialsPage({super.key});

  @override
  State<WebLearningMaterialsPage> createState() =>
      _WebLearningMaterialsPageState();
}

class _WebLearningMaterialsPageState extends State<WebLearningMaterialsPage> {
  final _data = SchoolDataService.instance;
  String? _classFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_refresh);
    MaterialAccessService.instance.addListener(_refresh);
    MaterialPurchaseService.instance.addListener(_refresh);
    MaterialAccessService.instance.ensureLoaded();
    MaterialPurchaseService.instance.load();
  }

  @override
  void dispose() {
    SchoolContentSyncService.instance.removeListener(_refresh);
    MaterialAccessService.instance.removeListener(_refresh);
    MaterialPurchaseService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<String> get _classes {
    final names = _data.getAllClassNames().toList();
    names.sort();
    return names;
  }

  List<LearningMaterialItem> get _items {
    var items = _data.learningMaterialsSnapshot().where(
      (m) => m.className.toLowerCase() != 'library',
    );
    if (_classFilter != null) {
      items = items.where((m) => m.className == _classFilter);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where(
        (m) =>
            m.bookName.toLowerCase().contains(q) ||
            m.materialName.toLowerCase().contains(q) ||
            m.className.toLowerCase().contains(q),
      );
    }
    return items.toList();
  }

  Future<void> _addBook({LearningMaterialItem? existing}) async {
    final s = AppLocale.instance.strings;
    final classes = _classes;
    if (classes.isEmpty && existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add classes first in Academic Management')),
      );
      return;
    }

    final bookCtrl = TextEditingController(text: existing?.bookName ?? '');
    final materialCtrl =
        TextEditingController(text: existing?.materialName ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price?.toStringAsFixed(0) ?? '',
    );
    var className = existing?.className ?? classes.first;
    var subject = existing?.subject ?? SchoolSubjects.all.first;
    var isFree = existing?.isFree ?? true;
    String? filePath = existing?.filePath;

    final saved = await showAdminFormDialog(
      context: context,
      title: existing == null ? 'Add Book' : s.editLearningMaterial,
      accent: WebErpTheme.primary,
      icon: Icons.menu_book_outlined,
      saveLabel: existing == null ? s.upload : s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing == null)
            adminDialogField(
              DropdownButtonFormField<String>(
                initialValue: className,
                decoration: adminFieldDecoration(
                  label: 'Class',
                  icon: Icons.class_outlined,
                  accent: WebErpTheme.primary,
                ),
                items: classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => className = v);
                },
              ),
            ),
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: subject,
              decoration: adminFieldDecoration(
                label: s.chooseSubjectYouTeach,
                icon: Icons.subject_outlined,
                accent: WebErpTheme.primary,
              ),
              items: SchoolSubjects.all
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => subject = v);
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: bookCtrl,
              decoration: adminFieldDecoration(
                label: s.bookNameLabel,
                icon: Icons.auto_stories_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: materialCtrl,
              decoration: adminFieldDecoration(
                label: s.materialNameLabel,
                icon: Icons.description_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: !isFree,
            title: Text(
              s.paidMaterialToggle,
              style: const TextStyle(fontSize: 14),
            ),
            onChanged: (v) => setDialogState(() => isFree = !v),
          ),
          if (!isFree)
            adminDialogField(
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: adminFieldDecoration(
                  label: s.priceEtbLabel,
                  icon: Icons.payments_outlined,
                  accent: WebErpTheme.primary,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await AnnouncementAttachmentService.instance
                  .pickAndSaveFiles(subdir: 'learning_materials');
              if (picked.isEmpty) return;
              setDialogState(() => filePath = picked.first.filePath);
            },
            icon: const Icon(Icons.attach_file),
            label: Text(filePath == null ? s.pickLearningMaterialFile : s.replaceFile),
          ),
        ],
      ),
    );

    final bookName = bookCtrl.text.trim();
    final materialName = materialCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    bookCtrl.dispose();
    materialCtrl.dispose();
    priceCtrl.dispose();
    if (saved != true) return;
    if (!mounted) return;
    if (bookName.isEmpty || materialName.isEmpty) return;
    if (filePath == null && existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pickLearningMaterialFile)),
      );
      return;
    }

    final adminName = AuthService.displayNameForRole(AuthService.roleAdmin);
    if (existing == null) {
      _data.addLearningMaterial(
        className: className,
        subject: subject,
        bookName: bookName,
        materialName: materialName,
        filePath: filePath!,
        teacherName: adminName,
        teacherId: 'ADMIN',
        isFree: isFree,
        price: price,
      );
    } else {
      _data.updateLearningMaterial(
        id: existing.id,
        bookName: bookName,
        materialName: materialName,
        filePath: filePath,
        isFree: isFree,
        price: price,
      );
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? s.learningMaterialUploaded : s.learningMaterialUpdated,
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final items = _items;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'e-Book and Material',
                    style: WebErpTheme.sectionTitle(context),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String?>(
                    value: _classFilter,
                    hint: const Text('All classes'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All classes')),
                      for (final c in _classes)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _classFilter = v),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: ModuleAccess.canManage('learning_materials')
                        ? () => _addBook()
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Book'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const MaterialPurchaseQueuePanel(
                mode: MaterialPurchaseQueueMode.adminConfirm,
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(s.noLearningMaterials))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final unlockedCount = MaterialAccessService.instance
                              .unlockedStudentIds(item.id)
                              .length;
                          return ListTile(
                            tileColor: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Row(
                              children: [
                                Flexible(child: Text(item.bookName)),
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: Icon(
                                    item.isFree
                                        ? Icons.lock_open
                                        : Icons.lock_outline,
                                    size: 14,
                                    color: item.isFree
                                        ? Colors.green.shade800
                                        : Colors.orange.shade900,
                                  ),
                                  label: Text(
                                    item.isFree
                                        ? s.freeBadge
                                        : item.price != null
                                            ? '${s.paidBadge} · ${item.price!.toStringAsFixed(0)} ETB'
                                            : s.paidBadge,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: item.isFree
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              item.isFree
                                  ? '${item.className} · ${item.subject} · ${item.materialName}'
                                  : '${item.className} · ${item.subject} · ${item.materialName} · $unlockedCount ${s.unlockedForCount}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isFree)
                                  IconButton(
                                    tooltip: s.manageAccess,
                                    icon: const Icon(Icons.lock_open_outlined),
                                    onPressed: ModuleAccess.canManage(
                                            'learning_materials')
                                        ? () => showMaterialAccessDialog(
                                              context: context,
                                              material: item,
                                              accent: WebErpTheme.primary,
                                            )
                                        : null,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: ModuleAccess.canManage(
                                          'learning_materials')
                                      ? () => _addBook(existing: item)
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
