import SwiftUI
import AVFoundation
import Vision

// MARK: – SwiftUI wrapper -----------------------------------------------------
struct CameraView: UIViewControllerRepresentable {
    @Binding var isUsingFrontCamera: Bool
    @Binding var sessionActive: Bool
    let playerAge: Int
    let playerHandedness: String
    
    func makeUIViewController(context: Context) -> CameraVC {
        CameraVC(
            isUsingFrontCamera: isUsingFrontCamera,
            sessionActive: sessionActive,
            playerAge: playerAge,
            playerHandedness: playerHandedness
        )
    }
    
    func updateUIViewController(_ uiViewController: CameraVC, context: Context) {
        if uiViewController.isUsingFrontCamera != isUsingFrontCamera {
            uiViewController.flipCamera(toFront: isUsingFrontCamera)
        }
        
        // Update player handedness when it changes
        if uiViewController.playerHandedness != playerHandedness {
            uiViewController.updatePlayerHandedness(playerHandedness)
        }
        
        // Clear overlay when session becomes inactive
        if uiViewController.sessionActive != sessionActive {
            uiViewController.sessionActive = sessionActive
            if !sessionActive {
                uiViewController.clearOverlay()
            }
        }
    }
}

// MARK: – UIKit view controller ----------------------------------------------
final class CameraVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    // Core objects
    private let session = AVCaptureSession()
    private var handler = VNSequenceRequestHandler()
    private var poseRequest = VNDetectHumanBodyPoseRequest()

    // UI
    private let overlay = BasketballOverlayView()
    private var preview: AVCaptureVideoPreviewLayer!
    
    // Camera state
    private var currentInput: AVCaptureDeviceInput?
    var isUsingFrontCamera: Bool
    var sessionActive: Bool
    
    // Basketball-specific components
    private let anomalyDetector = AnomalyDetector()
    private let aiCoach = AICoach()
    
    // Player profile
    private let playerAge: Int
    var playerHandedness: String {
        didSet {
            // Update overlay when handedness changes
            overlay.playerHandedness = playerHandedness
            // Update anomaly detector
            anomalyDetector.playerHandedness = playerHandedness
        }
    }
    
    // Session tracking
    private var sessionID: String = UUID().uuidString
    
    // MARK: - High Performance Rendering Control - OPTIMIZED FOR FLUENT LANDMARK TRACKING
    private var lastOverlayUpdateTime: TimeInterval = 0
    // CHANGED: Reduced interval for more fluent landmark rendering (from 0.033 to 0.016 = ~60 FPS)
    private let overlayUpdateInterval: TimeInterval = 0.016 // ~60 FPS overlay updates for smoother tracking
    private var isProcessingFrame = false
    private let processingQueue = DispatchQueue(label: "poseProcessing", qos: .userInteractive)
    private var hasActiveOverlay = false  // Track if overlay has content
    
    // ─────────────── Initialization ───────────────
    init(isUsingFrontCamera: Bool = false, sessionActive: Bool = false, playerAge: Int, playerHandedness: String) {
        self.isUsingFrontCamera = isUsingFrontCamera
        self.sessionActive = sessionActive
        self.playerAge = playerAge
        self.playerHandedness = playerHandedness
        super.init(nibName: nil, bundle: nil)
        
        // Configure pose request for better performance
        configurePoseRequest()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configurePoseRequest() {
        // Configure pose request for better performance
        poseRequest.preferBackgroundProcessing = false  // Process in foreground for speed
    }

    // ─────────────── Life‑cycle ───────────────
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()

        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Set initial handedness
        overlay.playerHandedness = playerHandedness
        view.addSubview(overlay)
        
        // Start anomaly detection session
        anomalyDetector.startSession()
        anomalyDetector.playerHandedness = playerHandedness
        
        // Set up AI coach callback
        aiCoach.onFeedbackReceived = { [weak self] feedback in
            DispatchQueue.main.async {
                self?.overlay.showCoachingFeedback(feedback)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInteractive).async { self.session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInteractive).async { self.session.stopRunning() }
    }
    
    // ─────────────── Update Player Handedness ───────────────
    func updatePlayerHandedness(_ handedness: String) {
        playerHandedness = handedness
    }

    // ─────────────── Camera config ───────────────
    private func setupCamera() {
        session.beginConfiguration()
        
        // Use higher preset for better quality while maintaining performance
        session.sessionPreset = .hd1920x1080
        
        // Set minimum frame duration for 60 FPS if supported
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                try device.lockForConfiguration()
                // Set to 60 FPS if available
                let desiredFrameRate = 60
                let ranges = device.activeFormat.videoSupportedFrameRateRanges
                for range in ranges {
                    if range.maxFrameRate >= Double(desiredFrameRate) {
                        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
                        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
                        break
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("Could not configure frame rate: \(error)")
            }
        }

        // Input
        setupCameraInput()

        // Preview
        preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        // Output with optimized settings for high frame rate processing
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        
        // CHANGED: Allow frame dropping only when absolutely necessary to maintain fluent tracking
        output.alwaysDiscardsLateVideoFrames = true  // Changed to true to prevent backlog
        
        output.setSampleBufferDelegate(self,
                                       queue: DispatchQueue(label: "basketballVideoQ",
                                                            qos: .userInteractive))
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        session.commitConfiguration()
    }
    
    private func setupCameraInput() {
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: position),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else { return }
        
        // Remove existing input if any
        if let currentInput = currentInput {
            session.removeInput(currentInput)
        }
        
        session.addInput(input)
        self.currentInput = input
    }
    
    // ─────────────── Camera flip function ───────────────
    func flipCamera(toFront: Bool) {
        guard isUsingFrontCamera != toFront else { return }
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove current input
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            // Update state
            self.isUsingFrontCamera = toFront
            
            // Add new input
            let position: AVCaptureDevice.Position = toFront ? .front : .back
            
            if let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: position),
               let newInput = try? AVCaptureDeviceInput(device: newCamera),
               self.session.canAddInput(newInput) {
                
                self.session.addInput(newInput)
                self.currentInput = newInput
                
                // Reconfigure frame rate for new camera
                do {
                    try newCamera.lockForConfiguration()
                    let desiredFrameRate = 60
                    let ranges = newCamera.activeFormat.videoSupportedFrameRateRanges
                    for range in ranges {
                        if range.maxFrameRate >= Double(desiredFrameRate) {
                            newCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
                            newCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(desiredFrameRate))
                            break
                        }
                    }
                    newCamera.unlockForConfiguration()
                } catch {
                    print("Could not configure frame rate: \(error)")
                }
            }
            
            self.session.commitConfiguration()
            
            // Reset Vision detection components for new camera
            self.resetVisionDetection()
        }
    }
    
    // ─────────────── Clear Overlay ───────────────
    func clearOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.overlay.clearAll()
        }
    }
    
    // ─────────────── Reset Vision Detection ───────────────
    private func resetVisionDetection() {
        // Create new handler and request to reset any internal state
        handler = VNSequenceRequestHandler()
        poseRequest = VNDetectHumanBodyPoseRequest()
        configurePoseRequest()
        
        // Reset anomaly detector
        anomalyDetector.startSession()
        
        // Reset processing flag
        isProcessingFrame = false
        lastOverlayUpdateTime = 0
        hasActiveOverlay = false
        
        // Clear overlay points to provide visual feedback that detection is resetting
        DispatchQueue.main.async { [weak self] in
            self?.overlay.clearAll()
        }
    }

    // ─────────────── Frame‑by‑frame processing - OPTIMIZED FOR FLUENT TRACKING ───────────────
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard sessionActive else {
            // Clear overlay when not active
            if hasActiveOverlay {
                hasActiveOverlay = false
                DispatchQueue.main.async { [weak self] in
                    self?.overlay.clearAll()
                }
            }
            return
        }
        
        // CHANGED: Reduced frame skipping logic for more responsive landmark tracking
        // Only skip if we have 2+ frames queued to prevent severe lag
        guard !isProcessingFrame else { return }
        
        isProcessingFrame = true

        // Correct EXIF for *this* frame
        let exif = exifOrientation(for: connection.videoOrientation,
                                   mirrored: connection.isVideoMirrored)

        // Process on high priority queue with immediate UI updates
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.handler.perform([self.poseRequest],
                                    on: sampleBuffer,
                                    orientation: exif)

                guard let obs = self.poseRequest.results?.first as? VNHumanBodyPoseObservation,
                      let joints = try? obs.recognizedPoints(.all) else {
                    self.isProcessingFrame = false
                    return
                }

                // Process for anomaly detection (keep existing frequency)
                if let anomaly = self.anomalyDetector.analyze(joints: joints) {
                    DispatchQueue.main.async {
                        self.handleAnomaly(anomaly)
                    }
                }
                
                // CHANGED: Update overlay more frequently for smoother landmark tracking
                let currentTime = CACurrentMediaTime()
                if currentTime - self.lastOverlayUpdateTime >= self.overlayUpdateInterval {
                    self.lastOverlayUpdateTime = currentTime
                    // Use higher priority queue for UI updates to ensure smooth landmark rendering
                    DispatchQueue.main.async {
                        self.process(joints: joints)
                    }
                }
                
                self.isProcessingFrame = false
                
            } catch {
                print("Vision error:", error)
                self.isProcessingFrame = false
            }
        }
    }

    // Convert Vision joints → view points for overlay rendering - OPTIMIZED
    private func process(joints: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) {
        // CHANGED: Reduced confidence threshold slightly for smoother tracking at high speeds
        let viewPoints = joints.compactMap { (name, pt) -> (VNHumanBodyPoseObservation.JointName, CGPoint)? in
            guard pt.confidence > 0.2 else { return nil }  // Reduced from 0.25 to 0.2
            
            // Flip Y for device coord, then map through the preview layer
            let devicePt = CGPoint(x: pt.location.x, y: 1 - pt.location.y)
            let viewPt = preview.layerPointConverted(fromCaptureDevicePoint: devicePt)
            return (name, viewPt)
        }
        
        // Update overlay with joint positions - this should now be much more responsive
        overlay.update(with: viewPoints)
        hasActiveOverlay = true  // Mark that we have active content
    }
    
    private func handleAnomaly(_ anomaly: Anomaly) {
        print("🏀 Anomaly detected: \(anomaly.type) - \(anomaly.metric)")
        
        // Show visual feedback
        overlay.showAnomalyAlert(anomaly)
        
        // Create payload for AI coach
        let payload = Payload(
            sessionID: sessionID,
            anomaly: anomaly,
            phoneTime: Date().timeIntervalSince1970,
            playerAge: playerAge,
            playerHandedness: playerHandedness
        )
        
        // Send to AI coach for feedback
        aiCoach.analyzeAnomaly(payload: payload)
    }
}

// MARK: – Helper that maps AVCapture orientation → EXIF
private func exifOrientation(for videoOrientation: AVCaptureVideoOrientation,
                             mirrored: Bool) -> CGImagePropertyOrientation {
    switch videoOrientation {
    case .portrait:            return mirrored ? .leftMirrored  : .right
    case .portraitUpsideDown:  return mirrored ? .rightMirrored : .left
    case .landscapeRight:      return mirrored ? .downMirrored  : .up
    case .landscapeLeft:       return mirrored ? .upMirrored    : .down
    @unknown default:          return .right
    }
}
