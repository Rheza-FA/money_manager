import '../models/shared_receipt.dart';

/// Deterministic, offline, app-agnostic semantic & linguistic receipt parser
/// for Indonesian and international payment receipts (QRIS, BCA/myBCA, GoPay,
/// BRImo, Livin' Mandiri, DANA, OVO, ShopeePay, SeaBank, Bank Jago, blu,
/// BNI/wondr, BSI/BYOND, CIMB OCTO, Permata, BTN, LinkAja, Jenius, Flip, POS,
/// and generic transfer/payment proofs).
class ReceiptParser {
  const ReceiptParser._();

  static ParsedReceipt parse(
    SharedReceiptPayload payload, {
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();

    final List<String> lines = _collectCleanLines(payload);
    final ({String label, String? provider, bool isQris}) source =
        _detectSource(
      lines: lines,
      referrer: payload.referrer,
      rawExtraText: payload.extraText,
      rawExtraSubject: payload.extraSubject,
    );

    final bool isLikelyIncoming = _detectIncoming(lines);
    final double? totalAmount = _extractBestAmount(lines);
    final ({DateTime date, bool explicit}) dateResult =
        _extractDateTime(lines, clock);
    final _QuantityExtraction rawQtyInfo = _extractQuantityInfo(lines);
    final ({
      String primary,
      List<String> candidates,
      String? noteName,
    }) names = _extractNames(
      lines: lines,
      provider: source.provider,
      isQris: source.isQris,
      isIncoming: isLikelyIncoming,
      itemizedName: rawQtyInfo.singleItemName,
    );

    final int? noteMultiplierQty = (rawQtyInfo.quantity == null &&
            !rawQtyInfo.hasMultipleDistinctItems &&
            names.noteName != null)
        ? _extractMultiplierFromNote(names.noteName!)
        : null;
    final _QuantityExtraction qtyInfo = noteMultiplierQty != null
        ? _QuantityExtraction(
            quantity: noteMultiplierQty,
            explicitUnitPrice: null,
            singleItemName: null,
            hasMultipleDistinctItems: false,
          )
        : rawQtyInfo;

    final ({int quantity, double? unitPrice}) reconciled =
        _reconcileQuantityAndUnitPrice(
      totalAmount: totalAmount,
      qtyInfo: qtyInfo,
    );

    String finalPrimary = names.primary;
    List<String> finalCandidates = names.candidates;
    if (reconciled.quantity > 1 && finalPrimary.isNotEmpty) {
      finalPrimary = _stripMultiplierAffix(finalPrimary);
      final List<String> strippedCandidates = <String>[];
      for (final String c in names.candidates) {
        final String stripped = _stripMultiplierAffix(c);
        if (stripped.isNotEmpty &&
            !strippedCandidates.any(
              (existing) => existing.toLowerCase() == stripped.toLowerCase(),
            )) {
          strippedCandidates.add(stripped);
        }
      }
      finalCandidates = strippedCandidates;
    }

    return ParsedReceipt(
      itemName: finalPrimary,
      nameCandidates: finalCandidates,
      amount: reconciled.unitPrice,
      quantity: reconciled.quantity,
      date: dateResult.date,
      hasExplicitDate: dateResult.explicit,
      sourceLabel: source.label,
      isQris: source.isQris,
      isLikelyIncoming: isLikelyIncoming,
      rawPreviewLines: List<String>.unmodifiable(
        lines.take(28).toList(growable: false),
      ),
    );
  }

  /// Resolves a clean source badge (e.g. `GoPay`, `BRImo`, `BCA`) from
  /// referrer and optional share metadata even when image OCR failed.
  static String detectSourceLabel({
    String? referrer,
    String? extraText,
    String? extraSubject,
  }) {
    return _detectSource(
      lines: const <String>[],
      referrer: referrer,
      rawExtraText: extraText,
      rawExtraSubject: extraSubject,
    ).label;
  }

  // ---------------------------------------------------------------------------
  // 1. Line Collection, Share-Wrapper Sanitization & Watermark Noise Filtering
  // ---------------------------------------------------------------------------

  static final RegExp _controlChars =
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u200B-\u200F\uFEFF]');
  static final RegExp _multiSpace = RegExp(r'[ \t]{2,}');
  static final RegExp _anyDigit = RegExp(r'[0-9]');

  /// Matches inline URLs (`https://...`, `http://...`, or trailing `https://`
  /// broken across lines by share captions).
  static final RegExp _urlInlineRegex = RegExp(
    r'https?://\S*',
    caseSensitive: false,
  );

  /// Matches standalone wrapped domain/shortlink lines (e.g.
  /// `app.gopay.co.id/NF8p/x3fpwee1` or `link.dana.id/m/...`).
  static final RegExp _wrappedDomainLineRegex = RegExp(
    r'^(?:[a-z0-9-]+\.)+(?:co\.id|or\.id|ac\.id|go\.id|id|com|net|org|io|app|me|link)(?:/\S*)?$',
    caseSensitive: false,
  );

  /// Matches conversational social/share-caption boilerplate attached by
  /// e-wallets/banks in `Intent.EXTRA_TEXT`.
  static final RegExp _shareWrapperNoiseRegex = RegExp(
    r'\b(hai,?\s*ini\s+bukti\s+transaksinya|buat\s+rincian\s+lebih\s+lanjut|bisa\s+cek\s+di\s+app|cek\s+rincian\s+transaksi\s+di|berikut\s+(?:adalah\s+)?bukti\s+transaksi|ini\s+bukti\s+(?:transaksi|pembayaran)(?:nya)?\s+ya|unduh\s+aplikasi|download\s+aplikasi|check\s+out\s+this\s+receipt|view\s+more\s+details\s+in\s+the\s+app)\b',
    caseSensitive: false,
  );

  static const Set<String> _knownVowellessTokens = <String>{
    // Business / legal / honorific prefixes & suffixes
    'PT',
    'CV',
    'UD',
    'TB',
    'RM',
    'PD',
    'FA',
    'HJ',
    'DR',
    'IR',
    'NY',
    'TN',
    'BP',
    'KH',
    'ST',
    'SH',
    'MH',
    'MM',
    'MT',
    'RS',
    'TK',
    'SD',
    'SMP',
    'SMA',
    'SMK',
    'TBK',
    // Financial / receipt / infrastructure / merchant acronyms
    'RP',
    'IDR',
    'QTY',
    'PC',
    'PCS',
    'QRIS',
    'NMID',
    'MPAN',
    'RRN',
    'STAN',
    'WIB',
    'WITA',
    'WIT',
    'CR',
    'DB',
    'VA',
    'ATM',
    'EDC',
    'BCA',
    'BRI',
    'BNI',
    'BSI',
    'BTN',
    'BJB',
    'BTPN',
    'SMBC',
    'CIMB',
    'OCBC',
    'HSBC',
    'KFC',
    'MCD',
    'XXI',
    'CGV',
    'MRT',
    'KRL',
    'LRT',
    'PLN',
    'BPJS',
    'PDAM',
    'SPBU',
    'JNE',
    'JNT',
    'POS',
    'SMS',
    'TV',
    'HP',
    'SIM',
    'STNK',
    'PBB',
    'PKB',
    'DKI',
    'DIY',
  };

  static const Set<String> _watermarkBrandTokens = <String>{
    'bri',
    'brimo',
    'bca',
    'mybca',
    'bni',
    'wondr',
    'mandiri',
    'livin',
    'bsi',
    'btn',
    'dana',
    'ovo',
    'gopay',
    'shopeepay',
    'seabank',
    'jago',
    'blu',
    'flip',
    'qris',
  };

  static final RegExp _vowelRegex = RegExp(r'[aiueoyAIUEOY]');
  static final RegExp _alphaWordRegex = RegExp(r'[A-Za-z]+');
  static final RegExp _compactBrandRegex = RegExp(
    r'^(?:[A-Za-z]&[A-Za-z]{1,2}|J\.?CO|D[\x27’]COST|7[\s-]*ELEVEN)$',
    caseSensitive: false,
  );
  static final RegExp _repeatedSingleCharRegex = RegExp(r'^([a-zA-Z])\1+$');
  static final RegExp _longConsonantClusterRegex =
      RegExp(r'[bcdfghjklmnpqrstvwxzBCDFGHJKLMNPQRSTVWXZ]{6,}');

  /// Linguistically detects OCR watermark/logo/guilloche gibberish such as
  /// `"bn br a bb"`, `"bn bri a bb"`, `"br bn"`, `"ii ll oo"`, or `"BRI BRI BRI"`
  /// while preserving legitimate Indonesian & English names, initials, and
  /// business acronyms (`PT`, `RM`, `KFC`, `PLN`, `M. Rizky`, `Warung Bu Sri`).
  static bool isGibberishOrWatermark(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    if (_compactBrandRegex.hasMatch(trimmed)) return false;

    final List<String> words = _alphaWordRegex
        .allMatches(trimmed)
        .map((Match m) => m.group(0)!)
        .toList(growable: false);
    if (words.isEmpty) return true;

    int totalAlpha = 0;
    int vowellessGarbageCount = 0;
    int repeatedCharNoiseCount = 0;
    int microWordCount = 0;
    int solidWordCount = 0;
    final Map<String, int> freq = <String, int>{};

    for (int i = 0; i < words.length; i++) {
      final String w = words[i];
      final String up = w.toUpperCase();
      final String low = w.toLowerCase();
      totalAlpha += w.length;
      freq[low] = (freq[low] ?? 0) + 1;

      if (w.length <= 2) {
        microWordCount++;
      }

      if (_repeatedSingleCharRegex.hasMatch(w)) {
        repeatedCharNoiseCount++;
        vowellessGarbageCount++;
        continue;
      }

      final bool knownToken = _knownVowellessTokens.contains(up);
      final bool hasVowel = _vowelRegex.hasMatch(w);

      if (w.length >= 2 && !hasVowel && !knownToken) {
        vowellessGarbageCount++;
        continue;
      }

      if (w.length >= 6 && _longConsonantClusterRegex.hasMatch(w)) {
        vowellessGarbageCount++;
        continue;
      }

      if ((w.length >= 3 && hasVowel) || knownToken) {
        solidWordCount++;
      }
    }

    if (totalAlpha < 2) return true;

    // 1. Vowelless consonant-cluster artifacts (`bn`, `br`, `bb`, `qwrt`)
    if (vowellessGarbageCount >= 2) return true;
    if (vowellessGarbageCount == 1 && words.length <= 2) return true;
    if (repeatedCharNoiseCount >= 1 && solidWordCount == 0) return true;
    if ((vowellessGarbageCount + repeatedCharNoiseCount) >= 1 &&
        microWordCount * 2 >= words.length) {
      return true;
    }

    // 2. Repeating diagonal watermark tokens (`BRI BRI`, `BCA BCA BCA`)
    if (words.length >= 2) {
      for (int i = 1; i < words.length; i++) {
        final String prev = words[i - 1].toLowerCase();
        final String curr = words[i].toLowerCase();
        if (prev == curr &&
            (_watermarkBrandTokens.contains(curr) || curr.length <= 3)) {
          return true;
        }
      }
    }
    if (words.length >= 3) {
      final int maxFreq =
          freq.values.fold<int>(0, (int m, int v) => v > m ? v : m);
      if (maxFreq >= 2 && maxFreq * 5 >= words.length * 3) {
        final String dominant =
            freq.entries.firstWhere((e) => e.value == maxFreq).key;
        if (_watermarkBrandTokens.contains(dominant) || dominant.length <= 3) {
          return true;
        }
      }
    }

    // 3. Fragmented micro-token soup (`a b c`, `bn bri a bb`, `bi ba bo`)
    if (words.length >= 3) {
      final bool allMicro = words.every((String w) => w.length <= 2);
      if (allMicro &&
          !words.every(
            (String w) => _knownVowellessTokens.contains(w.toUpperCase()),
          )) {
        return true;
      }
      if (microWordCount * 4 >= words.length * 3 && solidWordCount <= 1) {
        return true;
      }
    }

    if (words.length == 1 &&
        words.first.length < 2 &&
        !_knownVowellessTokens.contains(words.first.toUpperCase())) {
      return true;
    }

    return false;
  }

