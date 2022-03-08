//Functionality
//      App runs in background
// UI
//      Light & face status tracking/notification (only need ui)
//      Sound selection screen
//      Home screen
//      Camera screen
//      Create animation for camera screen (low priority)
// Fine tune values

import UIKit
import SceneKit
import ARKit
import AVFoundation
class ViewController: UIViewController, ARSCNViewDelegate {
    
    //declaring view & variables
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var startStopButton: UIButton!
    
    //blink detection variables
    var timestamp = NSDate().timeIntervalSince1970
    var queue: [Double] = []
    var analysis = ""
    var blink = false
    var acct: Float = 0.0
    
    //light status variables
    var light = true
    var onCooldown = false
    var player: AVAudioPlayer?
    
    //timer variables
    var timer = Timer()
    var count = 0
    var timerCounting = false
    
    //constants
    let threshold: Float = 10
    
    // MARK: Debuggers
    @IBOutlet weak var testLabel: UILabel!
    
    @IBAction func resetButton(_ sender: Any) {
        count = 0
        print("Reset button pressed")
        playSound()
    }
    
    @IBAction func awakeButton(_ sender: Any) {
        print("Awake button pressed")
    }
    
    @IBAction func sleepyButton(_ sender: Any) {
        print("Sleepy button presse")
    }
    
    @IBAction func startStopTapped(_ sender: Any) {
        if(timerCounting)
                {
                    timerCounting = false
                    timer.invalidate()
                    startStopButton.setTitle("START", for: .normal)
                    startStopButton.setTitleColor(UIColor.green, for: .normal)
                }
                else
                {
                    timerCounting = true
                    startStopButton.setTitle("STOP", for: .normal)
                    startStopButton.setTitleColor(UIColor.red, for: .normal)
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                        self.updateTimer()
                    })
                }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking is not supported on this device.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    //Creates wireframe
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        return node
    }
    
    //Updates wireframe
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            expression(anchor: faceAnchor)
            
            DispatchQueue.main.async {
                self.faceLabel.text = self.analysis
            }
        }
    }
    
    // MARK: - Checking For Blinking
    func expression(anchor: ARFaceAnchor) {
        print(checkFaceStatus(anchor: anchor))
        //cause mirrored or smthn
        let blinkRight = anchor.blendShapes[.eyeBlinkLeft]
        let blinkLeft = anchor.blendShapes[.eyeBlinkRight]
        let Lval = Double(truncating: blinkLeft ?? 0.0)
        let Rval = Double(truncating: blinkRight ?? 0.0)
        self.analysis = "Left blink = \(round(Lval*10)/10.0) & Right blink = \(round(Rval*10)/10.0)\nAcct = \(acct)\nArray = \(queue)"
        
        //blink check
        if (((blinkLeft?.decimalValue ?? 0.0 > 0.75) && (blinkRight?.decimalValue ?? 0.0 > 0.75)) && !blink){
            blink = true
            
            let newtimestamp = NSDate().timeIntervalSince1970
            let timestampDifference = abs(newtimestamp - timestamp)
            acct += Float(timestampDifference)
            timestamp = newtimestamp
            queue.append(timestampDifference)
            
            self.analysis += "\(queue[0])"
            
            //dump(queue)
            print("Acct\(acct)")
            
            //add wait maybe
            if (queue.count > 30){
                queue.remove(at: 0)
                if (acct > threshold){
                    acct = 0.0
                    statistics()
                }
            }
            
        } else if (blinkLeft?.decimalValue ?? 0.0 < 0.75) && (blinkRight?.decimalValue ?? 0.0 < 0.75) {
            blink = false
        }
        
    }
    
    func statistics () {
        let x = 60 * 30 / queue.avg();
        print(queue.avg())
        if(x < 10.2){
            //sleepy (maybe have a temperary popup for now)
            print("You are sleepy")
            playSound()
        }
        if(x > 15){
            //they need to see a doctor
            print("Seek a doctor")
        }
    }
    
    func checkFaceStatus (anchor: ARFaceAnchor) -> String {
        var status = ""
        // move the light estimation to another
        let frame = sceneView.session.currentFrame
        let lightEstimate = Int (frame?.lightEstimate?.ambientIntensity ?? 0)
        print("Lightestimate:\(lightEstimate)")
        
        if (lightEstimate < 50) {
            //print("Lighting is too dark")
            light = false
        } else {
            light = true
        }
        
        if (!light && !onCooldown){
            onCooldown = true
            let seconds = 2.5
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                if (!self.light){
                    print("It's too dark")
                    self.playSound()
                }
                self.onCooldown = false
            }
        }
        
        status = anchor.isTracked ? "Tracking working" : "Reposition"
        return status
    }
    
    func playSound() {
        guard let url = Bundle.main.url(forResource: "bleep", withExtension: "mp3") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.numberOfLoops = 5
            player.setVolume(75, fadeDuration: 1)
            
            player.play()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    @objc func updateTimer() {
        count = count + 1
        let time = secondsToHoursMinutesSeconds(seconds: count)
        let timeString = makeTimeString(hours: time.0, minutes: time.1, seconds: time.2)
        timerLabel.text = timeString
    }
    func secondsToHoursMinutesSeconds(seconds: Int) -> (Int, Int, Int) {
        return ((seconds / 3600), ((seconds % 3600) / 60),((seconds % 3600) % 60))
    }
    func makeTimeString(hours: Int, minutes: Int, seconds : Int) -> String  {
        var timeString = ""
        timeString += String(format: "%02d", hours)
        timeString += " : "
        timeString += String(format: "%02d", minutes)
        timeString += " : "
        timeString += String(format: "%02d", seconds)
        return timeString
    }
}

extension Array where Element: FloatingPoint {
    
    func sum() -> Element {
        return self.reduce(0, +)
    }
    
    func avg() -> Element {
        return self.sum() / Element(self.count)
    }
    
    func std() -> Element {
        let mean = self.avg()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }
}
