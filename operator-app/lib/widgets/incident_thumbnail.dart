import 'package:flutter/material.dart';

import 'authenticated_image.dart';

/// Snapshot preview used by the incident journal and the live activity panel.
/// Media is protected by the backend, so [AuthenticatedImage] sends the bearer
/// token with the request.
class IncidentThumbnail extends StatelessWidget {
  const IncidentThumbnail({
    super.key,
    required this.url,
    this.size = 56,
    this.borderRadius = 10,
  });

  final String? url;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: const Color(0xFFF2F2F7),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.38,
        color: scheme.onSurfaceVariant,
      ),
    );
    final imageUrl = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null || imageUrl.isEmpty
            ? placeholder
            : AuthenticatedImage(
                url: imageUrl,
                width: size,
                height: size,
                placeholder: placeholder,
              ),
      ),
    );
  }
}
