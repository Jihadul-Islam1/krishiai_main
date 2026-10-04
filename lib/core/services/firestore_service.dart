import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Thin facade over [FirebaseFirestore] + [Firebase] so the rest of the
/// codebase does not have to care about `main.dart` boot order.
///
///  - [boot] is called once from `main()` AFTER `Firebase.initializeApp`.
///  - [instance] returns the live [FirebaseFirestore] handle.
class FirestoreService {
  FirestoreService._(this._app);

  final FirebaseApp _app;

  static FirestoreService? _i;

  /// Called from `main()` immediately after `Firebase.initializeApp`.
  static FirestoreService boot() {
    if (_i != null) return _i!;
    final app = Firebase.app();
    _i = FirestoreService._(app);
    // cloud_firestore v6 enables IndexedDB / SQLite persistence by default.
    // No explicit settings call needed.
    return _i!;
  }

  /// The live Firestore instance associated with the [FirebaseApp] passed
  /// to [boot]. Use this when you need a vanilla handle (e.g. inside a
  /// Repository that talks to FsPaths).
  FirebaseFirestore get instance => FirebaseFirestore.instanceFor(app: _app);

  /// Clears every local cache and pending write for the current session.
  /// Called on sign-out so the next user does not inherit stale data.
  Future<void> clearCache() async {
    try {
      await instance.clearPersistence();
    } catch (_) {
      // clearPersistence may throw on some platforms / in some states.
      // Swallow - we still want terminate() to run.
    }
    try {
      await instance.terminate();
    } catch (_) {
      // ignore
    }
  }
}