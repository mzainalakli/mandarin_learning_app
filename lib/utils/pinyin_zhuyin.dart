const _pinyinToZhuyin = {
  'a': 'ㄚ', 'ai': 'ㄞ', 'an': 'ㄢ', 'ang': 'ㄤ', 'ao': 'ㄠ',
  'ba': 'ㄅㄚ', 'bai': 'ㄅㄞ', 'ban': 'ㄅㄢ', 'bang': 'ㄅㄤ', 'bao': 'ㄅㄠ', 'bei': 'ㄅㄟ', 'ben': 'ㄅㄣ', 'beng': 'ㄅㄥ', 'bi': 'ㄅㄧ', 'bian': 'ㄅㄧㄢ', 'biao': 'ㄅㄧㄠ', 'bie': 'ㄅㄧㄝ', 'bin': 'ㄅㄧㄣ', 'bing': 'ㄅㄧㄥ', 'bo': 'ㄅㄛ', 'bu': 'ㄅㄨ',
  'ca': 'ㄘㄚ', 'cai': 'ㄘㄞ', 'can': 'ㄘㄢ', 'cang': 'ㄘㄤ', 'cao': 'ㄘㄠ', 'ce': 'ㄘㄜ', 'cen': 'ㄘㄣ', 'ceng': 'ㄘㄥ', 'cha': 'ㄔㄚ', 'chai': 'ㄔㄞ', 'chan': 'ㄔㄢ', 'chang': 'ㄔㄤ', 'chao': 'ㄔㄠ', 'che': 'ㄔㄜ', 'chen': 'ㄔㄣ', 'cheng': 'ㄔㄥ', 'chi': 'ㄔ', 'chong': 'ㄔㄨㄥ', 'chou': 'ㄔㄡ', 'chu': 'ㄔㄨ', 'chua': 'ㄔㄨㄚ', 'chuai': 'ㄔㄨㄞ', 'chuan': 'ㄔㄨㄢ', 'chuang': 'ㄔㄨㄤ', 'chui': 'ㄔㄨㄟ', 'chun': 'ㄔㄨㄣ', 'chuo': 'ㄔㄨㄛ',
  'da': 'ㄉㄚ', 'dai': 'ㄉㄞ', 'dan': 'ㄉㄢ', 'dang': 'ㄉㄤ', 'dao': 'ㄉㄠ', 'de': 'ㄉㄜ', 'dei': 'ㄉㄟ', 'den': 'ㄉㄣ', 'deng': 'ㄉㄥ', 'di': 'ㄉㄧ', 'dia': 'ㄉㄧㄚ', 'dian': 'ㄉㄧㄢ', 'diao': 'ㄉㄧㄠ', 'die': 'ㄉㄧㄝ', 'ding': 'ㄉㄧㄥ', 'diu': 'ㄉㄧㄡ', 'dong': 'ㄉㄨㄥ', 'dou': 'ㄉㄡ', 'du': 'ㄉㄨ', 'duan': 'ㄉㄨㄢ', 'dui': 'ㄉㄨㄟ', 'dun': 'ㄉㄨㄣ', 'duo': 'ㄉㄨㄛ',
  'e': 'ㄜ', 'ei': 'ㄟ', 'en': 'ㄣ', 'eng': 'ㄥ', 'er': 'ㄦ',
  'fa': 'ㄈㄚ', 'fan': 'ㄈㄢ', 'fang': 'ㄈㄤ', 'fei': 'ㄈㄟ', 'fen': 'ㄈㄣ', 'feng': 'ㄈㄥ', 'fo': 'ㄈㄛ', 'fou': 'ㄈㄡ', 'fu': 'ㄈㄨ',
  'ga': 'ㄍㄚ', 'gai': 'ㄍㄞ', 'gan': 'ㄍㄢ', 'gang': 'ㄍㄤ', 'gao': 'ㄍㄠ', 'ge': 'ㄍㄜ', 'gei': 'ㄍㄟ', 'gen': 'ㄍㄣ', 'geng': 'ㄍㄥ', 'gong': 'ㄍㄨㄥ', 'gou': 'ㄍㄡ', 'gu': 'ㄍㄨ', 'gua': 'ㄍㄨㄚ', 'guai': 'ㄍㄨㄞ', 'guan': 'ㄍㄨㄢ', 'guang': 'ㄍㄨㄤ', 'gui': 'ㄍㄨㄟ', 'gun': 'ㄍㄨㄣ', 'guo': 'ㄍㄨㄛ',
  'ha': 'ㄏㄚ', 'hai': 'ㄏㄞ', 'han': 'ㄏㄢ', 'hang': 'ㄏㄤ', 'hao': 'ㄏㄠ', 'he': 'ㄏㄜ', 'hei': 'ㄏㄟ', 'hen': 'ㄏㄣ', 'heng': 'ㄏㄥ', 'hong': 'ㄏㄨㄥ', 'hou': 'ㄏㄡ', 'hu': 'ㄏㄨ', 'hua': 'ㄏㄨㄚ', 'huai': 'ㄏㄨㄞ', 'huan': 'ㄏㄨㄢ', 'huang': 'ㄏㄨㄤ', 'hui': 'ㄏㄨㄟ', 'hun': 'ㄏㄨㄣ', 'huo': 'ㄏㄨㄛ',
  'ji': 'ㄐㄧ', 'jia': 'ㄐㄧㄚ', 'jian': 'ㄐㄧㄢ', 'jiang': 'ㄐㄧㄤ', 'jiao': 'ㄐㄧㄠ', 'jie': 'ㄐㄧㄝ', 'jin': 'ㄐㄧㄣ', 'jing': 'ㄐㄧㄥ', 'jiong': 'ㄐㄧㄨㄥ', 'jiu': 'ㄐㄧㄡ', 'ju': 'ㄐㄩ', 'juan': 'ㄐㄩㄢ', 'jue': 'ㄐㄩㄝ', 'jun': 'ㄐㄩㄣ',
  'ka': 'ㄎㄚ', 'kai': 'ㄎㄞ', 'kan': 'ㄎㄢ', 'kang': 'ㄎㄤ', 'kao': 'ㄎㄠ', 'ke': 'ㄎㄜ', 'kei': 'ㄎㄟ', 'ken': 'ㄎㄣ', 'keng': 'ㄎㄥ', 'kong': 'ㄎㄨㄥ', 'kou': 'ㄎㄡ', 'ku': 'ㄎㄨ', 'kua': 'ㄎㄨㄚ', 'kuai': 'ㄎㄨㄞ', 'kuan': 'ㄎㄨㄢ', 'kuang': 'ㄎㄨㄤ', 'kui': 'ㄎㄨㄟ', 'kun': 'ㄎㄨㄣ', 'kuo': 'ㄎㄨㄛ',
  'la': 'ㄌㄚ', 'lai': 'ㄌㄞ', 'lan': 'ㄌㄢ', 'lang': 'ㄌㄤ', 'lao': 'ㄌㄠ', 'le': 'ㄌㄜ', 'lei': 'ㄌㄟ', 'leng': 'ㄌㄥ', 'li': 'ㄌㄧ', 'lia': 'ㄌㄧㄚ', 'lian': 'ㄌㄧㄢ', 'liang': 'ㄌㄧㄤ', 'liao': 'ㄌㄧㄠ', 'lie': 'ㄌㄧㄝ', 'lin': 'ㄌㄧㄣ', 'ling': 'ㄌㄧㄥ', 'liu': 'ㄌㄧㄡ', 'lo': 'ㄌㄛ', 'long': 'ㄌㄨㄥ', 'lou': 'ㄌㄡ', 'lu': 'ㄌㄨ', 'luan': 'ㄌㄨㄢ', 'lue': 'ㄌㄨㄝ', 'lun': 'ㄌㄨㄣ', 'luo': 'ㄌㄨㄛ', 'lv': 'ㄌㄩ', 'lve': 'ㄌㄩㄝ',
  'ma': 'ㄇㄚ', 'mai': 'ㄇㄞ', 'man': 'ㄇㄢ', 'mang': 'ㄇㄤ', 'mao': 'ㄇㄠ', 'me': 'ㄇㄜ', 'mei': 'ㄇㄟ', 'men': 'ㄇㄣ', 'meng': 'ㄇㄥ', 'mi': 'ㄇㄧ', 'mian': 'ㄇㄧㄢ', 'miao': 'ㄇㄧㄠ', 'mie': 'ㄇㄧㄝ', 'min': 'ㄇㄧㄣ', 'ming': 'ㄇㄧㄥ', 'miu': 'ㄇㄧㄡ', 'mo': 'ㄇㄛ', 'mou': 'ㄇㄡ', 'mu': 'ㄇㄨ',
  'na': 'ㄋㄚ', 'nai': 'ㄋㄞ', 'nan': 'ㄋㄢ', 'nang': 'ㄋㄤ', 'nao': 'ㄋㄠ', 'ne': 'ㄋㄜ', 'nei': 'ㄋㄟ', 'nen': 'ㄋㄣ', 'neng': 'ㄋㄥ', 'ni': 'ㄋㄧ', 'nian': 'ㄋㄧㄢ', 'niang': 'ㄋㄧㄤ', 'niao': 'ㄋㄧㄠ', 'nie': 'ㄋㄧㄝ', 'nin': 'ㄋㄧㄣ', 'ning': 'ㄋㄧㄥ', 'niu': 'ㄋㄧㄡ', 'nong': 'ㄋㄨㄥ', 'nou': 'ㄋㄡ', 'nu': 'ㄋㄨ', 'nuan': 'ㄋㄨㄢ', 'nue': 'ㄋㄨㄝ', 'nuo': 'ㄋㄨㄛ', 'nv': 'ㄋㄩ', 'nve': 'ㄋㄩㄝ',
  'o': 'ㄛ', 'ou': 'ㄡ',
  'pa': 'ㄆㄚ', 'pai': 'ㄆㄞ', 'pan': 'ㄆㄢ', 'pang': 'ㄆㄤ', 'pao': 'ㄆㄠ', 'pei': 'ㄆㄟ', 'pen': 'ㄆㄣ', 'peng': 'ㄆㄥ', 'pi': 'ㄆㄧ', 'pian': 'ㄆㄧㄢ', 'piao': 'ㄆㄧㄠ', 'pie': 'ㄆㄧㄝ', 'pin': 'ㄆㄧㄣ', 'ping': 'ㄆㄧㄥ', 'po': 'ㄆㄛ', 'pou': 'ㄆㄡ', 'pu': 'ㄆㄨ',
  'qi': 'ㄑㄧ', 'qia': 'ㄑㄧㄚ', 'qian': 'ㄑㄧㄢ', 'qiang': 'ㄑㄧㄤ', 'qiao': 'ㄑㄧㄠ', 'qie': 'ㄑㄧㄝ', 'qin': 'ㄑㄧㄣ', 'qing': 'ㄑㄧㄥ', 'qiong': 'ㄑㄧㄨㄥ', 'qiu': 'ㄑㄧㄡ', 'qu': 'ㄑㄩ', 'quan': 'ㄑㄩㄢ', 'que': 'ㄑㄩㄝ', 'qun': 'ㄑㄩㄣ',
  'ran': 'ㄖㄢ', 'rang': 'ㄖㄤ', 'rao': 'ㄖㄠ', 're': 'ㄖㄜ', 'ren': 'ㄖㄣ', 'reng': 'ㄖㄥ', 'ri': 'ㄖ', 'rong': 'ㄖㄨㄥ', 'rou': 'ㄖㄡ', 'ru': 'ㄖㄨ', 'rua': 'ㄖㄨㄚ', 'ruan': 'ㄖㄨㄢ', 'rui': 'ㄖㄨㄟ', 'run': 'ㄖㄨㄣ', 'ruo': 'ㄖㄨㄛ',
  'sa': 'ㄙㄚ', 'sai': 'ㄙㄞ', 'san': 'ㄙㄢ', 'sang': 'ㄙㄤ', 'sao': 'ㄙㄠ', 'se': 'ㄙㄜ', 'sen': 'ㄙㄣ', 'seng': 'ㄙㄥ', 'sha': 'ㄕㄚ', 'shai': 'ㄕㄞ', 'shan': 'ㄕㄢ', 'shang': 'ㄕㄤ', 'shao': 'ㄕㄠ', 'she': 'ㄕㄜ', 'shen': 'ㄕㄣ', 'sheng': 'ㄕㄥ', 'shi': 'ㄕ', 'shou': 'ㄕㄡ', 'shu': 'ㄕㄨ', 'shua': 'ㄕㄨㄚ', 'shuai': 'ㄕㄨㄞ', 'shuan': 'ㄕㄨㄢ', 'shuang': 'ㄕㄨㄤ', 'shui': 'ㄕㄨㄟ', 'shun': 'ㄕㄨㄣ', 'shuo': 'ㄕㄨㄛ', 'si': 'ㄙ', 'song': 'ㄙㄨㄥ', 'sou': 'ㄙㄡ', 'su': 'ㄙㄨ', 'suan': 'ㄙㄨㄢ', 'sui': 'ㄙㄨㄟ', 'sun': 'ㄙㄨㄣ', 'suo': 'ㄙㄨㄛ',
  'ta': 'ㄊㄚ', 'tai': 'ㄊㄞ', 'tan': 'ㄊㄢ', 'tang': 'ㄊㄤ', 'tao': 'ㄊㄠ', 'te': 'ㄊㄜ', 'teng': 'ㄊㄥ', 'ti': 'ㄊㄧ', 'tian': 'ㄊㄧㄢ', 'tiao': 'ㄊㄧㄠ', 'tie': 'ㄊㄧㄝ', 'ting': 'ㄊㄧㄥ', 'tong': 'ㄊㄨㄥ', 'tou': 'ㄊㄡ', 'tu': 'ㄊㄨ', 'tuan': 'ㄊㄨㄢ', 'tui': 'ㄊㄨㄟ', 'tun': 'ㄊㄨㄣ', 'tuo': 'ㄊㄨㄛ',
  'wa': 'ㄨㄚ', 'wai': 'ㄨㄞ', 'wan': 'ㄨㄢ', 'wang': 'ㄨㄤ', 'wei': 'ㄨㄟ', 'wen': 'ㄨㄣ', 'weng': 'ㄨㄥ', 'wo': 'ㄨㄛ', 'wu': 'ㄨ',
  'xi': 'ㄒㄧ', 'xia': 'ㄒㄧㄚ', 'xian': 'ㄒㄧㄢ', 'xiang': 'ㄒㄧㄤ', 'xiao': 'ㄒㄧㄠ', 'xie': 'ㄒㄧㄝ', 'xin': 'ㄒㄧㄣ', 'xing': 'ㄒㄧㄥ', 'xiong': 'ㄒㄧㄨㄥ', 'xiu': 'ㄒㄧㄡ', 'xu': 'ㄒㄩ', 'xuan': 'ㄒㄩㄢ', 'xue': 'ㄒㄩㄝ', 'xun': 'ㄒㄩㄣ',
  'ya': 'ㄧㄚ', 'yan': 'ㄧㄢ', 'yang': 'ㄧㄤ', 'yao': 'ㄧㄠ', 'ye': 'ㄧㄝ', 'yi': 'ㄧ', 'yin': 'ㄧㄣ', 'ying': 'ㄧㄥ', 'yo': 'ㄧㄛ', 'yong': 'ㄧㄨㄥ', 'you': 'ㄧㄡ', 'yu': 'ㄩ', 'yuan': 'ㄩㄢ', 'yue': 'ㄩㄝ', 'yun': 'ㄩㄣ',
  'za': 'ㄗㄚ', 'zai': 'ㄗㄞ', 'zan': 'ㄗㄢ', 'zang': 'ㄗㄤ', 'zao': 'ㄗㄠ', 'ze': 'ㄗㄜ', 'zei': 'ㄗㄟ', 'zen': 'ㄗㄣ', 'zeng': 'ㄗㄥ', 'zha': 'ㄓㄚ', 'zhai': 'ㄓㄞ', 'zhan': 'ㄓㄢ', 'zhang': 'ㄓㄤ', 'zhao': 'ㄓㄠ', 'zhe': 'ㄓㄜ', 'zhen': 'ㄓㄣ', 'zheng': 'ㄓㄥ', 'zhi': 'ㄓ', 'zhong': 'ㄓㄨㄥ', 'zhou': 'ㄓㄡ', 'zhu': 'ㄓㄨ', 'zhua': 'ㄓㄨㄚ', 'zhuai': 'ㄓㄨㄞ', 'zhuan': 'ㄓㄨㄢ', 'zhuang': 'ㄓㄨㄤ', 'zhui': 'ㄓㄨㄟ', 'zhun': 'ㄓㄨㄣ', 'zhuo': 'ㄓㄨㄛ', 'zi': 'ㄗ', 'zong': 'ㄗㄨㄥ', 'zou': 'ㄗㄡ', 'zu': 'ㄗㄨ', 'zuan': 'ㄗㄨㄢ', 'zui': 'ㄗㄨㄟ', 'zun': 'ㄗㄨㄣ', 'zuo': 'ㄗㄨㄛ',
};

