import 'package:mandarin_app/utils/pinyin_zhuyin.dart';

void main() {
  final testCases = [
    // Normal cases
    ('nǐ hǎo', 'ㄋㄧˇ ㄏㄠˇ'),
    ('xiè xie', 'ㄒㄧㄝˋ ㄒㄧㄝ'), // second syllable defaults to first tone
    ('zài jiàn', 'ㄗㄞˋ ㄐㄧㄢˋ'),
    // Edge cases - short syllables
    ('a', 'ㄚ'),
    ('e', 'ㄜ'),
    ('o', 'ㄛ'),
    ('ai', 'ㄞ'),
    ('an', 'ㄢ'),
    ('ang', 'ㄤ'),
    ('ao', 'ㄠ'),
    // Single letters with tone numbers
    ('a1', 'ㄚ'),
    ('e1', 'ㄜ'),
    ('o1', 'ㄛ'),
    // Neutral tone
    ('a5', '˙ㄚ'),
    ('e5', '˙ㄜ'),
    // Multi-syllable with short ones
    ('a ai an', 'ㄚ ㄞ ㄢ'),
    // Empty/whitespace
    ('', ''),
    ('   ', ''),
  ];

  print('Testing pinyinToZhuyin...');
  int passed = 0;
  int failed = 0;

  for (final (input, expected) in testCases) {
    final result = pinyinToZhuyin(input);
    if (result == expected) {
      print('✓ "$input" => "$result"');
      passed++;
    } else {
      print('✗ "$input" => "$result" (expected: "$expected")');
      failed++;
    }
  }

  print('\nResults: $passed passed, $failed failed');
}