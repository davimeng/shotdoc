import Foundation

class AICoach {
    
    // Callback for when feedback is generated
    var onFeedbackReceived: ((String) -> Void)?
    
    // Enhanced coaching feedback database with calibration-aware messages
    private let feedbackDatabase: [String: [String]] = [
        "ELBOW_FLARE": [
            "Keep your elbow directly under the ball. Imagine a straight line from your shoulder to your wrist.",
            "Tuck that elbow in! Your shooting elbow should be pointing toward the basket.",
            "Focus on keeping your elbow aligned. Wide elbows reduce accuracy and power.",
            "Your elbow is wider than optimal. Bring it back to a better position."
        ],
        "ELBOW_CHICKEN_WING": [
            "Give your shooting arm more space. Your elbow is too close to your body.",
            "Create a comfortable shooting pocket. Your elbow should have room to move freely.",
            "Avoid cramping your shooting form. Let your elbow extend naturally.",
            "Your elbow needs more extension. Open up your shooting pocket."
        ],
        "SHOULDER_LEAN": [
            "Keep your shoulders square to the basket. Avoid leaning to one side.",
            "Balance is key! Make sure your weight is evenly distributed.",
            "Stay centered over your feet. Leaning affects your shot consistency.",
            "Your shoulders are off balance. Center yourself for better accuracy."
        ],
        "LOW_RELEASE": [
            "Release the ball higher! Aim for a release point above your head.",
            "Get more arc on your shot. A higher release creates better shooting angles.",
            "Extend upward on your release. Think 'up and out' not 'out and down'.",
            "Your release point is too low. Get that ball up higher."
        ],
        "HEAD_DOWN": [
            "Keep your head up and eyes on the target! Look at where you want the ball to go.",
            "Focus on the rim, not the ball. Your eyes should track your target throughout the shot.",
            "Head positioning is crucial. Keep your chin up and eyes locked on the basket.",
            "Don't watch the ball - trust your shooting form and keep your eyes on the rim."
        ]
    ]
    
    // CHANGED: Track recent feedback to avoid repetition and reduce frequency
    private var recentFeedback: [String] = []
    private let maxRecentFeedback = 3
    
    // ADDED: Feedback cooldown system to reduce popup frequency
    private var lastFeedbackTime: Date = Date(timeIntervalSince1970: 0)
    private let feedbackCooldownInterval: TimeInterval = 8.0  // Increased from implicit ~2 seconds to 8 seconds
    private var consecutiveAnomalies: [String: Int] = [:]  // Track consecutive anomalies of same type
    private let minConsecutiveForFeedback = 3  // Require 3 consecutive anomalies before giving feedback
    
