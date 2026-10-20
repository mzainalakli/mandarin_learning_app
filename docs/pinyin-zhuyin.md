# Pinyin → Zhuyin Converter

Zhuyin (注音符號 / Bopomofo) is generated from Pinyin by [`lib/utils/pinyin_zhuyin.dart`](../lib/utils/pinyin_zhuyin.dart). It is pure Dart with no dependencies.

```dart
import 'package:mandarin_app/utils/pinyin_zhuyin.dart';

pinyinToZhuyin('nǐ hǎo');        // ㄋㄧˇ ㄏㄠˇ
pinyinToZhuyin('ni3 hao3');      // ㄋㄧˇ ㄏㄠˇ
pinyinToZhuyin('xie4 xie5');     // ㄒㄧㄝˋ ˙ㄒㄧㄝ
pinyinToZhuyin('');              // ''
```

## Where it is used

- Seeding the bundled dataset (every row gets Zhuyin generated).
- XLSX and CSV import, when the `zhuyin` cell is empty.
- It is **not** used for JSON import or the Quick Add form (Zhuyin stays empty unless you type it).

## How it works

1. The input is trimmed, lower-cased and split on whitespace into syllables. Output syllables are joined with a single space.
2. For each syllable the **tone** is detected:
   - a trailing digit `1`–`5` (`ni3`), or
   - a tone-marked vowel (`ā á ǎ à`, `ē é ě è`, `ī í ǐ ì`, `ō ó ǒ ò`, `ū ú ǔ ù`, `ǖ ǘ ǚ ǜ`).
   - With neither, the syllable is treated as **first tone** (no mark).
3. `ü` and the tone-marked ü forms are normalised to `v` for lookup.
4. The base syllable is looked up in a table of roughly 400 Pinyin syllables → Zhuyin. If it is missing, a fallback splits the syllable into an initial (`b p m f d t n l g k h j q x zh ch sh r z c s y w`) and a final and concatenates their Zhuyin.
5. The tone is appended: tone 1 → nothing, tone 2 → `ˊ`, tone 3 → `ˇ`, tone 4 → `ˋ`, **tone 5 / neutral → a leading `˙`**.
6. If anything throws, the original Pinyin is returned unchanged rather than raising.

## Input rules and caveats

- **Neutral tone must be written as `5`** (`xie5`). A bare second syllable such as the `xie` in `xiè xie` is read as *first tone* and gets no `˙`. The bundled dataset uses plain marked Pinyin, so neutral-tone syllables written without a digit come out without the dot.
- Apostrophes and hyphens are **not** handled: `xi'an` converts to `xi'ㄚn` and `ping-an` to `ping-ㄚn`. Separate syllables with spaces (`xi an`) instead.
- Input is case-insensitive (`NI3` works), and ü forms such as `nü3` and `lǜ` are supported.
- Because the generator works on Pinyin, polyphonic characters get the Zhuyin of whatever Pinyin the row contains — the converter never looks at Hanzi.
- Provide your own `zhuyin` value in the file to override generation.

## Verifying changes

Two small scripts print results for sample inputs:

```bash
dart run tool/test_pinyin_fix.dart   # pass/fail summary for edge cases
dart run tool/test_zhuyin.dart       # prints each sample with its expected value
```
