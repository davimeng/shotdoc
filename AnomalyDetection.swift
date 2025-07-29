import Foundation
import Vision

// MARK: - Anomaly Detection Models
struct Anomaly: Codable {
    let type: String        // e.g. "ELBOW_FLARE", "HEAD_DOWN"
    let metric: Float       // angle or delta
    let frameTime: Double   // ms since session start
    let severity: String    // "mild", "moderate", "severe"
    let description: String // Human-readable description
}

struct Payload: Codable {
    let sessionID: String
    let anomaly: Anomaly
    let phoneTime: Double
    let playerAge: Int
    let playerHandedness: String
}

// MARK: - Anomaly Detection Engine
class AnomalyDetector {
    private var sessionStartTime: Date?
    private var frameBuffer: [FrameAnalysis] = []
    private let bufferSize = 5
    private var lastAnomalyTime: Double = 0
    private let anomalyCooldown: Double = 2.0 // seconds
    
    // ADDED: Store player handedness
    var playerHandedness: String = "right"
    
    struct FrameAnalysis {
        let timestamp: Double
        let elbowAngle: Float?
        let shoulderLean: Float?
        let releaseHeight: Float?
        let headPosition: Float?
        let isAnomalous: Bool
    }
    
    func startSession() {
        sessionStartTime = Date()
        frameBuffer.removeAll()
        lastAnomalyTime = 0
    }
    
