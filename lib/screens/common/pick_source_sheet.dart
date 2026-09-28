import 'package:flutter/material.dart';

import '../../services/media/image_service.dart';

/// Kamera / galeri seçimi.
Future<PickSource?> showPickSourceSheet(BuildContext context) {
  return showModalBottomSheet<PickSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Kamerayla çek'),
            onTap: () => Navigator.pop(ctx, PickSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeriden seç'),
            onTap: () => Navigator.pop(ctx, PickSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
