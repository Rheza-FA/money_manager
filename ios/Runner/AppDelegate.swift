import Flutter
import PDFKit
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      IosReceiptShareCoordinator.shared.handleIncomingURL(url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      IosReceiptShareCoordinator.shared.handleIncomingURL(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    IosReceiptShareCoordinator.shared.attach(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

final class IosReceiptShareCoordinator {
  static let shared = IosReceiptShareCoordinator()

  private enum PendingState {
    case scanning
    case ready([String: Any?])
    case failed(String)
  }

  private let lock = NSLock()
  private let queue = DispatchQueue(label: "com.neymo.receipt_share_ocr", qos: .userInitiated)
  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var activeJobId: Int64 = 0
  private var pendingInitial: PendingState?

  private init() {}

  func attach(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "neymo/receipt_share",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "consumeInitialShare" {
        self.lock.lock()
        self.dartReady = true
        let snapshot = self.pendingInitial
        if case .scanning = snapshot {
          // Keep scanning marker until background OCR resolves.
        } else {
          self.pendingInitial = nil
        }
        self.lock.unlock()

        switch snapshot {
        case .none:
          result(nil)
        case .some(.scanning):
          result(["status": "scanning"])
        case .some(.ready(let payload)):
          result(["status": "ready", "payload": payload])
        case .some(.failed(let code)):
          result(["status": "error", "code": code])
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = methodChannel
  }

  func handleURLContexts(_ contexts: Set<UIOpenURLContext>) {
    guard let firstFile = contexts.first(where: { $0.url.isFileURL }) else { return }
    handleIncomingURL(firstFile.url)
  }

  func handleIncomingURL(_ url: URL) {
    guard url.isFileURL else { return }
    let jobId = startScanningJob()

    queue.async { [weak self] in
      guard let self = self else { return }
      let scoped = url.startAccessingSecurityScopedResource()
      defer {
        if scoped { url.stopAccessingSecurityScopedResource() }
        if url.path.contains("/Documents/Inbox/") {
          try? FileManager.default.removeItem(at: url)
        }
      }

      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? NSNumber,
          fileSize.int64Value > 20 * 1024 * 1024
        {
          self.deliverFailure(jobId: jobId, code: "FILE_TOO_LARGE")
          return
        }

        let ext = url.pathExtension.lowercased()
        if ext == "txt" {
          let text = try String(contentsOf: url, encoding: .utf8)
          self.deliverReady(
            jobId: jobId,
            payload: [
              "lines": [String](),
              "extraText": text,
              "extraSubject": nil,
              "mimeType": "text/plain",
              "referrer": nil,
              "hasAttachment": false,
            ]
          )
          return
        }

        let lines: [String]
        let mime: String
        if ext == "pdf" {
          lines = try self.extractFromPdf(url: url)
          mime = "application/pdf"
        } else {
          let data = try Data(contentsOf: url)
          guard let image = UIImage(data: data),
            let cgImage = self.normalizeImageForOcr(image)
          else {
            self.deliverFailure(jobId: jobId, code: "DECODE_IMAGE_FAILED")
            return
          }
          lines = try self.recognizeLines(cgImage: cgImage)
          mime = "image/\(ext.isEmpty ? "png" : ext)"
        }

        if lines.isEmpty {
          self.deliverFailure(jobId: jobId, code: "OCR_EMPTY")
          return
        }

        self.deliverReady(
          jobId: jobId,
          payload: [
            "lines": lines,
            "extraText": nil,
            "extraSubject": nil,
            "mimeType": mime,
            "referrer": nil,
            "hasAttachment": true,
          ]
        )
      } catch {
        self.deliverFailure(jobId: jobId, code: "OCR_FAILED")
      }
    }
  }

  private func startScanningJob() -> Int64 {
    lock.lock()
    activeJobId += 1
    let id = activeJobId
    let notify = dartReady
    if !dartReady { pendingInitial = .scanning }
    lock.unlock()

    if notify {
      DispatchQueue.main.async { [weak self] in
        self?.channel?.invokeMethod("onShareStarted", arguments: nil)
      }
    }
    return id
  }

  private func deliverReady(jobId: Int64, payload: [String: Any?]) {
    lock.lock()
    guard jobId == activeJobId else {
      lock.unlock()
      return
    }
    let push = dartReady
    pendingInitial = dartReady ? nil : .ready(payload)
    lock.unlock()

    if push {
      DispatchQueue.main.async { [weak self] in
        self?.channel?.invokeMethod("onShareResolved", arguments: payload)
      }
    }
  }

  private func deliverFailure(jobId: Int64, code: String) {
    lock.lock()
    guard jobId == activeJobId else {
      lock.unlock()
      return
    }
    let push = dartReady
    pendingInitial = dartReady ? nil : .failed(code)
    lock.unlock()

    if push {
      DispatchQueue.main.async { [weak self] in
        self?.channel?.invokeMethod("onShareFailed", arguments: code)
      }
    }
  }

  private func normalizeImageForOcr(_ image: UIImage) -> CGImage? {
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    guard pixelWidth > 0, pixelHeight > 0 else { return image.cgImage }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
    let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: targetSize))
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return rendered.cgImage
  }

  private func extractFromPdf(url: URL) throws -> [String] {
    guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
      throw NSError(domain: "NeymoReceipt", code: 1)
    }
    var allLines: [String] = []
    let count = min(2, doc.pageCount)
    for idx in 0..<count {
      guard let page = doc.page(at: idx) else { continue }
      let rect = page.bounds(for: .mediaBox)
      let maxSide = max(rect.width, rect.height, 1)
      let scale = min(max(2200.0 / maxSide, 1.5), 3.5)
      let targetSize = CGSize(width: rect.width * scale, height: rect.height * scale)

      let renderer = UIGraphicsImageRenderer(size: targetSize)
      let img = renderer.image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: targetSize))
        ctx.cgContext.translateBy(x: 0, y: targetSize.height)
        ctx.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: ctx.cgContext)
      }
      if let cg = img.cgImage {
        allLines.append(contentsOf: try recognizeLines(cgImage: cg))
      }
    }
    return allLines
  }

  private struct Segment {
    let text: String
    let minX: CGFloat
    let maxX: CGFloat
    let topEdgeY: CGFloat
    let centerY: CGFloat
    let height: CGFloat
  }

  private func recognizeLines(cgImage: CGImage) throws -> [String] {
    var segments: [Segment] = []
    var capturedError: Error?

    let request = VNRecognizeTextRequest { req, err in
      if let err = err {
        capturedError = err
        return
      }
      guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
      for obs in observations {
        guard let top = obs.topCandidates(1).first else { continue }
        let trimmed = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        if top.confidence > 0 && top.confidence < 0.36
          && !trimmed.contains(where: \.isNumber)
          && trimmed.lowercased() != "rp"
          && trimmed.lowercased() != "idr"
        {
          continue
        }
        let b = obs.boundingBox // Vision uses bottom-left origin; invert Y to top-down.
        let topDownTopY = 1.0 - b.maxY
        let topDownCenterY = 1.0 - b.midY
        segments.append(
          Segment(
            text: trimmed,
            minX: b.minX,
            maxX: b.maxX,
            topEdgeY: topDownTopY,
            centerY: topDownCenterY,
            height: max(b.height, 0.005)
          )
        )
      }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    if let err = capturedError { throw err }

    segments.sort {
      if abs($0.topEdgeY - $1.topEdgeY) > 0.002 { return $0.topEdgeY < $1.topEdgeY }
      return $0.minX < $1.minX
    }

    var rows: [[Segment]] = []
    for seg in segments {
      if let idx = rows.lastIndex(where: { row in
        let avgY = row.map(\.centerY).reduce(0, +) / CGFloat(row.count)
        let avgH = row.map(\.height).reduce(0, +) / CGFloat(row.count)
        let centerAligned = abs(seg.centerY - avgY) <= min(avgH, seg.height) * 0.55
        let topAligned =
          !centerAligned
          && row.contains { existing in
            abs(seg.topEdgeY - existing.topEdgeY) <= min(existing.height, seg.height) * 0.58
          }
        let inlineContained =
          !centerAligned && !topAligned
          && row.contains { existing in
            let vOverlap =
              min(existing.centerY + existing.height * 0.5, seg.centerY + seg.height * 0.5)
              - max(existing.centerY - existing.height * 0.5, seg.centerY - seg.height * 0.5)
            return vOverlap >= min(existing.height, seg.height) * 0.65
          }
        if !centerAligned && !topAligned && !inlineContained { return false }
        for existing in row {
          let overlap = min(existing.maxX, seg.maxX) - max(existing.minX, seg.minX)
          let minW = max(min(existing.maxX - existing.minX, seg.maxX - seg.minX), 0.001)
          if overlap > 0 && (overlap / minW) > 0.25 { return false }
        }
        return true
      }) {
        rows[idx].append(seg)
      } else {
        rows.append([seg])
      }
    }

    rows.sort {
      ($0.map(\.topEdgeY).min() ?? 0) < ($1.map(\.topEdgeY).min() ?? 0)
    }

    return rows.map { row in
      row.sorted { $0.minX < $1.minX }
        .map(\.text)
        .joined(separator: "   ")
    }
  }
}