  static List<String> _collectCleanLines(SharedReceiptPayload payload) {
    final List<String> raw = <String>[];
    final bool hasOcr = payload.ocrLines.isNotEmpty;

    void appendSanitizedBlock(String? text, {required bool isWrapperMetadata}) {
      if (text == null || text.isEmpty) return;

      // Strip full URLs before splitting lines so wrapped URLs don't leave fragments.
      final String withoutUrls = text.replaceAll(_urlInlineRegex, ' ');

      for (final String rawLine in withoutUrls.split(RegExp(r'\r?\n'))) {
        final String cleaned = rawLine
            .replaceAll(_controlChars, '')
            .replaceAll('\u00A0', ' ')
            .trim();
        if (cleaned.isEmpty) continue;
        if (_wrappedDomainLineRegex.hasMatch(cleaned)) continue;
        if (_shareWrapperNoiseRegex.hasMatch(cleaned)) continue;

        if (isWrapperMetadata && hasOcr) {
          // When OCR succeeded on an attached image/PDF, ignore extraText/subject
          // unless a line explicitly carries a structured currency value.
          if (!_currencyAmountRegex.hasMatch(cleaned)) {
            continue;
          }
        }

        // Strip pure watermark/logo OCR noise lines that contain no digits and
        // no key-value separator so they never pollute label-value adjacency.
        if (!_anyDigit.hasMatch(cleaned) &&
            !cleaned.contains(':') &&
            !_standaloneCurrencyToken.hasMatch(cleaned) &&
            !RegExp(r'^[-+]+$').hasMatch(cleaned) &&
            isGibberishOrWatermark(cleaned)) {
          continue;
        }

        raw.add(cleaned);
      }
    }

    for (final String line in payload.ocrLines) {
      appendSanitizedBlock(line, isWrapperMetadata: false);
    }
    appendSanitizedBlock(payload.extraSubject, isWrapperMetadata: true);
    appendSanitizedBlock(payload.extraText, isWrapperMetadata: true);

    final List<String> deduped = <String>[];
    for (final String line in raw) {
      if (deduped.length >= kMaxReceiptLines) break;
      final String normalized = line.replaceAll(_multiSpace, '  ');
      if (deduped.isEmpty ||
          deduped.last.toLowerCase() != normalized.toLowerCase()) {
        deduped.add(normalized);
      }
    }
    return deduped;
  }

  // ---------------------------------------------------------------------------
  // 2. Payment Provider & QRIS Instrument Detection
  // ---------------------------------------------------------------------------

  static const List<({String name, List<String> refKeys, List<String> textKeys})>
      _providers =
      <({String name, List<String> refKeys, List<String> textKeys})>[
    (
      name: 'BCA',
      refKeys: <String>['com.bca', 'mybca'],
      textKeys: <String>[
        'mybca',
        'm-bca',
        'm-transfer',
        'bca mobile',
        'halo bca',
        'pt bank central asia',
        'tahapan bca',
        'bca.co.id',
      ],
    ),
    (
      name: 'GoPay',
      refKeys: <String>['com.gojek', 'gopay'],
      textKeys: <String>[
        'gopay',
        'gopay saldo',
        'gopay tabungan',
        'gopaylater',
        'gopay.co.id',
        'gojek',
      ],
    ),
    (
      name: "Livin' Mandiri",
      refKeys: <String>['id.bmri.livin', 'bankmandiri'],
      textKeys: <String>[
        "livin' by mandiri",
        'livin by mandiri',
        'livin mandiri',
        'bank mandiri',
        'tabungan mandiri',
        'bankmandiri.co.id',
      ],
    ),
    (
      name: 'BRImo',
      refKeys: <String>['id.co.bri.brimo', 'bri.brimo', 'co.bri.brimo'],
      textKeys: <String>[
        'brimo',
        'bank rakyat indonesia',
        'bank bri',
        'bri.co.id',
        'sobri',
      ],
    ),
    (
      name: 'DANA',
      refKeys: <String>['id.dana'],
      textKeys: <String>[
        'saldo dana',
        'dana protection',
        'dana id',
        'bayar dengan dana',
        'dana.id',
      ],
    ),
    (
      name: 'OVO',
      refKeys: <String>['ovo.id'],
      textKeys: <String>[
        'ovo cash',
        'ovo points',
        'ovo id',
      ],
    ),
    (
      name: 'ShopeePay',
      refKeys: <String>['com.shopee', 'shopeepay'],
      textKeys: <String>[
        'shopeepay',
        'spaylater',
      ],
    ),
    (
      name: 'SeaBank',
      refKeys: <String>['seabank', 'bankbkemobile'],
      textKeys: <String>[
        'seabank',
        'bank seabank',
      ],
    ),
    (
      name: 'Bank Jago',
      refKeys: <String>['com.jago'],
      textKeys: <String>[
        'bank jago',
        'kantong jago',
        'kantong utama',
      ],
    ),
    (
      name: 'blu by BCA',
      refKeys: <String>['bcadigital.blu', 'bcadigital'],
      textKeys: <String>[
        'blu by bca',
        'bca digital',
        'bluaccount',
        'blusaving',
      ],
    ),
    (
      name: 'BNI',
      refKeys: <String>['src.com.bni', 'bni.wondr'],
      textKeys: <String>[
        'wondr by bni',
        'bni mobile',
        'bank negara indonesia',
      ],
    ),
    (
      name: 'BSI',
      refKeys: <String>['id.co.bankbsi', 'bsimobile', 'byond'],
      textKeys: <String>[
        'byond by bsi',
        'bsi mobile',
        'bank syariah indonesia',
      ],
    ),
    (
      name: 'CIMB Niaga',
      refKeys: <String>['cimbniaga', 'octomobile'],
      textKeys: <String>[
        'octo mobile',
        'octo clicks',
        'cimb niaga',
      ],
    ),
    (
      name: 'Permata',
      refKeys: <String>['permatamobilex', 'permatabank'],
      textKeys: <String>[
        'permata me',
        'permatamobile',
        'permatabank',
      ],
    ),
    (
      name: 'BTN',
      refKeys: <String>['id.co.btn', 'btn.bale'],
      textKeys: <String>[
        'bale by btn',
        'btn mobile',
        'bank tabungan negara',
      ],
    ),
    (
      name: 'LinkAja',
      refKeys: <String>['com.telkom.mwallet', 'linkaja'],
      textKeys: <String>[
        'linkaja',
        'saldo linkaja',
      ],
    ),
    (
      name: 'Jenius',
      refKeys: <String>['com.btpn.dc', 'jenius'],
      textKeys: <String>[
        'jenius',
        'smbc indonesia',
        'bank btpn',
      ],
    ),
    (
      name: 'Flip',
      refKeys: <String>['id.flip'],
      textKeys: <String>[
        'lentera inspirasi pertiwi',
        'flip id',
        'flip globe',
        'flip.id',
      ],
    ),
  ];

  static final RegExp _qrisPattern = RegExp(
    r'\b(qris|nmid|mpan)\b|pembayaran\s+qris|qris\s+(mpm|cpm)',
    caseSensitive: false,
  );

  static final RegExp _destinationBankPrefix = RegExp(
    r'\b(bank\s+tujuan|bank\s+penerima|ke\s+bank|tujuan\s+bank|beneficiary\s+bank|dompet\s+digital|top\s*up)\b',
    caseSensitive: false,
  );

  static ({String label, String? provider, bool isQris}) _detectSource({
    required List<String> lines,
    String? referrer,
    String? rawExtraText,
    String? rawExtraSubject,
  }) {
    String? detectedProvider;
    bool isQris = false;

    // 1. Authoritative package referrer from ShareReceiverActivity
    if (referrer != null && referrer.isNotEmpty) {
      final String lowerRef = referrer.toLowerCase();
      for (final p in _providers) {
        if (p.refKeys.any(lowerRef.contains)) {
          detectedProvider = p.name;
          break;
        }
      }
    }

    // 2. Score OCR lines
    final Map<String, int> scores = <String, int>{};
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final String lower = line.toLowerCase();

      if (!isQris && _qrisPattern.hasMatch(lower)) {
        isQris = true;
      }

      if (detectedProvider != null) continue;
      if (_destinationBankPrefix.hasMatch(lower)) continue;

      final int weight = i < 5 ? 4 : 1;
      for (final p in _providers) {
        if (p.textKeys.any(lower.contains)) {
          scores[p.name] = (scores[p.name] ?? 0) + weight;
        }
      }

      if (i < 5) {
        final String token = lower.trim();
        if (token == 'dana') scores['DANA'] = (scores['DANA'] ?? 0) + 5;
        if (token == 'ovo') scores['OVO'] = (scores['OVO'] ?? 0) + 5;
        if (token == 'bca') scores['BCA'] = (scores['BCA'] ?? 0) + 5;
        if (token == 'bri' || token == 'brimo') {
          scores['BRImo'] = (scores['BRImo'] ?? 0) + 5;
        }
        if (token == 'jago') {
          scores['Bank Jago'] = (scores['Bank Jago'] ?? 0) + 5;
        }
        if (token == 'wondr') scores['BNI'] = (scores['BNI'] ?? 0) + 5;
        if (token == 'byond' || token == 'bsi') {
          scores['BSI'] = (scores['BSI'] ?? 0) + 5;
        }
        if (token == 'flip') scores['Flip'] = (scores['Flip'] ?? 0) + 5;
      }
    }

