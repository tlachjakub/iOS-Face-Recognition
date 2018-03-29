//
//  ViewController.swift
//  iOS-Face-Extraction
//
//  Created by Jakub Tlach on 3/1/18.
//  Copyright © 2018 Jakub Tlach. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

	
	@IBOutlet weak var startRecSwitch: UISwitch!
	@IBOutlet weak var faceView: FaceView!
	
	@IBOutlet weak var totalCounter: UILabel!
	@IBOutlet weak var faceCounter: UILabel!
	
	
	// Loads the counters
	var totalNumber = UserDefaults.standard.integer(forKey: "totalNumber")
	
	// Number of the folder
	var faceNumber = UserDefaults.standard.integer(forKey: "faceNumber")
	
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		startRecSwitch.isOn = false
		
		// Update of the Counters
		update()
		
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
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
	
	
	
	
	
	
	
	// When the Switch is ON -> take the pictures of the eye
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
		
		
		
		// Folder
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
	

}

