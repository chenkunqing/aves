import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/vaults/details.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

final Vaults vaults = Vaults._private();

class Vaults extends ChangeNotifier {
  Set<VaultDetails> _rows = {};

  Vaults._private() {
    if (kFlutterMemoryAllocationsEnabled) ChangeNotifier.maybeDispatchObjectCreation(this);
  }

  Future<void> init() async {
    // Vault feature removed: keep legacy data inaccessible from the app.
    _rows = {};
    _vaultDirPaths = const {};
  }

  @override
  void dispose() {
    super.dispose();
  }

  Set<VaultDetails> get all => Set.unmodifiable(_rows);

  VaultDetails? detailsForPath(String dirPath) => null;

  Future<void> create(VaultDetails details) async {}

  Future<void> remove(Set<String> dirPaths) async {}

  Future<void> rename(String oldDirPath, String newDirPath) async {}

  // update details, except name
  Future<void> update(VaultDetails newDetails) async {}

  Future<void> clear() async {
    _rows.clear();
    _vaultDirPaths = const {};
  }

  Set<String>? _vaultDirPaths;

  Set<String> get vaultDirectories {
    _vaultDirPaths ??= _rows.map((v) => v.path).toSet();
    return _vaultDirPaths!;
  }

  VaultDetails? getVault(String? dirPath) => null;

  bool isVault(String dirPath) => false;

  bool isLocked(String dirPath) => false;

  bool isVaultEntryUri(String uriString) => false;

  void lock(Set<String> dirPaths) {}

  Future<void> unlock(BuildContext context, String dirPath) async {}

  Future<Set<AvesEntry>> recoverUntrackedItems(CollectionSource source, String dirPath) async => {};

  void _onScreenOff() {}

  bool get needProtection => false;

  void _onLockStateChanged() {}
}
