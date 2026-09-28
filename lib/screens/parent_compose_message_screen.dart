import 'package:flutter/material.dart';



import 'package:mayabela/l10n/app_strings.dart';

import 'package:mayabela/models/message.dart';

import 'package:mayabela/models/announcement.dart';

import 'package:mayabela/models/school_class.dart';

import 'package:mayabela/services/messaging_access_service.dart';

import 'package:mayabela/services/parent_messaging_policy.dart';

import 'package:mayabela/services/school_data_service.dart';

import 'package:mayabela/utils/scroll_safe_area.dart';

import 'package:mayabela/widgets/admin_form_ui.dart';

import 'package:mayabela/widgets/parent_child_picker.dart';

import 'package:mayabela/services/announcement_attachment_service.dart';

import 'package:mayabela/widgets/message_voice_input_bar.dart';

import 'package:mayabela/widgets/messages_ui.dart';



enum _ParentRecipientKind { homeroom, admin }



class ParentComposeMessageScreen extends StatefulWidget {

  const ParentComposeMessageScreen({super.key, this.child});



  final ChildProfile? child;



  @override

  State<ParentComposeMessageScreen> createState() =>

      _ParentComposeMessageScreenState();

}



class _ParentComposeMessageScreenState extends State<ParentComposeMessageScreen> {

  final _data = SchoolDataService.instance;

  final _subjectController = TextEditingController();

  final _bodyController = TextEditingController();



  _ParentRecipientKind _kind = _ParentRecipientKind.homeroom;

  ChildProfile? _selectedChild;

  final List<AnnouncementAttachment> _attachments = [];

  bool _pickingAttachment = false;



  @override

  void initState() {

    super.initState();

    _selectedChild = widget.child ?? _data.getChildren().firstOrNull;

  }



  @override

  void dispose() {

    _subjectController.dispose();

    _bodyController.dispose();

    super.dispose();

  }



  List<ChildProfile> get _children => _data.getChildren();



  StaffMemberOption? get _homeroomContact {

    final studentId = _selectedChild?.studentId;

    if (studentId != null) {

      final fromRegistry =

          ParentMessagingPolicy.homeroomStaffForStudent(studentId);

      if (fromRegistry != null) return fromRegistry;

    }

    return MessagingAccessService.homeroomStaffForParentClass(

      _selectedChild?.className ?? '',

      homeroomTeacherName: _selectedChild?.teacher,

    );

  }



  List<StaffMemberOption> get _adminContacts =>

      MessagingAccessService.adminContactsForParent();



  StaffMemberOption? get _resolvedRecipient {

    return switch (_kind) {

      _ParentRecipientKind.homeroom => _homeroomContact,

      _ParentRecipientKind.admin => _adminContacts.firstOrNull,

    };

  }



  Future<void> _pickAttachments() async {

    if (_pickingAttachment) return;

    setState(() => _pickingAttachment = true);

    final picked =

        await AnnouncementAttachmentService.instance.pickAndSaveMessageAttachments();

    if (!mounted) return;

    setState(() {

      _pickingAttachment = false;

      _attachments.addAll(picked);

    });

  }



  Future<void> _send() async {

    final s = AppLocale.instance.strings;

    final recipient = _resolvedRecipient;

    if (recipient == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(s.parentMessageNoRecipient)),

      );

