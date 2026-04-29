import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/images.dart';
import 'package:flutter/material.dart';

Future<void> showOrganizeZoomPreview(BuildContext context, AvesEntry entry) {
  return Navigator.push(
    context,
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _OrganizeZoomPreview(entry: entry);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  );
}

class _OrganizeZoomPreview extends StatefulWidget {
  final AvesEntry entry;

  const _OrganizeZoomPreview({required this.entry});

  @override
  State<_OrganizeZoomPreview> createState() => _OrganizeZoomPreviewState();
}

class _OrganizeZoomPreviewState extends State<_OrganizeZoomPreview> {
  final TransformationController _transformController = TransformationController();

  static const _maxScale = 5.0;
  static const _doubleTapScale = 2.5;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final Matrix4 target;
    if (currentScale > 1.1) {
      target = Matrix4.identity();
    } else {
      final position = details.localPosition;
      target = Matrix4.identity()
        ..translateByDouble(-position.dx * (_doubleTapScale - 1), -position.dy * (_doubleTapScale - 1), 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    _transformController.value = target;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _ZoomableImage(
              entry: widget.entry,
              transformController: _transformController,
              onDoubleTap: _onDoubleTap,
            ),
          ),
          Positioned(
            top: padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black38,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final AvesEntry entry;
  final TransformationController transformController;
  final void Function(TapDownDetails details) onDoubleTap;

  const _ZoomableImage({
    required this.entry,
    required this.transformController,
    required this.onDoubleTap,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  TapDownDetails? _doubleTapDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: () {
        final details = _doubleTapDetails;
        if (details != null) widget.onDoubleTap(details);
      },
      child: InteractiveViewer(
        transformationController: widget.transformController,
        maxScale: _OrganizeZoomPreviewState._maxScale,
        minScale: 1.0,
        child: Center(
          child: AspectRatio(
            aspectRatio: widget.entry.displayAspectRatio,
            child: Image(
              image: widget.entry.fullImage,
              fit: BoxFit.contain,
              frameBuilder: _frameBuilder,
              errorBuilder: _errorBuilder,
            ),
          ),
        ),
      ),
    );
  }

  Widget _frameBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded || frame != null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: widget.entry.bestCachedThumbnail, fit: BoxFit.contain),
        const Center(child: CircularProgressIndicator(color: Colors.white54)),
      ],
    );
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Image(image: widget.entry.bestCachedThumbnail, fit: BoxFit.contain);
  }
}
