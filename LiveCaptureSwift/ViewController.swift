//
//  ViewController.swift
//  LiveCaptureSwift
//
//  Created by Vladimir Kolbas on 6/27/16.
//  Copyright © 2016 Vladimir Kolbas. All rights reserved.
//

import UIKit
import AVFoundation

enum Eye {
    case Left, Right
}

class ViewController: UIViewController {
    
    // MARK: - Properties
    
    private let faceQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    private let sampleQueue = dispatch_queue_create("VideoSampleQueue", DISPATCH_QUEUE_SERIAL)
    private let faceContext = CIContext(options: nil)
    private let session = AVCaptureSession()
    private var token: dispatch_once_t = 0

    private var ciSize: CGSize!
    private let screenSize = UIScreen.mainScreen().bounds.size
    
    private static let pointNumber = 4
    private var positionPoints = Array<CGPoint>(count: pointNumber, repeatedValue: .zero)
    private var numPoints = 0
    private var frame = 0
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        return previewLayer
    }()
    
    private lazy var device: AVCaptureDevice = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        let frontDevices = devices.filter { $0.position == .Front }
        return frontDevices.first!
    }()
    
    private static let detectorAccuracy = CIDetectorAccuracyHigh
    private lazy var detector: CIDetector = {
        return CIDetector(
            ofType: CIDetectorTypeFace,
            context: self.faceContext,
            options: [CIDetectorAccuracy : detectorAccuracy]
        )
    }()
    
    private lazy var rightEyeView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        view.backgroundColor = .redColor()
        return view
    }()
    
    private lazy var leftEyeView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        view.backgroundColor = .redColor()
        return view
    }()
    
    private lazy var mouthView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 2))
        view.backgroundColor = .redColor()
        view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return view
    }()
    
    private lazy var beardImageView: UIImageView = {
        let beardImageView = UIImageView(image: UIImage(named: "beard")!)
        beardImageView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return beardImageView
    }()
    
    // MARK: - implementation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let input = try! AVCaptureDeviceInput(device: device)
        
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString : NSNumber(unsignedInt: kCMPixelFormat_32BGRA)]
        
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        
        session.addOutput(output)
        
        previewLayer.frame = view.layer.bounds
        previewLayer.contentsGravity = kCAGravityResizeAspect
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        view.layer.addSublayer(previewLayer)
        
        session.startRunning()
        
        view.addSubview(rightEyeView)
        view.addSubview(leftEyeView)
        view.addSubview(mouthView)
        view.addSubview(beardImageView)
    }
    
    private func drawEye(eye: Eye, atPosition position: CGPoint) {
        var newPosition = position
        newPosition.x = ciSize.width - position.x
        newPosition.y = -position.y
        
        newPosition.x = newPosition.x * screenSize.width / ciSize.width - 2
        newPosition.y = newPosition.y * screenSize.height / ciSize.height - 2
        
        dispatch_async(dispatch_get_main_queue()) {
            switch eye {
            case .Left:
                self.rightEyeView.center = newPosition
            case .Right:
                self.leftEyeView.center = newPosition
            }
        }
    }
    
    private func drawMouth(atPosition position: CGPoint, atAngle angle: Float) {
        var newPosition = position
        newPosition.x = ciSize.width - position.x
        newPosition.y = -position.y
        
        newPosition.x = newPosition.x * screenSize.width / ciSize.width - 15
        newPosition.y = newPosition.y * screenSize.height / ciSize.height - 1
        
        dispatch_async(dispatch_get_main_queue()) {
            let mouthAngle = -CGFloat(angle) * CGFloat(M_PI) / 180.0
            self.mouthView.center = newPosition
            self.mouthView.transform = CGAffineTransformMakeRotation(mouthAngle)
        }
    }
    
    private func positionBeard(leftEyePosition: CGPoint, rightEyePosition: CGPoint, mouthPosition: CGPoint, mouthAngle: CGFloat) {
        var newMouthPosition = mouthPosition
        newMouthPosition.x = ciSize.width - mouthPosition.x
        newMouthPosition.y = -mouthPosition.y
        
        newMouthPosition.x = newMouthPosition.x * screenSize.width / ciSize.width - 15
        newMouthPosition.y = newMouthPosition.y * screenSize.height / ciSize.height - 1
        
        var newLeftEyePosition = leftEyePosition
        newLeftEyePosition.x = ciSize.width - leftEyePosition.x
        newLeftEyePosition.y = -leftEyePosition.y
        
        newLeftEyePosition.x = newLeftEyePosition.x * screenSize.width / ciSize.width - 2
        newLeftEyePosition.y = newLeftEyePosition.y * screenSize.height / ciSize.height - 2
        
        var newRightEyePosition = rightEyePosition
        newRightEyePosition.x = ciSize.width - rightEyePosition.x
        newRightEyePosition.y = -rightEyePosition.y
        
        newRightEyePosition.x = newRightEyePosition.x * screenSize.width / ciSize.width - 2
        newRightEyePosition.y = newRightEyePosition.y * screenSize.height / ciSize.height - 2
        
        let midEyeY = (newRightEyePosition.y + newLeftEyePosition.y) / 2.0
        let distance = newMouthPosition.y - midEyeY
        let factor: CGFloat = 0.1
        let correction = distance * factor
        
        newMouthPosition.y = newMouthPosition.y - correction
        let mouthAngle = -CGFloat(mouthAngle) * CGFloat(M_PI) / 180.0
        
//        positionPoints[numPoints % ViewController.pointNumber] = newMouthPosition
//        numPoints += 1
        
        dispatch_async(dispatch_get_main_queue()) {
//            if self.numPoints < ViewController.pointNumber {
                self.beardImageView.center = newMouthPosition
//            } else {
//                self.beardImageView.center = self.average(self.positionPoints)
//            }
            
            self.beardImageView.transform = CGAffineTransformMakeRotation(mouthAngle)
        }
    }
    
    private func average(points: [CGPoint]) -> CGPoint {
        let xCount = points.map { $0.x }.reduce(0.0, combine: +)
        let yCount = points.map { $0.y }.reduce(0.0, combine: +)
        
        return CGPoint(x: xCount / CGFloat(points.count), y: yCount / CGFloat(points.count))
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        guard let cvImage = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(CVPixelBuffer: cvImage).imageByApplyingTransform(CGAffineTransformMakeRotation(-CGFloat(M_PI_2)))
        
        dispatch_once(&token) { () -> Void in
            self.ciSize = ciImage.extent.size;
        }
        
        dispatch_async(faceQueue) {
            
            if self.frame % 4 == 0 {
                if let feature = self.detector.featuresInImage(ciImage).first as? CIFaceFeature where
                    feature.hasLeftEyePosition && feature.hasRightEyePosition && feature.hasMouthPosition && feature.hasFaceAngle {
                    
                    self.drawEye(.Left, atPosition: feature.leftEyePosition)
                    self.drawEye(.Right, atPosition: feature.rightEyePosition)
                    self.drawMouth(atPosition: feature.mouthPosition, atAngle: feature.faceAngle)
                    self.positionBeard(feature.leftEyePosition, rightEyePosition: feature.rightEyePosition, mouthPosition: feature.mouthPosition, mouthAngle: CGFloat(feature.faceAngle))
                }
            }
        }
        
        self.frame += 1
    }
    
}