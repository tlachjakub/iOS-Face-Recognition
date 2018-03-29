//
//  FaceView.swift
//  iOS-Face-Extraction
//
//  Created by Jakub Tlach on 3/1/18.
//  Copyright © 2018 Jakub Tlach. All rights reserved.
//

import UIKit
import AVFoundation


class FaceView: UIView {
	
	
	// Configuration
	let zoom: CGFloat = 55
	let rotationRate: CGFloat = 1.5
	
	
	// Face Detector
	var ciDetector: CIDetector!
	let ciOptions = [CIDetectorImageOrientation: "1"]
	var context = CIContext()
	let cameraLayer = CALayer()
	var scale: CGFloat = 1
	
	var captureWidth: CGFloat = 0
	var captureHeight: CGFloat = 0
	
	
	
	
	
	
	// Inicialization
	func initialize(width: CGFloat, height: CGFloat) {
		
		// Size
		captureWidth = width
		captureHeight = height
		
		
		// Init Detector
		let options = [CIDetectorAccuracy: CIDetectorAccuracyLow, CIDetectorTracking: true] as [String : Any]
		ciDetector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)!
		
		
		// Init Layer
		cameraLayer.frame = CGRect(x: 0, y: 0, width: captureWidth, height: captureHeight)
		cameraLayer.position = CGPoint(x: frame.width / 2 , y: frame.height)
		layer.addSublayer(cameraLayer)
		ruCornerRadius = 1 //frame.width / 2
		
		
		// Init CGContext
		context = CGImage.ruCreateContext(width: captureWidth, height: captureHeight)
		
	}
	
	
	
	
	
	
	// Detect the face and render the image
	func updateImage(_ image: CIImage) {
		
		// Get Faces
		let faces = ciDetector.features(in: image, options: ciOptions)
		
		guard let face = faces.first as? CIFaceFeature else {
			return
		}


		// No Eyes?
		if !face.hasLeftEyePosition || !face.hasRightEyePosition {
			return
		}
		
		
		// Get Eyes
		let leftEyePos = face.leftEyePosition
		let rightEyePos = face.rightEyePosition
		let eyeDistance = leftEyePos.ruDistanceToPoint(rightEyePos)
		let eyeAngle = leftEyePos.ruAngleRadToPoint(rightEyePos) * rotationRate
		let scale: CGFloat = zoom / eyeDistance
		
//		let eyeX = leftEyePos.x
//		let eyeY = leftEyePos.y


		// Get Face
//		let facePosX = face.bounds.origin.x
//		let facePosY = face.bounds.origin.y
//		let faceScale: CGFloat = zoom / eyeDistance


		// Get mouth
		let mouthPosX = face.mouthPosition.x
		let mouthPosY = face.mouthPosition.y - 55
		
		
		// Convert to CGImage
		guard let cgImage = self.context.createCGImage(image, from: image.extent) else {
			return
		}
		
		
		// Render Image
		RUTools.runOnMainThread {
			//self.layer.contents = cgImage
			
			
			self.cameraLayer.contents = cgImage
//			self.cameraLayer.anchorPoint = CGPoint(x: eyeX / self.captureWidth, y: (self.captureHeight - eyeY) / self.captureHeight)
//			self.cameraLayer.anchorPoint = CGPoint(x: facePosX / self.captureWidth, y: (self.captureHeight - facePosY) / self.captureHeight)
			self.cameraLayer.anchorPoint = CGPoint(x: mouthPosX / self.captureWidth, y: (self.captureHeight - mouthPosY) / self.captureHeight)
			var transform = CATransform3DMakeRotation(-eyeAngle, 0, 0, 1)
			transform = CATransform3DScale(transform, -scale, scale, 1)
			self.cameraLayer.transform = transform
			
			
//			self.cameraLayer.transform = CATransform3DMakeScale(0.2, 2000.2, 1)
//			self.cameraLayer.transform = CATransform3DMakeTranslation(300.2, 0.2, 0)
//			self.cameraLayer.transform = CATransform3DMakeRotation(0.2, 0, 0, 1)

			
		}
	}
}

