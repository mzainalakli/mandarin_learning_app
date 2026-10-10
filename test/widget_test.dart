import 'package:flutter_test/flutter_test.dart';

import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/services/excel_service.dart';

List<Vocabulary> _vocabs(int count) => List.generate(
  count,
  (index) => Vocabulary(
    id: index + 1,
    hanzi: 'h$index',
    pinyin: 'p$index',
    meaning: 'm$index',
    category: 'test',
  ),
);

void main() {
  test('Vocabulary Traditional fields fall back when blank', () {
    final vocab = Vocabulary(
      hanzi: '谢谢',
      traditionalHanzi: '',
      pinyin: 'xiè xie',
      zhuyin: ' ',
      meaning: 'thank you',
      category: 'HSK 1',
    );
    expect(vocab.displayHanzi, '谢谢');
    expect(vocab.displayPronunciation, 'xiè xie');
  });

  test('Quiz session does not repeat before every word is served', () {
    final quiz = QuizProvider();
    final words = _vocabs(4);
    quiz.startNewQuiz(
      words,
      module: QuizModule.hanziToMeaning,
      answerMode: QuizAnswerMode.essay,
    );
    final seen = <int>{};
    for (var index = 0; index < words.length; index++) {
      seen.add(quiz.current!.id!);
      quiz.passQuestion();
    }
    expect(seen, hasLength(4));
    expect(quiz.current, isNotNull);
    expect(seen, contains(quiz.current!.id));
  });

  test('Passed question returns only after remaining questions', () {
    final quiz = QuizProvider();
    final words = _vocabs(3);
    quiz.startNewQuiz(
      words,
      module: QuizModule.hanziToMeaning,
      answerMode: QuizAnswerMode.essay,
    );
    final passedId = quiz.current!.id;
    quiz.passQuestion();
    final firstRemaining = quiz.current!.id;
    quiz.passQuestion();
    final secondRemaining = quiz.current!.id;
    expect({firstRemaining, secondRemaining}, isNot(contains(passedId)));
    quiz.passQuestion();
    expect({
      passedId,
      firstRemaining,
      secondRemaining,
    }, contains(quiz.current!.id));
  });

  test('Excel export imports all supported vocabulary fields', () {
    final source = Vocabulary(
      id: 1,
      hanzi: '谢谢',
      traditionalHanzi: '謝謝',
      pinyin: 'xiè xie',
      zhuyin: 'ㄒㄧㄝˋ ˙ㄒㄧㄝ',
      meaning: 'thank you',
      category: 'HSK 1',
    );
    final imported = ExcelService.importXlsx(ExcelService.exportXlsx([source]));
    expect(imported.skippedCount, 0);
    expect(
      imported.vocabs.single.toMap(),
      containsPair('traditionalHanzi', '謝謝'),
    );
    expect(imported.vocabs.single.zhuyin, 'ㄒㄧㄝˋ ˙ㄒㄧㄝ');
  });

  test('CSV export imports all supported vocabulary fields', () {
    final source = Vocabulary(
      id: 1,
      hanzi: '谢谢',
      traditionalHanzi: '謝謝',
      pinyin: 'xiè xie',
      zhuyin: 'ㄒㄧㄝˋ ˙ㄒㄧㄝ',
      meaning: 'thank you',
      category: 'HSK 1',
    );
    final imported = ExcelService.importCsv(ExcelService.exportCsv([source]));
    expect(imported.vocabs.single.displayHanzi, '謝謝');
    expect(imported.vocabs.single.displayPronunciation, 'xiè xie');
  });

  test('CSV accepts case-insensitive BOM headers', () {
    final imported = ExcelService.importCsv(
      '﻿HANZI,MEANING,PINYIN\n你好,hello,nǐ hǎo\n'.codeUnits,
    );
    expect(imported.vocabs.single.meaning, 'hello');
  });

  test('Excel template has two valid example rows', () {
    final template = ExcelService.importXlsx(ExcelService.createTemplate());
    expect(template.vocabs, hasLength(3));
    expect(template.skippedCount, 0);
  });
}
