//
//  ViewController.swift
//  imbk
//
//  Created by Andrew Ferrier on 10/05/2016.
//  Copyright © 2016 Andrew Ferrier. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func backupPhotos(sender: UIButton) {
        // TODO: Exclude videos
        
        var assets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)
        
        assets.enumerateObjectsUsingBlock { (obj, idx, bool) -> Void in
            PHImageManager.defaultManager().requestImageDataForAsset(obj as! PHAsset, options: nil)
            {
                imageData,dataUTI,orientation,info in self.uploadPhoto(imageData!)
            }
        }
    }
    
    func uploadPhoto(x: AnyObject) {
        print(x)
    }
}