    func analyzeAnomaly(payload: Payload) {
        let currentTime = Date()
        let anomalyType = payload.anomaly.type
        
        // CHANGED: Implement smarter feedback frequency control
        // Check cooldown period
        if currentTime.timeIntervalSince(lastFeedbackTime) < feedbackCooldownInterval {
            return  // Skip feedback if too soon since last one
        }
        
        // Track consecutive anomalies of the same type
        consecutiveAnomalies[anomalyType] = (consecutiveAnomalies[anomalyType] ?? 0) + 1
        
        // Only provide feedback after seeing multiple consecutive anomalies
        guard let count = consecutiveAnomalies[anomalyType], count >= minConsecutiveForFeedback else {
            return  // Not enough consecutive anomalies yet
        }
        
        // Reset counter for this anomaly type after providing feedback
        consecutiveAnomalies[anomalyType] = 0
        lastFeedbackTime = currentTime
        
        // Generate contextual feedback based on anomaly type and player profile
        let feedback = generateFeedback(for: payload)
        
        // Deliver feedback with slight delay to simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onFeedbackReceived?(feedback)
        }
    }
    
    private func generateFeedback(for payload: Payload) -> String {
        let anomaly = payload.anomaly
        let baseMessages = feedbackDatabase[anomaly.type] ?? ["Keep working on your form!"]
        
        // Filter out recently used feedback
        let availableMessages = baseMessages.filter { !recentFeedback.contains($0) }
        let messagesToUse = availableMessages.isEmpty ? baseMessages : availableMessages
        
        // Select a random message
        let baseMessage = messagesToUse.randomElement() ?? "Keep practicing!"
        
        // Add context based on severity and player profile
        let contextualMessage = addContext(to: baseMessage, anomaly: anomaly, payload: payload)
        
        // Track this feedback
        recentFeedback.append(contextualMessage)
        if recentFeedback.count > maxRecentFeedback {
            recentFeedback.removeFirst()
        }
        
        return contextualMessage
    }
    
    private func addContext(to message: String, anomaly: Anomaly, payload: Payload) -> String {
        var contextualMessage = message
        
        // Add severity context
        switch anomaly.severity {
        case "severe":
            contextualMessage += " This is a significant issue that needs immediate attention."
        case "moderate":
            contextualMessage += " Work on correcting this gradually."
        default:
            contextualMessage += " Small adjustments can make a big difference."
        }
        
        // Add specific context for different anomaly types
        switch anomaly.type {
        case "HEAD_DOWN":
            contextualMessage += " Remember: where your eyes go, the ball follows!"
        case "ELBOW_FLARE", "ELBOW_CHICKEN_WING":
            contextualMessage += " Focus on consistent elbow positioning."
        case "SHOULDER_LEAN":
            contextualMessage += " Balance is the foundation of good shooting."
        case "LOW_RELEASE":
            contextualMessage += " Higher release means better arc and accuracy."
        default:
            break
        }
        
        // Add age-appropriate context
        if payload.playerAge < 12 {
            contextualMessage = "Hey young shooter! " + contextualMessage + " Remember, practice makes perfect!"
        } else if payload.playerAge < 16 {
            contextualMessage = "Nice work! " + contextualMessage + " Keep grinding!"
        } else {
            contextualMessage = contextualMessage + " Stay focused on the fundamentals."
        }
        
        return contextualMessage
    }
    
    // Method to provide general encouragement
    func provideEncouragement() -> String {
        let encouragements = [
            "Great job staying focused on your form!",
            "Your shooting mechanics are improving!",
            "Keep up the consistent practice!",
            "Remember, every great shooter started with fundamentals!",
            "You're developing muscle memory - stay patient!",
            "Consistency is key - you're on the right track!",
            "Excellent head positioning - keep your eyes on target!",
            "Your form tracking is looking smooth today!"
        ]
        
        return encouragements.randomElement() ?? "Keep shooting!"
    }
    
    // Method to provide session summary
    func generateSessionSummary(anomalies: [Anomaly]) -> String {
        if anomalies.isEmpty {
            return "Excellent session! No major form issues detected. Your shooting mechanics and focus are on point!"
        }
        
        let anomalyTypes = Set(anomalies.map { $0.type })
        let primaryIssue = anomalies.max { $0.severity < $1.severity }?.type ?? "GENERAL"
        
        // Count different types of issues
        let mechanicIssues = anomalies.filter { ["ELBOW_FLARE", "ELBOW_CHICKEN_WING", "SHOULDER_LEAN", "LOW_RELEASE"].contains($0.type) }.count
        let focusIssues = anomalies.filter { $0.type == "HEAD_DOWN" }.count
        
        var summary = "Session Summary:\n"
        summary += "• Detected \(anomalies.count) form corrections\n"
        
        if mechanicIssues > 0 {
            summary += "• Shooting mechanics: \(mechanicIssues) adjustments needed\n"
        }
        
        if focusIssues > 0 {
            summary += "• Head/eye tracking: \(focusIssues) focus reminders\n"
        }
        
        summary += "• Primary focus area: \(primaryIssue.replacingOccurrences(of: "_", with: " "))\n"
        summary += "• Keep practicing these fundamentals for improvement!"
        
        return summary
    }
    
    // Method to provide real-time encouragement during good form
    func providePositiveFeedback(detectedFeatures: [String]) -> String? {
        let positiveMessages = [
            "Perfect shooting form! Keep it up!",
            "Excellent head position - eyes on target!",
            "Great elbow alignment!",
            "Beautiful shooting mechanics!",
            "That's textbook form right there!",
            "Keep that consistency going!"
        ]
        
        // CHANGED: Reduced positive feedback frequency to match new system
        if Int.random(in: 1...15) == 1 {  // Reduced from 1...10 to 1...15
            return positiveMessages.randomElement()
        }
        
        return nil
    }
    
    // Method to provide calibration-specific feedback
    func provideCalibrationFeedback(shotNumber: Int, totalShots: Int) -> String {
        let remainingShots = totalShots - shotNumber
        
        switch shotNumber {
        case 1:
            return "Great first shot! \(remainingShots) more to go. Keep using your natural form."
        case 2...3:
            return "Good consistency! \(remainingShots) shots remaining. Focus on repeating this form."
        case 4...6:
            return "Halfway there! \(remainingShots) more shots. Your baseline is taking shape."
        case 7...8:
            return "Almost done! \(remainingShots) shots left. Maintain this shooting rhythm."
        case 9:
            return "Final shot! Make it count - this completes your personal baseline."
        case 10:
            return "Calibration complete! Your personal shooting profile has been created."
        default:
            return "Shot \(shotNumber) recorded! \(remainingShots) more to go."
        }
    }
}
