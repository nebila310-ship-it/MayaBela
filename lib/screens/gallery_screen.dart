import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/gallery_media_service.dart';
import 'package:mayabela/services/gallery_share_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

enum GalleryViewMode { teacher, parent, school }

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    this.mode = GalleryViewMode.teacher,
    this.initialClass,
    this.embedded = false,
  });

  final GalleryViewMode mode;
  final String? initialClass;
  final bool embedded;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const _allClasses = '__all__';

  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  final _share = GalleryShareService.instance;
  String? _selectedClass;

  bool get _isSchoolWide => widget.mode == GalleryViewMode.school;

  List<String> get _classOptions {
    if (widget.mode == GalleryViewMode.parent) {
      return _data
          .getChildren()
          .map((child) => child.className)
          .toSet()
          .toList();
    }
    if (_isSchoolWide) {
      final schoolId = AuthService.activeSchoolId ?? '';
      final names = <String>{
        ..._data.getAllClassNames(),
        ..._data.gallerySnapshot().map((post) => post.className),
        ...SchoolRegistryService.instance.sectionsForSchool(schoolId),
      };
      return names.where((name) => name.trim().isNotEmpty).toList()..sort();
    }
    return _access.myClasses.map((assignment) => assignment.className).toList();
  }

  List<GalleryPost> get _posts {
    if (widget.mode == GalleryViewMode.parent) {
      final className = _selectedClass;
      if (className != null) {
        return _data.getGalleryForClass(className);
      }
      return _data.getGalleryForParent();
    }
    if (_isSchoolWide &&
        (_selectedClass == null || _selectedClass == _allClasses)) {
      return _data.gallerySnapshot().toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    }
    final className = _selectedClass ?? _classOptions.firstOrNull;
    if (className == null || className == _allClasses) return [];
    return _data.getGalleryForClass(className);
  }

  String get _authorName {
    if (_isSchoolWide) {
      return AuthService.displayNameForRole(
        AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
      );
    }
    return _access.teacherName;
  }

  bool get _canPost {
    if (widget.mode == GalleryViewMode.parent) return false;
    if (_isSchoolWide) return ModuleAccess.canManage('gallery');
    final className = _selectedClass;
    return className != null && _access.canPostGallery(className);
  }

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_refresh);
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass;
    } else if (_isSchoolWide) {
      _selectedClass = _allClasses;
    } else if (_classOptions.isNotEmpty) {
      _selectedClass = _classOptions.first;
    }
  }

  @override
  void dispose() {
    SchoolContentSyncService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  IconData _iconForType(GalleryPostType type) {
    switch (type) {
      case GalleryPostType.photo:
        return Icons.photo;
      case GalleryPostType.video:
        return Icons.videocam;
      case GalleryPostType.note:
        return Icons.note_alt;
    }
  }

  Color _colorForType(GalleryPostType type) {
    switch (type) {
      case GalleryPostType.photo:
        return Colors.purple;
      case GalleryPostType.video:
        return Colors.red;
      case GalleryPostType.note:
        return Colors.orange;
    }
  }

  String _typeLabel(GalleryPostType type, AppStrings s) {
    switch (type) {
      case GalleryPostType.photo:
        return s.photo;
      case GalleryPostType.video:
        return s.video;
      case GalleryPostType.note:
        return s.note;
    }
  }

  Future<void> _addPost() async {
    final s = AppLocale.instance.strings;
    var className = _selectedClass == _allClasses ? null : _selectedClass;
    if (!_isSchoolWide && className == null) return;

    final titleController = TextEditingController();
    final captionController = TextEditingController();
    var type = GalleryPostType.photo;
    String? mediaLabel;
    String? mediaPath;
    var attachments = <String>[];
    var pickingMedia = false;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.addToGallery,
      subtitle: className ?? s.dashboardTitle('gallery'),
      accent: Colors.deepPurple,
      icon: Icons.collections_outlined,
      saveLabel: s.upload,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSchoolWide)
            AdminFormDialogSection(
              title: s.className,
              icon: Icons.class_outlined,
              color: Colors.deepPurple,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: className,
                  decoration: adminFieldDecoration(
                    label: s.className,
                    icon: Icons.class_outlined,
                    accent: Colors.deepPurple,
                  ),
                  items: _classOptions
                      .map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => className = value),
                ),
              ],
            ),
          AdminFormDialogSection(
            title: s.typeLabel,
            icon: Icons.perm_media_outlined,
            color: Colors.deepPurple,
            children: [
              SegmentedButton<GalleryPostType>(
                segments: [
                  ButtonSegment(
                    value: GalleryPostType.photo,
                    label: Text(s.photo),
                    icon: const Icon(Icons.photo),
                  ),
                  ButtonSegment(
                    value: GalleryPostType.video,
                    label: Text(s.video),
                    icon: const Icon(Icons.videocam),
                  ),
                  ButtonSegment(
                    value: GalleryPostType.note,
                    label: Text(s.note),
                    icon: const Icon(Icons.note),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (selection) {
                  setDialogState(() => type = selection.first);
                },
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.titleLabel,
            icon: Icons.edit_outlined,
            color: Colors.deepPurple.shade300,
            children: [
              adminDialogField(
                TextField(
                  controller: titleController,
                  decoration: adminFieldDecoration(
                    label: s.titleLabel,
                    icon: Icons.title_outlined,
                    accent: Colors.deepPurple,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: captionController,
                  maxLines: 3,
                  decoration: adminFieldDecoration(
                    label: s.captionNotes,
                    icon: Icons.notes_outlined,
                    accent: Colors.deepPurple,
                  ),
                ),
              ),
              if (type != GalleryPostType.note)
                OutlinedButton.icon(
                  onPressed: pickingMedia
                      ? null
                      : () async {
                          setDialogState(() => pickingMedia = true);
                          final pick = type == GalleryPostType.photo
                              ? await GalleryMediaService.instance.pickPhoto()
                              : await GalleryMediaService.instance.pickVideo();
                          setDialogState(() {
                            pickingMedia = false;
                            if (pick != null) {
                              mediaPath = pick.filePath;
                              mediaLabel = pick.displayName;
                            }
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: pickingMedia
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(mediaLabel ?? s.chooseMedia(_typeLabel(type, s))),
                ),
              const SizedBox(height: 12),
              CourseAttachmentPicker(
                paths: attachments,
                subdir: 'gallery_attachments',
                canEdit: true,
                allowShareDownload: false,
                onChanged: (paths) =>
                    setDialogState(() => attachments = List<String>.from(paths)),
              ),
            ],
          ),
        ],
      ),
    );

    if (saved != true ||
        (className == null || className!.trim().isEmpty) ||
        titleController.text.trim().isEmpty ||
        captionController.text.trim().isEmpty ||
        (type != GalleryPostType.note && mediaPath == null)) {
      titleController.dispose();
      captionController.dispose();
      return;
    }

    _data.addGalleryPost(
      className: className!,
      type: type,
      title: titleController.text.trim(),
      caption: captionController.text.trim(),
      authorName: _authorName,
      mediaLabel: mediaLabel,
      mediaPath: mediaPath,
      attachmentPaths: attachments,
    );
    titleController.dispose();
    captionController.dispose();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.galleryPosted),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _sharePost(GalleryPost post) async {
    final s = AppLocale.instance.strings;
    final result = await _share.sharePost(post);
    if (!mounted) return;
    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message!)),
      );
    } else if (!_share.hasShareableMedia(post)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.savedNote(post.title))),
      );
    }
  }

  Future<void> _downloadPost(GalleryPost post) async {
    final s = AppLocale.instance.strings;
    if (!mounted) return;

    if (post.type == GalleryPostType.note || !_share.hasShareableMedia(post)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.savedNote(post.title))),
      );
      return;
    }

    final result = await _share.downloadPost(post);
    if (!mounted) return;

    if (!result.success || result.file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? s.galleryDownloadFailed),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.downloadedDemo(result.file!.path.split('/').last)),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: s.open,
          textColor: Colors.white,
          onPressed: () =>
              openAttachmentWithFeedback(context, path: result.file!.path),
        ),
      ),
    );
  }

  Future<void> _openMedia(GalleryPost post) async {
    final path = post.mediaPath;
    if (path == null || path.isEmpty) return;
    if (post.type == GalleryPostType.photo || attachmentPathIsImage(path)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentImagePreviewScreen(
            path: path,
            allowShareDownload: widget.mode == GalleryViewMode.parent,
            image: PlatformPathImage(
              path: path,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      );
      return;
    }
    await openAttachmentWithFeedback(context, path: path);
  }

  Widget _mediaPreview(GalleryPost post, Color color, AppStrings s) {
    Widget child;
    final path = post.mediaPath;
    if (path != null &&
        (post.type == GalleryPostType.photo || attachmentPathIsImage(path))) {
      child = PlatformPathImage(
        path: path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => _mediaPlaceholder(post, color),
      );
    } else if (path != null &&
        post.type == GalleryPostType.video &&
        !kIsWeb &&
        !path.startsWith('asset:') &&
        !path.startsWith('http') &&
        File(path).existsSync()) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Container(color: color.withValues(alpha: 0.18)),
          Center(
            child: Icon(Icons.play_circle_fill, size: 56, color: color),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                post.mediaLabel ?? s.video,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    } else if (path != null &&
        (path.startsWith('http://') || path.startsWith('https://')) &&
        post.type == GalleryPostType.video) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Container(color: color.withValues(alpha: 0.18)),
          Center(
            child: Icon(Icons.play_circle_fill, size: 56, color: color),
          ),
        ],
      );
    } else {
      child = _mediaPlaceholder(post, color);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: path == null ? null : () => _openMedia(post),
        child: child,
      ),
    );
  }

  Widget _mediaPlaceholder(GalleryPost post, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_iconForType(post.type), size: 40, color: color),
        if (post.mediaLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              post.mediaLabel!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _classFilter(AppStrings s) {
    final showFilter = (widget.mode == GalleryViewMode.teacher &&
            _classOptions.length > 1) ||
        _isSchoolWide;
    if (!showFilter) return const SizedBox.shrink();

    final items = <DropdownMenuItem<String>>[
      if (_isSchoolWide)
        DropdownMenuItem(
          value: _allClasses,
          child: Text(s.allClasses),
        ),
      ..._classOptions.map(
        (name) => DropdownMenuItem(
          value: name,
          child: Text(name),
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 0 : 16,
        widget.embedded ? 0 : 16,
        widget.embedded ? 0 : 16,
        12,
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedClass),
        initialValue: _selectedClass,
        decoration: InputDecoration(
          labelText: s.className,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: (value) => setState(() => _selectedClass = value),
      ),
    );
  }

  Widget _postList(AppStrings s) {
    if (_posts.isEmpty) {
      return Center(child: Text(s.noGalleryPosts));
    }
    return ListView.separated(
      padding: widget.embedded
          ? const EdgeInsets.only(bottom: 24)
          : listPagePadding(context),
      itemCount: _posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = _posts[index];
        final color = _colorForType(post.type);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 120,
                color: color.withValues(alpha: 0.12),
                child: _mediaPreview(post, color, s),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(post.className),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(_typeLabel(post.type, s)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(post.caption),
                    if (post.attachmentPaths.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      HomeworkAttachmentsPanel(
                        attachmentPaths: post.attachmentPaths,
                        compact: true,
                        allowShareDownload:
                            widget.mode == GalleryViewMode.parent,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '${post.authorName} · ${post.postedAt.day}/${post.postedAt.month}/${post.postedAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (widget.mode == GalleryViewMode.parent) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _sharePost(post),
                              icon: const Icon(Icons.share),
                              label: Text(s.share),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _downloadPost(post),
                              icon: const Icon(Icons.download),
                              label: Text(s.download),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _embeddedHeader(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            s.dashboardTitle('gallery'),
            style: WebErpTheme.sectionTitle(context),
          ),
          const Spacer(),
          if (_canPost)
            FilledButton.icon(
              onPressed: _addPost,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(s.addPost),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded) ...[
              _embeddedHeader(s),
              Text(
                s.schoolGalleryHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
            ],
            _classFilter(s),
            Expanded(child: _postList(s)),
          ],
        );

        if (widget.embedded) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: body,
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.purple,
            title: Text(
              widget.mode == GalleryViewMode.parent
                  ? s.classGallery
                  : s.dashboardTitle('gallery'),
            ),
          ),
          floatingActionButton: _canPost
              ? FloatingActionButton.extended(
                  onPressed: _addPost,
                  backgroundColor: Colors.purple,
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(s.addPost),
                )
              : null,
          body: body,
        );
      },
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
