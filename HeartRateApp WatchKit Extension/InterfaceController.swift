//
//  InterfaceController.swift
//  HeartRateApp WatchKit Extension
//
//  Created by Brian Remer on 5/25/20.
//  Copyright © 2020 Brian Remer. All rights reserved.
//
//

import WatchKit
import HealthKit
import Foundation
import WatchConnectivity
import CoreMotion

class InterfaceController: WKInterfaceController {

    //HealthKit Variables
    private var healthStore = HKHealthStore()
    let heartRateQuantity = HKUnit(from: "count/min")
    private var value = 0
    var queryArray = [HKAnchoredObjectQuery]()
    var dataArray = [String]()
    
    //CoreMotion variables
    private var coreMotion = CMMotionManager()
    let queue = OperationQueue()
    @IBOutlet var xaccel: WKInterfaceLabel!
    @IBOutlet var yaccel: WKInterfaceLabel!
    @IBOutlet var zaccel: WKInterfaceLabel!
    @IBOutlet var xGyroLabel: WKInterfaceLabel!
    @IBOutlet var yGyroLabel: WKInterfaceLabel!
    @IBOutlet var zGyroLabel: WKInterfaceLabel!
    
    
    //data keeping track of the x, y, and z for accelerometer
    private var xAccelData = 0.0
    private var yAccelData = 0.0
    private var zAccelData = 0.0
    
    //data keeping track of the x, y, and z for gyroscope
    private var xGyro = 0.0
    private var yGyro = 0.0
    private var zGyro = 0.0
    
    //session variables
    var session = WCSession.default//**3
    
    //button variables
    var buttonCheck = true
    var getHeartRate = false
    var exercise = ""
    
    //workout session variable
    lazy var workoutSession = startWorkout()
    lazy var workoutSessionNewOS = startWorkoutWithHealthStore(healthStore)
    
    @IBOutlet var displayTest: WKInterfaceLabel!
    @IBOutlet var startButton: WKInterfaceButton!
    @IBOutlet var bpm: WKInterfaceLabel!
    
