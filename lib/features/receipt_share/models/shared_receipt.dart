import 'package:flutter/foundation.dart';

/// Maximum number of lines retained from a single shared receipt payload to
/// bound memory and parsing work on pathological inputs.
const int kMaxReceiptLines = 120;

/// Maximum character length kept per line.
const int kMaxReceiptLineLength = 240;

@immutable
class SharedReceiptPayload {
  final List<String> ocrLines;
  final String? extraText;
  final String? extraSubject;
  final String? mimeType;
  final String? referrer;
  final bool hasAttachment;

  const SharedReceiptPayload({
    this.ocrLines = const <String>[],
    this.extraText,
    this.extraSubject,
    this.mimeType,
    this.referrer,
    this.hasAttachment = false,
  });

  factory SharedReceiptPayload.fromMap(Map<Object?, Object?> map) {
    final List<String> sanitizedLines = <String>[];
    final Object? rawLines = map['lines'];
    if (rawLines is List<Object?>) {
      for (final Object? entry in rawLines) {
        if (sanitizedLines.length >= kMaxReceiptLines) break;
        if (entry is String) {
          final String trimmed = entry.trim();
          if (trimmed.isNotEmpty) {
            sanitizedLines.add(
              trimmed.length > kMaxReceiptLineLength
                  ? trimmed.substring(0, kMaxReceiptLineLength)
                  : trimmed,
            );
          }
        }
      }
    }

    String? cleanOptional(Object? raw, {int maxLen = 4000}) {
      if (raw is! String) return null;
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.length > maxLen ? trimmed.substring(0, maxLen) : trimmed;
    }

    final String? mime = cleanOptional(map['mimeType'], maxLen: 120);
    final bool inferredAttachment = map['hasAttachment'] is bool
        ? map['hasAttachment'] as bool
        : (sanitizedLines.isNotEmpty ||
            (mime != null && !mime.toLowerCase().startsWith('text/')));

    return SharedReceiptPayload(
      ocrLines: List<String>.unmodifiable(sanitizedLines),
      extraText: cleanOptional(map['extraText']),
      extraSubject: cleanOptional(map['extraSubject'], maxLen: 300),
      mimeType: mime,
      referrer: cleanOptional(map['referrer'], maxLen: 200),
      hasAttachment: inferredAttachment,
    );
  }

  bool get isEmpty =>
      ocrLines.isEmpty &&
      (extraText == null || extraText!.isEmpty) &&
      (extraSubject == null || extraSubject!.isEmpty);
}

@immutable
class ParsedReceipt {
  final String itemName;
  final List<String> nameCandidates;
  final double? amount;
  final int quantity;
  final DateTime date;
  final bool hasExplicitDate;
  final String sourceLabel;
  final bool isQris;
  final bool isLikelyIncoming;
  final List<String> rawPreviewLines;

  const ParsedReceipt({
    required this.itemName,
    this.nameCandidates = const <String>[],
    required this.amount,
    this.quantity = 1,
    required this.date,
    this.hasExplicitDate = false,
    required this.sourceLabel,
    this.isQris = false,
    this.isLikelyIncoming = false,
    this.rawPreviewLines = const <String>[],
  });

  bool get isComplete =>
      itemName.trim().isNotEmpty &&
      quantity > 0 &&
      amount != null &&
      amount! > 0;
}

enum ReceiptShareStatus {
  idle,
  scanning,
  ready,
  error,
}

@immutable
class ReceiptShareState {
  final ReceiptShareStatus status;
  final int sessionId;
  final ParsedReceipt? parsed;
  final String? errorCode;

  const ReceiptShareState({
    this.status = ReceiptShareStatus.idle,
    this.sessionId = 0,
    this.parsed,
    this.errorCode,
  });

  bool get isActive => status != ReceiptShareStatus.idle;
}
