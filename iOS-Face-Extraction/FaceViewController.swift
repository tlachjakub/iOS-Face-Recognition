//
//  FaceViewController.swift
//  iOS-Face-Extraction
//
//  Created by Jakub Tlach on 3/7/18.
//  Copyright © 2018 Jakub Tlach. All rights reserved.
//

import UIKit
import AVFoundation
import SceneKit
import ARKit
import Vision

class FaceViewController: UIViewController, ARSCNViewDelegate {
	
	
	@IBOutlet var sceneView: ARSCNView!
	@IBOutlet weak var faceView: FaceView!
	@IBOutlet weak var startRecSwitch: UISwitch!
	
	@IBOutlet weak var textOverlay: UILabel!
	@IBOutlet weak var debugTextView: UITextView!
	
	@IBOutlet weak var totalCounter: UILabel!
	@IBOutlet weak var faceCounter: UILabel!
	
	var sessionWidth: Int = 0
	var sessionHeight: Int = 0
	
	var faceImage: UIImage = UIImage()
	var faceCI: CIImage = CIImage()
	var isFaceViewInitialized = false
	
	let bubbleDepth: Float = 0.01 // the "depth" of 3D text
	let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
	var visionRequests = [VNRequest]()
	
	
	// VNRequest: Either Retangles or Landmarks
	var faceDetectionRequest: VNRequest!
	
	
	// Loads the counters
	var totalNumber = UserDefaults.standard.integer(forKey: "totalNumber")
	
	// Number of the folder
	var faceNumber = UserDefaults.standard.integer(forKey: "faceNumber")
	
	
	
	
	
	
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		
		//////////////////////////////////////////////////////////////////
		// AR KIT
		//////////////////////////////////////////////////////////////////
		
		// Set the view's delegate
		sceneView.delegate = self

		// Show statistics such as fps and timing information
		sceneView.showsStatistics = true

		// Create a new scene
		let scene = SCNScene() // SCNScene(named: "art.scnassets/ship.scn")!

		// Set the scene to the view
		sceneView.scene = scene

		// Enable Default Lighting - makes the 3D text a bit poppier.
		sceneView.autoenablesDefaultLighting = true


		
		
		//////////////////////////////////////////////////////////////////
		// Tap Gesture Recognizer
		//////////////////////////////////////////////////////////////////
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
		view.addGestureRecognizer(tapGesture)


		
		
		
		//////////////////////////////////////////////////////////////////
		// ML & VISION
		//////////////////////////////////////////////////////////////////
		
