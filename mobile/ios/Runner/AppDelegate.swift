import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var exportResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ManualOCR") else { return }
    let exportChannel = FlutterMethodChannel(name: "manual_collector/export", binaryMessenger: registrar.messenger())
    exportChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "savePdf" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { return }
      guard self.exportResult == nil else {
        result(FlutterError(code: "busy", message: "请先完成当前保存", details: nil)); return
      }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
            FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(code: "missing", message: "PDF 不存在", details: nil)); return
      }
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      guard var presenter = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "unavailable", message: "无法打开文件保存窗口", details: nil)); return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      self.exportResult = result
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: path)], asCopy: true)
      } else {
        picker = UIDocumentPickerViewController(url: URL(fileURLWithPath: path), in: .exportToService)
      }
      picker.delegate = self
      presenter.present(picker, animated: true)
    }
    let channel = FlutterMethodChannel(name: "manual_collector/ocr", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_path", message: "缺少图片路径", details: nil)); return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
          request.usesLanguageCorrection = true
          try VNImageRequestHandler(url: URL(fileURLWithPath: path)).perform([request])
          let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return ["text": candidate.string, "x": box.minX, "y": 1 - box.maxY,
                    "width": box.width, "height": box.height]
          }
          DispatchQueue.main.async { result(lines) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "ocr_failed", message: "识别失败，请重试：\(error.localizedDescription)", details: nil))
          }
        }
      }
    }
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = exportResult
    exportResult = nil
    result?(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = exportResult
    exportResult = nil
    result?(false)
  }

}
