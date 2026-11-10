/// Flexible Arabic name matching for the personal duty-roster highlight.
/// The first name is the anchor; any other one or more name segments may match.
/// Ambiguous top-scoring matches are deliberately not highlighted.
class DutyRosterNameMatcher {
  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^ء-ي0-9a-zA-Z]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int? uniqueBestMatchIndex({
    required String accountName,
    required List<String> rosterNames,
  }) {
    final accountTokens = normalize(accountName)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
    if (accountTokens.length < 2 || rosterNames.isEmpty) return null;

    final firstName = accountTokens.first;
    final remainingNames = accountTokens.skip(1).toSet();
    var bestScore = 1;
    int? bestIndex;
    var tied = false;

    for (var index = 0; index < rosterNames.length; index++) {
      final rosterTokens = normalize(rosterNames[index])
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toSet();
      if (!rosterTokens.contains(firstName)) continue;

      // First name plus any other matching segment, not necessarily the last.
      final score = 1 + rosterTokens.intersection(remainingNames).length;
      if (score < 2) continue;

      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
        tied = false;
      } else if (score == bestScore) {
        tied = true;
      }
    }

    return tied ? null : bestIndex;
  }
}
