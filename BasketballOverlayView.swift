import UIKit
import Vision
import AVFoundation

final class BasketballOverlayView: UIView {
    
    // Joint visualization
    private var jointLayers: [VNHumanBodyPoseObservation.JointName : CALayer] = [:]
    private var connectionLayers: [CAShapeLayer] = []
    
    // Enhanced face tracking elements
    private var faceLayer = CAShapeLayer()
    private var eyeTrackingLayers: [CALayer] = []
    private var headDirectionIndicator = CAShapeLayer()
    
    // Basketball-specific UI elements
    private let shootingHandLabel = UILabel()
    private let mechanicsLabel = UILabel()
    private let faceTrackingLabel = UILabel()
    private let anomalyBorder = CAShapeLayer()
    private let coachingFeedbackView = UIView()
    private let feedbackLabel = UILabel()
    
    // ADDED: Store player handedness
    var playerHandedness: String = "right"
    
    // Animation timers
    private var anomalyTimer: Timer?
    private var feedbackTimer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setupUI()
        setupFaceTracking()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        // Shooting hand label
        shootingHandLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        shootingHandLabel.textColor = .systemOrange
        shootingHandLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        shootingHandLabel.layer.cornerRadius = 8
        shootingHandLabel.clipsToBounds = true
        shootingHandLabel.textAlignment = .center
        addSubview(shootingHandLabel)
        
        // Mechanics info label
        mechanicsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        mechanicsLabel.textColor = .systemGreen
        mechanicsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        mechanicsLabel.layer.cornerRadius = 8
        mechanicsLabel.clipsToBounds = true
        mechanicsLabel.textAlignment = .center
        mechanicsLabel.numberOfLines = 3
        addSubview(mechanicsLabel)
        
        // Face tracking label
        faceTrackingLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        faceTrackingLabel.textColor = .systemBlue
        faceTrackingLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        faceTrackingLabel.layer.cornerRadius = 8
        faceTrackingLabel.clipsToBounds = true
        faceTrackingLabel.textAlignment = .center
        faceTrackingLabel.numberOfLines = 2
        addSubview(faceTrackingLabel)
        
        // Anomaly border
        anomalyBorder.fillColor = UIColor.clear.cgColor
        anomalyBorder.strokeColor = UIColor.systemRed.cgColor
        anomalyBorder.lineWidth = 6
        anomalyBorder.isHidden = true
        layer.addSublayer(anomalyBorder)
        
        // CHANGED: Coaching feedback view - MORE TRANSPARENT appearance
        // OPACITY CHANGE LOCATION: Modify the alpha component value below (currently 0.4) to adjust transparency
        // Values: 0.1 = very transparent, 0.5 = medium transparent, 0.9 = mostly opaque
        coachingFeedbackView.backgroundColor = UIColor.black.withAlphaComponent(0.4)  // <-- CHANGE THIS VALUE for opacity
        coachingFeedbackView.layer.cornerRadius = 12
        coachingFeedbackView.isHidden = true
        
        // ADDED: Subtle border for better visibility with high transparency
        coachingFeedbackView.layer.borderWidth = 1
        coachingFeedbackView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        addSubview(coachingFeedbackView)
        
        // Feedback label
        feedbackLabel.font = .systemFont(ofSize: 16, weight: .medium)
        feedbackLabel.textColor = .white
        feedbackLabel.numberOfLines = 0
        feedbackLabel.textAlignment = .center
        coachingFeedbackView.addSubview(feedbackLabel)
        
