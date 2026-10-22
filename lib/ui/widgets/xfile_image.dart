import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../core/theme/kn_colors.dart';

/// Shows a picked image on every platform (Image.file is unavailable on web).
class XFileImage extends StatelessWidget {
  const XFileImage(this.file, {super.key, required this.width, required this.height});
  final XFile file;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: file.readAsBytes(),
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!, width: width, height: height, fit: BoxFit.cover)
            : Container(width: width, height: height, color: context.kn.surfaceHigh),
      );
}
