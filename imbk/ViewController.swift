//
//  ViewController.swift
//  imbk
//
//  Created by Andrew Ferrier on 10/05/2016.
//  Copyright © 2016 Andrew Ferrier. All rights reserved.
//

import UIKit
import Photos
import NMSSH

extension PHFetchResult: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

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

        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
            var counter = 0;

            for asset in assets {
                counter++;
                let asset = asset as! PHAsset

                // This request must be synchronous otherwise the resultHandler ends up back on the main thread.
                let myOptions = PHImageRequestOptions()
                myOptions.synchronous = true

                PHImageManager.defaultManager().requestImageDataForAsset(asset, options: myOptions, resultHandler:
                    {
                        imageData,dataUTI,orientation,info in
                        self.uploadPhoto(imageData!, index: counter, totalNumber: assets.count, creationDate: asset.creationDate!)
                })
            }
        }
    }

    func uploadPhoto(imageData: NSData, index: Int, totalNumber: Int, creationDate: NSDate) {
        dispatch_async(dispatch_get_main_queue()) {
            self.statusLabel.text = "Uploading: " + String(index) + "/" + String(totalNumber)
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