      return;

    }

    final body = _bodyController.text.trim();

    if (body.isEmpty && _attachments.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(s.messageBodyRequired)),

      );

      return;

    }



    final ids = _data.sendParentDirectMessage(

      body: body,

      subject: _subjectController.text.trim().isEmpty

          ? null

          : _subjectController.text.trim(),

      staffId: recipient.id,

      studentId: _selectedChild?.studentId,

      attachments: List.unmodifiable(_attachments),

    );

    if (!mounted) return;

    if (ids.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(s.messageSendFailed)),

      );

      return;

    }

    final uploaded = await _data.persistConversationToCloud(ids.single);

    if (!mounted) return;

    if (!uploaded) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(
            _data.lastConversationPersistError ?? s.messageSendFailed,
          ),

          backgroundColor: const Color(0xFFB91C1C),

        ),

      );

      return;

    }

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(s.messageSent),

        backgroundColor: const Color(0xFF15803D),

      ),

    );

    Navigator.pop(context, ids.first);

  }



  @override

  Widget build(BuildContext context) {

    return ListenableBuilder(

      listenable: AppLocale.instance,

      builder: (context, _) {

        final s = AppLocale.instance.strings;

        final homeroom = _homeroomContact;

        return Scaffold(

          backgroundColor: ParentChildPalette.surface,

          appBar: AppBar(

            backgroundColor: ParentChildPalette.primary,

            foregroundColor: Colors.white,

            title: Text(s.parentComposeTitle),

          ),

          body: ListView(

            padding: listPagePadding(context),

            children: [

              if (_children.length > 1 && widget.child == null) ...[

                DropdownButtonFormField<ChildProfile>(

                  key: ValueKey(_selectedChild?.studentId),

                  initialValue: _selectedChild,

                  decoration: adminFieldDecoration(

                    label: s.chooseChildLabel,

                    icon: Icons.child_care_outlined,

                    accent: ParentChildPalette.primary,

                  ),

                  items: _children

                      .map(

                        (c) => DropdownMenuItem(

                          value: c,

                          child: Text(c.name),

                        ),

                      )

                      .toList(),

                  onChanged: (value) {

                    setState(() => _selectedChild = value);

                  },

                ),

                const SizedBox(height: 16),

              ],

              Text(

                s.parentMessageRecipientLabel,

                style: const TextStyle(fontWeight: FontWeight.bold),

              ),

              const SizedBox(height: 8),

              SegmentedButton<_ParentRecipientKind>(

                segments: [

                  ButtonSegment(

                    value: _ParentRecipientKind.homeroom,

                    label: Text(s.homeroomTeacherShort),

                    icon: const Icon(Icons.home_outlined, size: 18),

                  ),

                  ButtonSegment(

                    value: _ParentRecipientKind.admin,

                    label: Text(s.adminLabel),

                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),

                  ),

                ],

                selected: {_kind},

                onSelectionChanged: (value) {

                  setState(() => _kind = value.first);

                },

              ),

              const SizedBox(height: 16),

              if (_kind == _ParentRecipientKind.homeroom)

                _RecipientPreview(

                  name: homeroom?.displayName ?? _selectedChild?.teacher ?? '—',

                  subtitle: s.homeroomTeacherShort,

                )

              else

                _RecipientPreview(

                  name: _adminContacts.firstOrNull?.displayName ?? s.adminLabel,

                  subtitle: s.schoolAdministration,

                ),

              const SizedBox(height: 20),

              TextField(

                controller: _subjectController,

                decoration: adminFieldDecoration(

                  label: s.titleLabel,

                  icon: Icons.title_outlined,

                  accent: ParentChildPalette.primary,

                ),

              ),

              const SizedBox(height: 12),

              if (_attachments.isNotEmpty)

                Padding(

                  padding: const EdgeInsets.only(bottom: 8),

                  child: PendingAttachmentRow(

                    attachments: _attachments,

                    onRemove: (attachment) => setState(() {

                      _attachments.removeWhere((a) => a.id == attachment.id);

                    }),

                  ),

                ),

              MessageVoiceInputBar(

                controller: _bodyController,

                accent: ParentChildPalette.primary,

                pickingAttachment: _pickingAttachment,

                onPickAttachment: _pickAttachments,

                onSend: _send,

                onSendVoice: (attachment) =>

                    setState(() => _attachments.add(attachment)),

                hintText: s.bodyLabel,

              ),

            ],

          ),

        );

      },

    );

  }

}



class _RecipientPreview extends StatelessWidget {

  const _RecipientPreview({required this.name, required this.subtitle});



  final String name;

  final String subtitle;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(

          color: ParentChildPalette.secondary.withValues(alpha: 0.3),

        ),

      ),

      child: Row(

        children: [

          CircleAvatar(

            backgroundColor: ParentChildPalette.primary.withValues(alpha: 0.15),

            child: Text(

              name.isNotEmpty ? name[0] : '?',

              style: const TextStyle(color: ParentChildPalette.deep),

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  name,

                  style: const TextStyle(fontWeight: FontWeight.bold),

                ),

                Text(

                  subtitle,

                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}


