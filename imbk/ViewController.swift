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

enum ConnectionError: ErrorType {
    case NotConnected
    case NotAuthorized
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
            var failure = false;
            
            for asset in assets {
                guard failure == false else {
                    break;
                }
                
                counter += 1;
                let asset = asset as! PHAsset
                
                // This request must be synchronous otherwise the resultHandler ends up back on the main thread.
                let myOptions = PHImageRequestOptions()
                myOptions.synchronous = true
                
                PHImageManager.defaultManager().requestImageDataForAsset(asset, options: myOptions, resultHandler:
                    {
                        imageData,dataUTI,orientation,info in
                        do {
                            try self.uploadPhoto(imageData!, index: counter, totalNumber: assets.count, creationDate: asset.creationDate!)
                        } catch ConnectionError.NotAuthorized {
                            self.updateStatus("Could not authorize - probably the username or password is wrong.");
                            failure = true;
                        } catch ConnectionError.NotConnected {
                            self.updateStatus("Could not connect - probably the hostname is wrong.")
                            failure = true;
                        } catch {
                            self.updateStatus("Unknown error");
                            failure = true;
                        }
                })
            }
            
            if (!failure) {
                dispatch_async(dispatch_get_main_queue()) {
                    self.statusLabel.text = "Uploading complete."
                }
            }
        }
    }
    
    func uploadPhoto(imageData: NSData, index: Int, totalNumber: Int, creationDate: NSDate) throws {
        self.updateStatus("Uploading: " + String(index) + "/" + String(totalNumber))
        
        let host = self.host.text
        let username = self.username.text
        let password = self.password.text
        let session = NMSSHSession(host: host, andUsername: username)
        
        session.connect()
        guard session.connected else {
            throw ConnectionError.NotConnected
        }
        
        session.authenticateByPassword(password)
        guard session.authorized else {
            throw ConnectionError.NotAuthorized
        }
        
        let sftpSession = NMSFTP.connectWithSession(session)
        
        let dateFormatter = NSDateFormatter()
        let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let date = dateFormatter.stringFromDate(creationDate)
        let filePath =  "/home/ferriera/" + date + ".jpg"
        
        sftpSession.writeContents(imageData, toFileAtPath: filePath)
        NSLog(filePath + " successfully written.")
        
        session.disconnect()
    }
    
    func updateStatus(status: String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.statusLabel.text = status;
        }
    }
}

