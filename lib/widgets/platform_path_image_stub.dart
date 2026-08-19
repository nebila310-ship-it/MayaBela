import 'package:flutter/material.dart';

Widget buildIoPathImage({
  required String path,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Icon(Icons.image_not_supported_outlined, size: width ?? height ?? 40);
}
