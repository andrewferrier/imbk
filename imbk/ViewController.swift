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
        let assets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)

        assets.enumerateObjectsUsingBlock { (obj, idx, bool) -> Void in
            let asset = obj as! PHAsset
            PHImageManager.defaultManager().requestImageDataForAsset(asset, options: nil)
            {
                imageData,dataUTI,orientation,info in self.uploadPhoto(imageData!, creationDate: asset.creationDate!)
            }
        }
    }

    func uploadPhoto(imageData: NSData, creationDate: NSDate) {
        let host = "XXX"
        let username = "XXX"
        let password = "XXX"
        let session = NMSSHSession(host: host, andUsername: username)
        session.connect()
        if session.connected == true {
            session.authenticateByPassword(password)
            if session.authorized == true {
                NSLog("Authentication succeeded")
            }

            let sftpSession = NMSFTP.connectWithSession(session)

            let dateFormatter = NSDateFormatter()
            let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
            dateFormatter.locale = enUSPosixLocale
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let date = dateFormatter.stringFromDate(creationDate)

            sftpSession.writeContents(imageData, toFileAtPath: "/home/ferriera/" + date + ".jpg")
        }
        session.disconnect()
    }
}