        // Setup constraints for feedback view
        coachingFeedbackView.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            coachingFeedbackView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            coachingFeedbackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 100),
            coachingFeedbackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 20),
            coachingFeedbackView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -20),
            coachingFeedbackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            feedbackLabel.leadingAnchor.constraint(equalTo: coachingFeedbackView.leadingAnchor, constant: 16),
            feedbackLabel.trailingAnchor.constraint(equalTo: coachingFeedbackView.trailingAnchor, constant: -16),
            feedbackLabel.topAnchor.constraint(equalTo: coachingFeedbackView.topAnchor, constant: 12),
            feedbackLabel.bottomAnchor.constraint(equalTo: coachingFeedbackView.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupFaceTracking() {
        // Face boundary
        faceLayer.fillColor = UIColor.clear.cgColor
        faceLayer.strokeColor = UIColor.systemBlue.cgColor
        faceLayer.lineWidth = 2
        faceLayer.lineDashPattern = [5, 5] // Dashed line for subtle indication
        layer.addSublayer(faceLayer)
        
        // Head direction indicator
        headDirectionIndicator.fillColor = UIColor.systemPurple.cgColor
        headDirectionIndicator.strokeColor = UIColor.systemPurple.cgColor
        headDirectionIndicator.lineWidth = 3
        layer.addSublayer(headDirectionIndicator)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Position labels manually (not using Auto Layout to keep them simple)
        // Move them higher and make them thicker
        let labelWidth: CGFloat = 180  // Increased width
        let rightMargin: CGFloat = 20
        let topOffset: CGFloat = 110   // Moved higher from the top
        
        shootingHandLabel.sizeToFit()
        shootingHandLabel.frame = CGRect(
            x: bounds.width - labelWidth - rightMargin,
            y: topOffset,
            width: labelWidth,
            height: shootingHandLabel.bounds.height + 18  // Made thicker with more padding
        )
        
        mechanicsLabel.sizeToFit()
        mechanicsLabel.frame = CGRect(
            x: bounds.width - labelWidth - rightMargin,
            y: shootingHandLabel.frame.maxY + 12,  // Increased spacing
            width: labelWidth,
            height: mechanicsLabel.bounds.height + 18  // Made thicker with more padding
        )
        
        // Face tracking label
        faceTrackingLabel.sizeToFit()
        faceTrackingLabel.frame = CGRect(
            x: bounds.width - labelWidth - rightMargin,
            y: mechanicsLabel.frame.maxY + 12,
            width: labelWidth,
            height: faceTrackingLabel.bounds.height + 18  // Made thicker with more padding
        )
        
        // Update anomaly border to match view bounds
        anomalyBorder.path = UIBezierPath(rect: bounds).cgPath
    }
    
    // MARK: - Public Methods
    
    func update(with joints: [(VNHumanBodyPoseObservation.JointName, CGPoint)]) {
        updateWithFace(joints: joints, faceObservations: nil, previewLayer: nil)
    }
    
    func updateWithFace(joints: [(VNHumanBodyPoseObservation.JointName, CGPoint)],
                       faceObservations: [VNFaceObservation]?,
                       previewLayer: AVCaptureVideoPreviewLayer?) {
        // Clear existing joint layers
        jointLayers.values.forEach { $0.removeFromSuperlayer() }
        jointLayers.removeAll()
        
        // Clear connection layers
        connectionLayers.forEach { $0.removeFromSuperlayer() }
        connectionLayers.removeAll()
        
        // Create new joint layers
        for (jointName, point) in joints {
            let jointLayer = CALayer()
            jointLayer.backgroundColor = colorForJoint(jointName).cgColor
            jointLayer.frame = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            jointLayer.cornerRadius = 4
            layer.addSublayer(jointLayer)
            jointLayers[jointName] = jointLayer
        }
        
        // Draw connections for key basketball joints
        drawBasketballConnections(joints: joints)
        
        // Update labels
        updateLabels(joints: joints)
        
        // Render face tracking if available
        if let faces = faceObservations, let preview = previewLayer {
            renderFaceTracking(faces: faces, previewLayer: preview)
        } else {
            clearFaceTracking()
        }
    }
    
    func showAnomalyAlert(_ anomaly: Anomaly) {
        // Flash red border
        anomalyBorder.isHidden = false
        
        // Animate border
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 0.3
        animation.autoreverses = true
        animation.repeatCount = 3
        anomalyBorder.add(animation, forKey: "flash")
        
        // Hide border after animation
        anomalyTimer?.invalidate()
        anomalyTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            self?.anomalyBorder.isHidden = true
        }
    }
    
    // CHANGED: Modified coaching feedback display for better transparency and longer display time
    func showCoachingFeedback(_ feedback: String) {
        feedbackLabel.text = feedback
        coachingFeedbackView.isHidden = false
        
        // Animate in with slower, more gentle animation
        coachingFeedbackView.alpha = 0
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {  // Slower fade in
            self.coachingFeedbackView.alpha = 1
        }
        
        // CHANGED: Extended auto-hide time for longer reading time
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in  // Increased from 5.0 to 8.0 seconds
            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseInOut) {  // Slower fade out
                self?.coachingFeedbackView.alpha = 0
            } completion: { _ in
                self?.coachingFeedbackView.isHidden = true
            }
        }
    }
    
    func clearAll() {
        // Clear joints
        jointLayers.values.forEach { $0.removeFromSuperlayer() }
        jointLayers.removeAll()
        
        // Clear connections
        connectionLayers.forEach { $0.removeFromSuperlayer() }
        connectionLayers.removeAll()
        
        // Clear face tracking
        clearFaceTracking()
        
        // Clear labels
        shootingHandLabel.text = ""
        mechanicsLabel.text = ""
        faceTrackingLabel.text = ""
        
        // Hide anomaly indicators
        anomalyBorder.isHidden = true
        coachingFeedbackView.isHidden = true
        
        // Cancel timers
        anomalyTimer?.invalidate()
        feedbackTimer?.invalidate()
    }
    
    // MARK: - Private Methods
    
    private func colorForJoint(_ joint: VNHumanBodyPoseObservation.JointName) -> UIColor {
        switch joint {
        case .rightWrist, .leftWrist:
            return .systemOrange
        case .rightElbow, .leftElbow:
            return .systemBlue
        case .rightShoulder, .leftShoulder:
            return .systemGreen
        case .nose:
            return .systemPurple
        default:
            return .systemYellow
        }
    }
    
    private func drawBasketballConnections(joints: [(VNHumanBodyPoseObservation.JointName, CGPoint)]) {
        let jointDict = Dictionary(joints, uniquingKeysWith: { first, _ in first })
        
        // FIXED: Draw shooting arm connections based on player handedness
        let shootingArmConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)]
        
        if playerHandedness == "left" {
            shootingArmConnections = [
                (.leftShoulder, .leftElbow),
                (.leftElbow, .leftWrist)
            ]
        } else { // Default to right
            shootingArmConnections = [
                (.rightShoulder, .rightElbow),
                (.rightElbow, .rightWrist)
            ]
        }
        
        for (joint1, joint2) in shootingArmConnections {
            if let point1 = jointDict[joint1], let point2 = jointDict[joint2] {
                drawConnection(from: point1, to: point2, color: .systemOrange)
            }
        }
        
        // Draw shoulder line
        if let leftShoulder = jointDict[.leftShoulder], let rightShoulder = jointDict[.rightShoulder] {
            drawConnection(from: leftShoulder, to: rightShoulder, color: .systemGreen)
        }
    }
    
    private func drawConnection(from: CGPoint, to: CGPoint, color: UIColor) {
        let connectionLayer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: from)
        path.addLine(to: to)
        
        connectionLayer.path = path.cgPath
        connectionLayer.strokeColor = color.cgColor
        connectionLayer.lineWidth = 2
        connectionLayer.lineCap = .round
        
        layer.addSublayer(connectionLayer)
        connectionLayers.append(connectionLayer)
    }
    
    private func updateLabels(joints: [(VNHumanBodyPoseObservation.JointName, CGPoint)]) {
        let jointDict = Dictionary(joints, uniquingKeysWith: { first, _ in first })
        
        // FIXED: Update shooting hand label based on player handedness
        let shootingWrist: VNHumanBodyPoseObservation.JointName = playerHandedness == "left" ? .leftWrist : .rightWrist
        let shootingSide = playerHandedness == "left" ? "LEFT" : "RIGHT"
        
        if jointDict[shootingWrist] != nil {
            shootingHandLabel.text = "\(shootingSide) HAND"
        } else {
            shootingHandLabel.text = ""
        }
        
        // FIXED: Update mechanics label with correct shooting arm detection
        var mechanicsText = ""
        
        if playerHandedness == "left" {
            if jointDict[.leftShoulder] != nil && jointDict[.leftElbow] != nil && jointDict[.leftWrist] != nil {
                mechanicsText += "ARM: ✓\n"
            }
        } else {
            if jointDict[.rightShoulder] != nil && jointDict[.rightElbow] != nil && jointDict[.rightWrist] != nil {
                mechanicsText += "ARM: ✓\n"
            }
        }
        
        if jointDict[.leftShoulder] != nil && jointDict[.rightShoulder] != nil {
            mechanicsText += "SHOULDERS: ✓\n"
        }
        if jointDict[.nose] != nil {
            mechanicsText += "HEAD: ✓"
        }
        
        mechanicsLabel.text = mechanicsText
    }
    
    private func renderFaceTracking(faces: [VNFaceObservation], previewLayer: AVCaptureVideoPreviewLayer) {
        // Clear previous face layers
        clearFaceTracking()
        
        guard !faces.isEmpty else { return }
        
        for face in faces {
            // Draw face boundary
            let faceBounds = previewLayer.layerRectConverted(fromMetadataOutputRect: face.boundingBox)
            faceLayer.path = UIBezierPath(rect: faceBounds).cgPath
            
            // Add eye tracking if landmarks are available
            if let landmarks = face.landmarks {
                renderEyeTracking(landmarks: landmarks, in: faceBounds)
            }
            
            // Update face tracking label
            updateFaceTrackingLabel(face: face)
        }
    }
    
    private func renderEyeTracking(landmarks: VNFaceLandmarks2D, in faceBounds: CGRect) {
        // Render eyes for shooting focus tracking
        if let leftEye = landmarks.leftEye {
            let eyeLayer = createEyeLayer(points: leftEye.normalizedPoints, bounds: faceBounds)
            layer.addSublayer(eyeLayer)
            eyeTrackingLayers.append(eyeLayer)
        }
        
        if let rightEye = landmarks.rightEye {
            let eyeLayer = createEyeLayer(points: rightEye.normalizedPoints, bounds: faceBounds)
            layer.addSublayer(eyeLayer)
            eyeTrackingLayers.append(eyeLayer)
        }
    }
    
    private func createEyeLayer(points: [CGPoint], bounds: CGRect) -> CALayer {
        let eyeLayer = CAShapeLayer()
        let path = UIBezierPath()
        
        if !points.isEmpty {
            // Convert normalized points to view coordinates
            let firstPoint = CGPoint(
                x: bounds.minX + points[0].x * bounds.width,
                y: bounds.minY + points[0].y * bounds.height
            )
            path.move(to: firstPoint)
            
            for point in points.dropFirst() {
                let viewPoint = CGPoint(
                    x: bounds.minX + point.x * bounds.width,
                    y: bounds.minY + point.y * bounds.height
                )
                path.addLine(to: viewPoint)
            }
            path.close()
        }
        
        eyeLayer.path = path.cgPath
        eyeLayer.strokeColor = UIColor.systemBlue.cgColor
        eyeLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        eyeLayer.lineWidth = 1
        
        return eyeLayer
    }
    
    private func updateFaceTrackingLabel(face: VNFaceObservation) {
        var faceText = "👁️ FACE: ✓\n"
        
        // Check if looking up (good for shooting)
        if let landmarks = face.landmarks, let nose = landmarks.nose {
            let noseY = nose.normalizedPoints.first?.y ?? 0.5
            if noseY < 0.4 {
                faceText += "LOOKING UP: ✓"
            } else {
                faceText += "LOOKING DOWN: ⚠️"
            }
        }
        
        faceTrackingLabel.text = faceText
    }
    
    private func clearFaceTracking() {
        // Clear face boundary
        faceLayer.path = nil
        
        // Clear eye tracking layers
        eyeTrackingLayers.forEach { $0.removeFromSuperlayer() }
        eyeTrackingLayers.removeAll()
        
        // Clear head direction indicator
        headDirectionIndicator.path = nil
        
        // Clear face tracking label
        faceTrackingLabel.text = ""
    }
}
