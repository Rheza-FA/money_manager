import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_receipt.dart';
import '../parser/receipt_parser.dart';

const MethodChannel kReceiptShareChannel = MethodChannel('neymo/receipt_share');

/// Root navigator key used to present the shared-receipt sheet cleanly on top
/// of whichever post-splash screen is currently visible.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ReceiptShareNotifier extends Notifier<ReceiptShareState> {
  int _sessionCounter = 0;
  bool _attached = false;

  @override
  ReceiptShareState build() {
    ref.onDispose(() {
      if (_attached) {
        kReceiptShareChannel.setMethodCallHandler(null);
        _attached = false;
      }
    });
    return const ReceiptShareState();
  }

  /// Attaches the platform channel handler and consumes any cold-start share
  /// payload once the post-splash UI is mounted and ready to present modals.
  Future<void> attachWhenReady() async {
    if (_attached) return;
    _attached = true;

    kReceiptShareChannel.setMethodCallHandler(_handleNativeCall);

    try {
      final Map<Object?, Object?>? initial = await kReceiptShareChannel
          .invokeMapMethod<Object?, Object?>('consumeInitialShare');
      if (initial == null) return;

      final Object? status = initial['status'];
      if (status == 'scanning') {
        _startScanningSession();
      } else if (status == 'ready') {
        final Object? rawPayload = initial['payload'];
        if (rawPayload is Map<Object?, Object?>) {
          _resolvePayload(rawPayload, forceNewSession: true);
        }
      } else if (status == 'error') {
        final Object? errObj = initial['error'] ?? initial['code'];
        _failFromNative(errObj, forceNewSession: true);
      }
    } on MissingPluginException {
      // Non-mobile targets (Web / Desktop) do not register the native channel.
    } on PlatformException catch (e) {
      _failFromNative(e.code, forceNewSession: true);
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onShareStarted':
        _startScanningSession();
        return null;
      case 'onShareResolved':
        final Object? args = call.arguments;
        if (args is Map<Object?, Object?>) {
          _resolvePayload(
            args,
            forceNewSession: state.status != ReceiptShareStatus.scanning,
          );
        } else {
          _failFromNative(
            'EMPTY_PAYLOAD',
            forceNewSession: state.status != ReceiptShareStatus.scanning,
          );
        }
        return null;
      case 'onShareFailed':
        _failFromNative(
          call.arguments,
          forceNewSession: state.status != ReceiptShareStatus.scanning,
        );
        return null;
      default:
        return null;
    }
  }

  void _startScanningSession() {
    _sessionCounter++;
    state = ReceiptShareState(
      status: ReceiptShareStatus.scanning,
      sessionId: _sessionCounter,
    );
  }

  void _resolvePayload(
    Map<Object?, Object?> rawMap, {
    bool forceNewSession = false,
  }) {
    final SharedReceiptPayload payload = SharedReceiptPayload.fromMap(rawMap);
    if (payload.isEmpty) {
      _failFromNative(
        <String, Object?>{
          'code': 'EMPTY_TEXT',
          'referrer': payload.referrer,
        },
        forceNewSession: forceNewSession,
      );
      return;
    }

    final ParsedReceipt parsed = ReceiptParser.parse(payload);

    // If an image/PDF attachment yielded only stripped promo noise with zero
    // meaningful receipt text, surface the read-error state cleanly.
    if (payload.hasAttachment &&
        parsed.rawPreviewLines.isEmpty &&
        parsed.itemName.isEmpty &&
        parsed.amount == null) {
      _failFromNative(
        <String, Object?>{
          'code': 'OCR_EMPTY',
          'referrer': payload.referrer,
          'extraText': payload.extraText,
          'extraSubject': payload.extraSubject,
        },
        forceNewSession: forceNewSession,
      );
      return;
    }

    if (forceNewSession || _sessionCounter == 0) {
      _sessionCounter++;
    }
    state = ReceiptShareState(
      status: ReceiptShareStatus.ready,
      sessionId: _sessionCounter,
      parsed: parsed,
    );
  }

  void _failFromNative(Object? rawError, {bool forceNewSession = false}) {
    String code = 'OCR_FAILED';
    String? referrer;
    String? extraText;
    String? extraSubject;

    if (rawError is String && rawError.isNotEmpty) {
      code = rawError;
    } else if (rawError is Map<Object?, Object?>) {
      final Object? rawCode = rawError['code'];
      if (rawCode is String && rawCode.isNotEmpty) {
        code = rawCode;
      }
      if (rawError['referrer'] is String) {
        referrer = rawError['referrer'] as String;
      }
      if (rawError['extraText'] is String) {
        extraText = rawError['extraText'] as String;
      }
      if (rawError['extraSubject'] is String) {
        extraSubject = rawError['extraSubject'] as String;
      }
    }

    if (forceNewSession || _sessionCounter == 0) {
      _sessionCounter++;
    }

    final String detectedSource = ReceiptParser.detectSourceLabel(
      referrer: referrer,
      extraText: extraText,
      extraSubject: extraSubject,
    );

    final DateTime now = DateTime.now();
    state = ReceiptShareState(
      status: ReceiptShareStatus.error,
      sessionId: _sessionCounter,
      errorCode: code,
      parsed: ParsedReceipt(
        itemName: '',
        amount: null,
        quantity: 1,
        date: now,
        sourceLabel: detectedSource,
      ),
    );
  }

  /// Resets state to idle when the review sheet is closed or saved.
  void clear() {
    if (state.status == ReceiptShareStatus.idle) return;
    state = ReceiptShareState(
      status: ReceiptShareStatus.idle,
      sessionId: _sessionCounter,
    );
  }
}

final NotifierProvider<ReceiptShareNotifier, ReceiptShareState>
    receiptShareProvider =
    NotifierProvider<ReceiptShareNotifier, ReceiptShareState>(
  ReceiptShareNotifier.new,
);
