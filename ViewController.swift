import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    //declaring view & variables
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceLabel: UILabel!
        var timestamp = NSDate().timeIntervalSince1970
    var queue: [Double] = []
    var analysis = ""
    var blink = false
    var acct: Float = 0.0
    
    let threshold: Float = 10
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        //sceneView.showsStatistics = true
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
    
    // MARK: - Checking For Blinking
    func expression(anchor: ARFaceAnchor) {
        //cause mirrored or smthn
        let blinkRight = anchor.blendShapes[.eyeBlinkLeft]
        let blinkLeft = anchor.blendShapes[.eyeBlinkRight]
        let Lval = Double(truncating: blinkLeft ?? 0.0)
        let Rval = Double(truncating: blinkRight ?? 0.0)
        self.analysis = "Left blink = \(round(Lval*10)/10.0) & Right blink = \(round(Rval*10)/10.0)\nAcct = \(acct)\nArray = \(queue)"
        
        //blink check
        if (((blinkLeft?.decimalValue ?? 0.0 > 0.75) && (blinkRight?.decimalValue ?? 0.0 > 0.75)) && !blink){
            blink = true
            //print("Blink: \(blink)")
            
            //var acct = 0.0
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
                    //DO STATISTICS!!!!
                }
            }
            
        } else if (blinkLeft?.decimalValue ?? 0.0 < 0.75) && (blinkRight?.decimalValue ?? 0.0 < 0.75) {
            blink = false
        }
        
        
    }
    
    func statistics () {
        let x = 60 * 30 / queue.avg();
        if(x < 10.2){
        //sleepy (maybe have a temperary popup for now)
            print("You are sleepy")
        }
        if(x > 15){
        //they need to see a doctor
            print("Seek a doctor")
        }
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
