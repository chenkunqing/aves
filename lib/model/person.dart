import 'package:aves/services/common/services.dart';

final PersonStore personStore = PersonStore._private();

class PersonRow {
  final int? personId;
  final String? name;
  final int? coverEntryId;

  const PersonRow({
    this.personId,
    this.name,
    this.coverEntryId,
  });

  factory PersonRow.fromMap(Map<String, Object?> map) {
    return PersonRow(
      personId: map['personId'] as int?,
      name: map['name'] as String?,
      coverEntryId: map['coverEntryId'] as int?,
    );
  }

  Map<String, Object?> toMap() => {
        if (personId != null) 'personId': personId,
        'name': name,
        'coverEntryId': coverEntryId,
      };

  PersonRow copyWith({String? name, int? coverEntryId}) {
    return PersonRow(
      personId: personId,
      name: name ?? this.name,
      coverEntryId: coverEntryId ?? this.coverEntryId,
    );
  }
}

class PersonStore {
  final Map<int, PersonRow> _persons = {};
  final Map<int, Set<int>> _entryPersons = {};
  final Map<int, Set<int>> _personEntries = {};
  final Map<int, String> _coverBoundingBoxes = {};

  PersonStore._private();

  Future<void> init() async {
    _persons.clear();
    _entryPersons.clear();
    _personEntries.clear();
    _coverBoundingBoxes.clear();

    final persons = await localMediaDb.loadAllPersons();
    for (final person in persons) {
      if (person.personId != null) {
        _persons[person.personId!] = person;
      }
    }

    final embeddings = await localMediaDb.loadAllFaceEmbeddings();
    for (final entry in embeddings.entries) {
      final entryId = entry.key;
      for (final emb in entry.value) {
        if (emb.personId != null) {
          _entryPersons.putIfAbsent(entryId, () => {}).add(emb.personId!);
          _personEntries.putIfAbsent(emb.personId!, () => {}).add(entryId);
          final person = _persons[emb.personId!];
          if (person != null && person.coverEntryId == entryId && !_coverBoundingBoxes.containsKey(emb.personId!)) {
            _coverBoundingBoxes[emb.personId!] = emb.boundingBox;
          }
        }
      }
    }
  }

  List<int> get allPersonIds => _persons.keys.toList()..sort();

  int get personCount => _persons.length;

  PersonRow? getById(int personId) => _persons[personId];

  Set<int> getPersonsForEntry(int entryId) => _entryPersons[entryId] ?? {};

  Set<int> getEntriesForPerson(int personId) => _personEntries[personId] ?? {};

  String? getCoverBoundingBox(int personId) => _coverBoundingBoxes[personId];

  void setCoverBoundingBox(int personId, String boundingBox) {
    _coverBoundingBoxes[personId] = boundingBox;
  }

  Future<int> addPerson(PersonRow person) async {
    final id = await localMediaDb.savePerson(person);
    _persons[id] = PersonRow(
      personId: id,
      name: person.name,
      coverEntryId: person.coverEntryId,
    );
    return id;
  }

  Future<void> updatePerson(PersonRow person) async {
    if (person.personId == null) return;
    await localMediaDb.updatePerson(person);
    _persons[person.personId!] = person;
  }

  Future<void> removePerson(int personId) async {
    await localMediaDb.removePerson(personId);
    _persons.remove(personId);
    final entries = _personEntries.remove(personId) ?? {};
    for (final entryId in entries) {
      _entryPersons[entryId]?.remove(personId);
      if (_entryPersons[entryId]?.isEmpty ?? false) {
        _entryPersons.remove(entryId);
      }
    }
  }

  void assignFaceToPersonInCache(int entryId, int personId, {String? boundingBox}) {
    _entryPersons.putIfAbsent(entryId, () => {}).add(personId);
    _personEntries.putIfAbsent(personId, () => {}).add(entryId);
    if (boundingBox != null && !_coverBoundingBoxes.containsKey(personId)) {
      _coverBoundingBoxes[personId] = boundingBox;
    }
  }

  void resetCache() {
    _persons.clear();
    _entryPersons.clear();
    _personEntries.clear();
    _coverBoundingBoxes.clear();
  }

  void mergePersonInCache(int fromPersonId, int toPersonId) {
    final entries = _personEntries.remove(fromPersonId) ?? {};
    for (final entryId in entries) {
      _entryPersons[entryId]?.remove(fromPersonId);
      _entryPersons.putIfAbsent(entryId, () => {}).add(toPersonId);
      _personEntries.putIfAbsent(toPersonId, () => {}).add(entryId);
    }
  }

  Future<void> clear() async {
    _persons.clear();
    _entryPersons.clear();
    _personEntries.clear();
    await localMediaDb.clearPersons();
    await localMediaDb.clearFaceEmbeddings();
  }

  Future<void> removeByEntryIds(Set<int> ids) async {
    for (final entryId in ids) {
      final personIds = _entryPersons.remove(entryId) ?? {};
      for (final personId in personIds) {
        _personEntries[personId]?.remove(entryId);
      }
    }
    await localMediaDb.removeFaceEmbeddingsByEntryIds(ids);
  }
}
