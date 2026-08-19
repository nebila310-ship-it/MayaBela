import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

export 'package:mayabela/widgets/staff_role_labels.dart';

/// Table-style role picker (same mental model as the staff directory Role column).
/// Prefer this over stacked checkboxes so the chosen role is obvious.
/// On narrow/phone widths, uses tappable list rows instead of a DataTable.
class StaffRolePickerTable extends StatelessWidget {
  const StaffRolePickerTable({
    super.key,
    required this.roles,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    this.accent = const Color(0xFF4527A0),
    this.isRoleEnabled,
    this.emptyHint = 'No roles available.',
  });

  final List<StaffRole> roles;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// When false, tapping a role replaces the selection (one role only).
  final bool multiSelect;
  final Color accent;
  final bool Function(StaffRole role)? isRoleEnabled;
  final String emptyHint;

  void _toggle(StaffRole role) {
    final enabled = isRoleEnabled?.call(role) ?? true;
    if (!enabled) return;
    final next = Set<String>.from(selected);
    if (multiSelect) {
      if (next.contains(role.key)) {
        next.remove(role.key);
      } else {
        next.add(role.key);
      }
    } else {
      if (next.contains(role.key) && next.length == 1) {
        next.clear();
      } else {
        next
          ..clear()
          ..add(role.key);
      }
    }
    onChanged(next);
  }

  String _typeLabel(StaffRole role) {
    if (role.ownerOnly) return 'Owner only';
    if (role.builtIn) return 'Built-in';
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    if (roles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyHint, style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    final selectedLabel = selected.isEmpty
        ? 'None selected'
        : staffRolesSummary(selected.toList(), s);
    final narrow = WebViewport.isNarrow(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected.isEmpty
                ? Colors.orange.shade50
                : accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected.isEmpty
                  ? Colors.orange.shade200
                  : accent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected.isEmpty
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 18,
                color: selected.isEmpty ? Colors.orange.shade800 : accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  multiSelect
                      ? 'Selected role(s): $selectedLabel'
                      : 'Selected role: $selectedLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected.isEmpty ? Colors.orange.shade900 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          multiSelect
              ? 'Tap a row to add or remove a role.'
              : 'Tap one row to choose the role for this staff member.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        if (narrow)
          Column(
            children: [
              for (final role in roles)
                Builder(
                  builder: (context) {
                    final enabled = isRoleEnabled?.call(role) ?? true;
                    final isSelected = selected.contains(role.key);
                    return Material(
                      color: isSelected
                          ? accent.withValues(alpha: 0.12)
                          : enabled
                              ? null
                              : Colors.grey.shade100,
                      child: ListTile(
                        enabled: enabled,
                        selected: isSelected,
                        onTap: enabled ? () => _toggle(role) : null,
                        title: Text(
                          staffRoleLabel(role, s),
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _typeLabel(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: accent, size: 22)
                            : Icon(
                                Icons.circle_outlined,
                                color: Colors.grey.shade400,
                                size: 22,
                              ),
                      ),
                    );
                  },
                ),
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final role in roles)
                  DataRow(
                    selected: selected.contains(role.key),
                    color: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return accent.withValues(alpha: 0.12);
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade100;
                      }
                      return null;
                    }),
                    onSelectChanged: (isRoleEnabled?.call(role) ?? true)
                        ? (_) => _toggle(role)
                        : null,
                    cells: [
                      DataCell(
                        Text(
                          staffRoleLabel(role, s),
                          style: TextStyle(
                            fontWeight: selected.contains(role.key)
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _typeLabel(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      DataCell(
                        selected.contains(role.key)
                            ? Text(
                                'Selected',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : Text(
                                '—',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