const _toneMarks = {'1': '', '2': 'ˊ', '3': 'ˇ', '4': 'ˋ', '5': '˙'};

String pinyinToZhuyin(String pinyin) {
  if (pinyin.trim().isEmpty) return '';
  try {
    final syllables = pinyin.trim().toLowerCase().split(RegExp(r'\s+'));
    final result = <String>[];

    for (final syllable in syllables) {
      if (syllable.isEmpty) continue;
      final zhuyinSyllable = _convertSyllable(syllable);
      result.add(zhuyinSyllable);
    }

    return result.join(' ');
  } catch (_) {
    return pinyin; // Safe fallback instead of throwing
  }
}

String _convertSyllable(String syllable) {
  String tone = '1'; // Default to first tone when no explicit tone given
  String base = syllable;

  if (RegExp(r'[12345]$').hasMatch(syllable)) {
    tone = syllable[syllable.length - 1];
    base = syllable.substring(0, syllable.length - 1);
  } else {
    final toneMatch = RegExp(r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]').firstMatch(syllable);
    if (toneMatch != null) {
      final toneChar = toneMatch.group(0)!;
      final toneMap = {
        'ā': '1', 'á': '2', 'ǎ': '3', 'à': '4',
        'ē': '1', 'é': '2', 'ě': '3', 'è': '4',
        'ī': '1', 'í': '2', 'ǐ': '3', 'ì': '4',
        'ō': '1', 'ó': '2', 'ǒ': '3', 'ò': '4',
        'ū': '1', 'ú': '2', 'ǔ': '3', 'ù': '4',
        'ǖ': '1', 'ǘ': '2', 'ǚ': '3', 'ǜ': '4',
      };
      tone = toneMap[toneChar] ?? '1';
      base = syllable.replaceAll(toneChar, _stripTone(toneChar));
    }
  }

  base = base
      .replaceAll('ü', 'v')
      .replaceAll('Ü', 'v')
      .replaceAll('ǖ', 'v')
      .replaceAll('ǘ', 'v')
      .replaceAll('ǚ', 'v')
      .replaceAll('ǜ', 'v');

  String zhuyin;
  if (_pinyinToZhuyin.containsKey(base)) {
    zhuyin = _pinyinToZhuyin[base]!;
  } else {
    zhuyin = _fallbackConvert(base);
  }

  if (tone == '5') {
    zhuyin = '˙$zhuyin';
  } else if (tone != '1') {
    zhuyin += _toneMarks[tone]!;
  }

  return zhuyin;
}

