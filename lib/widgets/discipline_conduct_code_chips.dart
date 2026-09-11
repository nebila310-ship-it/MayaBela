import 'package:flutter/material.dart';

import 'package:mayabela/models/discipline_case.dart';

/// Suggested code-of-conduct chips. Selection is still free text on the case.
class DisciplineConductCodeChips extends StatelessWidget {
  const DisciplineConductCodeChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code of conduct',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final code in DisciplineConductCodes.codes)
              FilterChip(
                label: Text(code),
                selected: selected == code,
                onSelected: (on) => onSelected(on ? code : ''),
              ),
          ],
        ),
      ],
    );
  }
}