    // 3. Fallback metadata hint (extraSubject / extraText domain hints) if still unknown
    if (detectedProvider == null && scores.isEmpty) {
      final String meta =
          '${rawExtraSubject ?? ''} ${rawExtraText ?? ''}'.toLowerCase();
      if (meta.isNotEmpty) {
        for (final p in _providers) {
          if (p.textKeys.any(meta.contains)) {
            detectedProvider = p.name;
            break;
          }
        }
      }
    }

    if (detectedProvider == null && scores.isNotEmpty) {
      final List<MapEntry<String, int>> sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      detectedProvider = sorted.first.key;
    }

    final String label;
    if (detectedProvider != null && isQris) {
      label = '$detectedProvider • QRIS';
    } else if (detectedProvider != null) {
      label = detectedProvider;
    } else if (isQris) {
      label = 'QRIS';
    } else {
      label = 'Receipt';
    }

    return (label: label, provider: detectedProvider, isQris: isQris);
  }

  // ---------------------------------------------------------------------------
  // 3. Transaction Direction Scoring (Incoming Money `+` vs Expense `-`)
  // ---------------------------------------------------------------------------

  static final RegExp _strongIncomingPhrase = RegExp(
    r'\b(uang\s+masuk|dana\s+masuk|transfer\s+masuk|saldo\s+masuk|transaksi\s+masuk|terima\s+uang|terima\s+dana|terima\s+saldo|terima\s+transfer|menerima\s+transfer|pembayaran\s+diterima|dana\s+diterima|uang\s+diterima|berhasil\s+diterima|incoming\s+transfer|money\s+received|payment\s+received|funds\s+received|received\s+money|nota\s+kredit|credit\s+advice)\b',
    caseSensitive: false,
  );

  static final RegExp _creditMutationMarker = RegExp(
    r'(?:(?:mutasi|jenis\s+mutasi|tipe\s+mutasi|status\s+mutasi)\s*[:=-]?\s*(?:cr|kredit|credit|uang\s+masuk)\b|\b(?:rp\.?|idr)\s*[0-9][0-9.,]*\s+cr$)',
    caseSensitive: false,
  );

  static final RegExp _explicitPlusAmount = RegExp(
    r'(?:^|\s{2,})\+\s*(?:rp\.?|idr)?\s*[1-9][0-9]{0,2}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?$',
    caseSensitive: false,
  );

  static final RegExp _explicitMinusAmount = RegExp(
    r'(?:^|\s{2,})-\s*(?:rp\.?|idr)\s*[0-9]',
    caseSensitive: false,
  );

  static final RegExp _strongOutflowPhrase = RegExp(
    r'\b(pembayaran\s+berhasil|pembelian\s+berhasil|total\s+bayar|total\s+pembayaran|total\s+tagihan|bayar\s+ke|dibayar\s+ke|pembayaran\s+ke|pembayaran\s+qris|nama\s+merchant|lokasi\s+merchant|diterima\s+oleh|terkirim)\b',
    caseSensitive: false,
  );

  static final RegExp _debitMutationMarker = RegExp(
    r'(?:(?:mutasi|jenis\s+mutasi|tipe\s+mutasi)\s*[:=-]?\s*(?:db|debet|debit|uang\s+keluar)\b|\b(?:rp\.?|idr)\s*[0-9][0-9.,]*\s+db$)',
    caseSensitive: false,
  );

  static bool _detectIncoming(List<String> lines) {
    int incomingScore = 0;
    int outflowScore = 0;

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (_disqualifiedAmountLine.hasMatch(line)) continue;

      if (_strongIncomingPhrase.hasMatch(line)) {
        incomingScore += 4;
      }
      if (_creditMutationMarker.hasMatch(line)) {
        incomingScore += 3;
      }
      if (_explicitPlusAmount.hasMatch(line)) {
        incomingScore += 3;
      }

      if (_strongOutflowPhrase.hasMatch(line)) {
        outflowScore += 3;
      }
      if (_explicitMinusAmount.hasMatch(line) ||
          _debitMutationMarker.hasMatch(line)) {
        outflowScore += 3;
      }
    }

    return incomingScore >= 3 && incomingScore > outflowScore;
  }

  // ---------------------------------------------------------------------------
  // 4. Amount Extraction & Indonesian/English Currency Normalization
  // ---------------------------------------------------------------------------

  static final RegExp _currencyAmountRegex = RegExp(
    r'([+-])?\s*(?:rp\.?|idr)\s*([0-9][0-9O., ]*[0-9]|[0-9]{3,})',
    caseSensitive: false,
  );

  static final RegExp _bareAmountLineRegex = RegExp(
    r'^[+-]?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{4,10}(?:[.,][0-9]{2})?)$',
  );

  static final RegExp _trailingColumnBareAmountRegex = RegExp(
    r'(?:[:=-]\s*|\s{2,})[+-]?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?)$',
  );

  static final RegExp _standaloneCurrencyToken = RegExp(
    r'^[+-]?\s*(?:rp\.?|idr)$',
    caseSensitive: false,
  );

  static final RegExp _disqualifiedAmountLine = RegExp(
    r'\b(sisa\s+saldo|saldo\s+akhir|saldo\s+awal|saldo\s+anda|ending\s+balance|available\s+balance|limit\s+harian|cashback|gopay\s+coins|ovo\s+points|shopee\s+coins|koin|diskon|potongan|voucher|promo|hemat|no\.?\s*ref|nomor\s+referensi|id\s+transaksi|no\.?\s*rek|nomor\s+rekening|nomor\s+tujuan|nmid|mpan|rrn|stan|virtual\s+account|no\.?\s*va|nomor\s+briva|no\.?\s*briva|kode\s+bayar|id\s+pelanggan|nomor\s+pelanggan|npwp)\b',
    caseSensitive: false,
  );

  static final RegExp _feeLine = RegExp(
    r'\b(biaya\s+admin\w*|biaya\s+layanan|biaya\s+transaksi|biaya\s+transfer|biaya\s+pengiriman|ongkos\s+kirim|ongkir|admin\s+fee|service\s+fee|convenience\s+fee|delivery\s+fee|biaya\s+meterai|bea\s+meterai|pajak|ppn|pb1|tip)\b|^biaya\b|^fee\b',
    caseSensitive: false,
  );

  static final RegExp _totalTier1Line = RegExp(
    r'\b(total\s+bayar|total\s+pembayaran|total\s+transaksi|total\s+nominal|total\s+tagihan|total\s+transfer|jumlah\s+bayar|total\s+pendebetan|total\s+debet|total\s+kredit|total\s+diterima|total\s+payment|total\s+amount|grand\s+total|total\s+paid|total\s+belanja|total\s+pesanan)\b|^total\s*[:=-]?',
    caseSensitive: false,
  );

  static final RegExp _nominalTier2Line = RegExp(
    r'\b(nominal\s+transaksi|nominal\s+pembayaran|nominal\s+transfer|nominal\s+top\s*up|nominal\s+masuk|jumlah\s+pembayaran|jumlah\s+transaksi|jumlah\s+transfer|jumlah\s+masuk|nilai\s+transaksi|transaction\s+amount|transfer\s+amount|subtotal|harga\s+total)\b|^(nominal|jumlah|amount|harga)\b',
    caseSensitive: false,
  );

  static final RegExp _successStatusLine = RegExp(
    r'\b(berhasil|sukses|successful|terkirim|diterima|transaksi\s+berhasil|pembayaran\s+berhasil|transfer\s+berhasil|transfer\s+masuk|uang\s+masuk|dana\s+masuk|payment\s+successful)\b',
    caseSensitive: false,
  );

  /// Parses an Indonesian or English formatted currency number into a `double`.
  /// Returns `null` if outside valid Rupiah transaction bounds.
  static double? parseRupiahNumber(String raw, {bool allowOcrZeroFix = false}) {
    String s = raw.trim();
    if (s.isEmpty) return null;

    if (allowOcrZeroFix) {
      s = s.replaceAll('O', '0').replaceAll('o', '0');
    }

    // Collapse spaces around thousand separators (e.g., "28 . 500" -> "28.500").
    s = s.replaceAllMapped(
      RegExp(r'\s*([.,])\s*'),
      (Match m) => m.group(1)!,
    );
    final int spaceIdx = s.indexOf(' ');
    if (spaceIdx > 0) {
      s = s.substring(0, spaceIdx);
    }
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;

    final int lastDot = s.lastIndexOf('.');
    final int lastComma = s.lastIndexOf(',');

    String normalized;
    if (lastDot != -1 && lastComma != -1) {
      if (lastComma > lastDot) {
        normalized = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = s.replaceAll(',', '');
      }
    } else if (lastDot != -1) {
      final List<String> parts = s.split('.');
      if (parts.length > 2) {
        normalized = s.replaceAll('.', '');
      } else {
        final String decimals = parts[1];
        if (decimals.length == 3) {
          normalized = s.replaceAll('.', '');
        } else {
          normalized = s;
        }
      }
    } else if (lastComma != -1) {
      final List<String> parts = s.split(',');
      if (parts.length > 2) {
        normalized = s.replaceAll(',', '');
      } else {
        final String decimals = parts[1];
        if (decimals.length == 3) {
          normalized = s.replaceAll(',', '');
        } else {
          normalized = s.replaceAll(',', '.');
        }
      }
    } else {
      normalized = s;
    }

    final double? parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    final double rounded = parsed.roundToDouble();
    if (rounded > 10000000000) return null;
    return rounded;
  }

  static double? _extractBestAmount(List<String> lines) {
    final List<({double value, int score, String kind})> candidates =
        <({double value, int score, String kind})>[];
    double? explicitFee;

    int classifyLineScore(String line, int index) {
      if (_disqualifiedAmountLine.hasMatch(line)) return -1000;
      if (_feeLine.hasMatch(line)) return -45;
      if (_totalTier1Line.hasMatch(line)) return 100;
      if (_nominalTier2Line.hasMatch(line)) return 75;

      final String stripped = line
          .replaceAll(_currencyAmountRegex, '')
          .replaceAll(RegExp(r'\b(?:cr|db)$', caseSensitive: false), '')
          .trim();
      if (stripped.isEmpty && index <= 10) {
        final bool nearSuccess =
            (index > 0 && _successStatusLine.hasMatch(lines[index - 1])) ||
                (index + 1 < lines.length &&
                    _successStatusLine.hasMatch(lines[index + 1]));
        return nearSuccess ? 70 : 55;
      }
      return 20;
    }

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final int baseScore = classifyLineScore(line, i);
      if (baseScore <= -500) continue;

      final Iterable<RegExpMatch> matches =
          _currencyAmountRegex.allMatches(line);

      if (matches.isNotEmpty) {
        final RegExpMatch match = matches.last;
        final String rawNum = match.group(2) ?? '';
        final double? val = parseRupiahNumber(rawNum, allowOcrZeroFix: true);
        if (val != null) {
          if (baseScore == -45) {
            if (val > 0) explicitFee ??= val;
          } else if (val >= 100) {
            final String kind = baseScore >= 100
                ? 'total'
                : (baseScore >= 75 ? 'nominal' : 'other');
            candidates.add((value: val, score: baseScore, kind: kind));
          }
        }
        continue;
      }

      // 2-column Total / Nominal / Fee row where OCR omitted tiny "Rp" prefix
      if ((baseScore >= 75 || baseScore == -45) &&
          !_dateCheckLoose.hasMatch(line)) {
        final RegExpMatch? colBare =
            _trailingColumnBareAmountRegex.firstMatch(line);
        if (colBare != null) {
          final double? val = parseRupiahNumber(
            colBare.group(1) ?? '',
            allowOcrZeroFix: false,
          );
          if (val != null) {
            if (baseScore == -45) {
              if (val > 0) explicitFee ??= val;
            } else if (val >= 100) {
              final String kind = baseScore >= 100 ? 'total' : 'nominal';
              candidates.add((value: val, score: baseScore, kind: kind));
            }
            continue;
          }
        }
      }

      // Stacked label -> value on next line (including hero bare amount right
      // below status header when tiny superscript "Rp" was skipped by OCR).
      if (i + 1 < lines.length) {
        final String nextLine = lines[i + 1].trim();
        final bool isPureSuperscriptCurrency =
            _standaloneCurrencyToken.hasMatch(line.trim());
        final bool isHeroSuccessHeader =
            i <= 6 && _successStatusLine.hasMatch(line);

        if (baseScore >= 75 ||
            baseScore == -45 ||
            isPureSuperscriptCurrency ||
            isHeroSuccessHeader) {
          double? nextVal;
          final Iterable<RegExpMatch> nextCurrency =
              _currencyAmountRegex.allMatches(nextLine);
          if (nextCurrency.isNotEmpty) {
            nextVal = parseRupiahNumber(
              nextCurrency.last.group(2) ?? '',
              allowOcrZeroFix: true,
            );
          } else if (_bareAmountLineRegex.hasMatch(nextLine) &&
              !_dateCheckLoose.hasMatch(nextLine)) {
            nextVal = parseRupiahNumber(nextLine);
          }

          if (nextVal != null) {
            if (baseScore == -45) {
              if (nextVal > 0) explicitFee ??= nextVal;
            } else if (nextVal >= 100) {
              final int inheritedScore = isPureSuperscriptCurrency
                  ? (i <= 8 ? 62 : 25)
                  : (isHeroSuccessHeader && baseScore < 75 ? 65 : baseScore);
              final String kind = inheritedScore >= 100
                  ? 'total'
                  : (inheritedScore >= 75 ? 'nominal' : 'other');
              candidates.add(
                (value: nextVal, score: inheritedScore, kind: kind),
              );
              i++;
            }
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final int cmpScore = b.score.compareTo(a.score);
      if (cmpScore != 0) return cmpScore;
      return b.value.compareTo(a.value);
    });

    final ({double value, int score, String kind}) winner = candidates.first;

    if (winner.kind == 'nominal' &&
        explicitFee != null &&
        explicitFee > 0 &&
        explicitFee < winner.value * 0.5 &&
        !candidates.any((c) => c.kind == 'total')) {
      return winner.value + explicitFee;
    }

    return winner.value;
  }

  // ---------------------------------------------------------------------------
  // 5. Quantity (`Qty`) Extraction & Exact Unit-Price Reconciliation
  // ---------------------------------------------------------------------------

  static final RegExp _explicitQtyInlineRegex = RegExp(
    r'^(?:qty|quantity|kuantitas|jumlah\s+barang|jumlah\s+item|total\s+item|total\s+barang|jumlah\s+pesanan|banyaknya|jml\s+barang|jml\s+item)\s*(?:[:=-]\s*|\s{2,})([1-9][0-9]{0,2})(?:\s*(?:pcs|pc|item|items|barang|porsi|cup|pax|tiket|unit|buah|bungkus|botol|x))?$',
    caseSensitive: false,
  );

  static final RegExp _explicitQtyLabelOnlyRegex = RegExp(
    r'^(?:qty|quantity|kuantitas|jumlah\s+barang|jumlah\s+item|total\s+item|total\s+barang|jumlah\s+pesanan|banyaknya|jml\s+barang|jml\s+item)\s*[:=-]?$',
    caseSensitive: false,
  );

  static final RegExp _bareQtyValueRegex = RegExp(
    r'^([1-9][0-9]{0,2})(?:\s*(?:pcs|pc|item|items|barang|porsi|cup|pax|tiket|unit|buah|bungkus|botol))?$',
    caseSensitive: false,
  );

  static final RegExp _prefixMultiplierItemRegex = RegExp(
    r'^([1-9][0-9]{0,2})\s*[xX×]\s+([A-Za-z][A-Za-z0-9 &.,()/+-]{2,})$',
  );

  static final RegExp _itemWithQtyTimesPriceRegex = RegExp(
    r'^(.+?)\s+([1-9][0-9]{0,2})\s*(?:pcs|pc|item|porsi|cup)?\s*[xX×@]\s*(?:rp\.?|idr)?\s*([0-9][0-9.,]{2,})(?:\s+.*)?$',
    caseSensitive: false,
  );

  static final RegExp _standaloneQtyTimesPriceRegex = RegExp(
    r'^([1-9][0-9]{0,2})\s*(?:pcs|pc|item|porsi|cup)?\s*[xX×@]\s*(?:rp\.?|idr)?\s*([0-9][0-9.,]{2,})(?:\s+.*)?$',
    caseSensitive: false,
  );

  static final RegExp _suffixMultiplierItemRegex = RegExp(
    r'^([A-Za-z][A-Za-z0-9 &.,/+-]{2,}?)\s*(?:\(\s*(?:[xX×]\s*([1-9][0-9]{0,2})|([1-9][0-9]{0,2})\s*[xX×])\s*\)|\s+[xX×]([1-9][0-9]{0,2}))$',
  );

  static _QuantityExtraction _extractQuantityInfo(List<String> lines) {
    int? explicitQty;
    final List<({int qty, String? name, double? unitPrice})> itemMultipliers =
        <({int qty, String? name, double? unitPrice})>[];

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();

      // 1. Explicit Qty key-value row
      final RegExpMatch? inlineQty = _explicitQtyInlineRegex.firstMatch(line);
      if (inlineQty != null) {
        final int? q = int.tryParse(inlineQty.group(1) ?? '');
        if (q != null && q >= 1 && q <= 999) {
          explicitQty ??= q;
          continue;
        }
      }
      if (_explicitQtyLabelOnlyRegex.hasMatch(line)) {
        // Check stacked below first, then 2-column look-behind if stranded
        if (i + 1 < lines.length) {
          final RegExpMatch? nextVal =
              _bareQtyValueRegex.firstMatch(lines[i + 1].trim());
          if (nextVal != null) {
            final int? q = int.tryParse(nextVal.group(1) ?? '');
            if (q != null && q >= 1 && q <= 999) {
              explicitQty ??= q;
              i++;
              continue;
            }
          }
        }
        if (explicitQty == null && i > 0) {
          final RegExpMatch? prevVal =
              _bareQtyValueRegex.firstMatch(lines[i - 1].trim());
          if (prevVal != null) {
            final int? q = int.tryParse(prevVal.group(1) ?? '');
            if (q != null && q >= 1 && q <= 999) {
              explicitQty ??= q;
              continue;
            }
          }
        }
      }

      // 2. Itemized `Name   2 x Rp 18.000`
      final RegExpMatch? itemTimesPrice =
          _itemWithQtyTimesPriceRegex.firstMatch(line);
      if (itemTimesPrice != null) {
        final String rawName = (itemTimesPrice.group(1) ?? '').trim();
        final int? q = int.tryParse(itemTimesPrice.group(2) ?? '');
        final double? unit = parseRupiahNumber(itemTimesPrice.group(3) ?? '');
        if (q != null &&
            q >= 1 &&
            q <= 999 &&
            unit != null &&
            unit >= 100 &&
            !_isKnownFieldLabel(rawName)) {
          final String cleanedName = _cleanDisplayName(rawName);
          itemMultipliers.add((
            qty: q,
            name: _isValidMerchant(cleanedName) ? cleanedName : null,
            unitPrice: unit,
          ));
          continue;
        }
      }

      // 3. Standalone `2 x Rp 18.000` preceded by item name on line i-1
      final RegExpMatch? standaloneTimes =
          _standaloneQtyTimesPriceRegex.firstMatch(line);
      if (standaloneTimes != null) {
        final int? q = int.tryParse(standaloneTimes.group(1) ?? '');
        final double? unit = parseRupiahNumber(standaloneTimes.group(2) ?? '');
        if (q != null && q >= 1 && q <= 999 && unit != null && unit >= 100) {
          String? prevName;
          if (i > 0 && !_isKnownFieldLabel(lines[i - 1])) {
            final String candidate = _cleanDisplayName(lines[i - 1]);
            if (_isValidMerchant(candidate)) prevName = candidate;
          }
          itemMultipliers.add((qty: q, name: prevName, unitPrice: unit));
          continue;
        }
      }

      // 4. Prefix multiplier `2x Kopi Kenangan Mantan   Rp 44.000`
      final RegExpMatch? prefixMatch =
          _prefixMultiplierItemRegex.firstMatch(line);
      if (prefixMatch != null) {
        final int? q = int.tryParse(prefixMatch.group(1) ?? '');
        String rest = (prefixMatch.group(2) ?? '').trim();
        rest = rest.replaceAll(_currencyAmountRegex, '').trim();
        rest = rest
            .replaceFirst(RegExp(r'\s+[0-9]{1,3}(?:[.,][0-9]{3})+$'), '')
            .trim();
        final String cleanedName = _cleanDisplayName(rest);
        if (q != null &&
            q >= 1 &&
            q <= 999 &&
            _isValidMerchant(cleanedName) &&
            !_isKnownFieldLabel(cleanedName)) {
          itemMultipliers.add((qty: q, name: cleanedName, unitPrice: null));
          continue;
        }
      }

      // 5. Suffix multiplier `Americano (x2)` or `Kopi Susu   x2`
      final RegExpMatch? suffixMatch =
          _suffixMultiplierItemRegex.firstMatch(line);
      if (suffixMatch != null) {
        final String rawName = (suffixMatch.group(1) ?? '').trim();
        final String rawQty = suffixMatch.group(2) ??
            suffixMatch.group(3) ??
            suffixMatch.group(4) ??
            '';
        final int? q = int.tryParse(rawQty);
        final String cleanedName = _cleanDisplayName(rawName);
        if (q != null &&
            q >= 1 &&
            q <= 999 &&
            _isValidMerchant(cleanedName) &&
            !_isKnownFieldLabel(cleanedName)) {
          itemMultipliers.add((qty: q, name: cleanedName, unitPrice: null));
        }
      }
    }

    if (itemMultipliers.length == 1) {
      final single = itemMultipliers.first;
      return _QuantityExtraction(
        quantity: explicitQty ?? single.qty,
        explicitUnitPrice: single.unitPrice,
        singleItemName: single.name,
        hasMultipleDistinctItems: false,
      );
    }

    if (itemMultipliers.length > 1) {
      final int sumQty = itemMultipliers.fold<int>(0, (acc, e) => acc + e.qty);
      return _QuantityExtraction(
        quantity: explicitQty ?? sumQty,
        explicitUnitPrice: null,
        singleItemName: null,
        hasMultipleDistinctItems: true,
      );
    }

    return _QuantityExtraction(
      quantity: explicitQty,
      explicitUnitPrice: null,
      singleItemName: null,
      hasMultipleDistinctItems: false,
    );
  }

  static ({int quantity, double? unitPrice}) _reconcileQuantityAndUnitPrice({
    required double? totalAmount,
    required _QuantityExtraction qtyInfo,
  }) {
    final int? candidateQty = qtyInfo.quantity;
    if (candidateQty == null || candidateQty <= 1) {
      if (totalAmount != null) {
        return (quantity: 1, unitPrice: totalAmount);
      }
      if (qtyInfo.explicitUnitPrice != null) {
        return (quantity: 1, unitPrice: qtyInfo.explicitUnitPrice);
      }
      return (quantity: 1, unitPrice: null);
    }

    if (qtyInfo.hasMultipleDistinctItems) {
      if (totalAmount != null) {
        return (quantity: 1, unitPrice: totalAmount);
      }
      return (quantity: candidateQty, unitPrice: null);
    }

    if (totalAmount != null) {
      if (qtyInfo.explicitUnitPrice != null &&
          (candidateQty * qtyInfo.explicitUnitPrice! - totalAmount).abs() < 1) {
        return (quantity: candidateQty, unitPrice: qtyInfo.explicitUnitPrice);
      }

      final int roundedTotal = totalAmount.round();
      if (roundedTotal > 0 && roundedTotal % candidateQty == 0) {
        return (
          quantity: candidateQty,
          unitPrice: (roundedTotal ~/ candidateQty).toDouble(),
        );
      }

      return (quantity: 1, unitPrice: totalAmount);
    }

    if (qtyInfo.explicitUnitPrice != null) {
      return (quantity: candidateQty, unitPrice: qtyInfo.explicitUnitPrice);
    }

    return (quantity: candidateQty, unitPrice: null);
  }

  static final RegExp _suffixUnitCountRegex = RegExp(
    r'^([A-Za-z][A-Za-z0-9 &.,/+-]{2,}?)\s+([1-9][0-9]{0,2})\s*(?:pcs|pc|item|items|barang|porsi|cup|pax|tiket|unit|buah|bungkus|botol)$',
    caseSensitive: false,
  );

  static int? _extractMultiplierFromNote(String note) {
    final String trimmed = note.trim();
    final RegExpMatch? prefix = _prefixMultiplierItemRegex.firstMatch(trimmed);
    if (prefix != null) {
      final int? q = int.tryParse(prefix.group(1) ?? '');
      if (q != null && q >= 2 && q <= 999) return q;
    }
    final RegExpMatch? suffix = _suffixMultiplierItemRegex.firstMatch(trimmed);
    if (suffix != null) {
      final String rawQ =
          suffix.group(2) ?? suffix.group(3) ?? suffix.group(4) ?? '';
      final int? q = int.tryParse(rawQ);
      if (q != null && q >= 2 && q <= 999) return q;
    }
    final RegExpMatch? unitMatch = _suffixUnitCountRegex.firstMatch(trimmed);
    if (unitMatch != null) {
      final int? q = int.tryParse(unitMatch.group(2) ?? '');
      if (q != null && q >= 2 && q <= 999) return q;
    }
    return null;
  }

  static String _stripMultiplierAffix(String input) {
    if (input.contains(' • ')) {
      return input
          .split(' • ')
          .map(_stripSingleMultiplierAffix)
          .where((s) => s.isNotEmpty)
          .join(' • ');
    }
    return _stripSingleMultiplierAffix(input);
  }

  static String _stripSingleMultiplierAffix(String input) {
    String s = input.trim();
    s = s.replaceFirst(RegExp(r'^[1-9][0-9]{0,2}\s*[xX×]\s+'), '');
    s = s.replaceFirst(
      RegExp(
        r'\s*(?:\(\s*(?:[xX×]\s*[1-9][0-9]{0,2}|[1-9][0-9]{0,2}\s*[xX×])\s*\)|\s+[xX×][1-9][0-9]{0,2}|\s+[1-9][0-9]{0,2}\s*(?:pcs|pc|item|items|barang|porsi|cup|pax|tiket|unit|buah|bungkus|botol))$',
        caseSensitive: false,
      ),
      '',
    );
    return s.trim();
  }

  // ---------------------------------------------------------------------------
  // 6. Universal Direction-Aware Entity, Counterparty & Note Extraction
  // ---------------------------------------------------------------------------

  static final RegExp _senderLabelRegex = RegExp(
    r'^(?:sumber\s+dana|rekening\s+sumber|dari\s+rekening|dari\s+kantong|nama\s+pengirim|pengirim|pemilik\s+rekening|terima\s+dari|diterima\s+dari|source\s+of\s+funds?|from\s+account|received\s+from|sender|dari|from)(?:\s*[:=-]\s*(.+)|\s{2,}(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  static final RegExp _senderSingleSpacePrepositionRegex = RegExp(
    r'^(?:nama\s+pengirim|terima\s+dari|diterima\s+dari|received\s+from|dari\s+rekening)\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _noteLabelRegex = RegExp(
    r'^(?:berita(?:\s+transfer)?|catatan(?:\s+transfer)?|keterangan|pesan|deskripsi|keperluan|referensi\s+pelanggan|notes?|remarks?|message|rincian\s+item)(?:\s*[:=-]\s*(.+)|\s{2,}(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  static final RegExp _merchantPrepositionRegex = RegExp(
    r'^(?:pembayaran\s+ke|bayar\s+ke|dibayar\s+ke|ditujukan\s+ke|transfer\s+ke|ditransfer\s+ke|dikirim\s+ke|kirim\s+ke|diterima\s+oleh|rekening\s+tujuan|ke\s+rek\.?|kepada|paid\s+to|transfer\s+to|sent\s+to|ke)(?:\s*[:=-]\s*(.+)|\s+(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  static final RegExp _merchantLabelRegex = RegExp(
    r'^(?:nama\s+merchant|merchant\s+name|merchant|outlet|toko|nama\s+penerima|penerima\s+dana|penerima|nama\s+tujuan|tujuan\s+transfer|tujuan|beneficiary(?:\s+name)?|recipient(?:\s+name)?|nama\s+institusi|institusi|penyedia\s+jasa|biller(?:\s+name)?|nama\s+pelanggan|alias\s+penerima|pembelian|produk|layanan)(?:\s*[:=-]\s*(.+)|\s{2,}(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  /// Multi-word unambiguous labels when OCR collapsed the 2-column gap to 1 space.
  static final RegExp _merchantSingleSpaceUnambiguousRegex = RegExp(
    r'^(?:nama\s+merchant|merchant\s+name|nama\s+penerima|penerima\s+dana|nama\s+tujuan|tujuan\s+transfer|beneficiary\s+name|recipient\s+name|nama\s+institusi|penyedia\s+jasa|nama\s+pelanggan)\s+(.+)$',
    caseSensitive: false,
  );

  /// Generic `Nama` / `Name` row used by BRImo, Livin', BNI, and VA/Top-Up cards
  /// (evaluated only outside the user's own account section).
  static final RegExp _genericNameLabelRegex = RegExp(
    r'^(?:nama|name|atas\s+nama)(?:\s*[:=-]\s*(.+)|\s{2,}(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  static final RegExp _ownDestinationAccountRegex = RegExp(
    r'^(?:ke\s+rekening|ke\s+kantong|rekening\s+tujuan|rekening\s+penerima|masuk\s+ke|credited\s+to|to\s+account)(?:\s*[:=-]\s*(.+)|\s{2,}(.+)|\s*[:=-]?)$',
    caseSensitive: false,
  );

  static final RegExp _pureBankOrProviderLineRegex = RegExp(
    r'^(?:pt\.?\s+)?(?:bank\s+[a-z0-9 .,&()-]{2,32}|bca|mybca|bri|brimo|bni|wondr|mandiri|livin|bsi|byond|btn|bjb|cimb(?:\s+niaga)?|octo(?:\s+mobile)?|permata(?:\s*bank)?|danamon|ocbc(?:\s+nisp)?|panin|maybank|uob|jenius|btpn|smbc|seabank|jago|blu|gopay|dana|ovo|shopeepay|linkaja|flip|bi-fast|bifast|online|rtol|transfer\s+bank\s+[a-z0-9 ]+)$',
    caseSensitive: false,
  );

  static final RegExp _txTypeLabelRegex = RegExp(
    r'^(?:jenis\s+transaksi|tipe\s+transaksi|transaction\s+type|dompet\s+digital|jenis\s+layanan)\s*(?:[:=-]\s*(.+)|\s{2,}(.+))?$',
    caseSensitive: false,
  );

  static final RegExp _meaninglessNote = RegExp(
    r'^(-+|n/?a|kosong|tidak\s+ada|none|null|transfer|pembayaran|qris|bayar|lainnya|other|transaksi|opsional|\(opsional\)|catatan\s*\(?opsional\)?|[0-9\s.,/-]+)$',
    caseSensitive: false,
  );

  static final RegExp _accountOrNumericLine = RegExp(
    r'^(?:[a-z]{2,10}\s*[-•·:]\s*)?[0-9xX*•\s.+-]{5,}$',
    caseSensitive: false,
  );

  /// Anchored structural field/section labels so words like `"Sukses"` inside
  /// `"Toko Sukses Makmur"` or `"SeaBank"` under `"Tujuan"` are NEVER mistaken
  /// for field headers.
  static final RegExp _structuralHeaderOrLabel = RegExp(
    r'^(?:transaksi\s+berhasil|pembayaran\s+berhasil|transfer\s+berhasil|transfer\s+masuk(?:\s+berhasil)?|top[\s-]*up\s+berhasil|pembelian\s+berhasil|uang\s+masuk|dana\s+masuk|saldo\s+masuk|berhasil!?|sukses!?|successful!?|terkirim!?|rincian\s+transaksi|rincian\s+pembayaran|detail\s+transaksi|detail\s+pembayaran|laporan\s+transaksi|ringkasan\s+transaksi|catatan\s+transaksi|bukti\s+transaksi|bukti\s+pembayaran|struk\s+transaksi|transaction\s+details|payment\s+details|successful\s+transaction|metode\s+pembayaran|lokasi\s+merchant|kota\s+merchant|nomor\s+referensi|no\.?\s*ref(?:erensi)?|id\s+transaksi|id\s+order|waktu(?:\s+selesai|\s+transaksi)?|tanggal(?:\s+transaksi)?|status(?:\s+transaksi)?|jenis\s+transaksi|tipe\s+transaksi|transaction\s+type|bank\s+tujuan|bank\s+penerima|bank\s+pengirim|nomor\s+tujuan|rekening\s+tujuan|no\.?\s*rek(?:ening)?|nomor\s+rekening|nomor\s+briva|no\.?\s*briva|id\s+pelanggan|nomor\s+pelanggan|dompet\s+digital|acquirer|pan\s+merchant|terminal\s+id|nmid|mpan|rrn|stan)(?:\s*[:=-].*|\s{2,}.*|[!.]?)$',
    caseSensitive: false,
  );

  static final RegExp _boilerplateUnlabeledExclusion = RegExp(
    r'\b(transaksi\s+berhasil|pembayaran\s+berhasil|transfer\s+berhasil|transfer\s+masuk|uang\s+masuk|dana\s+masuk|saldo\s+masuk|rincian\s+transaksi|rincian\s+pembayaran|detail\s+transaksi|detail\s+pembayaran|laporan\s+transaksi|ringkasan\s+transaksi|catatan\s+transaksi|transaction\s+details|payment\s+details|successful\s+transaction|metode\s+pembayaran|sumber\s+dana|rekening\s+sumber|bank\s+tujuan|bank\s+penerima|lokasi\s+merchant|nomor\s+referensi|no\.?\s*ref|id\s+transaksi|waktu\s+selesai|total\s+bayar|total\s+pembayaran|total\s+transaksi|total\s+nominal|jumlah\s+pembayaran|nominal\s+transaksi|biaya\s+admin|biaya\s+transaksi|sisa\s+saldo|bukti\s+pembayaran|bukti\s+transaksi|resi\s+ini|struk\s+ini|hubungi\s+halo|terima\s+kasih|bagikan|unduh|lihat\s+detail|nmid|mpan|rrn|stan|acquirer|pan\s+merchant|terminal\s+id|jenis\s+transaksi|pembayaran\s+qris|m-transfer|gopay\s+saldo|saldo\s+dana|ovo\s+cash)\b',
    caseSensitive: false,
  );

  static const Set<String> _preservedAcronyms = <String>{
    'BCA',
    'BRI',
    'BNI',
    'BSI',
    'BTN',
    'BJB',
    'CIMB',
    'OCBC',
    'HSBC',
    'UOB',
    'PLN',
    'PDAM',
    'BPJS',
    'BRIVA',
    'KFC',
    'MCD',
    'XXI',
    'CGV',
    'KRL',
    'MRT',
    'LRT',
    'QRIS',
    'PT',
    'CV',
    'UD',
    'RM',
    'TB',
    'PD',
    'TBK',
    'SPBU',
    'RS',
    'UI',
    'ITB',
    'UGM',
    'ATM',
    'EDC',
    'ID',
    'JNE',
    'JNT',
  };

  static ({
    String primary,
    List<String> candidates,
    String? noteName,
  }) _extractNames({
    required List<String> lines,
    required String? provider,
    required bool isQris,
    required bool isIncoming,
    required String? itemizedName,
  }) {
    String? noteName;
    String? counterpartyName;
    String? genericLabeledName;
    String? txTypeFallback;
    final Set<int> ownAccountIndices = <int>{};

    void markOwnSectionBlock(int labelIdx, String inlineVal) {
      ownAccountIndices.add(labelIdx);
      if (inlineVal.isEmpty) {
        for (int step = 1; step <= 3 && labelIdx + step < lines.length; step++) {
          final String next = lines[labelIdx + step].trim();
          if (_genericNameLabelRegex.hasMatch(next)) {
            ownAccountIndices.add(labelIdx + step);
            continue;
          }
          if (_isKnownFieldLabel(next)) break;
          ownAccountIndices.add(labelIdx + step);
          if (step >= 2 &&
              !_accountOrNumericLine.hasMatch(next) &&
              !_pureBankOrProviderLineRegex.hasMatch(next)) {
            break;
          }
        }
      } else {
        for (int step = 1; step <= 2 && labelIdx + step < lines.length; step++) {
          final String next = lines[labelIdx + step].trim();
          if (_genericNameLabelRegex.hasMatch(next)) {
            ownAccountIndices.add(labelIdx + step);
            continue;
          }
          if (_isKnownFieldLabel(next)) break;
          if (_accountOrNumericLine.hasMatch(next) ||
              _accountOrNumericLine.hasMatch(inlineVal) ||
              _pureBankOrProviderLineRegex.hasMatch(inlineVal)) {
            ownAccountIndices.add(labelIdx + step);
          } else {
            break;
          }
        }
      }
    }

    // Pass 1: Identify and quarantine the user's OWN account rows:
    // - Outgoing expense: `Sumber Dana` / `Pengirim` / `Dari Rekening` is the user.
    // - Incoming money:   `Tujuan` / `Penerima` / `Ke Rekening` is the user.
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (!isIncoming) {
        final RegExpMatch? m = _senderLabelRegex.firstMatch(line);
        if (m != null) {
          final String inline = (m.group(1) ?? m.group(2) ?? '').trim();
          markOwnSectionBlock(i, inline);
        }
      } else {
        final RegExpMatch? m = _ownDestinationAccountRegex.firstMatch(line) ??
            _merchantLabelRegex.firstMatch(line);
        if (m != null) {
          final String inline = (m.group(1) ?? m.group(2) ?? '').trim();
          markOwnSectionBlock(i, inline);
        }
      }
    }

    String? resolveCounterpartyBelow(int startIdx) {
      String? bankFallback;
      final int maxIdx = (startIdx + 3).clamp(0, lines.length - 1);
      for (int k = startIdx; k <= maxIdx && k < lines.length; k++) {
        if (ownAccountIndices.contains(k)) break;
        final String cand = lines[k].trim();

        // Allow `Nama   BUDI SANTOSO` inside a `Penerima` / `Pengirim` block.
        final RegExpMatch? nestedName = _genericNameLabelRegex.firstMatch(cand);
        if (nestedName != null) {
          final String nestedInline =
              (nestedName.group(1) ?? nestedName.group(2) ?? '').trim();
          if (nestedInline.isNotEmpty &&
              !isGibberishOrWatermark(nestedInline)) {
            return nestedInline;
          }
          continue;
        }

        if (_isKnownFieldLabel(cand)) break;
        if (_accountOrNumericLine.hasMatch(cand)) continue;
        if (_currencyAmountRegex.hasMatch(cand) ||
            _bareAmountLineRegex.hasMatch(cand) ||
            _dateCheckLoose.hasMatch(cand)) {
          break;
        }
        if (isGibberishOrWatermark(cand)) continue;
        if (_pureBankOrProviderLineRegex.hasMatch(cand)) {
          bankFallback ??= cand;
          continue;
        }
        return cand;
      }
      return bankFallback;
    }

    String? resolveLookBehindValue(int labelIdx) {
      if (labelIdx <= 0) return null;
      final int prevIdx = labelIdx - 1;
      if (ownAccountIndices.contains(prevIdx)) return null;
      final String prev = lines[prevIdx].trim();
      if (_isKnownFieldLabel(prev)) return null;
      if (_successStatusLine.hasMatch(prev)) return null;
      if (_accountOrNumericLine.hasMatch(prev)) return null;
      if (_pureBankOrProviderLineRegex.hasMatch(prev)) return null;
      if (_currencyAmountRegex.hasMatch(prev) ||
          _bareAmountLineRegex.hasMatch(prev) ||
          _dateCheckLoose.hasMatch(prev)) {
        return null;
      }
      if (isGibberishOrWatermark(prev)) return null;
      final String cleaned = _cleanDisplayName(prev);
      return _isValidMerchant(cleaned) ? prev : null;
    }

    String? resolveLabelMatch({
      required int lineIndex,
      required String inlineVal,
    }) {
      if (inlineVal.isNotEmpty) {
        if (_accountOrNumericLine.hasMatch(inlineVal)) {
          return resolveCounterpartyBelow(lineIndex + 1);
        }
        if (_pureBankOrProviderLineRegex.hasMatch(inlineVal)) {
          return resolveCounterpartyBelow(lineIndex + 1) ?? inlineVal;
        }
        if (isGibberishOrWatermark(inlineVal)) {
          return resolveCounterpartyBelow(lineIndex + 1);
        }
        return inlineVal;
      }
      if (lineIndex + 1 < lines.length) {
        final String? below = resolveCounterpartyBelow(lineIndex + 1);
        if (below != null) return below;
      }
      return resolveLookBehindValue(lineIndex);
    }

    // Pass 2: Extract explicit Note, Counterparty (Merchant/Recipient or Sender),
    // Generic `Nama`, and Transaction Type
    for (int i = 0; i < lines.length; i++) {
      if (ownAccountIndices.contains(i)) continue;
      final String line = lines[i].trim();

      // 1. Note / Berita / Catatan / Keterangan
      if (noteName == null) {
        String? candidateNote;
        final RegExpMatch? m = _noteLabelRegex.firstMatch(line);
        if (m != null) {
          final String inline = (m.group(1) ?? m.group(2) ?? '').trim();
          if (inline.isNotEmpty) {
            candidateNote = inline;
          } else if (i + 1 < lines.length &&
              !ownAccountIndices.contains(i + 1) &&
              !_isKnownFieldLabel(lines[i + 1])) {
            candidateNote = lines[i + 1].trim();
          }
        }
        if (candidateNote != null) {
          final String cleaned = _cleanDisplayName(candidateNote);
          if (_isValidNote(cleaned)) {
            noteName = cleaned;
          }
        }
      }

      // 2. Direction-aware Counterparty
      if (counterpartyName == null) {
        String? candidateCounterparty;

        if (isIncoming) {
          final RegExpMatch? senderMatch = _senderLabelRegex.firstMatch(line);
          final RegExpMatch? senderPrep = senderMatch == null
              ? _senderSingleSpacePrepositionRegex.firstMatch(line)
              : null;
          if (senderMatch != null || senderPrep != null) {
            final String inline = senderMatch != null
                ? (senderMatch.group(1) ?? senderMatch.group(2) ?? '').trim()
                : (senderPrep!.group(1) ?? '').trim();
            candidateCounterparty = resolveLabelMatch(
              lineIndex: i,
              inlineVal: inline,
            );
          }
        } else {
          final RegExpMatch? m = _merchantLabelRegex.firstMatch(line);
          final RegExpMatch? unambig = m == null
              ? _merchantSingleSpaceUnambiguousRegex.firstMatch(line)
              : null;
          final RegExpMatch? prep = (m == null && unambig == null)
              ? _merchantPrepositionRegex.firstMatch(line)
              : null;

          if (m != null || unambig != null || prep != null) {
            final String inline = m != null
                ? (m.group(1) ?? m.group(2) ?? '').trim()
                : unambig != null
                    ? (unambig.group(1) ?? '').trim()
                    : (prep!.group(1) ?? prep.group(2) ?? '').trim();
            candidateCounterparty = resolveLabelMatch(
              lineIndex: i,
              inlineVal: inline,
            );
          }
        }

        if (candidateCounterparty != null) {
          final String cleaned = _cleanDisplayName(candidateCounterparty);
          if (_isValidMerchant(cleaned)) {
            counterpartyName = cleaned;
          }
        }
      }

      // 3. Standalone `Nama` / `Name` outside the user's own account block
      // (used heavily by BRImo VA/Top-Up/Transfer cards)
      if (genericLabeledName == null) {
        final RegExpMatch? gm = _genericNameLabelRegex.firstMatch(line);
        if (gm != null) {
          final String inline = (gm.group(1) ?? gm.group(2) ?? '').trim();
          final String? resolved = resolveLabelMatch(
            lineIndex: i,
            inlineVal: inline,
          );
          if (resolved != null) {
            final String cleaned = _cleanDisplayName(resolved);
            if (_isValidMerchant(cleaned)) {
              genericLabeledName = cleaned;
            }
          }
        }
      }

      // 4. Transaction Type / Dompet Digital fallback
      if (txTypeFallback == null) {
        final RegExpMatch? txMatch = _txTypeLabelRegex.firstMatch(line);
        if (txMatch != null) {
          String rawTx = (txMatch.group(1) ?? txMatch.group(2) ?? '').trim();
          if (rawTx.isEmpty &&
              i + 1 < lines.length &&
              !_isKnownFieldLabel(lines[i + 1])) {
            rawTx = lines[i + 1].trim();
          }
          if (rawTx.isNotEmpty) {
            final String cleanedTx = _cleanDisplayName(rawTx);
            if (_isValidNote(cleanedTx)) {
              txTypeFallback = cleanedTx;
            }
          }
        }
      }
    }

    counterpartyName ??= genericLabeledName;

    // Pass 3: Positional fallback for hero receipts (GoPay, OVO, DANA, QRIS cards)
    if (counterpartyName == null && itemizedName == null) {
      final int scanLimit = (lines.length * 0.80).ceil().clamp(1, 20);
      for (int i = 0; i < scanLimit && i < lines.length; i++) {
        if (ownAccountIndices.contains(i)) continue;
        final String line = lines[i].trim();
        if (_isPlausibleUnlabeledMerchant(line, provider)) {
          final String cleaned = _cleanDisplayName(line);
          if (_isValidMerchant(cleaned)) {
            counterpartyName = cleaned;
            break;
          }
        }
      }
    }

    final List<String> candidates = <String>[];
    void addUnique(String? val) {
      if (val == null) return;
      final String trimmed = val.trim();
      if (trimmed.isEmpty) return;
      if (!candidates.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
        candidates.add(trimmed);
      }
    }

    addUnique(noteName);
    addUnique(itemizedName);
    addUnique(counterpartyName);
    addUnique(genericLabeledName);
    if (noteName != null && counterpartyName != null) {
      final String combined = '$noteName • $counterpartyName';
      if (combined.length <= 48) {
        addUnique(combined);
      }
    }
    if (txTypeFallback != null) {
      addUnique(txTypeFallback);
    }

    if (candidates.isNotEmpty) {
      return (
        primary: candidates.first,
        candidates: candidates,
        noteName: noteName,
      );
    }

    final List<String> fallbacks = <String>[];
    if (isIncoming) {
      if (provider != null) {
        fallbacks.add('$provider Incoming');
      }
      fallbacks.add('Incoming Transfer');
    } else {
      if (isQris) fallbacks.add('QRIS Payment');
      if (provider != null) fallbacks.add('$provider Transaction');
    }
    return (
      primary: isIncoming && fallbacks.isNotEmpty ? fallbacks.first : '',
      candidates: fallbacks,
      noteName: null,
    );
  }

  static bool _isKnownFieldLabel(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    final String lower = trimmed.toLowerCase();
    return _totalTier1Line.hasMatch(lower) ||
        _nominalTier2Line.hasMatch(lower) ||
        _feeLine.hasMatch(lower) ||
        _disqualifiedAmountLine.hasMatch(lower) ||
        _senderLabelRegex.hasMatch(lower) ||
        _merchantLabelRegex.hasMatch(lower) ||
        _merchantSingleSpaceUnambiguousRegex.hasMatch(lower) ||
        _ownDestinationAccountRegex.hasMatch(lower) ||
        _noteLabelRegex.hasMatch(lower) ||
        _explicitQtyLabelOnlyRegex.hasMatch(lower) ||
        _explicitQtyInlineRegex.hasMatch(lower) ||
        _structuralHeaderOrLabel.hasMatch(lower);
  }

  static bool _isValidNote(String cleaned) {
    if (cleaned.length < 2 || cleaned.length > 70) return false;
    if (_meaninglessNote.hasMatch(cleaned)) return false;
    if (_currencyAmountRegex.hasMatch(cleaned)) return false;
    if (_wrappedDomainLineRegex.hasMatch(cleaned)) return false;
    if (_shareWrapperNoiseRegex.hasMatch(cleaned)) return false;
    if (isGibberishOrWatermark(cleaned)) return false;
    return RegExp(r'[a-zA-Z]').hasMatch(cleaned);
  }

  static bool _isValidMerchant(String cleaned) {
    if (cleaned.length < 2 || cleaned.length > 70) return false;
    if (_meaninglessNote.hasMatch(cleaned)) return false;
    if (_accountOrNumericLine.hasMatch(cleaned)) return false;
    if (_currencyAmountRegex.hasMatch(cleaned)) return false;
    if (_dateCheckLoose.hasMatch(cleaned)) return false;
    if (_wrappedDomainLineRegex.hasMatch(cleaned)) return false;
    if (_shareWrapperNoiseRegex.hasMatch(cleaned)) return false;
    if (isGibberishOrWatermark(cleaned)) return false;
    return RegExp(r'[a-zA-Z]{2,}|[A-Za-z]&[A-Za-z]').hasMatch(cleaned);
  }

  static bool _isPlausibleUnlabeledMerchant(String line, String? provider) {
    if (line.length < 3 || line.length > 56) return false;
    if (_currencyAmountRegex.hasMatch(line)) return false;
    if (_bareAmountLineRegex.hasMatch(line)) return false;
    if (_accountOrNumericLine.hasMatch(line)) return false;
    if (_isKnownFieldLabel(line)) return false;
    if (_boilerplateUnlabeledExclusion.hasMatch(line)) return false;
    if (_shareWrapperNoiseRegex.hasMatch(line)) return false;
    if (_wrappedDomainLineRegex.hasMatch(line)) return false;
    if (_dateCheckLoose.hasMatch(line)) return false;
    if (line.contains(':') || line.contains('http') || line.contains('@')) {
      return false;
    }
    if (isGibberishOrWatermark(line)) return false;

    final String lower = line.toLowerCase();
    if (provider != null && lower == provider.toLowerCase()) return false;
    for (final p in _providers) {
      if (lower == p.name.toLowerCase()) return false;
    }
    if (_pureBankOrProviderLineRegex.hasMatch(lower) ||
        _watermarkBrandTokens.contains(lower)) {
      return false;
    }

    return RegExp(r'[a-zA-Z]{3,}|[A-Za-z]&[A-Za-z]').hasMatch(line);
  }

  static String _cleanDisplayName(String raw) {
    String s = raw.trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:pembayaran\s+ke|bayar\s+ke|dibayar\s+ke|ditujukan\s+ke|transfer\s+ke|ditransfer\s+ke|dikirim\s+ke|kirim\s+ke|diterima\s+oleh|terima\s+dari|diterima\s+dari|received\s+from|nama\s+merchant|merchant\s+name|nama\s+penerima|nama\s+tujuan|nama\s+pengirim|kepada|qris\s*[-:]?)\s+',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(RegExp(r'^[:=-]+\s*'), '');
    s = s.replaceFirst(RegExp(r'[,\s]+ID$'), '');
    s = s.replaceAll(_multiSpace, ' ').trim();
    if (s.isEmpty) return '';

    final String lettersOnly = s.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    final bool isAllCaps =
        lettersOnly.length >= 3 && lettersOnly == lettersOnly.toUpperCase();
    if (!isAllCaps) return s;

    return s.split(' ').map((String word) {
      if (word.isEmpty) return word;
      final String alpha = word.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (_preservedAcronyms.contains(alpha.toUpperCase())) {
        return word.toUpperCase();
      }
      final String lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  // ---------------------------------------------------------------------------
  // 7. Date & Time Extraction (Indonesian + English + m-BCA Short Format)
  // ---------------------------------------------------------------------------

  static const Map<String, int> _monthMap = <String, int>{
    'jan': 1,
    'januari': 1,
    'january': 1,
    'feb': 2,
    'februari': 2,
    'february': 2,
    'mar': 3,
    'maret': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'mei': 5,
    'may': 5,
    'jun': 6,
    'juni': 6,
    'june': 6,
    'jul': 7,
    'juli': 7,
    'july': 7,
    'agu': 8,
    'agt': 8,
    'ags': 8,
    'agustus': 8,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'okt': 10,
    'oktober': 10,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'nop': 11,
    'november': 11,
    'des': 12,
    'desember': 12,
    'dec': 12,
    'december': 12,
  };

  static final RegExp _dateCheckLoose = RegExp(
    r'\b(\d{1,2}\s+(?:jan|feb|mar|apr|mei|may|jun|jul|agu|agt|aug|sep|sept|okt|oct|nov|nop|des|dec)[a-z]*\s+\d{4}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{2}-\d{2})\b',
    caseSensitive: false,
  );

  static final RegExp _dmyNamedRegex = RegExp(
    r'\b(\d{1,2})[\s/-]+([a-zA-Z]{3,9})[\s,/-]+(\d{4})(?:[\s,•·|-]+(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?\s*(am|pm)?)?',
    caseSensitive: false,
  );

  static final RegExp _mdyNamedRegex = RegExp(
    r'\b([a-zA-Z]{3,9})\s+(\d{1,2}),?\s+(\d{4})(?:[\s,•·|-]+(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?\s*(am|pm)?)?',
    caseSensitive: false,
  );

  static final RegExp _dmyNumericRegex = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:[\s,•·|-]+(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?)?',
  );

  static final RegExp _ymdIsoRegex = RegExp(
    r'\b(\d{4})-(\d{2})-(\d{2})(?:[\sT]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  );

  static final RegExp _shortDmWithTimeRegex = RegExp(
    r'(?<![0-9/])(\d{2})/(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?(?![0-9])',
  );

  static final RegExp _standaloneTimeRegex = RegExp(
    r'\b(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?\s*(?:wib|wita|wit)\b',
    caseSensitive: false,
  );

  static final RegExp _labeledOrPrefixedTimeRegex = RegExp(
    r'(?:^(?:waktu(?:\s+transaksi|\s+selesai)?|jam|pukul|time)\s*(?:[:=-]\s*|\s{2,})(\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?|\b(\d{1,2}):(\d{2})(?::(\d{2}))?\s*[·•|,-]\s*\d{1,2}[\s/-])',
    caseSensitive: false,
  );

  static ({DateTime date, bool explicit}) _extractDateTime(
    List<String> lines,
    DateTime now,
  ) {
    int? fallbackHour;
    int? fallbackMinute;

    for (final String line in lines) {
      final RegExpMatch? t = _standaloneTimeRegex.firstMatch(line);
      if (t != null) {
        final int? h = int.tryParse(t.group(1) ?? '');
        final int? m = int.tryParse(t.group(2) ?? '');
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          fallbackHour = h;
          fallbackMinute = m;
          break;
        }
      }
      final RegExpMatch? lt = _labeledOrPrefixedTimeRegex.firstMatch(line);
      if (lt != null) {
        final int? h = int.tryParse(lt.group(1) ?? lt.group(4) ?? '');
        final int? m = int.tryParse(lt.group(2) ?? lt.group(5) ?? '');
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          fallbackHour = h;
          fallbackMinute = m;
          break;
        }
      }
    }

    DateTime? buildValidDate({
      required int year,
      required int month,
      required int day,
      int? hour,
      int? minute,
      int? second,
      String? ampm,
    }) {
      if (year < 2020 || year > now.year + 1) return null;
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;

      int? h = hour;
      int? min = minute;
      if (h != null && ampm != null) {
        final String ap = ampm.toLowerCase();
        if (ap == 'pm' && h < 12) h += 12;
        if (ap == 'am' && h == 12) h = 0;
      }

      if (h == null || min == null) {
        if (fallbackHour != null && fallbackMinute != null) {
          h = fallbackHour;
          min = fallbackMinute;
        } else if (year == now.year && month == now.month && day == now.day) {
          h = now.hour;
          min = now.minute;
        } else {
          h = 12;
          min = 0;
        }
      }

      if (h < 0 || h > 23 || min < 0 || min > 59) return null;
      final DateTime candidate =
          DateTime(year, month, day, h, min, second ?? 0);
      if (candidate.month != month || candidate.day != day) return null;
      if (candidate.isAfter(now.add(const Duration(days: 2)))) return null;
      return candidate;
    }

    for (final String line in lines) {
      final RegExpMatch? dmyNamed = _dmyNamedRegex.firstMatch(line);
      if (dmyNamed != null) {
        final int? month = _monthMap[(dmyNamed.group(2) ?? '').toLowerCase()];
        if (month != null) {
          final DateTime? dt = buildValidDate(
            day: int.parse(dmyNamed.group(1)!),
            month: month,
            year: int.parse(dmyNamed.group(3)!),
            hour: int.tryParse(dmyNamed.group(4) ?? ''),
            minute: int.tryParse(dmyNamed.group(5) ?? ''),
            second: int.tryParse(dmyNamed.group(6) ?? ''),
            ampm: dmyNamed.group(7),
          );
          if (dt != null) return (date: dt, explicit: true);
        }
      }

      final RegExpMatch? mdyNamed = _mdyNamedRegex.firstMatch(line);
      if (mdyNamed != null) {
        final int? month = _monthMap[(mdyNamed.group(1) ?? '').toLowerCase()];
        if (month != null) {
          final DateTime? dt = buildValidDate(
            day: int.parse(mdyNamed.group(2)!),
            month: month,
            year: int.parse(mdyNamed.group(3)!),
            hour: int.tryParse(mdyNamed.group(4) ?? ''),
            minute: int.tryParse(mdyNamed.group(5) ?? ''),
            second: int.tryParse(mdyNamed.group(6) ?? ''),
            ampm: mdyNamed.group(7),
          );
          if (dt != null) return (date: dt, explicit: true);
        }
      }

      final RegExpMatch? ymd = _ymdIsoRegex.firstMatch(line);
      if (ymd != null) {
        final DateTime? dt = buildValidDate(
          year: int.parse(ymd.group(1)!),
          month: int.parse(ymd.group(2)!),
          day: int.parse(ymd.group(3)!),
          hour: int.tryParse(ymd.group(4) ?? ''),
          minute: int.tryParse(ymd.group(5) ?? ''),
          second: int.tryParse(ymd.group(6) ?? ''),
        );
        if (dt != null) return (date: dt, explicit: true);
      }

      final RegExpMatch? dmyNum = _dmyNumericRegex.firstMatch(line);
      if (dmyNum != null) {
        final DateTime? dt = buildValidDate(
          day: int.parse(dmyNum.group(1)!),
          month: int.parse(dmyNum.group(2)!),
          year: int.parse(dmyNum.group(3)!),
          hour: int.tryParse(dmyNum.group(4) ?? ''),
          minute: int.tryParse(dmyNum.group(5) ?? ''),
          second: int.tryParse(dmyNum.group(6) ?? ''),
        );
        if (dt != null) return (date: dt, explicit: true);
      }

      final RegExpMatch? shortBca = _shortDmWithTimeRegex.firstMatch(line);
      if (shortBca != null) {
        final int day = int.parse(shortBca.group(1)!);
        final int month = int.parse(shortBca.group(2)!);
        final int inferredYear =
            month > now.month + 1 ? now.year - 1 : now.year;
        final DateTime? dt = buildValidDate(
          year: inferredYear,
          month: month,
          day: day,
          hour: int.parse(shortBca.group(3)!),
          minute: int.parse(shortBca.group(4)!),
          second: int.tryParse(shortBca.group(5) ?? ''),
        );
        if (dt != null) return (date: dt, explicit: true);
      }
    }

    return (date: now, explicit: false);
  }
}

class _QuantityExtraction {
  final int? quantity;
  final double? explicitUnitPrice;
  final String? singleItemName;
  final bool hasMultipleDistinctItems;

  const _QuantityExtraction({
    required this.quantity,
    required this.explicitUnitPrice,
    required this.singleItemName,
    required this.hasMultipleDistinctItems,
  });
}