		// Setup Vision Model
		guard let selectedModel = try? VNCoreMLModel(for: kerasFacesModel().model) else {
			fatalError("Could not load model")
		}
		
		
		// Set up Vision-CoreML Request
		let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
		classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
		visionRequests = [classificationRequest]
		
		
		// Begin Loop to Update CoreML
		loopCoreMLUpdate()
		
		
		// Update of the Counters
		update()
	}
	
	
	
	
	
	
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// Create a session configuration
		let configuration = ARWorldTrackingConfiguration()
		
		// Enable plane detection
		configuration.planeDetection = .horizontal

		// Run the view's session
		sceneView.session.run(configuration)
	}
	
	
	
	
	
	
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		// Pause the view's session
		sceneView.session.pause()
	}
	
	
	
	
	
	
	
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	
	
	
	
	
	

	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MARK: - ARSCNViewDelegate
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		DispatchQueue.main.async {
			// Do any desired updates to SceneKit here.
		}
	}



	
	
	
	
	
	
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MARK: - Interaction
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	@objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
		// HIT TEST : REAL WORLD
		// Get Screen Centre
		let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY - 150)

		let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.

		if let closestResult = arHitTestResults.first {
			// Get Coordinates of HitTest
			let transform : matrix_float4x4 = closestResult.worldTransform
			let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

			// Create 3D Text
			let node : SCNNode = createNewBubbleParentNode(textOverlay.text!)
			sceneView.scene.rootNode.addChildNode(node)
			node.position = worldCoord
		}
	}




	func createNewBubbleParentNode(_ text : String) -> SCNNode {
		// Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.

		// TEXT BILLBOARD CONSTRAINT
		let billboardConstraint = SCNBillboardConstraint()
		billboardConstraint.freeAxes = SCNBillboardAxis.Y

		// BUBBLE-TEXT
		let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
		var font = UIFont(name: "Futura", size: 0.15)
		font = font?.withTraits(traits: .traitBold)
		bubble.font = font
		bubble.alignmentMode = kCAAlignmentCenter
		bubble.firstMaterial?.diffuse.contents = UIColor.red
		bubble.firstMaterial?.specular.contents = UIColor.white
		bubble.firstMaterial?.isDoubleSided = true
		// bubble.flatness // setting this too low can cause crashes.
		bubble.chamferRadius = CGFloat(bubbleDepth)

		// BUBBLE NODE
		let (minBound, maxBound) = bubble.boundingBox
		let bubbleNode = SCNNode(geometry: bubble)
		// Centre Node - to Centre-Bottom point
		bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
		// Reduce default text size
		bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)

		// CENTRE POINT NODE
		let sphere = SCNSphere(radius: 0.003)
		sphere.firstMaterial?.diffuse.contents = UIColor.yellow
		let sphereNode = SCNNode(geometry: sphere)

		// BUBBLE PARENT NODE
		let bubbleNodeParent = SCNNode()
		bubbleNodeParent.addChildNode(bubbleNode)
		bubbleNodeParent.addChildNode(sphereNode)
		bubbleNodeParent.constraints = [billboardConstraint]

		return bubbleNodeParent
	}


	
	
	
	
	
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MARK: - MACHINE LEARNING
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	func loopCoreMLUpdate() {
		// Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
		RUTools.runAfter(0.04) {
			// 1. Run Update.
			self.updateCoreML()
			// 2. Loop this function.
			self.loopCoreMLUpdate()
		}
	}
	
	
	
	

	func updateCoreML() {
		
		// Get Camera Image as RGB
		let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
		if pixbuff == nil { return }
		
		
		
		// Get the width and height
		sessionWidth = CVPixelBufferGetWidth(pixbuff!)
		sessionHeight = CVPixelBufferGetHeight(pixbuff!)
		
		
//		print("Session before rotation:")
//		print("Width: \(sessionWidth)")
//		print("Height: \(sessionHeight)")
		
		
		// Convert to CIImage
		let ciImage = CIImage(cvPixelBuffer: pixbuff!)
		guard let cgImage = convertCIImageToCGImage(inputImage: ciImage) else {
			print("convertCIImageToCGImage failed")
			return
		}
		let rotatedImage = rotateCGImage(cgImage)
		
		
		
		// Convert to UIImage and fix orientation
		//var rotatedImage = UIImage(ciImage: ciImage)
		//rotatedImage = rotatedImage.fixImageOrientation()!
		
		//let image = UIImage(cgImage: cgImage!, scale: CGFloat(1.0), orientation: .left )
		
		// Convert to pixelBuffer back
//		let fixedImage = image.pixelBuffer()
//		guard let returnImage = image.ciImage else {
//			return
//		}
		
		
		
		
//		// Get the width and height from the image with fixed orientation
//		sessionWidth = CVPixelBufferGetWidth(fixedImage!)
//		sessionHeight = CVPixelBufferGetHeight(fixedImage!)
		
		
//		print("-------------------------")
//		print("Width: \(rotatedImage.width)")
//		print("Height: \(rotatedImage.height)")
		
		
		
		// Inicialization
		if !isFaceViewInitialized {
			faceView.initialize(width: CGFloat(rotatedImage.width), height: CGFloat(rotatedImage.height))
			isFaceViewInitialized = true
		}
		
		
		// Face detection and zoom
		let ciImageFixed = CIImage(cgImage: rotatedImage)
		faceView.updateImage(ciImageFixed)
		
		
		// Face image render for Vision Request
		faceImage = faceView.ruRenderedImage.ruAspectFillToSize(CGSize(width: 120, height: 120))
		faceCI = CIImage(image: faceImage)!

		
		// Prepare CoreML/Vision Request
		let imageRequestHandler = VNImageRequestHandler(ciImage: faceCI, options: [:])
		
		
		// Run Vision Image Request
		do {
			try imageRequestHandler.perform(self.visionRequests)
		} catch {
			print(error)
		}
	}
	
	
	
	
	
	
	// Rotate CGImage
	func rotateCGImage(_ cgImage: CGImage) -> CGImage {
		
		let targetWidth = cgImage.height
		let targetHeight = cgImage.width
		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
		guard let context = CGContext(data: nil, width: targetWidth, height: targetHeight,
									  bitsPerComponent: cgImage.bitsPerComponent,
									  bytesPerRow: targetWidth * cgImage.bitsPerComponent,
									  space: cgImage.colorSpace!,
									  bitmapInfo: bitmapInfo.rawValue) else {
										ruPrint("ERROR @ ruAspectFillToSize: Can't create Context")
										return cgImage
		}
		
		// Rotate Right
		context.translateBy(x: 0, y: CGFloat(targetHeight))
		context.rotate(by: RUTools.degToRadF(-90))
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
		if let ref = context.makeImage() {
			return ref
		} else {
			ruPrint("ERROR @ ruAspectFillToSize: Can't create UIImage")
			return cgImage
		}
	}
	
	
	
	
	
	
	// Convert CIImage to CGImage
	func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
		
		let context = CIContext(options: nil)
		return context.createCGImage(inputImage, from: inputImage.extent)
	}
	
	
	
	
	
	
	
	// Vision classification
	func classificationCompleteHandler(request: VNRequest, error: Error?) {
		
		// Catch Errors
		if error != nil {
			print("Error: " + (error?.localizedDescription)!)
			return
		}
		guard let observations = request.results else {
			print("No results")
			return
		}
		
		
		// Get Classifications
		let classifications = observations[0...2] // top 3 results
			.flatMap({ $0 as? VNClassificationObservation })
			.map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
			.joined(separator: "\n")
		
		
		// Render Classifications
		DispatchQueue.main.async {
			
			// Display Debug Text on screen
			self.debugTextView.text = "TOP 3 PROBABILITIES: \n" + classifications
			
			// Display Top Symbol
			var symbol = "❎"
			let topPrediction = classifications.components(separatedBy: "\n")[0]
			let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
			// Only display a prediction if confidence is above 1%
			let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
			if (topPredictionScore != nil && topPredictionScore! > 0.01) {
				//				if (topPredictionName == "Okubutae") { symbol = "Okubutae" }
				symbol = topPredictionName
			}
			
			self.textOverlay.text = symbol
		}
	}
	
	
	
	
	


	// When the Switch is ON -> take the images of the face
	func takePhotos() {

		// Stop?
		if !startRecSwitch.isOn {
			return
		}


		// No Image?
		if faceView.cameraLayer.contents == nil {

			// Continue
			RUTools.runAfter (0.2) { self.takePhotos() }
			return
		}


		// Get image
		let image = faceView.ruRenderedImage.ruAspectFillToSize(CGSize(width: 120, height: 120))


		// Folder for faces
		let folder = RUTools.documentsURL.appendingPathComponent("\(faceNumber)")
		if !FileManager.default.fileExists(atPath: folder.path) {
			try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		}


		// Save the image
		if let data = UIImagePNGRepresentation(image) {
			let path1 = folder.appendingPathComponent("\(totalNumber).png")
			try? data.write(to: path1)
		}


		// Increase the counter
		totalNumber += 1
		update()


		// Continue
		RUTools.runAfter(0.1) { self.takePhotos() }
	}



	
	
	
	
	
	// Start recording switch
	@IBAction func startStopSwitch(_ sender: Any) {

		if startRecSwitch.isOn {
			faceNumber += 1
		}

		takePhotos()
		save()
	}
	
	
	
	
	
	// Update counters
	func update() {
		totalCounter.text = "x \(totalNumber)"
		faceCounter.text = "x \(faceNumber)"
	}
	
	
	
	
	
	
	
	// Save counters
	func save() {
		UserDefaults.standard.set(totalNumber, forKey: "totalNumber")
		UserDefaults.standard.set(faceNumber, forKey: "faceNumber")
		UserDefaults.standard.synchronize()
		update()
	}

	
}







