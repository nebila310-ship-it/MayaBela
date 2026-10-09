import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/gallery_compose.dart';
import 'package:mayabela/services/gallery_media_service.dart';
import 'package:mayabela/services/gallery_share_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
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
  bool _openingMedia = false;

  bool get _isSchoolWide => widget.mode == GalleryViewMode.school;

  bool get _isFamilyViewer {
    final role = AuthService.currentUser?.roleKey;
    return widget.mode == GalleryViewMode.parent ||
        role == AuthService.roleParent ||
        role == AuthService.roleStudent;
  }

  List<String> get _classOptions {
    if (_isFamilyViewer) {
      return _data.galleryClassOptionsForViewer();
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
    if (_isFamilyViewer) {
      final className = _selectedClass;
      if (className != null && className != _allClasses) {
        final forClass = _data.getGalleryForClass(className);
        if (forClass.isNotEmpty) return forClass;
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
    if (_isFamilyViewer) return false;
    if (_isSchoolWide) return ModuleAccess.canManage('gallery');
    final className = _selectedClass;
    return className != null && _access.canPostGallery(className);
  }

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_refresh);
    unawaited(GalleryMediaService.instance.promotePendingToCloud());
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass;
    } else if (_isSchoolWide || _isFamilyViewer) {
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

  Future<String?> _cloudPathOrNull(String? path, String? fileName) async {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;
    if (!ProfilePhotoCodec.isDeviceLocalPath(value)) return value;
    final cached = WebAttachmentCache.instance.read(value);
    if (cached == null || cached.isEmpty) return null;
    final retry = await GalleryMediaService.instance.persistBytes(
      fileName: (fileName ?? attachmentFileName(value)).trim().isEmpty
          ? 'gallery.jpg'
          : fileName ?? attachmentFileName(value),
      bytes: cached,
    );
    if (retry == null) return null;
    if (ProfilePhotoCodec.isDeviceLocalPath(retry.filePath)) return null;
    return retry.filePath;
  }

  Future<void> _addPost() async {
    final s = AppLocale.instance.strings;
    var className = _selectedClass == _allClasses ? null : _selectedClass;
    className ??= _classOptions.firstOrNull;
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
      canSave: (_) =>
          (className ?? '').trim().isNotEmpty &&
          GalleryCompose.hasPublishableContent(
            title: titleController.text,
            mediaPath: mediaPath,
            attachments: attachments,
          ),
      saveBlockedReason: (_) {
        if ((className ?? '').trim().isEmpty) return s.selectClass;
        if (!GalleryCompose.hasPublishableContent(
          title: titleController.text,
          mediaPath: mediaPath,
          attachments: attachments,
        )) {
          return s.galleryNeedContent;
        }
        return null;
      },
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
                  onChanged: (_) => setDialogState(() {}),
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
                          GalleryMediaPick? pick;
                          var failed = false;
                          try {
                            pick = type == GalleryPostType.photo
                                ? await GalleryMediaService.instance.pickPhoto()
                                : await GalleryMediaService.instance
                                    .pickVideo();
                          } catch (_) {
                            failed = true;
                            pick = null;
                          }
                          if (!context.mounted) return;
                          setDialogState(() {
                            pickingMedia = false;
                            if (pick != null) {
                              mediaPath = pick.filePath;
                              mediaLabel = pick.displayName;
                            }
                          });
                          if (failed ||
                              (pick == null &&
                                  GalleryMediaService
                                          .instance.lastRejectedMaxMb !=
                                      null)) {
                            final maxMb = GalleryMediaService
                                .instance.lastRejectedMaxMb;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  maxMb != null
                                      ? s.galleryFileTooLarge(maxMb)
                                      : s.galleryMediaPickFailed,
                                ),
                              ),
                            );
                          }
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
              const SizedBox(height: 8),
              Text(
                s.gallerySizeHint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );

    if (saved != true) {
      titleController.dispose();
      captionController.dispose();
      return;
    }

    final composed = GalleryCompose.resolve(
      title: titleController.text,
      caption: captionController.text,
      type: type,
      mediaPath: mediaPath,
      mediaLabel: mediaLabel,
      attachments: attachments,
    );
    final postedClass = className?.trim();
    titleController.dispose();
    captionController.dispose();

    if (postedClass == null ||
        postedClass.isEmpty ||
        !GalleryCompose.hasPublishableContent(
          title: composed.title,
          mediaPath: composed.mediaPath,
          attachments: attachments,
        )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              postedClass == null || postedClass.isEmpty
                  ? s.selectClass
                  : s.galleryNeedContent,
            ),
          ),
        );
      }
      return;
    }

    final cloudMediaPath = await _cloudPathOrNull(
      composed.mediaPath,
      composed.mediaLabel,
    );
    if (composed.mediaPath != null &&
        composed.mediaPath!.trim().isNotEmpty &&
        cloudMediaPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.galleryCloudRequired),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }
    final cloudAttachments = <String>[];
    for (final path in attachments) {
      final cloud = await _cloudPathOrNull(path, attachmentFileName(path));
      if (cloud == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.galleryCloudRequired),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }
      cloudAttachments.add(cloud);
    }

    _data.addGalleryPost(
      className: postedClass,
      type: composed.type,
      title: composed.title,
      caption: composed.caption,
      authorName: _authorName,
      mediaLabel: composed.mediaLabel,
      mediaPath: cloudMediaPath,
      attachmentPaths: cloudAttachments,
    );
    if (_isSchoolWide && _selectedClass != _allClasses) {
      _selectedClass = postedClass;
    }
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

  String? _pathToOpen(GalleryPost post) {
    final media = post.mediaPath?.trim();
    if (media != null && media.isNotEmpty) return media;
    for (final path in post.attachmentPaths) {
      final trimmed = path.trim();
      if (trimmed.isNotEmpty && attachmentPathIsImage(trimmed)) return trimmed;
    }
    for (final path in post.attachmentPaths) {
      final trimmed = path.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Widget _brokenPhoto() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 64,
        ),
        const SizedBox(height: 12),
        Text(
          AppLocale.instance.strings.galleryPhotoOpenFailed,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Future<void> _openMedia(GalleryPost post) async {
    if (_openingMedia) return;
    final path = _pathToOpen(post);
    if (path == null) return;
    if (post.type == GalleryPostType.photo || attachmentPathIsImage(path)) {
      _openingMedia = true;
      try {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AttachmentImagePreviewScreen(
              path: path,
              allowShareDownload: _isFamilyViewer,
              image: _GalleryBytesImage(
                path: path,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _brokenPhoto(),
              ),
            ),
          ),
        );
      } finally {
        _openingMedia = false;
      }
      return;
    }
    _openingMedia = true;
    try {
      await openAttachmentWithFeedback(context, path: path);
    } finally {
      _openingMedia = false;
    }
  }

  Widget _mediaPreview(GalleryPost post, Color color, AppStrings s) {
    Widget child;
    final path = _pathToOpen(post);
    if (path != null &&
        (post.type == GalleryPostType.photo || attachmentPathIsImage(path))) {
      child = _GalleryBytesImage(
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
    final showFilter = (_isFamilyViewer && _classOptions.length > 1) ||
        (widget.mode == GalleryViewMode.teacher && _classOptions.length > 1) ||
        _isSchoolWide;
    if (!showFilter) return const SizedBox.shrink();

    final items = <DropdownMenuItem<String>>[
      if (_isSchoolWide || _isFamilyViewer)
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
    if (items.isEmpty) return const SizedBox.shrink();
    final selected = items.any((item) => item.value == _selectedClass)
        ? _selectedClass
        : items.first.value;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 0 : 16,
        widget.embedded ? 0 : 16,
        widget.embedded ? 0 : 16,
        12,
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selected),
        initialValue: selected,
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
          child: InkWell(
            onTap: _pathToOpen(post) == null ? null : () => _openMedia(post),
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
                          allowShareDownload: _isFamilyViewer,
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
                      if (_isFamilyViewer) ...[
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
              _isFamilyViewer
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

/// Copies attachment bytes so Flutter web can open the same gallery photo
/// more than once. [Image.memory] can transfer the cached buffer on the
/// first decode, which left later taps with nothing to display.
class _GalleryBytesImage extends StatefulWidget {
  const _GalleryBytesImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<_GalleryBytesImage> createState() => _GalleryBytesImageState();
}

class _GalleryBytesImageState extends State<_GalleryBytesImage> {
  Uint8List? _bytes;
  bool _failed = false;
  bool _retried = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(_GalleryBytesImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = null;
      _failed = false;
      _retried = false;
      unawaited(_load());
    }
  }

  Future<void> _load({bool bypassCache = false}) async {
    final gen = ++_generation;
    final path = widget.path.trim();
    if (path.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (path.startsWith('asset:')) return;
    if ((path.startsWith('http://') || path.startsWith('https://')) &&
        !ProfilePhotoCodec.isPrivateSchoolFilesUrl(path) &&
        !bypassCache) {
      return;
    }
    try {
      if (bypassCache) {
        WebAttachmentCache.instance.remove(path);
      }
      var bytes = await ProfilePhotoCodec.bytesFromStoredPath(path);
      if ((bytes == null || bytes.isEmpty) && !bypassCache) {
        WebAttachmentCache.instance.remove(path);
        bytes = await ProfilePhotoCodec.bytesFromStoredPath(path);
      }
      if (!mounted || gen != _generation) return;
      final loaded = bytes;
      if (loaded == null || loaded.isEmpty) {
        setState(() => _failed = true);
        return;
      }
      setState(() {
        _bytes = Uint8List.fromList(loaded);
        _failed = false;
      });
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _failed = true);
      }
    }
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) {
    return widget.errorBuilder?.call(context, error, stack) ??
        Icon(
          Icons.broken_image_outlined,
          size: widget.width ?? widget.height ?? 40,
        );
  }

  Widget _loadingBox() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const ColoredBox(color: Color(0x33000000)),
    );
  }

  Widget _memoryImage(Uint8List bytes) {
    return Image.memory(
      Uint8List.fromList(bytes),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) {
        if (!_retried) {
          _retried = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_load(bypassCache: true));
          });
        }
        return _error(context, error, stack);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.path.trim();
    if (value.isEmpty) {
      return _error(context, Exception('empty path'), StackTrace.current);
    }
    if (_failed) {
      return _error(context, Exception('gallery photo'), StackTrace.current);
    }

    final cached = _bytes ?? WebAttachmentCache.instance.read(value);
    if (cached != null && cached.isNotEmpty) {
      return _memoryImage(cached);
    }

    if (ProfilePhotoCodec.isPrivateSchoolFilesUrl(value)) {
      return _loadingBox();
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (value.startsWith('asset:')) {
      return Image.asset(
        value.substring('asset:'.length),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (kIsWeb || WebAttachmentCache.instance.isWebPath(value)) {
      return _error(context, Exception('missing web cache'), StackTrace.current);
    }

    return _loadingBox();
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
