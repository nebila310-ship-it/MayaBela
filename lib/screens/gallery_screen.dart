import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/gallery_media_service.dart';
import 'package:mayabela/services/gallery_share_service.dart';
import 'package:mayabela/services/school_data_service.dart';import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

enum GalleryViewMode { teacher, parent }

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    this.mode = GalleryViewMode.teacher,
    this.initialClass,
  });

  final GalleryViewMode mode;
  final String? initialClass;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  final _share = GalleryShareService.instance;
  String? _selectedClass;

  List<String> get _classOptions {
    if (widget.mode == GalleryViewMode.parent) {
      return _data
          .getChildren()
          .map((child) => child.className)
          .toSet()
          .toList();
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
    final className = _selectedClass ?? _classOptions.firstOrNull;
    if (className == null) return [];
    return _data.getGalleryForClass(className);
  }

  @override
  void initState() {
    super.initState();
    if (_classOptions.isNotEmpty) {
      _selectedClass = widget.initialClass ?? _classOptions.first;
    }
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
    final className = _selectedClass;
    if (className == null) return;

    final titleController = TextEditingController();
    final captionController = TextEditingController();
    var type = GalleryPostType.photo;
    String? mediaLabel;
    String? mediaPath;
    var pickingMedia = false;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.addToGallery,
      subtitle: className,
      accent: Colors.deepPurple,
      icon: Icons.collections_outlined,
      saveLabel: s.upload,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            ],
          ),
        ],
      ),
    );

    if (saved != true ||
        titleController.text.trim().isEmpty ||
        captionController.text.trim().isEmpty ||
        (type != GalleryPostType.note && mediaPath == null)) {
      titleController.dispose();
      captionController.dispose();
      return;
    }

    _data.addGalleryPost(
      className: className,
      type: type,
      title: titleController.text.trim(),
      caption: captionController.text.trim(),
      authorName: _access.teacherName,
      mediaLabel: mediaLabel,
      mediaPath: mediaPath,
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
          onPressed: () => OpenFile.open(result.file!.path),
        ),
      ),
    );
  }

  Widget _mediaPreview(GalleryPost post, Color color, AppStrings s) {
    final path = post.mediaPath;
    if (path != null && post.type == GalleryPostType.photo) {
      if (path.startsWith('asset:')) {
        return Image.asset(
          path.substring('asset:'.length),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => _mediaPlaceholder(post, color),
        );
      }
      if (File(path).existsSync()) {
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
    }
    if (path != null &&
        post.type == GalleryPostType.video &&
        !path.startsWith('asset:') &&
        File(path).existsSync()) {
      return Stack(
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
    }
    return _mediaPlaceholder(post, color);
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final canPost = widget.mode == GalleryViewMode.teacher &&
            _selectedClass != null &&
            _access.canPostGallery(_selectedClass!);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.purple,
            title: Text(
              widget.mode == GalleryViewMode.parent
                  ? s.classGallery
                  : s.dashboardTitle('gallery'),
            ),
          ),
          floatingActionButton: canPost
              ? FloatingActionButton.extended(
                  onPressed: _addPost,
                  backgroundColor: Colors.purple,
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(s.addPost),
                )
              : null,
          body: Column(
            children: [
              if (widget.mode == GalleryViewMode.teacher &&
                  _classOptions.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selectedClass),
                    initialValue: _selectedClass,
                    decoration: InputDecoration(
                      labelText: s.className,
                      border: const OutlineInputBorder(),
                    ),
                    items: _classOptions
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedClass = value),
                  ),
                ),
              Expanded(
                child: _posts.isEmpty
                    ? Center(child: Text(s.noGalleryPosts))
                    : ListView.separated(
                        padding: listPagePadding(context),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(post.className),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Chip(
                                            label: Text(
                                              _typeLabel(post.type, s),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
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
                                      const SizedBox(height: 10),
                                      Text(
                                        '${post.authorName} · ${post.postedAt.day}/${post.postedAt.month}/${post.postedAt.year}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (widget.mode ==
                                          GalleryViewMode.parent) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _sharePost(post),
                                                icon: const Icon(Icons.share),
                                                label: Text(s.share),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _downloadPost(post),
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
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
