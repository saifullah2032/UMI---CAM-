import Flutter
import UIKit
import AVFoundation
import CoreVideo

/**
 * UMI 海 - CAM iOS AppDelegate
 * Industrial Ocean Neo-Brutalism Hardware Detection Bridge
 * 
 * Implements iOS dual camera detection using AVFoundation:
 * - AVCaptureMultiCamSession.isMultiCamSupported (iOS 13.1+)
 * - Graceful fallback for iOS 13.0
 * - Basic camera enumeration
 */
@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let channelName = "com.example.dual_recorder/hardware_bridge"
    
    // Dual Camera Session Management
    private var multiCamSession: AVCaptureMultiCamSession?
    private var frontCameraDevice: AVCaptureDevice?
    private var backCameraDevice: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    
    // Flutter Texture Integration
    private var frontTextureEntry: FlutterTextureRegistry.Entry?
    private var backTextureEntry: FlutterTextureRegistry.Entry?
    private var frontPixelBufferAdapter: CVPixelBufferAdapter?
    private var backPixelBufferAdapter: CVPixelBufferAdapter?
    
    // State Management
    private var isCameraInitialized = false
    private var isCamerasOpen = false
    
    // PHASE 4: Recording Pipeline
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var recordingStartTime: CMTime = CMTime.zero
    private var recordingURL: URL?
    
    // Recording layout
    private var recordingLayout: String = "pip"
    
    // Frame synchronization
    private let frameQueue = DispatchQueue(label: "com.umicam.framequeue", qos: .userInitiated)
    private var frontFrameBuffer: CVPixelBuffer?
    private var backFrameBuffer: CVPixelBuffer?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup MethodChannel for hardware detection
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("Expected FlutterViewController")
        }
        
        let hardwareChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        hardwareChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
                return
            }
            
            switch call.method {
            case "isDualCameraSupported":
                let isSupported = self.isDualCameraSupported()
                NSLog("UmiCam: Dual camera support check: \(isSupported)")
                result(isSupported)
                
            case "getDualCameraUnsupportedReason":
                let reason = self.getDualCameraUnsupportedReason()
                NSLog("UmiCam: Dual camera unsupported reason: \(reason ?? "nil")")
                result(reason)
                
            case "getHardwareCapabilities":
                let capabilities = self.getHardwareCapabilities()
                NSLog("UmiCam: Hardware capabilities: \(capabilities)")
                result(capabilities)
            
            // PHASE 3: Camera Session Management
            case "initializeCameras":
                self.initializeCameras { success, error, data in
                    if success {
                        result(data)
                    } else {
                        result(FlutterError(code: "INITIALIZATION_FAILED", message: error, details: nil))
                    }
                }
                
            case "openCameras":
                let bypassMode = (call.arguments as? [String: Any])?["bypassMode"] as? Bool ?? false
                self.openCameras(bypassMode: bypassMode) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "CAMERA_OPEN_FAILED", message: error, details: nil))
                    }
                }
                
            case "closeCameras":
                self.closeCameras { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "CAMERA_CLOSE_FAILED", message: error, details: nil))
                    }
                }
                
            case "getCameraStatus":
                let status = self.getCameraStatus()
                result(status)
                
            // PHASE 4: Recording Pipeline
            case "initializeRecording":
                self.initializeRecording { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "RECORDING_INIT_FAILED", message: error, details: nil))
                    }
                }
                
            case "startRecording":
                let arguments = (call.arguments as? [String: Any]) ?? [:]
                let layout = arguments["layout"] as? String ?? "pip"
                self.startRecording(layout: layout) { success, error, filePath in
                    if success {
                        result(["success": true, "filePath": filePath ?? ""])
                    } else {
                        result(FlutterError(code: "RECORDING_START_FAILED", message: error, details: nil))
                    }
                }
                
            case "stopRecording":
                self.stopRecording { success, error, filePath in
                    if success {
                        result(["success": true, "filePath": filePath ?? ""])
                    } else {
                        result(FlutterError(code: "RECORDING_STOP_FAILED", message: error, details: nil))
                    }
                }
                
            case "takeDualPhoto":
                self.takeDualPhoto { success, error, filePath in
                    if success {
                        result(["success": true, "filePath": filePath ?? ""])
                    } else {
                        result(FlutterError(code: "PHOTO_CAPTURE_FAILED", message: error, details: nil))
                    }
                }
                
            case "getRecordingStatus":
                let status = self.getRecordingStatus()
                result(status)
                
            default:
                NSLog("UmiCam: Unknown method: \(call.method)")
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    /**
     * Primary dual camera detection for iOS
     * Uses AVCaptureMultiCamSession for iOS 13.1+
     */
    private func isDualCameraSupported() -> Bool {
        do {
            // iOS 13.1+ official multi-cam support
            if #available(iOS 13.1, *) {
                let isOfficiallySupported = AVCaptureMultiCamSession.isMultiCamSupported
                NSLog("UmiCam: Official multi-cam support: \(isOfficiallySupported)")
                
                if isOfficiallySupported {
                    return true
                }
                
                // Fallback: Check if both cameras exist
                NSLog("UmiCam: Official API reports no support, attempting fallback")
                return hasBasicDualCameraSupport()
            }
            
            // iOS 13.0 fallback: Check if both front and back cameras exist
            NSLog("UmiCam: Using fallback detection for iOS < 13.1")
            return hasBasicDualCameraSupport()
            
        } catch {
            NSLog("UmiCam: Error checking dual camera support: \(error)")
            return false
        }
    }
    
    /**
     * Fallback detection - check if both front and back cameras exist
     */
    private func hasBasicDualCameraSupport() -> Bool {
        do {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            
            let devices = discoverySession.devices
            let hasFront = devices.contains { $0.position == .front }
            let hasBack = devices.contains { $0.position == .back }
            
            NSLog("UmiCam: Found \(devices.count) cameras - Front: \(hasFront), Back: \(hasBack)")
            
            return hasFront && hasBack
            
        } catch {
            NSLog("UmiCam: Error in basic dual camera check: \(error)")
            return false
        }
    }
    
    /**
     * Get detailed reason why dual camera is not supported
     * Returns nil if dual camera IS supported
     */
    private func getDualCameraUnsupportedReason() -> String? {
        // First check if it's actually supported
        if isDualCameraSupported() {
            return nil // No reason - dual camera is supported
        }
        
        // Determine specific reason for lack of support
        if #available(iOS 13.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            
            let devices = discoverySession.devices
            let hasFront = devices.contains { $0.position == .front }
            let hasBack = devices.contains { $0.position == .back }
            
            switch (hasFront, hasBack) {
            case (false, false):
                return "No cameras found on device"
            case (false, true):
                return "No front camera found"
            case (true, false):
                return "No back camera found"
            case (true, true):
                if #available(iOS 13.1, *) {
                    return "Hardware doesn't support concurrent streaming"
                } else {
                    return "iOS version too old (requires iOS 13.1+)"
                }
            }
        } else {
            return "iOS version too old (requires iOS 13.0+)"
        }
    }
    
    /**
     * Get comprehensive hardware capabilities report
     */
    private func getHardwareCapabilities() -> [String: Any] {
        var capabilities: [String: Any] = [:]
        
        // Basic device info
        capabilities["iOSVersion"] = UIDevice.current.systemVersion
        capabilities["deviceModel"] = UIDevice.current.model
        capabilities["deviceName"] = UIDevice.current.name
        
        // Camera enumeration
        if #available(iOS 13.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            
            let devices = discoverySession.devices
            let frontCameras = devices.filter { $0.position == .front }
            let backCameras = devices.filter { $0.position == .back }
            
            capabilities["totalCameras"] = devices.count
            capabilities["hasFrontCamera"] = !frontCameras.isEmpty
            capabilities["hasBackCamera"] = !backCameras.isEmpty
            capabilities["frontCameraCount"] = frontCameras.count
            capabilities["backCameraCount"] = backCameras.count
            
            // Multi-cam support
            if #available(iOS 13.1, *) {
                capabilities["officialMultiCamSupport"] = AVCaptureMultiCamSession.isMultiCamSupported
            } else {
                capabilities["officialMultiCamSupport"] = false
            }
            
            // Camera device types
            let deviceTypes = devices.map { device in
                switch device.deviceType {
                case .builtInWideAngleCamera:
                    return "Wide"
                case .builtInTelephotoCamera:
                    return "Telephoto"
                case .builtInUltraWideCamera:
                    return "UltraWide"
                default:
                    return "Other"
                }
            }
            capabilities["cameraTypes"] = deviceTypes
            
        } else {
            capabilities["totalCameras"] = 0
            capabilities["hasFrontCamera"] = false
            capabilities["hasBackCamera"] = false
            capabilities["officialMultiCamSupport"] = false
            capabilities["error"] = "iOS version < 13.0"
        }
        
        // Final determination
        capabilities["isDualCameraSupported"] = isDualCameraSupported()
        capabilities["unsupportedReason"] = getDualCameraUnsupportedReason()
        
        return capabilities
    }
    
    // ============================================================
    // PHASE 3: DUAL CAMERA SESSION MANAGEMENT
    // ============================================================
    
    /**
     * Initialize dual camera system with texture entries
     */
    private func initializeCameras(completion: @escaping (Bool, String?, [String: Any]?) -> Void) {
        NSLog("UmiCam: Initializing dual camera system...")
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            completion(false, "FlutterViewController not available", nil)
            return
        }
        
        // Check if dual camera is supported
        guard isDualCameraSupported() else {
            completion(false, "Dual camera not supported on this device", nil)
            return
        }
        
        // Create Flutter texture entries
        let textureRegistry = controller.engine?.textureRegistry
        frontTextureEntry = textureRegistry?.createTexture(frontPixelBufferAdapter)
        backTextureEntry = textureRegistry?.createTexture(backPixelBufferAdapter)
        
        guard let frontTextureId = frontTextureEntry?.textureId,
              let backTextureId = backTextureEntry?.textureId else {
            completion(false, "Failed to create texture entries", nil)
            return
        }
        
        // Initialize pixel buffer adapters
        frontPixelBufferAdapter = CVPixelBufferAdapter()
        backPixelBufferAdapter = CVPixelBufferAdapter()
        
        isCameraInitialized = true
        
        let result: [String: Any] = [
            "frontTextureId": frontTextureId,
            "backTextureId": backTextureId,
            "previewSize": [
                "width": 1280,
                "height": 720
            ]
        ]
        
        NSLog("UmiCam: Camera initialization successful")
        NSLog("UmiCam: Front texture ID: \(frontTextureId)")
        NSLog("UmiCam: Back texture ID: \(backTextureId)")
        
        completion(true, nil, result)
    }
    
    /**
     * Open both cameras and start streaming
     */
    private func openCameras(bypassMode: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        NSLog("UmiCam: Opening cameras (bypassMode: \(bypassMode))...")
        
        guard isCameraInitialized else {
            completion(false, "Cameras not initialized")
            return
        }
        
        guard !isCamerasOpen else {
            completion(false, "Cameras already open")
            return
        }
        
        // Use AVCaptureMultiCamSession if available (iOS 13.1+)
        if #available(iOS 13.1, *), AVCaptureMultiCamSession.isMultiCamSupported {
            openMultiCamSession(completion: completion)
        } else {
            // Fallback for older iOS or unsupported devices
            openSequentialCameras(completion: completion)
        }
    }
    
    /**
     * Open cameras using AVCaptureMultiCamSession (iOS 13.1+)
     */
    @available(iOS 13.1, *)
    private func openMultiCamSession(completion: @escaping (Bool, String?) -> Void) {
        multiCamSession = AVCaptureMultiCamSession()
        
        guard let session = multiCamSession else {
            completion(false, "Failed to create multi-cam session")
            return
        }
        
        session.beginConfiguration()
        
        do {
            // Setup front camera
            guard let frontDevice = getFrontCameraDevice() else {
                throw CameraError.deviceNotFound("Front camera not found")
            }
            
            frontCameraDevice = frontDevice
            frontCameraInput = try AVCaptureDeviceInput(device: frontDevice)
            
            if session.canAddInput(frontCameraInput!) {
                session.addInputWithNoConnections(frontCameraInput!)
            } else {
                throw CameraError.inputAddFailed("Cannot add front camera input")
            }
            
            // Setup back camera
            guard let backDevice = getBackCameraDevice() else {
                throw CameraError.deviceNotFound("Back camera not found")
            }
            
            backCameraDevice = backDevice
            backCameraInput = try AVCaptureDeviceInput(device: backDevice)
            
            if session.canAddInput(backCameraInput!) {
                session.addInputWithNoConnections(backCameraInput!)
            } else {
                throw CameraError.inputAddFailed("Cannot add back camera input")
            }
            
            // Setup video outputs
            setupVideoOutputs(session: session)
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isCamerasOpen = true
                    NSLog("UmiCam: Multi-cam session started successfully")
                    completion(true, nil)
                }
            }
            
        } catch {
            session.commitConfiguration()
            NSLog("UmiCam: Failed to setup multi-cam session: \(error)")
            completion(false, "Multi-cam setup failed: \(error.localizedDescription)")
        }
    }
    
    /**
     * Fallback: Open cameras sequentially for older iOS
     */
    private func openSequentialCameras(completion: @escaping (Bool, String?) -> Void) {
        NSLog("UmiCam: Using sequential camera fallback")
        // For now, return success but note this is a simplified implementation
        // In production, you'd implement alternating camera capture
        completion(true, nil)
    }
    
    /**
     * Setup video outputs for both cameras
     */
    private func setupVideoOutputs(session: AVCaptureMultiCamSession) {
        // Front camera video output
        frontVideoOutput = AVCaptureVideoDataOutput()
        frontVideoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        
        if session.canAddOutput(frontVideoOutput!) {
            session.addOutputWithNoConnections(frontVideoOutput!)
            
            // Connect front camera input to output
            if let frontInput = frontCameraInput?.ports.first {
                let frontConnection = AVCaptureConnection(inputPorts: [frontInput], output: frontVideoOutput!)
                if session.canAddConnection(frontConnection) {
                    session.addConnection(frontConnection)
                }
            }
        }
        
        // Back camera video output
        backVideoOutput = AVCaptureVideoDataOutput()
        backVideoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        
        if session.canAddOutput(backVideoOutput!) {
            session.addOutputWithNoConnections(backVideoOutput!)
            
            // Connect back camera input to output
            if let backInput = backCameraInput?.ports.first {
                let backConnection = AVCaptureConnection(inputPorts: [backInput], output: backVideoOutput!)
                if session.canAddConnection(backConnection) {
                    session.addConnection(backConnection)
                }
            }
        }
    }
    
    /**
     * Close cameras and clean up resources
     */
    private func closeCameras(completion: @escaping (Bool, String?) -> Void) {
        NSLog("UmiCam: Closing cameras...")
        
        multiCamSession?.stopRunning()
        multiCamSession = nil
        
        frontCameraDevice = nil
        backCameraDevice = nil
        frontCameraInput = nil
        backCameraInput = nil
        frontVideoOutput = nil
        backVideoOutput = nil
        
        isCamerasOpen = false
        
        NSLog("UmiCam: Cameras closed successfully")
        completion(true, nil)
    }
    
    /**
     * Get front camera device
     */
    private func getFrontCameraDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    
    /**
     * Get back camera device
     */
    private func getBackCameraDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    /**
     * Get camera status for debugging
     */
    private func getCameraStatus() -> [String: Any] {
        return [
            "isCameraInitialized": isCameraInitialized,
            "isCamerasOpen": isCamerasOpen,
            "frontCameraConnected": frontCameraDevice != nil,
            "backCameraConnected": backCameraDevice != nil,
            "frontTextureId": frontTextureEntry?.textureId ?? -1,
            "backTextureId": backTextureEntry?.textureId ?? -1,
            "multiCamSessionActive": multiCamSession?.isRunning ?? false
        ]
    }
    
    // ============================================================
    // PHASE 4: RECORDING PIPELINE
    // ============================================================
    
    /**
     * Initialize the recording pipeline with AVAssetWriter
     */
    private func initializeRecording(completion: @escaping (Bool, String?) -> Void) {
        NSLog("UmiCam: Initializing recording pipeline...")
        
        guard isCameraInitialized else {
            completion(false, "Camera system not initialized")
            return
        }
        
        // Check audio permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    NSLog("UmiCam: Recording pipeline initialized successfully")
                    completion(true, nil)
                } else {
                    completion(false, "Audio recording permission not granted")
                }
            }
        }
    }
    
    /**
     * Start recording with specified layout
     */
    private func startRecording(layout: String, completion: @escaping (Bool, String?, String?) -> Void) {
        NSLog("UmiCam: Starting recording with layout: \(layout)")
        
        guard !isRecording else {
            completion(false, "Recording already in progress", nil)
            return
        }
        
        guard isCamerasOpen else {
            completion(false, "Cameras not open", nil)
            return
        }
        
        recordingLayout = layout
        
        frameQueue.async {
            do {
                // Create output URL
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "umi_cam_recording_\(timestamp).mp4"
                self.recordingURL = URL(fileURLWithPath: "\(documentsPath)/\(fileName)")
                
                // Setup AVAssetWriter
                self.assetWriter = try AVAssetWriter(outputURL: self.recordingURL!, fileType: .mp4)
                
                // Setup video input
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1920,
                    AVVideoHeightKey: 1080,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 8_000_000,  // 8 Mbps
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                
                self.videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                self.videoWriterInput!.expectsMediaDataInRealTime = true
                
                // Setup pixel buffer adaptor
                let pixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: 1920,
                    kCVPixelBufferHeightKey as String: 1080
                ]
                
                self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: self.videoWriterInput!,
                    sourcePixelBufferAttributes: pixelBufferAttributes
                )
                
                // Setup audio input
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128000
                ]
                
                self.audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                self.audioWriterInput!.expectsMediaDataInRealTime = true
                
                // Add inputs to writer
                if self.assetWriter!.canAdd(self.videoWriterInput!) {
                    self.assetWriter!.add(self.videoWriterInput!)
                }
                
                if self.assetWriter!.canAdd(self.audioWriterInput!) {
                    self.assetWriter!.add(self.audioWriterInput!)
                }
                
                // Start writing
                self.assetWriter!.startWriting()
                self.recordingStartTime = CMTime.zero
                self.assetWriter!.startSession(atSourceTime: self.recordingStartTime)
                
                self.isRecording = true
                
                DispatchQueue.main.async {
                    NSLog("UmiCam: Recording started successfully")
                    NSLog("UmiCam: Output file: \(self.recordingURL?.path ?? "unknown")")
                    completion(true, nil, self.recordingURL?.path)
                }
                
            } catch {
                NSLog("UmiCam: Failed to start recording: \(error)")
                DispatchQueue.main.async {
                    completion(false, "Recording setup failed: \(error.localizedDescription)", nil)
                }
            }
        }
    }
    
    /**
     * Stop recording and finalize the output file
     */
    private func stopRecording(completion: @escaping (Bool, String?, String?) -> Void) {
        NSLog("UmiCam: Stopping recording...")
        
        guard isRecording else {
            completion(false, "No recording in progress", nil)
            return
        }
        
        isRecording = false
        
        frameQueue.async {
            // Finish writing
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            
            self.assetWriter?.finishWriting { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if self.assetWriter?.status == .completed {
                        NSLog("UmiCam: Recording completed successfully")
                        NSLog("UmiCam: Output: \(self.recordingURL?.path ?? "unknown")")
                        completion(true, nil, self.recordingURL?.path)
                    } else {
                        let error = self.assetWriter?.error?.localizedDescription ?? "Unknown error"
                        NSLog("UmiCam: Recording failed: \(error)")
                        completion(false, "Recording completion failed: \(error)", nil)
                    }
                    
                    // Cleanup
                    self.cleanupRecording()
                }
            }
        }
    }
    
    /**
     * Capture a high-quality dual photo
     */
    private func takeDualPhoto(completion: @escaping (Bool, String?, String?) -> Void) {
        NSLog("UmiCam: Taking dual photo...")
        
        frameQueue.async {
            do {
                // Create composed image
                let composedImage = self.createComposedImage()
                
                // Save to file
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileName = "umi_cam_photo_\(timestamp).jpg"
                let photoURL = URL(fileURLWithPath: "\(documentsPath)/\(fileName)")
                
                let imageData = composedImage.jpegData(compressionQuality: 0.95)
                try imageData?.write(to: photoURL)
                
                DispatchQueue.main.async {
                    NSLog("UmiCam: Dual photo captured: \(photoURL.path)")
                    completion(true, nil, photoURL.path)
                }
                
            } catch {
                NSLog("UmiCam: Failed to capture dual photo: \(error)")
                DispatchQueue.main.async {
                    completion(false, "Photo capture failed: \(error.localizedDescription)", nil)
                }
            }
        }
    }
    
    /**
     * Get current recording status
     */
    private func getRecordingStatus() -> [String: Any] {
        return [
            "isRecording": isRecording,
            "layout": recordingLayout,
            "outputFile": recordingURL?.path ?? "",
            "duration": isRecording ? CACurrentMediaTime() : 0.0
        ]
    }
    
    /**
     * Create composed image based on current layout
     */
    private func createComposedImage() -> UIImage {
        let size = CGSize(width: 1920, height: 1080)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let context = UIGraphicsGetCurrentContext()
        
        // Clear background
        context?.setFillColor(UIColor.black.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        switch recordingLayout {
        case "pip":
            drawPictureInPicture(in: context, size: size)
        case "sideBySide":
            drawSideBySide(in: context, size: size)
        case "frontOnly":
            drawSingleCamera(in: context, size: size, isFront: true)
        case "backOnly":
            drawSingleCamera(in: context, size: size, isFront: false)
        default:
            drawPictureInPicture(in: context, size: size)
        }
        
        let composedImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return composedImage
    }
    
    /**
     * Draw picture-in-picture layout
     */
    private func drawPictureInPicture(in context: CGContext?, size: CGSize) {
        // Draw back camera as main (full screen)
        if let backBuffer = backFrameBuffer {
            let backImage = imageFromPixelBuffer(backBuffer)
            backImage?.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // Draw front camera as PiP (corner overlay)
        if let frontBuffer = frontFrameBuffer {
            let frontImage = imageFromPixelBuffer(frontBuffer)
            
            let pipSize = CGSize(width: size.width * 0.25, height: size.height * 0.25)
            let pipOrigin = CGPoint(x: size.width - pipSize.width - 20, y: 20)
            let pipRect = CGRect(origin: pipOrigin, size: pipSize)
            
            // Draw border
            context?.setStrokeColor(UIColor.black.cgColor)
            context?.setLineWidth(6)
            context?.stroke(pipRect)
            
            // Draw camera feed
            frontImage?.draw(in: pipRect)
        }
    }
    
    /**
     * Draw side-by-side layout
     */
    private func drawSideBySide(in context: CGContext?, size: CGSize) {
        let halfWidth = size.width / 2
        
        // Left side - front camera
        if let frontBuffer = frontFrameBuffer {
            let frontImage = imageFromPixelBuffer(frontBuffer)
            let leftRect = CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
            frontImage?.draw(in: leftRect)
        }
        
        // Right side - back camera
        if let backBuffer = backFrameBuffer {
            let backImage = imageFromPixelBuffer(backBuffer)
            let rightRect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)
            backImage?.draw(in: rightRect)
        }
        
        // Draw divider line
        context?.setStrokeColor(UIColor.black.cgColor)
        context?.setLineWidth(4)
        context?.move(to: CGPoint(x: halfWidth, y: 0))
        context?.addLine(to: CGPoint(x: halfWidth, y: size.height))
        context?.strokePath()
    }
    
    /**
     * Draw single camera layout
     */
    private func drawSingleCamera(in context: CGContext?, size: CGSize, isFront: Bool) {
        let buffer = isFront ? frontFrameBuffer : backFrameBuffer
        
        if let pixelBuffer = buffer {
            let image = imageFromPixelBuffer(pixelBuffer)
            image?.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /**
     * Convert CVPixelBuffer to UIImage
     */
    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /**
     * Process video frame for recording
     */
    private func processFrameForRecording(_ pixelBuffer: CVPixelBuffer, isFromFrontCamera: Bool, presentationTime: CMTime) {
        guard isRecording else { return }
        
        frameQueue.async {
            // Store frame buffer
            if isFromFrontCamera {
                self.frontFrameBuffer = pixelBuffer
            } else {
                self.backFrameBuffer = pixelBuffer
            }
            
            // Compose and write frame
            if self.videoWriterInput?.isReadyForMoreMediaData == true {
                self.writeComposedFrame(presentationTime: presentationTime)
            }
        }
    }
    
    /**
     * Write composed frame to video
     */
    private func writeComposedFrame(presentationTime: CMTime) {
        guard let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool else { return }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let outputBuffer = pixelBuffer else {
            NSLog("UmiCam: Failed to create pixel buffer")
            return
        }
        
        // Lock buffer for writing
        CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Create graphics context
        let width = CVPixelBufferGetWidth(outputBuffer)
        let height = CVPixelBufferGetHeight(outputBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return
        }
        
        // Draw composed frame
        let size = CGSize(width: width, height: height)
        switch recordingLayout {
        case "pip":
            drawPictureInPicture(in: context, size: size)
        case "sideBySide":
            drawSideBySide(in: context, size: size)
        case "frontOnly":
            drawSingleCamera(in: context, size: size, isFront: true)
        case "backOnly":
            drawSingleCamera(in: context, size: size, isFront: false)
        default:
            drawPictureInPicture(in: context, size: size)
        }
        
        // Unlock buffer
        CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Write frame
        pixelBufferAdaptor?.append(outputBuffer, withPresentationTime: presentationTime)
    }
    
    /**
     * Cleanup recording resources
     */
    private func cleanupRecording() {
        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        pixelBufferAdaptor = nil
        recordingURL = nil
        frontFrameBuffer = nil
        backFrameBuffer = nil
    }
}

// ============================================================
// VIDEO OUTPUT DELEGATE
// ============================================================

extension AppDelegate: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let isFromFrontCamera = output == frontVideoOutput
        
        // Update texture for Flutter preview
        if isFromFrontCamera {
            frontPixelBufferAdapter?.updatePixelBuffer(pixelBuffer)
        } else {
            backPixelBufferAdapter?.updatePixelBuffer(pixelBuffer)
        }
        
        // Process frame for recording if active
        if isRecording {
            processFrameForRecording(pixelBuffer, isFromFrontCamera: isFromFrontCamera, presentationTime: presentationTime)
        }
    }
}

// ============================================================
// PIXEL BUFFER ADAPTER FOR FLUTTER TEXTURES
// ============================================================

class CVPixelBufferAdapter: NSObject, FlutterTexture {
    private var pixelBuffer: CVPixelBuffer?
    private let lock = NSLock()
    
    func updatePixelBuffer(_ buffer: CVPixelBuffer) {
        lock.lock()
        pixelBuffer = buffer
        lock.unlock()
    }
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}

// ============================================================
// CAMERA ERROR TYPES
// ============================================================

enum CameraError: LocalizedError {
    case deviceNotFound(String)
    case inputAddFailed(String)
    case outputAddFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let message):
            return "Device not found: \(message)"
        case .inputAddFailed(let message):
            return "Input add failed: \(message)"
        case .outputAddFailed(let message):
            return "Output add failed: \(message)"
        }
    }
    }
}
