import SwiftUI
import AVFoundation

enum ScanMode: String, CaseIterable {
    case single = "拍照"
    case burst = "连拍"
    case document = "文档"
}

struct ScanView: View {
    @State private var scanMode: ScanMode = .single
    @State private var capturedPages: [UIImage] = []
    @State private var showConfirm = false
    @State private var isCapturing = false
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        ZStack {
            // Camera preview placeholder
            cameraPreviewPlaceholder
                .ignoresSafeArea()

            VStack {
                // Mode selector
                modePicker
                Spacer()
                // Bottom bar
                bottomBar
            }
        }
        .navigationDestination(isPresented: $showConfirm) {
            ScanConfirmView()
        }
        .navigationTitle("扫描")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var modePicker: some View {
        Picker("扫描模式", selection: $scanMode) {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }

    private var cameraPreviewPlaceholder: some View {
        ZStack {
            Color.black
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.3))
                Text("相机预览区域")
                    .foregroundStyle(.white.opacity(0.5))
                    .md3BodyLarge()
            }

            // Viewfinder corner indicator
            ViewfinderCornerOverlay()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 24) {
            // Thumbnail / page count
            Button {
                if !capturedPages.isEmpty {
                    showConfirm = true
                }
            } label: {
                if let last = capturedPages.last {
                    Image(uiImage: last)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.colors.outlineVariant, lineWidth: 1)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("\(capturedPages.count)")
                                .md3LabelLarge()
                                .foregroundStyle(.white)
                        )
                }
            }
            .buttonStyle(.plain)

            // Capture button
            Button {
                capturePage()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(theme.colors.primary, lineWidth: 4)
                            .frame(width: 62, height: 62)
                    )
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                    )
            }
            .buttonStyle(.plain)

            // Done button
            Button {
                if !capturedPages.isEmpty {
                    showConfirm = true
                }
            } label: {
                Text("完成")
                    .md3LabelLarge()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(theme.colors.primary)
                    .clipShape(Capsule())
            }
            .disabled(capturedPages.isEmpty)
            .opacity(capturedPages.isEmpty ? 0.4 : 1)
        }
        .padding(.bottom, 32)
        .padding(.horizontal, 16)
    }

    private func capturePage() {
        isCapturing = true
        // TODO: 실제 AVCapturePhotoOutput 캡처 로직
        let placeholder = UIImage()
        capturedPages.append(placeholder)
        isCapturing = false
    }
}

struct ViewfinderCornerOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.75
            let h = geo.size.height * 0.45
            let inset = (geo.size.width - w) / 2
            let vInset = (geo.size.height - h) / 2
            ZStack {
                ForEach([(0, 0), (1, 0), (0, 1), (1, 1)], id: \.0) { col, row in
                    RoundedRectangle(cornerRadius: 4)
                        .trim(from: col == 0 ? 0 : 0.75,
                              to: col == 0 ? 0.25 : 1)
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 40, height: 40)
                        .position(
                            x: inset + (col == 0 ? 0 : w),
                            y: vInset + (row == 0 ? 0 : h)
                        )
                }
            }
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(MD3Theme())
}