    // Updated analyze method to include face observations
    func analyze(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], faceObservations: [VNFaceObservation]? = nil) -> Anomaly? {
        guard let startTime = sessionStartTime else { return nil }
        
        let currentTime = Date().timeIntervalSince(startTime)
        
        // Calculate shooting mechanics
        let elbowAngle = calculateElbowAngle(joints: joints)
        let shoulderLean = calculateShoulderLean(joints: joints)
        let releaseHeight = calculateReleaseHeight(joints: joints)
        let headPosition = analyzeFaceDirection(faceObservations: faceObservations)
        
        // Check for anomalies
        let hasElbowAnomaly = checkElbowAnomaly(angle: elbowAngle)
        let hasLeanAnomaly = checkShoulderLeanAnomaly(lean: shoulderLean)
        let hasReleaseAnomaly = checkReleaseHeightAnomaly(height: releaseHeight)
        let hasHeadAnomaly = checkHeadPositionAnomaly(position: headPosition)
        
        let frameAnalysis = FrameAnalysis(
            timestamp: currentTime,
            elbowAngle: elbowAngle,
            shoulderLean: shoulderLean,
            releaseHeight: releaseHeight,
            headPosition: headPosition,
            isAnomalous: hasElbowAnomaly || hasLeanAnomaly || hasReleaseAnomaly || hasHeadAnomaly
        )
        
        // Add to buffer
        frameBuffer.append(frameAnalysis)
        if frameBuffer.count > bufferSize {
            frameBuffer.removeFirst()
        }
        
        // Check if we should flag an anomaly (3 of 5 frames)
        if frameBuffer.count == bufferSize {
            let anomalousFrames = frameBuffer.filter { $0.isAnomalous }.count
            if anomalousFrames >= 3 && (currentTime - lastAnomalyTime) > anomalyCooldown {
                lastAnomalyTime = currentTime
                return detectPrimaryAnomaly(in: frameBuffer)
            }
        }
        
        return nil
    }
    
    private func detectPrimaryAnomaly(in buffer: [FrameAnalysis]) -> Anomaly? {
        let frameTime = buffer.last?.timestamp ?? 0
        
        // Check for head position anomalies first (most important for basketball)
        let headPositions = buffer.compactMap { $0.headPosition }
        if !headPositions.isEmpty {
            let avgHeadPosition = headPositions.average()
            if avgHeadPosition > 0.6 {
                return Anomaly(
                    type: "HEAD_DOWN",
                    metric: avgHeadPosition,
                    frameTime: frameTime * 1000,
                    severity: avgHeadPosition > 0.7 ? "severe" : "moderate",
                    description: "Keep your head up and eyes on the target"
                )
            }
        }
        
        // Check for elbow anomalies (most common shooting form issue)
        let elbowAngles = buffer.compactMap { $0.elbowAngle }
        if !elbowAngles.isEmpty {
            let avgElbowAngle = elbowAngles.average()
            if avgElbowAngle < 40 {
                return Anomaly(
                    type: "ELBOW_CHICKEN_WING",
                    metric: avgElbowAngle,
                    frameTime: frameTime * 1000,
                    severity: avgElbowAngle < 25 ? "severe" : "moderate",
                    description: "Elbow is tucked too close to body"
                )
            } else if avgElbowAngle > 90 {
                return Anomaly(
                    type: "ELBOW_FLARE",
                    metric: avgElbowAngle,
                    frameTime: frameTime * 1000,
                    severity: avgElbowAngle > 110 ? "severe" : "moderate",
                    description: "Elbow is flared out too wide"
                )
            }
        }
        
        // Check for shoulder lean
        let shoulderLeans = buffer.compactMap { $0.shoulderLean }
        if !shoulderLeans.isEmpty {
            let avgLean = shoulderLeans.average()
            if abs(avgLean) > 15 {
                return Anomaly(
                    type: "SHOULDER_LEAN",
                    metric: avgLean,
                    frameTime: frameTime * 1000,
                    severity: abs(avgLean) > 25 ? "severe" : "moderate",
                    description: "Body is leaning too much to one side"
                )
            }
        }
        
        // Check for release height
        let releaseHeights = buffer.compactMap { $0.releaseHeight }
        if !releaseHeights.isEmpty {
            let avgHeight = releaseHeights.average()
            if avgHeight < -0.05 {
                return Anomaly(
                    type: "LOW_RELEASE",
                    metric: avgHeight,
                    frameTime: frameTime * 1000,
                    severity: avgHeight < -0.15 ? "severe" : "moderate",
                    description: "Release point is too low"
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Angle Calculations
    private func calculateElbowAngle(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Float? {
        // FIXED: Use correct shooting hand based on player preference
        let isLeftHanded = playerHandedness == "left"
        
        let shoulder: VNHumanBodyPoseObservation.JointName = isLeftHanded ? .leftShoulder : .rightShoulder
        let elbow: VNHumanBodyPoseObservation.JointName = isLeftHanded ? .leftElbow : .rightElbow
        let wrist: VNHumanBodyPoseObservation.JointName = isLeftHanded ? .leftWrist : .rightWrist
        
        guard let shoulderPt = joints[shoulder],
              let elbowPt = joints[elbow],
              let wristPt = joints[wrist],
              shoulderPt.confidence > 0.5,
              elbowPt.confidence > 0.5,
              wristPt.confidence > 0.5 else { return nil }
        
        let shoulderLoc = CGPoint(x: shoulderPt.location.x, y: shoulderPt.location.y)
        let elbowLoc = CGPoint(x: elbowPt.location.x, y: elbowPt.location.y)
        let wristLoc = CGPoint(x: wristPt.location.x, y: wristPt.location.y)
        
        // Calculate angle between upper arm and forearm
        let upperArm = CGPoint(x: elbowLoc.x - shoulderLoc.x, y: elbowLoc.y - shoulderLoc.y)
        let forearm = CGPoint(x: wristLoc.x - elbowLoc.x, y: wristLoc.y - elbowLoc.y)
        
        let angle = angleBetweenVectors(v1: upperArm, v2: forearm)
        return Float(angle)
    }
    
    private func calculateShoulderLean(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Float? {
        guard let rightShoulder = joints[.rightShoulder],
              let leftShoulder = joints[.leftShoulder],
              rightShoulder.confidence > 0.5,
              leftShoulder.confidence > 0.5 else { return nil }
        
        let shoulderLine = CGPoint(
            x: rightShoulder.location.x - leftShoulder.location.x,
            y: rightShoulder.location.y - leftShoulder.location.y
        )
        
        let angle = atan2(shoulderLine.y, shoulderLine.x) * 180 / .pi
        return Float(angle)
    }
    
    private func calculateReleaseHeight(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Float? {
        // FIXED: Use correct shooting hand for release height calculation
        let isLeftHanded = playerHandedness == "left"
        let wristJoint: VNHumanBodyPoseObservation.JointName = isLeftHanded ? .leftWrist : .rightWrist
        
        guard let wrist = joints[wristJoint],
              let head = joints[.nose],
              wrist.confidence > 0.5,
              head.confidence > 0.5 else { return nil }
        
        let heightDiff = wrist.location.y - head.location.y
        return Float(heightDiff)
    }
    
    // MARK: - Face Analysis
    private func analyzeFaceDirection(faceObservations: [VNFaceObservation]?) -> Float? {
        guard let faces = faceObservations,
              let face = faces.first,
              let landmarks = face.landmarks,
              let nose = landmarks.nose else { return nil }
        
        // Check if player is looking at the basket (head alignment)
        let noseY = nose.normalizedPoints.first?.y ?? 0.5
        return Float(noseY)
    }
    
    // MARK: - Anomaly Checkers
    private func checkElbowAnomaly(angle: Float?) -> Bool {
        guard let angle = angle else { return false }
        return angle < 40 || angle > 90
    }
    
    private func checkShoulderLeanAnomaly(lean: Float?) -> Bool {
        guard let lean = lean else { return false }
        return abs(lean) > 15
    }
    
    private func checkReleaseHeightAnomaly(height: Float?) -> Bool {
        guard let height = height else { return false }
        return height < -0.05
    }
    
    private func checkHeadPositionAnomaly(position: Float?) -> Bool {
        guard let position = position else { return false }
        return position > 0.6 // Looking down too much
    }
}

// MARK: - Utility Extensions
extension Array where Element == Float {
    func average() -> Float {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Float(count)
    }
}

// MARK: - Geometry Helpers
func angleBetweenVectors(v1: CGPoint, v2: CGPoint) -> Double {
    let dot = v1.x * v2.x + v1.y * v2.y
    let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
    let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
    
    guard mag1 > 0 && mag2 > 0 else { return 0 }
    
    let cosAngle = dot / (mag1 * mag2)
    let clampedCos = max(-1, min(1, cosAngle))
    let angle = acos(clampedCos) * 180 / .pi
    
    return angle
}
