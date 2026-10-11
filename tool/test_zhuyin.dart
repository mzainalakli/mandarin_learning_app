import 'package:mandarin_app/utils/pinyin_zhuyin.dart';

void main() {
  final tests = [
    ('nǐ hǎo', 'ㄋㄧˇ ㄏㄠˇ'),
    ('xiè xie', 'ㄒㄧㄝˋ ˙ㄒㄧㄝ'),
    ('zài jiàn', 'ㄗㄞˋ ㄐㄧㄢˋ'),
    ('rén', 'ㄖㄣˊ'),
    ('wǒ', 'ㄨㄛˇ'),
    ('nǐ', 'ㄋㄧˇ'),
    ('tā', 'ㄊㄚ'),
    ('shì', 'ㄕˋ'),
    ('yǒu', 'ㄧㄡˇ'),
    ('méi yǒu', 'ㄇㄟˊ ㄧㄡˇ'),
    ('qǐng', 'ㄑㄧㄥˇ'),
    ('duì bu qǐ', 'ㄉㄨㄟˋ ˙ㄅㄨ ㄑㄧˇ'),
    ('ni3 hao3', 'ㄋㄧˇ ㄏㄠˇ'),
    ('xie4 xie5', 'ㄒㄧㄝˋ ˙ㄒㄧㄝ'),
  ];
  
  for (final (input, expected) in tests) {
    final result = pinyinToZhuyin(input);
    final status = result == expected ? '✓' : '✗';
    print('$status $input => $result (expected: $expected)');
  }
}