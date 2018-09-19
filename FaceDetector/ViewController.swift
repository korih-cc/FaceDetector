//
//  ViewController.swift
//  FaceDetector
//
//  Created by Hiroyuki Koshizawa on 2018/09/18.
//  Copyright © 2018年 korih. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    // 出力用ラベル
    @IBOutlet weak private var _rollLabel : UILabel!
    @IBOutlet weak private var _yawLabel : UILabel!
    
    private var _captureSession = AVCaptureSession()
    private var _videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    private var _videoOutput = AVCaptureVideoDataOutput()
    private var _videoLayer : AVCaptureVideoPreviewLayer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // カメラ関連の設定
        self._captureSession = AVCaptureSession()
        self._videoOutput = AVCaptureVideoDataOutput()
        self._videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        do {
            let videoInput = try AVCaptureDeviceInput(device: self._videoDevice!) as AVCaptureDeviceInput
            self._captureSession.addInput(videoInput)
        } catch let error as NSError {
            print(error)
        }
        
        self._videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]

        self._videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        self._videoOutput.alwaysDiscardsLateVideoFrames = true
        
        self._captureSession.addOutput(self._videoOutput)

        for connection in self._videoOutput.connections {
            connection.videoOrientation = .portrait
        }
        
        self._videoLayer = AVCaptureVideoPreviewLayer(session: self._captureSession)
        self._videoLayer?.frame = UIScreen.main.bounds
        self._videoLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.view.layer.addSublayer(self._videoLayer!)

        self._captureSession.startRunning()
    }

    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let resultImage: UIImage = UIImage(cgImage: imageRef!)
        return resultImage
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        DispatchQueue.main.async {
            let image: UIImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            
            // 顔検出用のリクエストを生成
            let request = VNDetectFaceRectanglesRequest { (request: VNRequest, error: Error?) in
                // 顔枠を削除
                self.view.subviews.forEach {
                    if $0 != self._rollLabel && $0 != self._yawLabel {
                        $0.removeFromSuperview()
                    }
                }
                
                for observation in request.results as! [VNFaceObservation] {
                    // 顔枠Viewのframe計算
                    let xRate : CGFloat = self.view.bounds.width / image.size.width
                    let yRate : CGFloat = self.view.bounds.height / image.size.height
                    
                    let faceRect = CGRect(
                        x: observation.boundingBox.minX * image.size.width * xRate,
                        y: (1 - observation.boundingBox.maxY) * image.size.height * yRate,
                        width: observation.boundingBox.width * image.size.width * xRate,
                        height: observation.boundingBox.height * image.size.height * yRate
                    )

                    // 顔枠Viewの設定
                    let faceTrackingView = UIView(frame: faceRect)
                    faceTrackingView.backgroundColor = UIColor.clear
                    faceTrackingView.layer.borderWidth = 1.0
                    faceTrackingView.layer.borderColor = UIColor.green.cgColor
                    self.view.addSubview(faceTrackingView)
                    self.view.bringSubviewToFront(faceTrackingView)

                    // ロール(傾き)の出力
                    if let roll = observation.roll {
                        let rollText = String(format: "%.1f", roll.doubleValue * 180.0 / Double.pi)
                        self._rollLabel.text = "roll: \(rollText)"
                    } else {
                        self._rollLabel.text = ""
                    }
                    
                    // ヨー角の出力
                    if let yaw = observation.yaw {
                        let yawText = String(format: "%.1f", yaw.doubleValue * 180.0 / Double.pi)
                        self._yawLabel.text = "yaw: \(yawText)"
                    } else {
                        self._yawLabel.text = ""
                    }
                }
                
                self.view.bringSubviewToFront(self._rollLabel)
                self.view.bringSubviewToFront(self._yawLabel)
            }

            // 顔検出開始
            if let cgImage = image.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }
        }
    }

}

