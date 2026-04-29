import 'dart:io' as io;

import 'package:aves/services/common/services.dart';
import 'package:aves/widgets/common/map/leaflet/vector_style_reader_extra.dart';
import 'package:flutter/material.dart';
import 'package:vector_map_tiles/src/io/io.dart' as vmtio show Directory; // ignore: implementation_imports
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

class OsmLibertyLayer extends StatefulWidget {
  const OsmLibertyLayer({super.key});

  @override
  State<OsmLibertyLayer> createState() => _OsmLibertyLayerState();
}

class _OsmLibertyLayerState extends State<OsmLibertyLayer> {
  late final Future<TileProviders> _tileProviderFuture;
  late final Future<Style> _styleFuture;

  static const _openMapTileProviderSource = 'openmaptiles';

  static const _openFreeMapTileProviderUri = 'https://tiles.openfreemap.org/planet';

  static const _osmLibertyStyleUri = 'https://tiles.openfreemap.org/styles/liberty';

  @override
  void initState() {
    super.initState();

    _tileProviderFuture = ExtraStyleReader.readProviderByName(
      {
        _openMapTileProviderSource: {
          'url': _openFreeMapTileProviderUri,
          'type': 'vector',
        },
      },
    ).then(TileProviders.new);

    _styleFuture = StyleReader(
      uri: _osmLibertyStyleUri,
      logger: const vtr.Logger.console(),
    ).readExtra(skipSources: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TileProviders>(
      future: _tileProviderFuture,
      builder: (context, tileProviderSnapshot) {
        return FutureBuilder<Style>(
          future: _styleFuture,
          builder: (context, styleSnapshot) {
            if (tileProviderSnapshot.hasError) return Text(tileProviderSnapshot.error.toString());
            if (styleSnapshot.hasError) return Text(styleSnapshot.error.toString());

            final tileProviders = tileProviderSnapshot.data;
            final style = styleSnapshot.data;
            if (tileProviders == null || style == null) return const SizedBox();

            return VectorTileLayer(
              tileProviders: tileProviders,
              theme: style.theme,
              sprites: style.sprites,
              // `vector` is higher quality and follows map orientation, but it is slower
              layerMode: VectorTileLayerMode.raster,
              cacheFolder: () async {
                final cacheRoot = await storageService.getExternalCacheDirectory();
                final path = pContext.join(cacheRoot, 'map_vector_tiles');
                dynamic result;
                if (vmtio.Directory == String) {
                  result = path;
                } else if (vmtio.Directory == io.Directory) {
                  result = io.Directory(path);
                } else {
                  throw Exception('vmtio.Directory type is not supported');
                }
                return result;
              },
            );
          },
        );
      },
    );
  }
}
