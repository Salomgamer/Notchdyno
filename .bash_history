mkdir -p NotchIsland/NotchIsland .github/workflows && echo "Directories ready!"
cat << 'EOF' > setup.sh
mkdir -p NotchIsland/NotchIsland .github/workflows
echo "Project directories created successfully!"
EOF

bash setup.sh
cat << 'EOF' > project.yml
name: NotchIsland
options:
  bundleIdPrefix: com.custom
  deploymentTarget:
    iOS: "16.0"
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.custom.notchisland
    MARKETING_VERSION: "2.0.0"
    CURRENT_PROJECT_VERSION: "2"
    SWIFT_VERSION: "5.0"
    CODE_SIGN_IDENTITY: ""
    CODE_SIGNING_REQUIRED: NO
    CODE_SIGNING_ALLOWED: NO
targets:
  NotchIsland:
    type: application
    platform: iOS
    sources:
      - NotchIsland
    info:
      path: NotchIsland/Info.plist
      properties:
        CFBundleDisplayName: NotchIsland
        UILaunchScreen: {}
        NSMotionUsageDescription: "NotchIsland reads your live step count to display it inside the floating island."
        NSAppleMusicUsageDescription: "NotchIsland reads your currently playing song to display it in the island."
        UIBackgroundModes:
          - audio
          - location
          - processing
        UIApplicationSupportsIndirectInputEvents: true
EOF

cat << 'EOF' > .github/workflows/build.yml
name: Build NotchIsland v2 IPA

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  build-ipa:
    runs-on: macos-14
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Build Unsigned App
        run: |
          xcodebuild clean build \
            -project NotchIsland.xcodeproj \
            -scheme NotchIsland \
            -configuration Release \
            -sdk iphoneos \
            -derivedDataPath build_output \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Package into IPA
        run: |
          mkdir -p Payload
          cp -r build_output/Build/Products/Release-iphoneos/NotchIsland.app Payload/
          zip -r9 NotchIsland_v2_unsigned.ipa Payload

      - name: Upload IPA Artifact
        uses: actions/upload-artifact@v4
        with:
          name: NotchIsland-v2-IPA
          path: NotchIsland_v2_unsigned.ipa
EOF

cat << 'EOF' > NotchIsland/NotchIslandApp.swift
import SwiftUI

@main
struct NotchIslandApp: App {
    @StateObject private var manager = IslandManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        manager.ensureBackgroundExecution()
                    }
                }
        }
    }
}
EOF

cat << 'EOF' > NotchIsland/ContentView.swift
import SwiftUI
import AVKit

struct PiPLayerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        layer.frame = CGRect(x: 0, y: 0, width: 330, height: 60)
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        layer.frame = uiView.bounds
    }
}

struct ContentView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var isExpanded: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.04, green: 0.04, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack {
                    HStack(spacing: 14) {
                        Image(systemName: manager.isPlayingMusic ? "waveform.circle.fill" : "music.note")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.currentTrack)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(manager.currentArtist)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("👟 \(manager.stepCount)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Text("⏱️ \(manager.formattedStopwatch())")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if isExpanded {
                        Divider().background(Color.gray.opacity(0.4)).padding(.vertical, 6)
                        HStack(spacing: 24) {
                            Button(action: { manager.toggleStopwatch() }) {
                                Label(manager.isStopwatchRunning ? "Pause" : "Start", systemImage: manager.isStopwatchRunning ? "pause.fill" : "play.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.25))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                            
                            Button(action: { manager.resetStopwatch() }) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.25))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 16)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }
                
