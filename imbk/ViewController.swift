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
import KeychainSwift

extension PHFetchResult: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

enum ConnectionError: ErrorType {
    case NotConnected
    case NotAuthorized
}

class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var host: UITextField!
    @IBOutlet weak var port: UITextField!
    @IBOutlet weak var remoteDir: UITextField!
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.host.delegate = self
        self.port.delegate = self
        self.username.delegate = self
        self.password.delegate = self
        self.remoteDir.delegate = self

        self.statusLabel.text = ""

        let keychain = KeychainSwift()

        if let savedValue = keychain.get("host") {
            self.host.text = savedValue
        }

        if let savedValue = keychain.get("port") {
            self.port.text = savedValue
        } else {
            self.port.text = "22"
        }

        if let savedValue = keychain.get("remoteDir") {
            self.remoteDir.text = savedValue
        }

        if let savedValue = keychain.get("username") {
            self.username.text = savedValue
        }

        if let savedValue = keychain.get("password") {
            self.password.text = savedValue
        }
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

                    let keychain = KeychainSwift()

                    keychain.set(self.host.text!, forKey: "host")
                    keychain.set(self.port.text!, forKey: "port")
                    keychain.set(self.remoteDir.text!, forKey: "remoteDir")
                    keychain.set(self.username.text!, forKey: "username")
                    keychain.set(self.password.text!, forKey: "password")
                }
            }
        }
    }

    func uploadPhoto(imageData: NSData, index: Int, totalNumber: Int, creationDate: NSDate) throws {
        self.updateStatus("Uploading: " + String(index) + "/" + String(totalNumber))

        let host = self.host.text
        let port = self.port.text
        let username = self.username.text
        let password = self.password.text
        let session = NMSSHSession(host: host, port: Int(port!)!, andUsername: username)

        session.connect()
        guard session.connected else {
            throw ConnectionError.NotConnected
        }

        session.authenticateByPassword(password)
        guard session.authorized else {
            throw ConnectionError.NotAuthorized
        }

        let sftpSession = NMSFTP.connectWithSession(session)
        let date = formatDate(creationDate)
        let filePath =  self.remoteDir.text! + "/" + date + ".jpg"
        
        sftpSession.writeContents(imageData, toFileAtPath: filePath)
        NSLog(filePath + " successfully written.")
        
        session.disconnect()
    }

    func updateStatus(status: String) {
        NSLog("Status change: " + status)
        dispatch_async(dispatch_get_main_queue()) {
            self.statusLabel.text = status;
            self.statusLabel.sizeToFit()
        }
    }

    func formatDate(date: NSDate) -> String {
        let dateFormatter = NSDateFormatter()
        let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter.stringFromDate(date)
    }

    func textFieldShouldReturn(userText: UITextField) -> Bool {
        userText.resignFirstResponder()
        return true;
    }
}

