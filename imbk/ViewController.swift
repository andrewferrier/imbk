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
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var backupPhotosButton: UIButton!
    @IBOutlet weak var skipFilesSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.host.delegate = self
        self.port.delegate = self
        self.username.delegate = self
        self.password.delegate = self
        self.remoteDir.delegate = self

        self.updateStatus("")

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

        self.checkAuthorization()

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)

        if let completedDate = keychain.get("completedDate") {
            self.updateStatus("Backup last completed on " +  completedDate)
        }
    }

    func checkAuthorization() {
        let currentStatus = PHPhotoLibrary.authorizationStatus()

        switch currentStatus {
        case .Authorized:
            NSLog("Photos: Already authorized")
            break
        case .Restricted, .Denied:
            NSLog("Photos: Already restricted or denied")
            disableBackupPhotos()
            break
        case .NotDetermined:
            NSLog("Photos: now need to determine")
            PHPhotoLibrary.requestAuthorization() { (status) -> Void in
                switch status {
                case .Authorized:
                    NSLog("Photos: Now authorized")
                    break
                case .Restricted, .Denied:
                    NSLog("Photos: Now restricted or denied")
                    self.disableBackupPhotos()
                    break
                default:
                    break
                }
            }
            break
        }
    }

    func disableBackupPhotos() {
        self.updateStatus("Cannot backup media - permission hasn't been granted for imbk")
        self.backupPhotosButton.enabled = false
    }

    func dismissKeyboard() {
        view.endEditing(true)
    }

    func lockScreen() {
        NSLog("Disabling screen sleep")
        UIApplication.sharedApplication().idleTimerDisabled = true
        host.enabled = false
        port.enabled = false
        remoteDir.enabled = false
        username.enabled = false
        password.enabled = false
    }

    func unlockScreen() {
        NSLog("Re-enabling screen sleep")
        UIApplication.sharedApplication().idleTimerDisabled = false
        host.enabled = true
        port.enabled = true
        remoteDir.enabled = true
        username.enabled = true
        password.enabled = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func backupPhotos(sender: UIButton) {
        dismissKeyboard()

        let assets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)

        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
            self.lockScreen()

            var counter = 0

            let sftpSession = self.connectAndAuthenticate()

            if sftpSession != nil {
                for asset in assets {
                    counter += 1

                    // swiftlint:disable:next force_cast
                    let asset = asset as! PHAsset

                    // This request must be synchronous otherwise the resultHandler ends up back on the main thread.
                    let myOptions = PHImageRequestOptions()
                    myOptions.synchronous = true

                    PHImageManager.defaultManager().requestImageDataForAsset(asset, options: myOptions, resultHandler: {
                        imageData, dataUTI, orientation, info in
                        self.uploadPhoto(sftpSession!, imageData: imageData!, info: info!, index: counter, totalNumber: assets.count, creationDate: asset.creationDate!)
                    })
                }

                self.updateStatus("Uploading complete successfully.")

                sftpSession!.disconnect()

                self.unlockScreen()

                let keychain = KeychainSwift()

                keychain.set(self.host.text!, forKey: "host")
                keychain.set(self.port.text!, forKey: "port")
                keychain.set(self.remoteDir.text!, forKey: "remoteDir")
                keychain.set(self.username.text!, forKey: "username")
                keychain.set(self.password.text!, forKey: "password")
                keychain.set(NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: .ShortStyle, timeStyle: .ShortStyle), forKey: "completedDate")

                UIApplication.sharedApplication().cancelAllLocalNotifications()
                UIApplication.sharedApplication().applicationIconBadgeNumber = 0
                NSLog("All local notifications cancelled.")
            }
        }
    }

    func connectAndAuthenticate() -> NMSFTP? {
        let host = self.host.text
        let port = self.port.text
        let username = self.username.text
        let password = self.password.text

        let session = NMSSHSession(host: host, port: Int(port!)!, andUsername: username)

        self.updateStatus("Connecting... ")
        session.connect()
        guard session.connected else {
            self.updateStatus("Could not connect - probably the hostname is wrong.")
            return nil
        }

        self.updateStatus("Authenticating... ")
        session.authenticateByPassword(password)
        guard session.authorized else {
            self.updateStatus("Could not authorize - probably the username or password is wrong.")
            return nil
        }

        let sftpSession = NMSFTP.connectWithSession(session)

        return sftpSession
    }

    // swiftlint:disable:next function_parameter_count
    func uploadPhoto(sftpSession: NMSFTP, imageData: NSData, info: NSDictionary, index: Int, totalNumber: Int, creationDate: NSDate) {
        let date = formatDate(creationDate)

        // swiftlint:disable:next force_cast
        let originalFilePathURL = info.valueForKey("PHImageFileURLKey") as! NSURL
        let originalFilePathString = originalFilePathURL.absoluteString
        NSLog("Original file path is " + originalFilePathString)

        var originalFileExtension = originalFilePathURL.pathExtension

        if(originalFileExtension == nil) {
            originalFileExtension = ""
        } else {
            originalFileExtension = "." + originalFileExtension!
        }

        let finalFilePath =  self.remoteDir.text! + "/" + date + originalFileExtension!
        let tempFilePath = self.remoteDir.text! + "/.tmp" + originalFileExtension!

        let localFileLength = imageData.length
        let remoteFileLength = sftpSession.infoForFileAtPath(finalFilePath).fileSize

        if sftpSession.fileExistsAtPath(finalFilePath) &&
            remoteFileLength == localFileLength &&
            skipFilesSwitch.on {
            NSLog("WARNING: " + finalFilePath + " already exists, skipping.")
            self.updateStatus("WARNING: " + finalFilePath + " already exists, skipping.", count: index, total: totalNumber)
        } else {
            self.updateStatus("Uploading to temporary file...", count: index, total: totalNumber)
            var success = sftpSession.writeContents(imageData, toFileAtPath: tempFilePath,
                                      progress: { sent in
                                        self.updateStatus("Uploading to temporary file...", count: index, total: totalNumber, percentage: Float(sent) / Float(localFileLength))
                                        return true
                }
            )
            assert(success)

            self.updateStatus("Moving file to final location...", count: index, total: totalNumber)
            if sftpSession.fileExistsAtPath(finalFilePath) {
                sftpSession.removeFileAtPath(finalFilePath)
            }
            success = sftpSession.moveItemAtPath(tempFilePath, toPath: finalFilePath)
            assert(success)

            self.updateStatus("Done.", count: index, total: totalNumber)
            NSLog(finalFilePath + " successfully written.")
        }
    }

    func updateStatus(status: String, count: Int = 0, total: Int = 0, percentage: Float = -1) {
        NSLog("Status change: " + status)

        dispatch_async(dispatch_get_main_queue()) {
            var newStatus = ""

            if total > 0 {
                self.progressView.progress = Float(count) / Float(total)
                self.progressView.hidden = false
                newStatus = status + " \n(" + String(count) + "/" + String(total) + " files)"
                if percentage > 0 {
                    newStatus = newStatus + " \n(" + String(format: "%.0f", percentage * 100) + "% of file)"
                }
            } else {
                self.progressView.hidden = true
                newStatus = status
            }

            self.statusLabel.text = newStatus
        }
    }

    func formatDate(date: NSDate) -> String {
        let dateFormatter = NSDateFormatter()
        let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter.stringFromDate(date)
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let nextTage = textField.tag + 1

        let nextResponder = textField.superview?.viewWithTag(nextTage) as UIResponder!

        if nextResponder != nil {
            nextResponder?.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }

        return false // We do not want UITextField to insert line-breaks.
    }
}
