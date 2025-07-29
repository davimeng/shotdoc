////
////  ContentViewVer1.swift
////  bballapp
////
////  Created by Davis Meng on 7/22/25.
////
//
//import SwiftUI
//
//// Define SettingsView first
//struct SettingsView: View {
//    @Binding var playerAge: Int
//    @Binding var playerHandedness: String
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Player Profile") {
//                    HStack {
//                        Text("Age")
//                        Spacer()
//                        TextField("Age", value: $playerAge, format: .number)
//                            .keyboardType(.numberPad)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                            .frame(width: 60)
//                    }
//                    
//                    Picker("Handedness", selection: $playerHandedness) {
//                        Text("Right").tag("right")
//                        Text("Left").tag("left")
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
//                }
//                
//                Section("About") {
//                    Text("This app analyzes basketball shooting mechanics using computer vision and provides AI-powered coaching feedback.")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//            .navigationTitle("Settings")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// ContentView comes after SettingsView
//struct ContentView: View {
//    @State private var started = false
//    @State private var isUsingFrontCamera = false
//    @State private var showingSettings = false
//    @State private var playerAge = 16
//    @State private var playerHandedness = "right"
//    @State private var sessionActive = false
//    
//    var body: some View {
//        ZStack {
//            if started {
//                CameraView(
//                    isUsingFrontCamera: $isUsingFrontCamera,
//                    sessionActive: $sessionActive,
//                    playerAge: playerAge,
//                    playerHandedness: playerHandedness
//                )
//                
//                // Control overlay
//                VStack(spacing: 0) {
//                    // Top bezel with rounded corners and depth - full screen width
//                    ZStack(alignment: .top) {
//                        // Shadow layer
//                        UnevenRoundedRectangle(
//                            topLeadingRadius: 0,
//                            bottomLeadingRadius: 25,
//                            bottomTrailingRadius: 25,
//                            topTrailingRadius: 0,
//                            style: .continuous
//                        )
//                        .fill(Color.black.opacity(0.3))
//                        .frame(height: 92)
//                        .offset(y: 2)
//                        .blur(radius: 4)
//                        
//                        // Main bezel with gradient
//                        UnevenRoundedRectangle(
//                            topLeadingRadius: 0,
//                            bottomLeadingRadius: 25,
//                            bottomTrailingRadius: 25,
//                            topTrailingRadius: 0,
//                            style: .continuous
//                        )
//                        .fill(
//                            LinearGradient(
//                                gradient: Gradient(colors: [
//                                    Color.black,
//                                    Color.black.opacity(0.95)
//                                ]),
//                                startPoint: .top,
//                                endPoint: .bottom
//                            )
//                        )
//                        .frame(height: 90)
//                        .overlay(
//                            // Subtle border highlight on bottom edge
//                            UnevenRoundedRectangle(
//                                topLeadingRadius: 0,
//                                bottomLeadingRadius: 25,
//                                bottomTrailingRadius: 25,
//                                topTrailingRadius: 0,
//                                style: .continuous
//                            )
//                            .strokeBorder(
//                                LinearGradient(
//                                    gradient: Gradient(colors: [
//                                        Color.clear,
//                                        Color.white.opacity(0.1)
//                                    ]),
//                                    startPoint: .top,
//                                    endPoint: .bottom
//                                ),
//                                lineWidth: 1
//                            )
//                        )
//                        
//                        // Controls on the bezel
//                        VStack {
//                            Spacer()
//                                .frame(height: 40) // Increased space for status bar/notch/dynamic island
//                            
//                            // Main control area
//                            HStack {
//                                // Settings button with shadow
//                                Button(action: {
//                                    showingSettings.toggle()
//                                }) {
//                                    Image(systemName: "gear")
//                                        .font(.system(size: 22))
//                                        .foregroundColor(.white)
//                                        .frame(width: 44, height: 44)
//                                        .background(
//                                            Circle()
//                                                .fill(Color.white.opacity(0.15))
//                                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
//                                        )
//                                }
//                                .padding(.leading, 20)
//                                
//                                Spacer()
//                                
//                                // App title with subtle shadow
//                                Text("SHOT ANALYZER")
//                                    .font(.system(size: 16, weight: .semibold, design: .default))
//                                    .foregroundColor(.white)
//                                    .tracking(1.5)
//                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
//                                
//                                Spacer()
//                                
//                                // Session indicator with depth
//                                HStack(spacing: 6) {
//                                    Circle()
//                                        .fill(sessionActive ? Color.red : Color.green)
//                                        .frame(width: 10, height: 10)
//                                        .shadow(color: sessionActive ? .red.opacity(0.6) : .green.opacity(0.6), radius: 4)
//                                        .overlay(
//                                            Circle()
//                                                .fill(sessionActive ? Color.red : Color.clear)
//                                                .frame(width: 10, height: 10)
//                                                .scaleEffect(sessionActive ? 1.5 : 1)
//                                                .opacity(sessionActive ? 0 : 1)
//                                                .animation(sessionActive ? .easeInOut(duration: 1).repeatForever() : .default, value: sessionActive)
//                                        )
//                                    
//                                    Text(sessionActive ? "REC" : "READY")
//                                        .font(.system(size: 14, weight: .medium))
//                                        .foregroundColor(.white)
//                                }
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 8)
//                                .background(
//                                    Capsule()
//                                        .fill(Color.white.opacity(0.15))
//                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
//                                )
//                                .padding(.trailing, 20)
//                            }
//                            
//                            Spacer()
//                                .frame(height: 6) // Reduced bottom padding
//                        }
//                        .frame(height: 90)
//                    }
//                    // Remove horizontal padding to make it full screen width
//                    .offset(y: -8.2) // Move bezel up by 20 pixels
//                    .padding(.horizontal, -1) // Make bezel 1 pixel wider on each side
//          
//                    
//                    Spacer()
//                    
//                    // Bottom controls
//                    HStack {
//                        // Session control
//                        Button(action: {
//                            sessionActive.toggle()
//                        }) {
//                            Image(systemName: sessionActive ? "stop.fill" : "play.fill")
//                                .font(.system(size: 20))
//                                .foregroundColor(.white)
//                                .frame(width: 60, height: 60)
//                                .background(sessionActive ? Color.red : Color.green)
//                                .clipShape(Circle())
//                        }
//                        .padding(.leading, 40)
//                        .padding(.bottom, 40)
//                        
//                        Spacer()
//                        
//                        // Camera flip button
//                        Button(action: {
//                            isUsingFrontCamera.toggle()
//                        }) {
//                            Image(systemName: "camera.rotate.fill")
//                                .font(.system(size: 24))
//                                .foregroundColor(.white)
//                                .frame(width: 50, height: 50)
//                                .background(Color.white.opacity(0.2))
//                                .clipShape(Circle())
//                        }
//                        .padding(.trailing, 40)
//                        .padding(.bottom, 40)
//                    }
//                }
//            } else {
//                // Start screen
//                VStack(spacing: 30) {
//                    Text("🏀 Basketball Shot Analyzer")
//                        .font(.largeTitle.bold())
//                        .multilineTextAlignment(.center)
//                    
//                    Text("Real-time jumpshot mechanic analysis with AI coaching feedback")
//                        .font(.body)
//                        .multilineTextAlignment(.center)
//                        .foregroundColor(.secondary)
//                        .padding(.horizontal, 40)
//                    
//                    Button("Start Training") {
//                        started = true
//                        sessionActive = true
//                    }
//                    .font(.title2.bold())
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 40)
//                    .padding(.vertical, 16)
//                    .background(Color.orange)
//                    .cornerRadius(25)
//                }
//                .padding()
//            }
//        }
//        .ignoresSafeArea()
//        .sheet(isPresented: $showingSettings) {
//            SettingsView(playerAge: $playerAge, playerHandedness: $playerHandedness)
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}