                VStack(spacing: 6) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Always-On Out-of-App Floating Stream")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                    
                    PiPLayerView(layer: manager.sampleBufferDisplayLayer)
                        .frame(width: 330, height: 60)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1))
                }
                
                VStack(spacing: 14) {
                    Toggle("Auto-Pop Out When Swiping Home", isOn: $manager.autoPopOutOnExit)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                    
                    Button(action: { manager.togglePiP() }) {
                        HStack {
                            Image(systemName: manager.isPiPActive ? "pip.exit" : "pip.enter")
                            Text(manager.isPiPActive ? "Hide Floating Island" : "Activate Floating Island Now")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manager.isPiPActive ? Color.red : Color.green)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { manager.toggleStopwatch() }) {
                            HStack {
                                Image(systemName: manager.isStopwatchRunning ? "pause.circle.fill" : "stopwatch.fill")
                                Text(manager.isStopwatchRunning ? "Pause Timer" : "Start Stopwatch")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        Button(action: { manager.resetStopwatch() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    
                    Button(action: {
                        manager.isPlayingMusic.toggle()
                        if manager.isPlayingMusic && manager.currentTrack == "No Media Playing" {
                            manager.currentTrack = "Let It Happen"
                            manager.currentArtist = "Tame Impala"
                        }
                    }) {
                        HStack {
                            Image(systemName: "music.note.list")
                            Text("Test Media Expansion")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.purple.opacity(0.25))
                        .foregroundColor(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 16)
                
                Spacer()
                
                Text("Swipe up to your Home Screen or open any app—the black Dynamic Island pill pops out automatically and updates live in the background!")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
    }
}
EOF

cat << 'EOF' > NotchIsland/IslandManager.swift
import Foundation
import SwiftUI
import AVKit
import AVFoundation
import CoreMotion
import MediaPlayer
import Combine

class IslandManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published var currentTrack: String = "No Media Playing"
    @Published var currentArtist: String = "Play music to expand"
    @Published var isPlayingMusic: Bool = false
    
    @Published var stepCount: Int = 0
    @Published var stopwatchTime: TimeInterval = 0
    @Published var isStopwatchRunning: Bool = false
    @Published var isPiPActive: Bool = false
    @Published var autoPopOutOnExit: Bool = true
    
    private let pedometer = CMPedometer()
    private var stopwatchStartDate: Date?
    private var accumulatedStopwatchTime: TimeInterval = 0
    
    private var silentAudioPlayer: AVAudioPlayer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var renderSourceTimer: DispatchSourceTimer?
    
    let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    
    override init() {
        super.init()
        setupContinuousBackgroundAudio()
        startStepTracking()
        setupNowPlayingObserver()
        setupPiP()
        startHighPriorityFrameRenderer()
    }
    
    private func setupContinuousBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let wavData = Self.makeSilentWavData()
            silentAudioPlayer = try AVAudioPlayer(data: wavData)
            silentAudioPlayer?.numberOfLoops = -1
            silentAudioPlayer?.volume = 0.01
            silentAudioPlayer?.prepareToPlay()
            silentAudioPlayer?.play()
        } catch {
            print("Background Audio Error: \(error)")
        }
    }
    
    func ensureBackgroundExecution() {
        if silentAudioPlayer?.isPlaying == false {
            silentAudioPlayer?.play()
        }
        if backgroundTaskID == .invalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "KeepIslandAlive") { [weak self] in
                if let id = self?.backgroundTaskID {
                    UIApplication.shared.endBackgroundTask(id)
                }
                self?.backgroundTaskID = .invalid
            }
        }
        if autoPopOutOnExit, let pip = pipController, !pip.isPictureInPictureActive {
            pip.startPictureInPicture()
        }
    }
    
    private static func makeSilentWavData() -> Data {
        let sampleRate: Int32 = 8000
        let numSamples: Int32 = 8000
        let dataSize: Int32 = numSamples * 2
        let fileSize: Int32 = 36 + dataSize
        
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        data.append("WAVEfmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: Int32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: (sampleRate * 2).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: Int16(2).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: Int16(16).littleEndian) { Data($0) })
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        data.append(Data(count: Int(dataSize)))
        return data
    }
    
    func startStepTracking() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self?.stepCount = data.numberOfSteps.intValue
            }
        }
    }
    
    func setupNowPlayingObserver() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNowPlaying),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        updateNowPlaying()
    }
    
    @objc func updateNowPlaying() {
        let player = MPMusicPlayerController.systemMusicPlayer
        DispatchQueue.main.async {
            if let item = player.nowPlayingItem {
                self.currentTrack = item.title ?? "Unknown Track"
                self.currentArtist = item.artist ?? "Unknown Artist"
                self.isPlayingMusic = (player.playbackState == .playing)
            } else {
                self.isPlayingMusic = (player.playbackState == .playing)
            }
        }
    }
    
    func toggleStopwatch() {
        if isStopwatchRunning {
            if let start = stopwatchStartDate {
                accumulatedStopwatchTime += Date().timeIntervalSince(start)
            }
            stopwatchStartDate = nil
            isStopwatchRunning = false
        } else {
            stopwatchStartDate = Date()
            isStopwatchRunning = true
        }
    }
    
    func resetStopwatch() {
        stopwatchStartDate = nil
        accumulatedStopwatchTime = 0
        stopwatchTime = 0
        isStopwatchRunning = false
    }
    
    func formattedStopwatch() -> String {
        let total = stopwatchTime
        let totalSeconds = Int(total)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let tenths = Int((total - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    func setupPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
        pushIslandFrame()
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sampleBufferDisplayLayer,
            playbackDelegate: self
        )
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        pipController?.requiresLinearPlayback = true
    }
    
    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }
    
    func startHighPriorityFrameRenderer() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isStopwatchRunning, let start = self.stopwatchStartDate {
                self.stopwatchTime = self.accumulatedStopwatchTime + Date().timeIntervalSince(start)
            }
            self.pushIslandFrame()
        }
        timer.resume()
        renderSourceTimer = timer
    }
    
    private func pushIslandFrame() {
        let size = CGSize(width: 660, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            
            UIColor.black.setFill()
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 60)
            path.fill()
            
            UIColor(white: 0.25, alpha: 1.0).setStroke()
            path.lineWidth = 3
            path.stroke()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 23, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            let stepAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.systemGreen
            ]
            let timerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.systemOrange
            ]
            
            let musicIcon = isPlayingMusic ? "🎵 " : "⏸️ "
            let trackText = (musicIcon + currentTrack) as NSString
            trackText.draw(in: CGRect(x: 32, y: 24, width: 340, height: 32), withAttributes: titleAttrs)
            
            let artistText = currentArtist as NSString
            artistText.draw(in: CGRect(x: 32, y: 60, width: 340, height: 26), withAttributes: subAttrs)
            
            let stepsString = "👟 \(stepCount)" as NSString
            stepsString.draw(in: CGRect(x: 410, y: 24, width: 220, height: 32), withAttributes: stepAttrs)
            
            let swString = "⏱️ \(formattedStopwatch())" as NSString
            swString.draw(in: CGRect(x: 410, y: 60, width: 220, height: 32), withAttributes: timerAttrs)
        }
        
        if let sampleBuffer = image.toCMSampleBuffer() {
            if sampleBufferDisplayLayer.status == .failed {
                sampleBufferDisplayLayer.flush()
            }
            sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
}

extension IslandManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        DispatchQueue.main.async {
            self.toggleStopwatch()
        }
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension UIImage {
    func toCMSampleBuffer() -> CMSampleBuffer? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDesc = formatDescription else { return nil }
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 10),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: CMTime.invalid
        )
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }
}
EOF

