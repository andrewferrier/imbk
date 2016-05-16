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
    @IBOutlet weak var host: UITextField!
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.statusLabel.text = ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func backupPhotos(sender: UIButton) {
        let assets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            assets.enumerateObjectsUsingBlock { (obj, idx, bool) -> Void in
                let asset = obj as! PHAsset
                PHImageManager.defaultManager().requestImageDataForAsset(asset, options: nil)
                    {
                        imageData,dataUTI,orientation,info in self.uploadPhoto(imageData!, index: idx, totalNumber: assets.count, creationDate: asset.creationDate!)
                }
            }
        }
    }

    func uploadPhoto(imageData: NSData, index: Int, totalNumber: Int, creationDate: NSDate) {
        dispatch_async(dispatch_get_main_queue()) {
            self.statusLabel.text = "Uploading: " + String(index + 1) + "/" + String(totalNumber)
        }
        
        let host = self.host.text
        let username = self.username.text
        let password = self.password.text
        let session = NMSSHSession(host: host, andUsername: username)
        session.connect()
        if session.connected == true {
            session.authenticateByPassword(password)

            let sftpSession = NMSFTP.connectWithSession(session)

            let dateFormatter = NSDateFormatter()
            let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
            dateFormatter.locale = enUSPosixLocale
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let date = dateFormatter.stringFromDate(creationDate)
            let filePath =  "/home/ferriera/" + date + ".jpg"

            sftpSession.writeContents(imageData, toFileAtPath: filePath)
            NSLog(filePath + " successfully written.")
        }
        session.disconnect()
    }
}