    @IBOutlet var bpmActual: WKInterfaceLabel!
    
    
    //function for authorizing the use of the healthkit extension for the watch
    func authorizeHealthKit() {
        let healthKitTypes: Set = [
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
        
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { (success, error) in
            
            if success {
            } else {
                print("error authorizating HealthStore. You're propably on iPad")
            }
        }
    }
 

    
    
    
    
    //function that operates based on the Start/Stop button
    @IBAction func buttonPress() {
        let stop = "Stop"
        let start = "Start"
        
        //runs if the Start button is pressed
        if(buttonCheck){
            startButton.setTitle(stop)
            startButton.setBackgroundColor(UIColor(red: 255/255, green: 0, blue:0, alpha:1.0))
            buttonCheck = false
            
            getHeartRate = true
            
            //starting the workoutsession for the watch to run in the background
            //healthStore.start(workoutSessionNewOS!)
            if #available(watchOSApplicationExtension 5.0, *) {
                workoutSessionNewOS?.startActivity(with: Date())
            } else {
                healthStore.start(workoutSessionNewOS!)
            }
            //starting the query for the heart rate data
            queryArray.append(getCurrentHeartRateData())
            
            //starting the other sensors
            startAccelerometer()
            altGyroscopeStarter()
        }
        //runs when the Stop button is pressed
        else{
            startButton.setTitle(start)
            startButton.setBackgroundColor(UIColor(red: 0, green: 255/255, blue:0, alpha:1.0))
            buttonCheck = true
            getHeartRate = false
            
            //goes through each active query and stops them
            for i in queryArray{
                healthStore.stop(i)
            }
            
            //This function stops the mock heart rate data from being made.
            //Only used when testing on the Xcode Simulator
            //stopMockHeartData()
            
            //creates the dictionary with the data, and then sends the dictionary from the watch to the iPhone
            let data: [String: Any] = ["watch": dataArray]
            session.sendMessage(data, replyHandler: nil, errorHandler: nil)
            
            //removes all data from the array once it has been sent
            dataArray.removeAll()
            
            //stops the other sensors
            stopAccelerometer()
            stopDeviceMotionUpdates()
            
            //ends the workout session with the phone
            if #available(watchOSApplicationExtension 5.0, *) {
                workoutSessionNewOS?.end()
            } else {
                healthStore.end(workoutSessionNewOS!)
            }
        }
    }
    
    //function that starts collecting accelerometer data
    func startAccelerometer(){
        if coreMotion.isAccelerometerAvailable{
            coreMotion.accelerometerUpdateInterval = 0.1
            coreMotion.startAccelerometerUpdates(to: .main) {
                [weak self] (data, error) in
                guard let data = data, error == nil else {
                    return
                }
                
                self!.xaccel.setText(String(format: "%.2f", data.acceleration.x))
                self!.yaccel.setText(String(format: "%.2f", data.acceleration.y))
                self!.zaccel.setText(String(format: "%.2f", data.acceleration.z))
                
                self!.xAccelData = data.acceleration.x
                self!.yAccelData = data.acceleration.y
                self!.zAccelData = data.acceleration.z
            }
        }
    }
    
    //function to stop accelerometer updates
    func stopAccelerometer(){
        coreMotion.stopAccelerometerUpdates()
    }
    
    //starts the Gyroscope using the Device Motion Updates
    func altGyroscopeStarter(){
        coreMotion.deviceMotionUpdateInterval = 0.1
        coreMotion.startDeviceMotionUpdates(to: .main){
            (deviceMotion: CMDeviceMotion?, error: Error?) in
            if error != nil {
                print("Encountered error: \(error!)")
            }
            
            if deviceMotion != nil {
                self.xGyro = deviceMotion!.rotationRate.x
                self.yGyro = deviceMotion!.rotationRate.y
                self.zGyro = (deviceMotion?.rotationRate.z)!
                
                self.xGyroLabel.setText(String(format: "%.2f", deviceMotion!.rotationRate.x))
                self.yGyroLabel.setText(String(format: "%.2f", deviceMotion!.rotationRate.y))
                self.zGyroLabel.setText(String(format: "%.2f", deviceMotion!.rotationRate.z))
                
                self.dataArray.append(self.exercise + "," + "," + String(self.xAccelData) + "," + String(self.yAccelData) + "," + String(self.zAccelData) + "," + String(self.xGyro) + "," + String(self.yGyro) + "," + String(self.zGyro) + "\n")
                
            }
            
            
        }
        
    }
    
    //stops the Gyroscope
    func stopDeviceMotionUpdates(){
        coreMotion.stopDeviceMotionUpdates()
    }
    
    //function that builds a workout session so the watch collects data in the background
    //since this only makes sure the app is continuing to work in the background, the activity and location
    //for the HKWorkoutSession does not matter
    func startWorkout() -> HKWorkoutSession{
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        
        let workoutSession = try? HKWorkoutSession(configuration: configuration)
        
        return workoutSession!
        
    }
    
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        //This sets the selected exercise for the data
        if let passedExercise: String = context as? String {
            exercise = passedExercise
        }
        if exercise != "" {
            bpm.setText(exercise)
        }
        
        //sets up the connectivity section
        session.delegate = self
        session.activate()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    
    
    
    
    
    //These commented out functions are used to create random heart rate samples for the watch
    //They are only necessary to test the collection of heart rate samples on the Xcode simulator,
    //and they become uneccessary when using a physical device
    /*
    private var timer: Timer?
    
    @objc private func saveMockHeartData() {
        
        // 1. Create a heart rate BPM Sample
        let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"),
                                           doubleValue: Double(arc4random_uniform(80) + 100))
        let heartSample = HKQuantitySample(type: heartRateType,
                                           quantity: heartRateQuantity, start: NSDate() as Date, end: NSDate() as Date)
        
        // 2. Save the sample in the store
        healthStore.save(heartSample, withCompletion: { (success, error) -> Void in
            if let error = error {
                print("Error saving heart sample: \(error.localizedDescription)")
            }
        })
    }
     */
    
    //functions that create a random heart rate sample
    /*
    @objc func writeWater() {
        guard let waterType = HKSampleType.quantityType(forIdentifier: .heartRate) else {
            print("Sample type not available")
            return
        }
        
        let waterQuantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: Double(arc4random_uniform(80) + 100))
        let today = Date()
        let waterQuantitySample = HKQuantitySample(type: waterType, quantity: waterQuantity, start: today, end: today)
        
        HKHealthStore().save(waterQuantitySample) { (success, error) in
            //print("HK write finished - success: \(success); error: \(error)")
            //self.readWater()
        }
    }
    
    private func startMockHeartData() {
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                                       target: self,
                                                       selector: #selector(writeWater),
                                                       userInfo: nil,
                                                       repeats: true)
    }
    private func stopMockHeartData() {
        self.timer?.invalidate()
    }
 */
    
    
    
    //Heart Rate Data query variables
    var currentHeartRateSample : [HKSample]?
    
    var currentHeartLastSample : HKSample?
    
    var currentHeartRateBPM = Double()
    
    //This function gets continuous heart rate samples from the watch once it is called
    func getCurrentHeartRateData() -> HKAnchoredObjectQuery{
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let startDate : Date = calendar.date(from: components)!
        let endDate : Date = calendar.date(byAdding: Calendar.Component.day, value: 1, to: startDate as Date)!
        
        let sampleType : HKSampleType =  HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let predicate : NSPredicate =  HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let anchor: HKQueryAnchor = HKQueryAnchor(fromValue: 0)
        
        let anchoredQuery = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, anchor, error ) in
            
            if samples != nil {
                
                self.collectCurrentHeartRateSample(currentSampleTyple: samples!, deleted: deletedObjects!)
                
            }
            
        }
        
        anchoredQuery.updateHandler = { (query, samples, deletedObjects, anchor, error) -> Void in
            self.collectCurrentHeartRateSample(currentSampleTyple: samples!, deleted: deletedObjects!)
        }
        
        
        self.healthStore.execute(anchoredQuery)
        return anchoredQuery
        
        
    }
    
    //gets the specific heart rate value from the current sample
    func collectCurrentHeartRateSample(currentSampleTyple : [HKSample]?, deleted : [HKDeletedObject]?){
        
        self.currentHeartRateSample = currentSampleTyple
        
        //Get Last Sample of Heart Rate
        self.currentHeartLastSample = self.currentHeartRateSample?.last
        
        if self.currentHeartLastSample != nil {
            let lastHeartRateSample = self.currentHeartLastSample as! HKQuantitySample
            
            self.currentHeartRateBPM = lastHeartRateSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            
            bpmActual.setText(String(currentHeartRateBPM))
            dataArray.append(exercise + "," + String(currentHeartRateBPM) + "," + String(xAccelData) + "," + String(yAccelData) + "," + String(zAccelData) + "," + String(xGyro) + "," + String(yGyro) + "," + String(zGyro) + "\n")
            
        }
        
    }
    
    
    //function that starts a workoutsession
    func startWorkoutWithHealthStore(_ healthStore: HKHealthStore
                                    ) -> HKWorkoutSession? {
      let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
      
      let session1 : HKWorkoutSession
      do {
        if #available(watchOSApplicationExtension 5.0, *) {
            session1 = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        } else {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .running
            configuration.locationType = .outdoor
            session1 = try! HKWorkoutSession(configuration: configuration)
            // Fallback on earlier versions
        }
      } catch let error{
        // let the user know about the error
        return nil
      }
      
        if #available(watchOSApplicationExtension 5.0, *) {
            session1.startActivity(with: Date())
        } else {
            // Fallback on earlier versions
        }
      //self.session = session
      //self.healthStore = healthStore
      return session1
    }
    
    
    
   
    
    
    
    
    
    

    

}

extension InterfaceController: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        //print("received data: \(message)")
        //if let value = message["iPhone"] as? String {//**7.1
            //self.label.setText(value)
        //}
    }
}
