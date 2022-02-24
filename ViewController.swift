import UIKit
import SceneKit
import ARKit
//import EyeTracking

class ViewController: UIViewController, ARSCNViewDelegate {

    //declaring view & variables
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceLabel: UILabel!
    var timestamp = NSDate().timeIntervalSince1970
    var analysis = ""
    var blink = false
    //let eyeTracking = EyeTracking(configuration: Configuration(appID: "Somnos", blendShapes: [.eyeBlinkLeft, .eyeBlinkRight]))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        //sceneView.showsStatistics = true
        //^unnessecary
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking is not supported on this device.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()

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
    
    
    //check blinking
    func expression(anchor: ARFaceAnchor) {
        //cause mirrored or smthn
        let blinkRight = anchor.blendShapes[.eyeBlinkLeft]
        let blinkLeft = anchor.blendShapes[.eyeBlinkRight]
        let Lval = Double(truncating: blinkLeft ?? 0.0)
        let Rval = Double(truncating: blinkRight ?? 0.0)
        self.analysis = "Left blink = \(round(Lval*10)/10.0) & Right blink = \(round(Rval*10)/10.0)\n"
        

        
        if ((blinkLeft?.decimalValue ?? 0.0 > 0.75) && (blinkRight?.decimalValue ?? 0.0 > 0.75)) {
            self.analysis += "\nYou are blinking."
            
            var acct = 0.0
            var queue: [Double] = []
            let newtimestamp = NSDate().timeIntervalSince1970
            let timestampDifference = abs(newtimestamp - timestamp)
            timestamp = newtimestamp
            queue.append(timestampDifference)
            self.analysis += "\(queue[0])"
            //print("Queue: \(queue)")
            for i in queue{
                print (i)
            }
            //add wait
            if (queue.count > 30){
                let purged = queue[0]
                queue.remove(at: 0)
                let i = 15
                while i < queue.count{
                    acct += queue[i]
                }
                acct = acct - purged + 15
            }
        }
        
    }
}
