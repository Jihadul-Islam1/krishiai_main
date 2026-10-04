// Firestore document id helper built around the verified bdapps phone number.
//
// Strategy:
//   - BDapps already verified the phone (we trust it because they billed the
//     user). We just need a STABLE, SANITISED key we can reuse as a Firestore
//     document id for `users/{phone}`.
//   - Firestore document ids cannot contain `/` and must be <= 1500 bytes; we
//     only allow digits and a single leading `+` to stay E.164-ish.
//   - Sanitise rules:
//       * keep leading `+` (E.164 country code marker)
//       * drop spaces, dashes, parentheses, dots, slashes
//       * keep digits verbatim
//       * if no leading `+` is present, prepend `+880` (Bangladesh) when the
//         remaining digits match a BD mobile shape; otherwise leave it as-is
//         so non-BD numbers still work in future.
class PhoneKey {
  PhoneKey._();

  /// Returns the canonical document key for [input], or `null` if it cannot
  /// be reduced to a non-empty key. Callers must treat `null` as
  /// "user not logged in" — there is no `users/{empty}` document.
  static String? fromString(String? input) {
    if (input == null) return null;
    var s = input.trim();
    if (s.isEmpty) return null;

    final hasPlus = s.startsWith('+');
    final digitsOnly = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;

    var canonical = hasPlus ? '+$digitsOnly' : digitsOnly;

    // Heuristic: 11-digit BD mobile starting with 01 (e.g. 01712345678) gets
    // promoted to +880XXXXXXXXXX so the doc id is unambiguous internationally.
    if (!hasPlus &&
        digitsOnly.length == 11 &&
        digitsOnly.startsWith('01') &&
        (digitsOnly[2] == '6' || digitsOnly[2] == '8' || digitsOnly[2] == '7' || digitsOnly[2] == '9' || digitsOnly[2] == '3' || digitsOnly[2] == '5' || digitsOnly[2] == '4')) {
      canonical = '+880${digitsOnly.substring(1)}';
    }

    return canonical;
  }

  /// Same as [fromString] but throws if the input is empty. Use this inside
  /// repository methods that have already established a session.
  static String require(String input) {
    final key = fromString(input);
    if (key == null) {
      throw StateError('PhoneKey.require: empty phone');
    }
    return key;
  }
}
