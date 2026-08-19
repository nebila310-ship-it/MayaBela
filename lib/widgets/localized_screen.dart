import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';

typedef LocalizedBuilder = Widget Function(BuildContext context, AppStrings s);

class LocalizedScreen extends StatelessWidget {
  const LocalizedScreen({super.key, required this.builder});

  final LocalizedBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) => builder(context, AppLocale.instance.strings),
    );
  }
}
