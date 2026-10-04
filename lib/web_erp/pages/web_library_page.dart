import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/library_rental_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/year_start_sheet_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// School library — e-books catalog + rentals (free or paid).
class WebLibraryPage extends StatefulWidget {
  const WebLibraryPage({super.key});

  static const libraryClass = 'Library';

  @override
  State<WebLibraryPage> createState() => _WebLibraryPageState();
}

class _WebLibraryPageState extends State<WebLibraryPage>
    with SingleTickerProviderStateMixin {
  final _data = SchoolDataService.instance;
  late final TabController _tabs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    SchoolContentSyncService.instance.addListener(_refresh);
    LibraryRentalService.instance.addListener(_refresh);
    MaterialAccessService.instance.ensureLoaded();
    LibraryRentalService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    SchoolContentSyncService.instance.removeListener(_refresh);
    LibraryRentalService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<LearningMaterialItem> get _books {
    var items = _data.learningMaterialsSnapshot().where(
      (m) =>
          m.className.toLowerCase() == WebLibraryPage.libraryClass.toLowerCase(),
    );
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where(
        (m) =>
            m.bookName.toLowerCase().contains(q) ||
            m.materialName.toLowerCase().contains(q),
      );
    }
    return items.toList();
  }

  bool get _canManage => ModuleAccess.canManage('library');

  Future<void> _addBook({LearningMaterialItem? existing}) async {
    if (!_canManage) return;
    final s = AppLocale.instance.strings;
    final titleCtrl = TextEditingController(text: existing?.bookName ?? '');
    final authorCtrl = TextEditingController(text: existing?.materialName ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.price == null ? '' : existing!.price!.toStringAsFixed(0),
    );
    String? filePath = existing?.filePath;
    var subject = existing?.subject ?? 'General';
    var isFree = existing?.isFree ?? true;

    final saved = await showAdminFormDialog(
      context: context,
      title: existing == null ? 'Add e-Book / Material' : 'Edit e-Book / Material',
      accent: WebErpTheme.primary,
      icon: Icons.menu_book_outlined,
      saveLabel: existing == null ? s.upload : s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            TextField(
              controller: titleCtrl,
              decoration: adminFieldDecoration(
                label: 'Title',
                icon: Icons.menu_book_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: authorCtrl,
              decoration: adminFieldDecoration(
                label: 'Author / Category',
                icon: Icons.person_outline,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: subject,
              decoration: adminFieldDecoration(
                label: 'Subject',
                icon: Icons.category_outlined,
                accent: WebErpTheme.primary,
              ),
              items: ['General', ...SchoolSubjects.all.take(8)]
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => subject = v);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('Access', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Free'), icon: Icon(Icons.lock_open)),
              ButtonSegment(value: false, label: Text('Paid'), icon: Icon(Icons.payments_outlined)),
            ],
            selected: {isFree},
            onSelectionChanged: (v) => setDialogState(() => isFree = v.first),
          ),
          if (!isFree) ...[
            const SizedBox(height: 12),
            adminDialogField(
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: adminFieldDecoration(
                  label: 'Price (ETB)',
                  icon: Icons.attach_money,
                  accent: WebErpTheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await AnnouncementAttachmentService.instance
                  .pickAndSaveFiles(subdir: 'library');
              if (picked.isEmpty) return;
              setDialogState(() => filePath = picked.first.filePath);
            },
            icon: const Icon(Icons.upload_file),
            label: Text(filePath == null ? 'Upload PDF / e-Book' : 'Replace file'),
          ),
        ],
      ),
    );

    final title = titleCtrl.text.trim();
    final author = authorCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    titleCtrl.dispose();
    authorCtrl.dispose();
    priceCtrl.dispose();
    if (saved != true) return;
    if (!mounted) return;
    if (title.isEmpty || author.isEmpty) return;
    if (filePath == null && existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a file')),
      );
      return;
    }
    if (!isFree && (price == null || price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a price for paid items')),
      );
      return;
    }

    final adminName = AuthService.displayNameForRole(
      AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
    );
    if (existing == null) {
      _data.addLearningMaterial(
        className: WebLibraryPage.libraryClass,
        subject: subject,
        bookName: title,
        materialName: author,
        filePath: filePath!,
        teacherName: adminName,
        teacherId: AuthService.currentUser?.username ?? AuthService.roleAdmin,
        isFree: isFree,
        price: price,
      );
    } else {
      _data.updateLearningMaterial(
        id: existing.id,
        bookName: title,
        materialName: author,
        filePath: filePath,
        isFree: isFree,
        price: price,
      );
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Published' : s.save),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rentBook({LearningMaterialItem? preset}) async {
    if (!_canManage) return;
    final books = _data
        .learningMaterialsSnapshot()
        .where(
          (m) =>
              m.className.toLowerCase() ==
              WebLibraryPage.libraryClass.toLowerCase(),
        )
        .toList();
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an e-Book first')),
      );
      return;
    }

    var selectedBook = preset ?? books.first;
    final studentQuery = TextEditingController();
    AdminStudentRecord? selectedStudent;
    var isPaid = !(preset?.isFree ?? selectedBook.isFree);
    final priceCtrl = TextEditingController(
      text: selectedBook.price == null
          ? ''
          : selectedBook.price!.toStringAsFixed(0),
    );
    var studentHits = <AdminStudentRecord>[];

    final saved = await showAdminFormDialog(
      context: context,
      title: 'Rent a Book',
      accent: WebErpTheme.primary,
      icon: Icons.handshake_outlined,
      saveLabel: 'Confirm rent',
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: selectedBook.id,
              decoration: adminFieldDecoration(
                label: 'e-Book / Material',
                icon: Icons.auto_stories_outlined,
                accent: WebErpTheme.primary,
              ),
              items: books
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        '${b.bookName}${b.isFree ? ' (Free)' : ' (Paid)'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final book = books.firstWhere((b) => b.id == id);
                setDialogState(() {
                  selectedBook = book;
                  isPaid = !book.isFree;
                  priceCtrl.text =
                      book.price == null ? '' : book.price!.toStringAsFixed(0);
                });
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: studentQuery,
              decoration: adminFieldDecoration(
                label: 'Find student (name or ID)',
                icon: Icons.person_search_outlined,
                accent: WebErpTheme.primary,
              ),
              onChanged: (v) {
                final q = v.trim().toLowerCase();
                final schoolId = AuthService.activeSchoolId;
                final all = schoolId == null
                    ? StudentRegistryService.instance.getAllStudents()
                    : StudentRegistryService.instance.studentsForSchool(schoolId);
                setDialogState(() {
                  studentHits = q.isEmpty
                      ? <AdminStudentRecord>[]
                      : all
                          .where(
                            (s) =>
                                s.isActive &&
                                (s.fullName.toLowerCase().contains(q) ||
                                    s.studentId.toLowerCase().contains(q)),
                          )
                          .take(8)
                          .toList();
                });
              },
            ),
          ),
          if (selectedStudent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Selected: ${selectedStudent!.fullName} (${selectedStudent!.studentId})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          for (final hit in studentHits)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(hit.fullName),
              subtitle: Text('${hit.studentId} · ${hit.grade} ${hit.className}'),
              onTap: () => setDialogState(() {
                selectedStudent = hit;
                studentQuery.text = hit.fullName;
                studentHits = [];
              }),
            ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Free'), icon: Icon(Icons.lock_open)),
              ButtonSegment(value: true, label: Text('Paid'), icon: Icon(Icons.payments_outlined)),
            ],
            selected: {isPaid},
            onSelectionChanged: (v) => setDialogState(() => isPaid = v.first),
          ),
          if (isPaid) ...[
            const SizedBox(height: 12),
            adminDialogField(
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: adminFieldDecoration(
                  label: 'Amount (ETB)',
                  icon: Icons.attach_money,
                  accent: WebErpTheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final price = double.tryParse(priceCtrl.text.trim());
    studentQuery.dispose();
    priceCtrl.dispose();
    if (saved != true) return;
    if (!mounted) return;
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a student')),
      );
      return;
    }
    if (isPaid && (price == null || price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the paid amount')),
      );
      return;
    }

    await LibraryRentalService.instance.rent(
      materialId: selectedBook.id,
      bookTitle: selectedBook.bookName,
      studentId: selectedStudent!.studentId,
      studentName: selectedStudent!.fullName,
      isPaid: isPaid,
      price: price,
    );

    // Paid rent unlocks the digital material for that student.
    if (isPaid || !selectedBook.isFree) {
      await MaterialAccessService.instance.grant(
        materialId: selectedBook.id,
        studentId: selectedStudent!.studentId,
        grantedBy: AuthService.currentUser?.username ?? 'librarian',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPaid
              ? 'Rented (paid) to ${selectedStudent!.fullName}'
              : 'Rented (free) to ${selectedStudent!.fullName}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addCopies({LearningMaterialItem? preset}) async {
    if (!_canManage) return;
    final books = _data
        .learningMaterialsSnapshot()
        .where(
          (m) =>
              m.className.toLowerCase() ==
              WebLibraryPage.libraryClass.toLowerCase(),
        )
        .toList();
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an e-Book first')),
      );
      return;
    }
    var selectedBook = preset ?? books.first;
    final countCtrl = TextEditingController(text: '1');
    final saved = await showAdminFormDialog(
      context: context,
      title: 'Add copies',
      accent: WebErpTheme.primary,
      icon: Icons.library_add_outlined,
      saveLabel: 'Add copies',
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: selectedBook.id,
              decoration: adminFieldDecoration(
                label: 'Title',
                icon: Icons.auto_stories_outlined,
                accent: WebErpTheme.primary,
              ),
              items: books
                  .map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.bookName)),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setDialogState(
                  () => selectedBook = books.firstWhere((b) => b.id == id),
                );
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: adminFieldDecoration(
                label: 'Number of copies',
                icon: Icons.pin_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
    final count = int.tryParse(countCtrl.text.trim()) ?? 0;
    countCtrl.dispose();
    if (saved != true || count <= 0) return;
    await LibraryRentalService.instance.addCopies(
      materialId: selectedBook.id,
      bookTitle: selectedBook.bookName,
      count: count,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $count cop${count == 1 ? 'y' : 'ies'}.')),
    );
  }

  Future<void> _checkoutCopy({LibraryCopy? preset}) async {
    if (!_canManage) return;
    final available = LibraryRentalService.instance.copies
        .where((c) => c.isAvailable)
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available copies. Add copies first.')),
      );
      return;
    }
    var selected = preset ?? available.first;
    if (!selected.isAvailable) {
      selected = available.first;
    }
    final studentQuery = TextEditingController();
    AdminStudentRecord? selectedStudent;
    var studentHits = <AdminStudentRecord>[];
    var due = DateTime.now().add(
      const Duration(days: LibraryRentalService.defaultLoanDays),
    );
    final saved = await showAdminFormDialog(
      context: context,
      title: 'Checkout copy',
      accent: WebErpTheme.primary,
      icon: Icons.outbox_outlined,
      saveLabel: 'Checkout',
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: selected.id,
              decoration: adminFieldDecoration(
                label: 'Available copy',
                icon: Icons.qr_code_2_outlined,
                accent: WebErpTheme.primary,
              ),
              items: available
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.copyCode} · ${c.bookTitle}'),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setDialogState(
                  () => selected = available.firstWhere((c) => c.id == id),
                );
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: studentQuery,
              decoration: adminFieldDecoration(
                label: 'Find student (name or ID)',
                icon: Icons.person_search_outlined,
                accent: WebErpTheme.primary,
              ),
              onChanged: (v) {
                final q = v.trim().toLowerCase();
                final schoolId = AuthService.activeSchoolId;
                final all = schoolId == null
                    ? StudentRegistryService.instance.getAllStudents()
                    : StudentRegistryService.instance.studentsForSchool(schoolId);
                setDialogState(() {
                  studentHits = q.isEmpty
                      ? <AdminStudentRecord>[]
                      : all
                          .where(
                            (s) =>
                                s.isActive &&
                                (s.fullName.toLowerCase().contains(q) ||
                                    s.studentId.toLowerCase().contains(q)),
                          )
                          .take(8)
                          .toList();
                });
              },
            ),
          ),
          if (selectedStudent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Selected: ${selectedStudent!.fullName} (${selectedStudent!.studentId})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          for (final hit in studentHits)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(hit.fullName),
              subtitle: Text('${hit.studentId} · ${hit.className}'),
              onTap: () => setDialogState(() {
                selectedStudent = hit;
                studentQuery.text = hit.fullName;
                studentHits = [];
              }),
            ),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 180)),
                initialDate: due,
              );
              if (picked != null) setDialogState(() => due = picked);
            },
            child: Text('Due ${due.day}/${due.month}/${due.year}'),
          ),
        ],
      ),
    );
    studentQuery.dispose();
    if (saved != true) return;
    if (selectedStudent == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a student')),
      );
      return;
    }
    try {
      await LibraryRentalService.instance.checkout(
        copyId: selected.id,
        studentId: selectedStudent!.studentId,
        studentName: selectedStudent!.fullName,
        dueDate: due,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Checked out ${selected.copyCode} to ${selectedStudent!.fullName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _exportOverdue() async {
    final csv = LibraryRentalService.instance.overdueCsv();
    await YearStartSheetService.instance.shareCsv(
      csv: csv,
      fileName: 'library_overdue.csv',
      subject: 'Library overdue copies',
    );
  }

  Widget _circulationTab(BuildContext context) {
    final copies = LibraryRentalService.instance.copies;
    final overdue = LibraryRentalService.instance.overdue();
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _canManage ? () => _addCopies() : null,
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Add copies'),
            ),
            OutlinedButton.icon(
              onPressed: _canManage ? () => _checkoutCopy() : null,
              icon: const Icon(Icons.outbox_outlined),
              label: const Text('Checkout copy'),
            ),
            OutlinedButton.icon(
              onPressed: overdue.isEmpty ? null : _exportOverdue,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export overdue CSV'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Overdue',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (overdue.isEmpty)
          const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('No overdue copies.'),
          )
        else
          for (final loan in overdue)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(
                '${loan.copyCode ?? ''} · ${loan.bookTitle}'.trim(),
              ),
              subtitle: Text(
                '${loan.studentName} · ${loan.studentId} · '
                '${loan.daysOverdue()} day(s) overdue',
              ),
              trailing: _canManage
                  ? TextButton(
                      onPressed: () =>
                          LibraryRentalService.instance.markReturned(loan.id),
                      child: const Text('Return'),
                    )
                  : null,
            ),
        const SizedBox(height: 8),
        Text(
          'Copies',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (copies.isEmpty)
          const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('No physical copies yet. Use Add copies.'),
          )
        else
          for (final copy in copies)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                copy.isAvailable
                    ? Icons.menu_book_outlined
                    : Icons.outbox_outlined,
              ),
              title: Text('${copy.copyCode} · ${copy.bookTitle}'),
              subtitle: Text(
                copy.status == LibraryCopyStatus.checkedOut
                    ? 'Checked out'
                    : copy.status.name,
              ),
              trailing: copy.isAvailable && _canManage
                  ? TextButton(
                      onPressed: () => _checkoutCopy(preset: copy),
                      child: const Text('Checkout'),
                    )
                  : null,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    final narrow = WebViewport.isNarrow(context);
    final rentals = LibraryRentalService.instance.all;

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 12, narrow ? 12 : 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow) ...[
            Text('Library', style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search e-Books…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _canManage ? () => _addBook() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add e-Book'),
                ),
                OutlinedButton.icon(
                  onPressed: _canManage ? () => _rentBook() : null,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Rent a Book'),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Text('Library', style: WebErpTheme.sectionTitle(context)),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search e-Books…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _canManage ? () => _rentBook() : null,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Rent a Book'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _canManage ? () => _addBook() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add e-Book'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Publish e-Books, rent digital copies, and circulate physical copies. '
            'Overdue stays on this desk — not a second inventory ledger.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'e-Book and Material'),
              Tab(text: 'Loans'),
              Tab(text: 'Circulation'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                books.isEmpty
                    ? Center(
                        child: Text(
                          'No e-Books yet. Click Add e-Book to publish.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: narrow ? 200 : 260,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: narrow ? 0.78 : 0.82,
                        ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return Container(
                            decoration: WebErpTheme.cardDecoration(context),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.auto_stories,
                                      color: WebErpTheme.primary,
                                      size: 28,
                                    ),
                                    const Spacer(),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        book.isFree
                                            ? 'Free'
                                            : 'Paid${book.price == null ? '' : ' · ${book.price!.toStringAsFixed(0)} ETB'}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: book.isFree
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  book.bookName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  book.materialName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${LibraryRentalService.instance.copyCounts(book.id).available} of '
                                  '${LibraryRentalService.instance.copyCounts(book.id).total} copies in',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: _canManage
                                          ? () => _addBook(existing: book)
                                          : null,
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: _canManage
                                          ? () => _rentBook(preset: book)
                                          : null,
                                      child: const Text('Rent'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                rentals.isEmpty
                    ? Center(
                        child: Text(
                          'No rentals yet. Use Rent a Book.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: rentals.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = rentals[index];
                          return ListTile(
                            leading: Icon(
                              r.isPaid
                                  ? Icons.payments_outlined
                                  : Icons.lock_open,
                              color: r.isActive
                                  ? WebErpTheme.primary
                                  : Colors.grey,
                            ),
                            title: Text(
                              [
                                r.bookTitle,
                                if ((r.copyCode ?? '').isNotEmpty) r.copyCode!,
                              ].join(' · '),
                            ),
                            subtitle: Text(
                              '${r.studentName} · ${r.studentId}\n'
                              '${r.isPaid ? 'Paid${r.price == null ? '' : ' · ${r.price!.toStringAsFixed(0)} ETB'}' : 'Free'}'
                              '${r.dueDate == null ? '' : ' · Due ${r.dueDate!.day}/${r.dueDate!.month}/${r.dueDate!.year}'}'
                              '${r.isOverdue() ? ' · Overdue' : ''}'
                              '${r.isActive ? '' : ' · Returned'}',
                            ),
                            isThreeLine: true,
                            trailing: r.isActive
                                ? TextButton(
                                    onPressed: () async {
                                      await LibraryRentalService.instance
                                          .markReturned(r.id);
                                    },
                                    child: const Text('Return'),
                                  )
                                : const Text('Closed'),
                          );
                        },
                      ),
                _circulationTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
