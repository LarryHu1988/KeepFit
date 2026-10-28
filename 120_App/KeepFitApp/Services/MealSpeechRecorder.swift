import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class MealSpeechRecorder: ObservableObject {
    @Published var transcript = ""
    @Published var recording = false
    @Published private(set) var starting = false
    @Published private(set) var finishing = false
    private var generation = UUID()
    @Published var message: String?
    private let engine = AVAudioEngine()
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false

    func start() async {
        guard !recording && !starting && !finishing else { return }
        starting = true
        let attempt = generation
        defer { starting = false }
        message = nil
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard attempt == generation else { return }
        guard status == .authorized, microphone else {
            message = "请在系统设置中允许 KeepFit 使用麦克风与语音识别，也可以直接打字。"; return
        }
        guard let recognizer, recognizer.isAvailable else { message = "当前语音识别不可用，可以直接打字。"; return }
        do {
            stop()
            transcript = ""
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            request.contextualStrings = ["红烧肉", "番茄炒蛋", "宫保鸡丁", "米饭", "饺子", "包子", "面条", "半碗", "没吃", "剩下", "四个人一起吃"]
            self.request = request
            let activeGeneration = generation
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw MealModelError(message: "麦克风暂时不可用。") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            tapInstalled = true
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == activeGeneration else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if result?.isFinal == true { self.stop() }
                    else if error != nil && (self.recording || self.finishing) { self.message = "语音识别已结束，请核对文字后继续。"; self.stop() }
                }
            }
            engine.prepare(); try engine.start(); recording = true
        } catch { stop(); message = error.localizedDescription }
    }
    func finish() {
        guard recording else { return }
        recording = false; finishing = true
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); recognitionTask?.finish()
        let activeGeneration = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.generation == activeGeneration, self.finishing else { return }
            self.stop()
        }
    }
    func stop() {
        generation = UUID()
        recording = false; finishing = false
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); recognitionTask?.cancel(); recognitionTask = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
