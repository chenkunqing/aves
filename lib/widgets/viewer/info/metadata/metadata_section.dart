import 'dart:async';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/info.dart';
import 'package:aves/widgets/viewer/info/metadata/metadata_dir.dart';
import 'package:flutter/material.dart';

class MetadataSectionSliver extends StatefulWidget {
  final AvesEntry entry;
  final ValueNotifier<Map<String, MetadataDirectory>> metadataNotifier;

  const MetadataSectionSliver({
    super.key,
    required this.entry,
    required this.metadataNotifier,
  });

  @override
  State<StatefulWidget> createState() => _MetadataSectionSliverState();
}

class _MetadataSectionSliverState extends State<MetadataSectionSliver> {
  AvesEntry get entry => widget.entry;

  ValueNotifier<Map<String, MetadataDirectory>> get metadataNotifier => widget.metadataNotifier;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
    metadataNotifier.value = {};
    _getMetadata();
  }

  @override
  void didUpdateWidget(covariant MetadataSectionSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
    _getMetadata();
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(MetadataSectionSliver widget) {
    widget.entry.metadataChangeNotifier.addListener(_onMetadataChanged);
  }

  void _unregisterWidget(MetadataSectionSliver widget) {
    widget.entry.metadataChangeNotifier.removeListener(_onMetadataChanged);
  }

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  void _onMetadataChanged() {
    metadataNotifier.value = {};
    _getMetadata();
  }

  Future<void> _getMetadata() async {
    final titledDirectories = await entry.getMetadataDirectories(context);
    if (!mounted) return;
    metadataNotifier.value = Map.fromEntries(titledDirectories);
  }
}
