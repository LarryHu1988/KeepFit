import SwiftUI
import PhotosUI
import AuthenticationServices
import UIKit

enum MealInputMode: String, CaseIterable, Identifiable {
    case text, voice, photo
    var id: String { rawValue }
    var title: String { switch self { case .text: return localized("打字", "Type"); case .voice: return localized("语音", "Speak"); case .photo: return localized("拍照", "Photo") } }
    var icon: String { switch self { case .text: return "text.bubble"; case .voice: return "mic"; case .photo: return "camera" } }
}

struct MealModelSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var client = MealModelClient()
    @StateObject private var speech = MealSpeechRecorder()
    @State var mode: MealInputMode
    let referenceDate: Date
    let onSaved: (Date) -> Void
    var onCloudDeleted: (() -> Void)? = nil
    @State private var text = ""
    @State private var correction = ""
    @State private var answers: [String: String] = [:]
    @State private var draft: ModelMealDraft?
    @State private var challenge: MealAuthChallenge?
    @State private var busy = false
    @State private var error: String?
    @State private var acceptEstimates = false
    @State private var photo: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var camera = false
    @State private var consent = false
    @State private var showCloudDeletion = false
    @State private var createKey = UUID().uuidString
    @State private var createSignature = ""
    @State private var selectedTime = Date()
    private var pendingKey: String { "keepfit.model.pending." + (client.baseURL?.absoluteString ?? "none") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if client.baseURL == nil {
                        ContentUnavailableView(localized("饮食识别服务准备中", "Meal service is being prepared"), systemImage: "network", description: Text(localized("完成服务部署后即可直接使用，不需要你配置模型密钥。", "Once deployed, this service will work without a model API key.")))
                    } else if !client.authenticated {
                        authentication
                    } else if onCloudDeleted != nil {
                        Text(localized("正在删除云端饮食识别数据…", "Deleting cloud meal recognition data…"))
                    } else if let draft {
                        result(draft)
                    } else {
                        input
                    }
                    if let error {
                        Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("meal.error")
                    }
                    if busy {
                        HStack { ProgressView(); Text(localized("正在处理，请稍候…", "Working…")) }.font(.callout)
                    }
                }
                .padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localized("记一餐", "Log a meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(localized("关闭", "Close")) { dismiss() }.disabled(busy) } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if client.authenticated && onCloudDeleted == nil {
                        Menu {
                            Button(localized("删除云端识别记录并退出", "Delete cloud recognition data and sign out"), role: .destructive) { showCloudDeletion = true }
                        } label: { Image(systemName: "ellipsis.circle") }.disabled(busy)
                    }
                }
            }
            .confirmationDialog(localized("删除云端识别记录？手机中已保存的进食记录会保留。", "Delete cloud recognition data? Saved meals on this phone will remain."), isPresented: $showCloudDeletion, titleVisibility: .visible) {
                Button(localized("删除云端记录并退出", "Delete cloud data and sign out"), role: .destructive) {
                    run { try await client.deleteRemoteData(); UserDefaults.standard.removeObject(forKey: pendingKey); draft = nil; await prepareLogin() }
                }
            }
            .interactiveDismissDisabled(busy)
            .task {
                selectedTime = referenceDate
                if onCloudDeleted != nil, client.signedInUserID != appState.account.userID { client.signOut() }
                if client.authenticated {
                    if onCloudDeleted != nil { run { try await finishCloudDeletion() } }
                    else { await resumePending() }
                } else if client.baseURL != nil { await prepareLogin() }
            }
            .onDisappear { speech.stop() }
            .onChange(of: mode) { _, _ in speech.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop() } }
            .onChange(of: speech.transcript) { _, value in text = value }
            .onChange(of: photo) { _, value in
                Task {
                    guard let value else { return }
                    do {
                        guard let data = try await value.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw MealModelError(message: "无法读取照片，请换一张照片。") }
                        setPhoto(image)
                    } catch { self.error = error.localizedDescription }
                }
            }
            .sheet(isPresented: $camera) { MealCamera { image in if let image { setPhoto(image) } } }
        }
    }

    private var authentication: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(onCloudDeleted == nil ? localized("让 KeepFit 帮你理解这一餐", "Let KeepFit understand your meal") : localized("验证账号并删除云端数据", "Verify account and delete cloud data")).font(.title2.bold())
            if onCloudDeleted != nil { Text(localized("请使用当前 KeepFit 的 Apple 账号验证身份。验证后将删除其云端饮食识别数据，然后继续删除 App 账号。", "Verify with the Apple account used in KeepFit. Its cloud meal data will be deleted before app account deletion continues.")) }
            Text(localized("使用 Apple 登录启用云端饮食识别。只发送本次描述或照片，不会上传你的体重、运动和整份健康历史。", "Sign in with Apple to enable meal recognition. Only this meal's description or photo is sent, not your weight, activity or health history."))
            if let challenge {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = []
                    request.nonce = challenge.nonce
                } onCompletion: { result in
                    run {
                        let authorization = try result.get()
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { throw MealModelError(message: "Apple 未返回有效登录凭证。") }
                        if onCloudDeleted != nil, let expected = appState.account.userID, credential.user != expected {
                            throw MealModelError(message: "请使用当前 KeepFit 账号对应的 Apple 账号验证。")
                        }
                        try await client.signIn(identityToken: token, challenge: challenge, userID: credential.user)
                        if onCloudDeleted != nil { try await finishCloudDeletion() }
                        else { await resumePending() }
                    }
                }
                .signInWithAppleButtonStyle(.black).frame(height: 48).disabled(busy)
            } else {
                Button(localized("准备登录", "Prepare sign-in")) { Task { await prepareLogin() } }.disabled(busy)
            }
        }
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(localized("输入方式", "Input"), selection: $mode) {
                ForEach(MealInputMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).disabled(busy)
            DatePicker(localized("这餐时间", "Meal time"), selection: $selectedTime, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            Text(localized("不用先算克数，说说你实际吃了什么。", "Describe what you actually ate. No need to weigh it first.")).font(.headline)
            if mode == .voice {
                Button {
                    if speech.recording { speech.finish() } else { Task { await speech.start() } }
                } label: {
                    Label(speech.recording ? localized("结束录音", "Stop recording") : localized("开始说话", "Start speaking"), systemImage: speech.recording ? "stop.circle.fill" : "mic.fill")
                }.buttonStyle(.borderedProminent).tint(speech.recording ? .red : .orange).disabled(busy || speech.starting || speech.finishing)
                Text(localized("优先在设备上转写；系统不支持时可能使用 Apple 语音服务。文字可修改，核对后再识别。", "Transcription stays on device when supported; otherwise Apple speech services may be used. Review the text before submitting.")).font(.caption).foregroundStyle(.secondary)
                if let message = speech.message { Text(message).font(.caption) }
            }
            if mode == .photo {
                HStack {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { camera = true } label: { Label(localized("拍照", "Camera"), systemImage: "camera") }
                    }
                    PhotosPicker(selection: $photo, matching: .images) { Label(localized("选择照片", "Choose photo"), systemImage: "photo") }
                }.buttonStyle(.bordered).disabled(busy)
                if let data = photoData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Text(localized("整桌照片不等于你吃下的全部，可以补充“我吃了哪些、还剩多少”。", "A shared table is not your whole meal. Add what you ate and what was left.")).font(.caption).foregroundStyle(.secondary)
            }
            TextField(localized("例如：半碗米饭，三块红烧肉，青菜吃了几口。", "For example: half a bowl of rice, three pieces of pork and a little vegetables."), text: $text, axis: .vertical)
                .lineLimit(4...8).padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("meal.text").disabled(busy)
            Toggle(localized("同意将本次文字或照片交由 KeepFit 服务及小米 MiMo 模型服务处理", "Allow KeepFit and Xiaomi MiMo to process this description or photo"), isOn: $consent)
                .font(.caption).accessibilityIdentifier("meal.consent")
            Button { recognize() } label: { Label(localized("识别这一餐", "Understand this meal"), systemImage: "sparkles").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(.orange)
                .disabled(busy || speech.recording || speech.finishing || !consent || (mode == .photo ? photoData == nil : text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .accessibilityIdentifier("meal.recognize")
        }
    }

    @ViewBuilder private func result(_ value: ModelMealDraft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("核对这一餐", "Review your meal")).font(.title2.bold())
            if let date = value.understanding.mealTime {
                HStack { Text(localized("用餐时间", "Meal time")); Text(date, format: .dateTime.year().month().day().hour().minute()) }.font(.subheadline).foregroundStyle(.secondary)
            }
            Text(value.originalText).font(.callout).foregroundStyle(.secondary)
            if value.model.simulated { Text("演示数据 · 不代表真实识别结果").foregroundStyle(.red) }
            ForEach(value.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(item.name).font(.headline)
                        Spacer()
                        if item.includedInTotals, let n = item.nutrients { Text("约 \(Int(n.caloriesKcal.rounded())) kcal").foregroundStyle(.orange) }
                        else { Text(localized("未计入", "Excluded")).foregroundStyle(.secondary) }
                    }
                    Text(item.originalPortion).font(.subheadline)
                    if let n = item.nutrients, item.includedInTotals {
                        Text("蛋白质 \(n.proteinG, specifier: "%.1f")g · 脂肪 \(n.fatG, specifier: "%.1f")g · 碳水 \(n.carbsG, specifier: "%.1f")g").font(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup(localized("份量与营养依据", "Portion and nutrition source")) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(item.estimationNotes.enumerated()), id: \.offset) { _, note in Text(note) }
                            if let source = item.nutritionSource, let raw = source.url, let url = URL(string: raw), url.scheme == "https" {
                                Link(source.name, destination: url)
                            }
                        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.caption)
                }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14)).opacity(item.includedInTotals ? 1 : 0.6)
            }
            if let totals = value.totals, value.totalsComplete {
                Text(localized("本餐合计约 ", "Estimated meal total: ") + "\(Int(totals.caloriesKcal.rounded())) kcal").font(.title3.bold()).accessibilityIdentifier("meal.total")
            } else { Text(localized("信息还不完整，暂不显示整餐总量。", "More information is needed before calculating a meal total.")).foregroundStyle(.secondary) }
            ForEach(value.understanding.questions) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.text).font(.headline)
                    ForEach(question.options, id: \.self) { option in
                        Button { answers[question.id] = option } label: {
                            HStack { Text(option); Spacer(); if answers[question.id] == option { Image(systemName: "checkmark.circle.fill") } }
                        }.buttonStyle(.bordered).tint(.orange)
                    }
                    TextField(localized("也可以自己补充", "Or type your answer"), text: Binding(get: { answers[question.id] ?? "" }, set: { answers[question.id] = $0 }), axis: .vertical).textFieldStyle(.roundedBorder)
                }
            }
            if !value.understanding.questions.isEmpty {
                Button(localized("用这些补充更新", "Update with these answers")) {
                    run {
                        let sent = answers.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        let updated: ModelMealDraft = try await client.request("v1/intakes/\(value.id)/answers", method: "POST", body: ["expected_revision":value.revision,"answers":sent], key: operationKey(value, "answers", sent.description))
                        setDraft(updated)
                    }
                }.buttonStyle(.borderedProminent).tint(.orange).disabled(busy || answers.values.allSatisfy { $0.isEmpty })
            }
            ForEach(Array(value.understanding.warnings.enumerated()), id: \.offset) { _, warning in Text(warning).font(.caption).foregroundStyle(.secondary) }
            if value.status != "confirmed" {
                TextField(localized("哪里理解错了？直接告诉我", "Tell me what needs correcting"), text: $correction, axis: .vertical).textFieldStyle(.roundedBorder).accessibilityIdentifier("meal.correction")
                Button(localized("按我的纠正更新", "Apply correction")) {
                    run {
                        let updated: ModelMealDraft = try await client.request("v1/intakes/\(value.id)/revise", method: "POST", body: ["expected_revision":value.revision,"correction":correction], key: operationKey(value, "revise", correction))
                        setDraft(updated); correction = ""
                    }
                }.disabled(busy || correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if value.requiresEstimateAcceptance {
                    Toggle(localized("我接受以上明确标注的份量和营养估算", "I accept the stated portion and nutrition estimates"), isOn: $acceptEstimates).font(.callout).accessibilityIdentifier("meal.accept")
                }
            }
            Button { confirm(value) } label: { Text(localized("确认并保存这餐", "Confirm and save this meal")).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(.orange)
                .disabled(busy || !["ready_for_confirmation","confirmed"].contains(value.status) || (value.status != "confirmed" && value.requiresEstimateAcceptance && !acceptEstimates))
                .accessibilityIdentifier("meal.confirm")
            Button(localized("重新记录另一餐", "Start a different meal")) {
                draft = nil; answers = [:]; correction = ""; acceptEstimates = false; createSignature = ""
                UserDefaults.standard.removeObject(forKey: pendingKey)
            }.disabled(busy)
        }.disabled(busy)
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch {
                self.error = error.localizedDescription
                if !client.authenticated { challenge = nil; await prepareLogin() }
            }
        }
    }
    private func prepareLogin() async {
        do { challenge = try await client.challenge(); error = nil }
        catch { self.error = error.localizedDescription }
    }
    private func resumePending() async {
        guard let id = UserDefaults.standard.string(forKey: pendingKey) else { return }
        do { let restored: ModelMealDraft = try await client.request("v1/intakes/\(id)"); setDraft(restored) }
        catch {
            if (error as? MealModelError)?.statusCode == 404 { UserDefaults.standard.removeObject(forKey: pendingKey) }
            else { self.error = error.localizedDescription }
        }
    }
    private func setDraft(_ value: ModelMealDraft) {
        draft = value; answers = [:]; acceptEstimates = false
        UserDefaults.standard.set(value.id, forKey: pendingKey)
    }
    private func recognize() {
        speech.stop()
        var payload: [String: Any] = ["source":mode.rawValue,"timezone":TimeZone.current.identifier,"reference_time":ISO8601DateFormatter().string(from: selectedTime)]
        if mode == .voice { payload["transcript"] = text }
        else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { payload["text"] = text }
        if mode == .photo, let data = photoData { payload["image"] = ["mime_type":"image/jpeg","base64_data":data.base64EncodedString()] }
        let signature = text + mode.rawValue + String(selectedTime.timeIntervalSince1970) + String(photoData?.hashValue ?? 0)
        if signature != createSignature { createSignature = signature; createKey = UUID().uuidString }
        run {
            let result: ModelMealDraft = try await client.request("v1/intakes", method: "POST", body: payload, key: createKey)
            setDraft(result)
        }
    }
    private func finishCloudDeletion() async throws {
        try await client.deleteRemoteData()
        UserDefaults.standard.removeObject(forKey: pendingKey)
        onCloudDeleted?()
        dismiss()
    }
    private func confirm(_ value: ModelMealDraft) {
        run {
            let record: ModelMealRecord
            if let id = value.recordId { record = try await client.request("v1/records/\(id)") }
            else {
                record = try await client.request("v1/intakes/\(value.id)/confirm", method: "POST", body: ["expected_revision":value.revision,"accept_estimates":acceptEstimates], key: "confirm-\(value.id)-\(value.revision)")
                setDraft(record.snapshot)
            }
            try appState.importModelMeal(record)
            UserDefaults.standard.removeObject(forKey: pendingKey)
            onSaved(record.snapshot.understanding.mealTime ?? referenceDate); dismiss()
        }
    }
    private func operationKey(_ value: ModelMealDraft, _ action: String, _ content: String) -> String {
        "\(action)-\(value.id)-\(value.revision)-\(MealModelClient.logID(recordID: value.id, itemID: content).uuidString)"
    }
    private func setPhoto(_ image: UIImage) {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1,image.size.width * scale), height: max(1,image.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        photoData = rendered.jpegData(compressionQuality: 0.8)
        if (photoData?.count ?? 0) > 4 * 1024 * 1024 { photoData = nil; error = "照片过大，请选择更小的照片。" }
    }
}

private struct MealCamera: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController(); controller.sourceType = .camera; controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MealCamera
        init(_ parent: MealCamera) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { parent.onImage(info[.originalImage] as? UIImage); parent.dismiss() }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
