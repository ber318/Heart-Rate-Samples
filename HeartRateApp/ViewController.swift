//
//  ViewController.swift
//  HeartRateApp
//
//  Created by Brian Remer on 5/25/20.
//  Copyright © 2020 Brian Remer. All rights reserved.
//
//

import UIKit
import HealthKit
import WatchConnectivity
import MessageUI

class ViewController: UIViewController, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var label: UILabel!
    var session: WCSession?
    private var healthStore = HKHealthStore()
    private var data = [String]()
    private var csvString = NSMutableString()
    private var gender = "Male"
    private var age = 0
    @IBOutlet weak var MF: UISegmentedControl!
    @IBOutlet weak var Age: UISlider!
    @IBOutlet weak var AgeV: UILabel!
    
    //function that tracks gender option
    @IBAction func GChanged(_ sender: Any) {
        switch MF.selectedSegmentIndex{
        case 0:
            gender = "Male"
        case 1:
            gender = "Female"
        default:
            break
        }
    }
    
    //function that tracks age slider
    @IBAction func AgeVChange(_ sender: Any) {
        AgeV.text = "\((Int)(Age.value))"
        age = (Int)(Age.value)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //starts the session to communicate with the watch
        self.configureWatchKitSession()
    }

    //function that sets up communication between the iPhone and its paired Apple Watch
    func configureWatchKitSession() {
        
        if WCSession.isSupported() {//4.1
            session = WCSession.default//4.2
            session?.delegate = self//4.3
            session?.activate()//4.4
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //function that requests authorization from the user to access Healthkit
    func authorizeHealthKit() {
        let healthKitTypes: Set = [
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
        
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { _, _ in }
    }
    
    //Tied to the button that authorizes healthkit
    @IBAction func authorization(_ sender: Any) {
        authorizeHealthKit()
    }
    
    
    
    //function that converts the data from the array to a string for the csv file
    func convertDataToString(){
        //sets the csvString to nothing before rebuilding it
        csvString = ""
        
        //appends the heading and data line by line
        csvString.append("Age, Gender\n" + String(age) + "," + String(gender) + "\n")
        csvString.append("Exercise, Heart Rate, X Acceleration, Y Acceleration, Z Acceleration, X Rotation Rate, Y Rotation Rate, Z Rotation Rate\n")
        for line in data{
            csvString.append(line)
        }
    }
    
    //function that sets up the email to send out the csv file
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        convertDataToString()
        let csvEmail = csvString.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)

        let emailController = MFMailComposeViewController()
        emailController.mailComposeDelegate = self
        emailController.setSubject("CSV File")
        emailController.setMessageBody("", isHTML: false)
        
        // Attaching the .CSV file to the email.
        emailController.addAttachmentData(csvEmail!, mimeType: "text/csv", fileName: "Sample.csv")
        
        return emailController
    }
    
    //function that presents the email form to the user
    func sendEmail(){
        let emailViewController = configuredMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.present(emailViewController, animated: true, completion: nil)
        }
    }
    
    //function that closes the email form once the email has either been sent or deleted
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }


}

// WCSession delegate functions
//functions to make the watch session work
extension ViewController: WCSessionDelegate {
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    //function that receives the heart rate data and labels from the watch and calls the email function
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("received message: \(message)")
        DispatchQueue.main.async { //6
            if let value = message["watch"] as? String {
                self.label.text = value
            }
            if let value1 = message["watch"] as? [String] {
                self.data = value1
                self.label.text = "Success"
                self.sendEmail()
            }
        }
    }
}

