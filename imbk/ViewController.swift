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
import CryptoSwift

extension PHFetchResult: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

extension String {
    func truncate(length: Int) -> String {
        if self.characters.count > length {
            return self.substringToIndex(self.startIndex.advancedBy(length - 1))
        } else {
            return self
        }
    }
}

enum ConnectionError: ErrorType {
    case NotConnected
    case NotAuthorized
}

// swiftlint:disable:next type_body_length
class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var host: UITextField!
    @IBOutlet weak var port: UITextField!
    @IBOutlet weak var remoteDir: UITextField!
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var backupPhotosButton: UIButton!
    @IBOutlet weak var skipFilesSwitch: UISwitch!
    @IBOutlet weak var deleteFilesSwitch: UISwitch!
    @IBOutlet weak var statusText: UITextView!

    // Limit CRCs to the first megabyte; this should be sufficient to ensure uniqueness.
    let maxCrcLength = 1024 * 1024

    // Limit length of status text box
    let maxStatusLength = 1024 * 100
    let progressInterval = 0.5
    let maxVideoLength = 1024 * 1024 * 100

    override func viewDidLoad() {
        super.viewDidLoad()

        self.host.delegate = self
        self.port.delegate = self
        self.username.delegate = self
        self.password.delegate = self
        self.remoteDir.delegate = self

        self.statusText.text = ""

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

        self.deleteFilesSwitch.setOn(false, animated: false)

        self.statusText.contentInset = UIEdgeInsets(top: 0, left: -self.statusText.textContainer.lineFragmentPadding, bottom: 0, right: -self.statusText.textContainer.lineFragmentPadding)
    }

    func setKeychainValues() {
        let keychain = KeychainSwift()

        keychain.set(self.host.text!, forKey: "host")
        keychain.set(self.port.text!, forKey: "port")
        keychain.set(self.remoteDir.text!, forKey: "remoteDir")
        keychain.set(self.username.text!, forKey: "username")
        keychain.set(self.password.text!, forKey: "password")
        keychain.set(NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: .ShortStyle, timeStyle: .ShortStyle), forKey: "completedDate")
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
        backupPhotosButton.enabled = false
    }

    func unlockScreen() {
        NSLog("Re-enabling screen sleep")
        UIApplication.sharedApplication().idleTimerDisabled = false
        host.enabled = true
        port.enabled = true
        remoteDir.enabled = true
        username.enabled = true
        password.enabled = true
        backupPhotosButton.enabled = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func backupPhotos(sender: UIButton) {
        dismissKeyboard()

        let photoAssets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: nil)
        let videoAssets = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Video, options: nil)

        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
            self.lockScreen()

            var counter = 0

            let sftpSession = self.connectAndAuthenticate()

            if sftpSession != nil {
                var filesToBeKept = Set<String>()

                for asset in photoAssets {
                    counter += 1

                    // swiftlint:disable:next force_cast
                    let asset = asset as! PHAsset

                    // This request must be synchronous otherwise the resultHandler ends up back on the main thread.
                    let myOptions = PHImageRequestOptions()
                    myOptions.synchronous = true

                    PHImageManager.defaultManager().requestImageDataForAsset(asset, options: myOptions, resultHandler: {
                        imageData, dataUTI, orientation, info in
                        // swiftlint:disable:next force_cast
                        let url = (info! as NSDictionary).valueForKey("PHImageFileURLKey") as! NSURL

                        let file = self.uploadFile(sftpSession!, fileData: imageData!, originalURL: url, index: counter, totalNumber: photoAssets.count + videoAssets.count, creationDate: asset.creationDate!)

                        if file != nil {
                            filesToBeKept.insert(file!)
                        }
                    })
                }

                for asset in videoAssets {
                    counter += 1

                    // Allow since this always comes from PHAsset.fetchAssetsWithMediaType
                    // swiftlint:disable:next force_cast
                    let asset = asset as! PHAsset

                    // This request must be synchronous otherwise the resultHandler ends up back on the main thread.
                    let options = PHVideoRequestOptions()
                    options.networkAccessAllowed = true

                    let semaphore = dispatch_semaphore_create(0)

                    PHImageManager.defaultManager().requestAVAssetForVideo(asset, options: options, resultHandler: {
                        videoAsset, audioMix, info in
                        let urlAsset = videoAsset as? AVURLAsset
                        if urlAsset != nil {
                            let url = urlAsset!.URL
                            NSLog("Video asset URL is " + url.description)

                            let videoData = NSData(contentsOfURL: url)!

                            if videoData.length < self.maxVideoLength {
                                let file = self.uploadFile(sftpSession!, fileData: videoData, originalURL: url, index: counter, totalNumber: photoAssets.count + videoAssets.count, creationDate: asset.creationDate!)

                                if file != nil {
                                    filesToBeKept.insert(file!)
                                }
                            } else {
                                self.updateStatus("Cannot upload " + url.absoluteString + " as it is too large.")
                            }
                        }

                        dispatch_semaphore_signal(semaphore)
                    })

                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                }

                self.updateStatus("Uploading complete successfully.")

                if self.deleteFilesSwitch.on {
                    self.deleteRemotePhotos(sftpSession!, filesToBeKept: filesToBeKept)
                }

                self.updateStatus("Disconnecting...")

                sftpSession!.disconnect()

                self.unlockScreen()
                self.setKeychainValues()

                UIApplication.sharedApplication().cancelAllLocalNotifications()
                UIApplication.sharedApplication().applicationIconBadgeNumber = 0
                NSLog("All local notifications cancelled.")

                self.updateStatus("Backup complete.")
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
    func uploadFile(sftpSession: NMSFTP, fileData: NSData, originalURL: NSURL, index: Int, totalNumber: Int, creationDate: NSDate) -> String? {
        let uniqueFilename = getUniqueFilename(creationDate, fileData: fileData)

        let originalFilePathString = originalURL.absoluteString
        NSLog("Original file path is " + originalFilePathString)

        var originalFileExtension = originalURL.pathExtension
        originalFileExtension = (originalFileExtension == nil) ? "" : "." + originalFileExtension!
        NSLog("Original file extension is " + originalFileExtension!)

        let finalFileName = uniqueFilename + originalFileExtension!
        let finalFilePath =  self.remoteDir.text! + "/" + finalFileName
        let tempFilePath = self.remoteDir.text! + "/.tmp" + originalFileExtension!
        NSLog("Final file path is " + finalFilePath)
        NSLog("Temp file path is " + tempFilePath)

        let localFileLength = fileData.length

        if sftpSession.fileExistsAtPath(finalFilePath) &&
            sftpSession.infoForFileAtPath(finalFilePath).fileSize == localFileLength &&
            skipFilesSwitch.on {
            NSLog("WARNING: " + finalFilePath + " already exists, skipping.")
            self.updateStatus("WARNING: " + finalFilePath + " already exists, skipping.", count: index, total: totalNumber)

            return finalFileName
        } else {
            self.updateStatus("Uploading " + finalFileName + " to temporary file...", count: index, total: totalNumber)

            let fileSizeForDisplay = fileSizeDisplay(fileData.length)

            var lastUpdateTime = CFAbsoluteTimeGetCurrent()

            var success = sftpSession.writeContents(fileData, toFileAtPath: tempFilePath,
                                                    progress: { sent in
                                                        let difference = CFAbsoluteTimeGetCurrent() - lastUpdateTime

                                                        if difference > self.progressInterval {
                                                            self.updateStatus("Uploading " + finalFileName + " to temporary file...", fileSize: fileSizeForDisplay, count: index, total: totalNumber, percentage: Float(sent) / Float(localFileLength))

                                                            lastUpdateTime = CFAbsoluteTimeGetCurrent()
                                                        }

                                                        return true
                }
            )
            assert(success)

            self.updateStatus("Moving temporary file to " + finalFilePath + "...", count: index, total: totalNumber)
            if sftpSession.fileExistsAtPath(finalFilePath) {
                sftpSession.removeFileAtPath(finalFilePath)
            }
            success = sftpSession.moveItemAtPath(tempFilePath, toPath: finalFilePath)
            assert(success)

            self.updateStatus("Done.", count: index, total: totalNumber)
            NSLog(finalFilePath + " successfully written.")

            return finalFileName
        }
    }

    func deleteRemotePhotos(sftpSession: NMSFTP, filesToBeKept: Set<String>) {
        NSLog("Set of files to be kept: " + filesToBeKept.joinWithSeparator(", "))

        let remoteDirectoryListing = sftpSession.contentsOfDirectoryAtPath(self.remoteDir.text!)
        var filesAlreadyRemote = Set<String>()
        // swiftlint:disable:next force_cast
        for remoteFile in remoteDirectoryListing as! [NMSFTPFile] {
            if !remoteFile.isDirectory {
                filesAlreadyRemote.insert(remoteFile.filename)
            }
        }

        NSLog("Remote directory listing: " + filesAlreadyRemote.joinWithSeparator(", "))

        let filesToRemove = filesAlreadyRemote.subtract(filesToBeKept)

        NSLog("Files to remove: " + filesToRemove.joinWithSeparator(", "))

        for fileToRemove in filesToRemove {
            let fullFilePath = self.remoteDir.text! + "/" + fileToRemove
            self.updateStatus("Removing remote file " + fullFilePath)
            sftpSession.removeFileAtPath(fullFilePath)
        }
    }

    func updateStatus(status: String, count: Int = 0, total: Int = 0, percentage: Float = -1, fileSize: String = "Unknown size") {
        NSLog("Status change: " + status)

        dispatch_async(dispatch_get_main_queue()) {
            var newStatus = ""

            if total > 0 {
                self.progressView.progress = Float(count) / Float(total)
                self.progressView.hidden = false
                newStatus = status + " \n(" + String(count) + "/" + String(total) + " files)"
                if percentage > 0 {
                    newStatus = newStatus + " \n(" + String(format: "%.0f", percentage * 100) + "% of file - " + fileSize + ")"
                }
            } else {
                self.progressView.hidden = true
                newStatus = status
            }

            newStatus = newStatus + "\n" + self.statusText.text
            newStatus.truncate(self.maxStatusLength)

            self.statusText.text = newStatus
        }
    }

    func getUniqueFilename(date: NSDate, fileData: NSData) -> String {
        var fileDataForCRC: NSData

        if fileData.length > maxCrcLength {
            fileDataForCRC = fileData.subdataWithRange(NSRange(location: 0, length: maxCrcLength))
        } else {
            fileDataForCRC = fileData
        }

        let dateFormatter = NSDateFormatter()
        let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let formattedDate = dateFormatter.stringFromDate(date)

        let hash = fileDataForCRC.crc32()

        return formattedDate + "_" + hash!.toHexString()
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

    // Adapted from http://stackoverflow.com/a/40279734/27641
    func fileSizeDisplay(length: Int) -> String {
        let display = ["bytes", "KiB", "MiB", "GiB", "TiB"]
        var value: Double = Double(length)
        var type = 0
        while value > 1024 {
            value /= 1024
            type = type + 1

        }

        return "\(String(format:"%.2g", value)) \(display[type])"
    }
}