//////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: UIImage extension
//////////////////////////////////////////////////////////////////////////////////////////////////////

extension UIImage {
	func pixelBuffer() -> CVPixelBuffer? {
		let width = self.size.width
		let height = self.size.height
		let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
					 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
		var pixelBuffer: CVPixelBuffer?
		let status = CVPixelBufferCreate(kCFAllocatorDefault,
										 Int(width),
										 Int(height),
										 // If it's gray image
			//kCVPixelFormatType_OneComponent8,
			kCVPixelFormatType_32ARGB,
			attrs,
			&pixelBuffer)
		
		guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
			return nil
		}
		
		CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
		let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
		
		//let grayColorSpace = CGColorSpaceCreateDeviceGray()
		let RGBColorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(data: pixelData,
									  width: Int(width),
									  height: Int(height),
									  // bitsPerComponent: 8,
			bitsPerComponent: 8,
			bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
			space: RGBColorSpace,
			bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
			)
			else { return nil }
		
//		context.translateBy(x: 0, y: height)
//		context.scaleBy(x: 1.0, y: -1.0)
//		context.rotate(by: -90.0)
		
		UIGraphicsPushContext(context)
		self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
		UIGraphicsPopContext()
		CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
		
		return resultPixelBuffer
	}
}






//////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: Extensions
//////////////////////////////////////////////////////////////////////////////////////////////////////

extension UIFont {
	// Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
	func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
		let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
		return UIFont(descriptor: descriptor!, size: 0)
	}
}


















