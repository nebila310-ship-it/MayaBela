import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/screens/my_children_screen.dart';

/// Parent accent palette for child picker and hub.
class ParentChildPalette {
  ParentChildPalette._();

  static const primary = Color(0xFF0D9488);
  static const secondary = Color(0xFF14B8A6);
  static const deep = Color(0xFF115E59);
  static const surface = Color(0xFFF0FDFA);
  static const gradient = [Color(0xFF115E59), Color(0xFF0D9488), Color(0xFF2DD4BF)];
}

/// Shows a polished bottom sheet to pick a linked child.
Future<ChildProfile?> showParentChildPicker(
  BuildContext context, {
  required String title,
  String? subtitle,
}) async {
  final children = SchoolDataService.instance.getChildren();
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocale.instance.strings.noLinkedChildren)),
    );
    return null;
  }
  if (children.length == 1) return children.first;

  return showModalBottomSheet<ChildProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ParentChildPickerSheet(
      title: title,
      subtitle: subtitle,
      children: children,
    ),
  );
}

/// Opens child picker then navigates to the child hub.
Future<void> openParentChildHub(BuildContext context) async {
  final child = await showParentChildPicker(
    context,
    title: AppLocale.instance.strings.myChildrenScreen,
    subtitle: AppLocale.instance.strings.chooseChildSubtitle,
  );
  if (child == null || !context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChildDetailScreen(child: child)),
  );
}

class _ParentChildPickerSheet extends StatelessWidget {
  const _ParentChildPickerSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final data = SchoolDataService.instance;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: ParentChildPalette.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...children.map((child) {
                final rank = child.studentId != null
                    ? data.rankForStudentId(child.studentId!, child.className)
                    : data.rankForStudent(child.name, child.className);
                final attendance = (child.attendanceRate * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: ParentChildPalette.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pop(context, child),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  ParentChildPalette.primary.withValues(alpha: 0.15),
                              child: Text(
                                child.name.isNotEmpty
                                    ? child.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: ParentChildPalette.deep,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.childSummaryLine(
                                      child.grade,
                                      child.displaySection,
                                      child.teacher,
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _MiniChip(
                                  label: s.attendanceThisTerm(attendance),
                                  color: Colors.green.shade700,
                                  bg: Colors.green.shade50,
                                ),
                                if (rank != null) ...[
                                  const SizedBox(height: 6),
                                  _MiniChip(
                                    label: s.rankNumber(rank),
                                    color: ParentChildPalette.deep,
                                    bg: ParentChildPalette.primary
                                        .withValues(alpha: 0.12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
