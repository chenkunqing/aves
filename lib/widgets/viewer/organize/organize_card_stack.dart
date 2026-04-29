import 'dart:math' as math;

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/favourites.dart';
import 'package:aves/model/organize_basket.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/viewer/organize/organize_zoom_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OrganizeCardStack extends StatefulWidget {
  final List<AvesEntry> entries;
  final ValueNotifier<int> indexNotifier;
  final VoidCallback? onFirstInteraction;

  const OrganizeCardStack({
    super.key,
    required this.entries,
    required this.indexNotifier,
    this.onFirstInteraction,
  });

  @override
  State<OrganizeCardStack> createState() => OrganizeCardStackState();
}

class OrganizeCardStackState extends State<OrganizeCardStack> with TickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _dismissController;
  late AnimationController _snapBackController;
  late AnimationController _favouriteController;
  late Animation<Offset> _dismissAnimation;
  late Animation<Offset> _snapBackAnimation;
  late Animation<double> _snapBackRotation;
  double _rotation = 0;
  _SwipeDirection? _currentDirection;
  bool _showFavouriteAnimation = false;
  int? _pendingIndex;
  bool _isShowingZoom = false;

  static const _dismissThresholdVertical = 0.25;
  static const _dismissThresholdHorizontal = 0.3;
  static const _velocityThreshold = 1000.0;
  static const _maxRotation = 0.26; // ~15 degrees

  List<AvesEntry> get entries => widget.entries;
  int get currentIndex => widget.indexNotifier.value;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      vsync: this,
      duration: ADurations.organizeCardDismiss,
    )..addStatusListener(_onDismissComplete);

    _snapBackController = AnimationController(
      vsync: this,
      duration: ADurations.organizeCardSnapBack,
    )..addStatusListener(_onSnapBackComplete);

    _favouriteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showFavouriteAnimation = false);
          _favouriteController.reset();
        }
      });
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _snapBackController.dispose();
    _favouriteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= entries.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              context.l10n.organizeComplete,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildCurrentCard(size),
        if (_showFavouriteAnimation) _buildFavouriteAnimation(),
        _buildHintOverlays(size),
      ],
    );
  }

  Widget _buildCurrentCard(Size size) {
    final entry = entries[currentIndex];
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_dismissController, _snapBackController]),
        builder: (context, child) {
          final currentOffset = _isDragging ? _dragOffset : (_dismissController.isAnimating ? _dismissAnimation.value : (_snapBackController.isAnimating ? _snapBackAnimation.value : Offset.zero));
          final currentRotation = _isDragging ? _rotation : (_dismissController.isAnimating ? _rotation : (_snapBackController.isAnimating ? _snapBackRotation.value : 0.0));
          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(currentOffset.dx, currentOffset.dy, 0, 1)
              ..rotateZ(currentRotation),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: _buildCard(entry, size),
      ),
    );
  }

  Widget _buildCard(AvesEntry entry, Size size) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final maxWidth = size.width * 0.9;
    final maxHeight = size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: entry.displayAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailImage(
              entry: entry,
              extent: maxWidth,
              devicePixelRatio: dpr,
              fit: BoxFit.contain,
              showLoadingBackground: true,
            ),
            if (entry.isFavourite)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Themes.overlayBackgroundColor(brightness: Theme.of(context).brightness, blurred: settings.enableBlurEffect),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AIcons.favourite, size: 18, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintOverlays(Size size) {
    if (!_isDragging || _currentDirection == null) return const SizedBox();

    final progress = _getSwipeProgress(size);
    final clampedProgress = progress.clamp(0.0, 1.0);

    switch (_currentDirection!) {
      case _SwipeDirection.up:
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: clampedProgress * 0.6,
              child: Container(
                color: Colors.red,
                child: const Center(
                  child: Icon(AIcons.bin, size: 80, color: Colors.white),
                ),
              ),
            ),
          ),
        );
      case _SwipeDirection.down:
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: clampedProgress * 0.6,
              child: Container(
                color: Colors.amber,
                child: const Center(
                  child: Icon(AIcons.favourite, size: 80, color: Colors.white),
                ),
              ),
            ),
          ),
        );
      case _SwipeDirection.left:
      case _SwipeDirection.right:
        return const SizedBox();
    }
  }

  Widget _buildFavouriteAnimation() {
    return AnimatedBuilder(
      animation: _favouriteController,
      builder: (context, child) {
        final scale = 1.0 + _favouriteController.value * 0.5;
        final opacity = 1.0 - _favouriteController.value;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: const Icon(AIcons.favourite, size: 100, color: Colors.red),
          ),
        );
      },
    );
  }

  double _getSwipeProgress(Size size) {
    switch (_currentDirection) {
      case _SwipeDirection.up:
        return (-_dragOffset.dy) / (size.height * _dismissThresholdVertical);
      case _SwipeDirection.down:
        return _dragOffset.dy / (size.height * _dismissThresholdVertical);
      case _SwipeDirection.left:
        return (-_dragOffset.dx) / (size.width * _dismissThresholdHorizontal);
      case _SwipeDirection.right:
        return _dragOffset.dx / (size.width * _dismissThresholdHorizontal);
      case null:
        return 0;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_dismissController.isAnimating || _snapBackController.isAnimating) return;
    widget.onFirstInteraction?.call();
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
      _rotation = 0;
      _currentDirection = null;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isDragging) return;

    if (details.pointerCount >= 2) {
      _cancelDragAndShowZoom();
      return;
    }

    setState(() {
      _dragOffset += details.focalPointDelta;
      _rotation = _dragOffset.dx / MediaQuery.sizeOf(context).width * _maxRotation;
      _currentDirection = _computeDirection();
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final size = MediaQuery.sizeOf(context);
    final velocity = details.velocity.pixelsPerSecond;
    final direction = _currentDirection;

    if (direction == _SwipeDirection.up &&
        (-_dragOffset.dy > size.height * _dismissThresholdVertical || -velocity.dy > _velocityThreshold)) {
      _dismiss(Offset(_dragOffset.dx, -size.height * 1.5));
      _onSwipeUp();
    } else if (direction == _SwipeDirection.down &&
        (_dragOffset.dy > size.height * _dismissThresholdVertical || velocity.dy > _velocityThreshold)) {
      _onSwipeDown();
      _dismiss(Offset(_dragOffset.dx, size.height * 1.5));
    } else if (direction == _SwipeDirection.right &&
        (_dragOffset.dx > size.width * _dismissThresholdHorizontal || velocity.dx > _velocityThreshold)) {
      _dismiss(Offset(size.width * 1.5, _dragOffset.dy));
      _onSwipeRight();
    } else if (direction == _SwipeDirection.left &&
        (-_dragOffset.dx > size.width * _dismissThresholdHorizontal || -velocity.dx > _velocityThreshold)) {
      _dismiss(Offset(-size.width * 1.5, _dragOffset.dy));
      _onSwipeLeft();
    } else {
      _snapBack();
    }
  }

  void _cancelDragAndShowZoom() {
    setState(() {
      _isDragging = false;
      _dragOffset = Offset.zero;
      _rotation = 0;
      _currentDirection = null;
    });
    _showZoomPreview();
  }

  Future<void> _showZoomPreview() async {
    if (_isShowingZoom || currentIndex >= entries.length) return;
    _isShowingZoom = true;
    await showOrganizeZoomPreview(context, entries[currentIndex]);
    _isShowingZoom = false;
  }

  _SwipeDirection? _computeDirection() {
    if (_dragOffset.distance < 20) return null;
    final angle = _dragOffset.direction;
    if (angle > -math.pi * 0.75 && angle < -math.pi * 0.25) return _SwipeDirection.up;
    if (angle > math.pi * 0.25 && angle < math.pi * 0.75) return _SwipeDirection.down;
    if (angle.abs() < math.pi * 0.25) return _SwipeDirection.right;
    return _SwipeDirection.left;
  }

  void _dismiss(Offset target) {
    _dismissAnimation = Tween<Offset>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeOut),
    );
    _dismissController.forward(from: 0);
  }

  void _snapBack() {
    _snapBackAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut),
    );
    _snapBackRotation = Tween<double>(begin: _rotation, end: 0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.elasticOut),
    );
    _snapBackController.forward(from: 0);
  }

  void _onDismissComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _dismissController.reset();
    _dragOffset = Offset.zero;
    _rotation = 0;
    _currentDirection = null;
    final target = _pendingIndex;
    _pendingIndex = null;
    if (target != null) {
      setState(() {
        widget.indexNotifier.value = target.clamp(0, entries.length);
      });
    }
  }

  void _onSnapBackComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _snapBackController.reset();
    setState(() {
      _dragOffset = Offset.zero;
      _rotation = 0;
      _currentDirection = null;
    });
  }

  void _onSwipeUp() {
    final entry = entries[currentIndex];
    context.read<OrganizeBasket>().addToDeletion(entry, currentIndex);
    _pendingIndex = currentIndex + 1;
  }

  void _onSwipeDown() {
    final entry = entries[currentIndex];
    context.read<OrganizeBasket>().toggleFavourite(entry);
    setState(() => _showFavouriteAnimation = true);
    _favouriteController.forward(from: 0);
    _pendingIndex = currentIndex + 1;
  }

  void _onSwipeRight() {
    _pendingIndex = (currentIndex - 1).clamp(0, entries.length);
  }

  void _onSwipeLeft() {
    _pendingIndex = currentIndex + 1;
  }

  void goToIndex(int index) {
    setState(() {
      widget.indexNotifier.value = index.clamp(0, entries.length);
      _dragOffset = Offset.zero;
      _rotation = 0;
    });
  }
}

enum _SwipeDirection { up, down, left, right }