String _stripTone(String char) {
  return switch (char) {
    'ā' => 'a', 'á' => 'a', 'ǎ' => 'a', 'à' => 'a',
    'ē' => 'e', 'é' => 'e', 'ě' => 'e', 'è' => 'e',
    'ī' => 'i', 'í' => 'i', 'ǐ' => 'i', 'ì' => 'i',
    'ō' => 'o', 'ó' => 'o', 'ǒ' => 'o', 'ò' => 'o',
    'ū' => 'u', 'ú' => 'u', 'ǔ' => 'u', 'ù' => 'u',
    'ǖ' => 'v', 'ǘ' => 'v', 'ǚ' => 'v', 'ǜ' => 'v',
    _ => char,
  };
}

String _fallbackConvert(String base) {
  const initials = {
    'b': 'ㄅ', 'p': 'ㄆ', 'm': 'ㄇ', 'f': 'ㄈ',
    'd': 'ㄉ', 't': 'ㄊ', 'n': 'ㄋ', 'l': 'ㄌ',
    'g': 'ㄍ', 'k': 'ㄎ', 'h': 'ㄏ',
    'j': 'ㄐ', 'q': 'ㄑ', 'x': 'ㄒ',
    'zh': 'ㄓ', 'ch': 'ㄔ', 'sh': 'ㄕ', 'r': 'ㄖ',
    'z': 'ㄗ', 'c': 'ㄘ', 's': 'ㄙ',
    'y': 'ㄧ', 'w': 'ㄨ',
  };
  const finals = {
    'a': 'ㄚ', 'ai': 'ㄞ', 'an': 'ㄢ', 'ang': 'ㄤ', 'ao': 'ㄠ',
    'e': 'ㄜ', 'ei': 'ㄟ', 'en': 'ㄣ', 'eng': 'ㄥ', 'er': 'ㄦ',
    'i': 'ㄧ', 'ia': 'ㄧㄚ', 'ian': 'ㄧㄢ', 'iang': 'ㄧㄤ', 'iao': 'ㄧㄠ', 'ie': 'ㄧㄝ', 'in': 'ㄧㄣ', 'ing': 'ㄧㄥ', 'iong': 'ㄧㄨㄥ',
    'o': 'ㄛ', 'ou': 'ㄡ',
    'u': 'ㄨ', 'ua': 'ㄨㄚ', 'uai': 'ㄨㄞ', 'uan': 'ㄨㄢ', 'uang': 'ㄨㄤ', 'ui': 'ㄨㄟ', 'un': 'ㄨㄣ', 'uo': 'ㄨㄛ',
    'v': 'ㄩ', 've': 'ㄩㄝ', 'van': 'ㄩㄢ',
  };

  if (base.isEmpty) return '';

  final clean = base.trim().toLowerCase();
  if (clean.isEmpty) return '';

  for (var len = 3; len >= 1; len--) {
    if (clean.length < len) continue;
    if (initials.containsKey(clean.substring(0, len))) {
      final initial = initials[clean.substring(0, len)]!;
      final rest = clean.substring(len);
      if (finals.containsKey(rest)) {
        return initial + finals[rest]!;
      }
      if (rest.isEmpty) return initial;
    }
  }

  if (finals.containsKey(clean)) return finals[clean]!;

  return clean.split('').map((c) => _pinyinToZhuyin[c] ?? c).join('');
}