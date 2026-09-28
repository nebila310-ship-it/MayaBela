import 'package:flutter/material.dart';

import 'package:mayabela/screens/gallery_screen.dart';

/// School-wide gallery for the admin ERP shell.
class WebGalleryPage extends StatelessWidget {
  const WebGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GalleryScreen(
      mode: GalleryViewMode.school,
      embedded: true,
    );
  }
}
