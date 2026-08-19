import 'package:flutter/material.dart';

import 'package:mayabela/services/phone_launch_service.dart';

/// Phone [TextField] with a tap-to-dial icon. If this field is empty, optional
/// [fallbackNumbers] can be offered in a picker.
class PhoneContactField extends StatelessWidget {
  const PhoneContactField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.fallbackNumbers = const [],
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<PhoneDialOption> fallbackNumbers;

  Future<void> _dial(BuildContext context) async {
    final direct = controller.text.trim();
    if (direct.isNotEmpty) {
      final ok = await PhoneLaunchService.instance.dial(direct);
      if (context.mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
      return;
    }

    final options = fallbackNumbers
        .where((o) => o.phone.trim().isNotEmpty)
        .toList();
    if (options.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number to call')),
        );
      }
      return;
    }

    if (options.length == 1) {
      await PhoneLaunchService.instance.dial(options.first.phone);
      return;
    }

    if (!context.mounted) return;
    final picked = await showModalBottomSheet<PhoneDialOption>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose number to call',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...options.map(
              (o) => ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(o.label),
                subtitle: Text(o.phone),
                onTap: () => Navigator.pop(context, o),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      await PhoneLaunchService.instance.dial(picked.phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(Icons.phone, color: Colors.green.shade700),
          tooltip: 'Call',
          onPressed: () => _dial(context),
        ),
      ),
    );
  }
}

class PhoneDialOption {
  const PhoneDialOption({required this.label, required this.phone});

  final String label;
  final String phone;
}
