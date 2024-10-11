import UIKit
import Metal

class ModuleBViewController: UIViewController {
    
    // UI Elements
    var gestureLabel: UILabel!
    var frequencySlider: UISlider!
    var frequencyLabel: UILabel!
    var graphView: UIView!
    
    // Audio Constants
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
        static let MIN_FREQUENCY: Float = 17000.0 // Hz
        static let MAX_FREQUENCY: Float = 20000.0 // Hz
        static let FFT_ZOOM_SIZE: Int = 300
    }
    
    // Audio model for processing
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var currentFrequency: Float = 18000 {
        didSet {
            frequencyLabel.text = "Frequency: \(currentFrequency) Hz"
            audio.sineFrequency1 = currentFrequency // Set inaudible tone frequency
        }
    }
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.graphView)
    }()
    
    var timer: Timer? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Setup the graph
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            graph.addGraph(withName: "fftZoomed", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.FFT_ZOOM_SIZE)
            graph.makeGrids()
        }
        
        // Start audio processing
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play() // Play the inaudible tone
        
        // Setup a timer to update the graph and gesture detection
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
            self.detectDopplerShift()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        audio.stop()
    }
    
    // UI Setup
    func setupUI() {
        // Frequency slider
        frequencySlider = UISlider(frame: CGRect(x: 20, y: 80, width: 280, height: 40))
        frequencySlider.minimumValue = AudioConstants.MIN_FREQUENCY
        frequencySlider.maximumValue = AudioConstants.MAX_FREQUENCY
        frequencySlider.value = currentFrequency
        frequencySlider.addTarget(self, action: #selector(frequencySliderChanged), for: .valueChanged)
        view.addSubview(frequencySlider)

        // Frequency label
        frequencyLabel = UILabel(frame: CGRect(x: 20, y: 120, width: 280, height: 40))
        frequencyLabel.text = "Frequency: \(currentFrequency) Hz"
        view.addSubview(frequencyLabel)
        
        // Gesture label
        gestureLabel = UILabel(frame: CGRect(x: 20, y: 160, width: 280, height: 40))
        gestureLabel.text = "No Gesture"
        view.addSubview(gestureLabel)

        // Graph view
        graphView = UIView(frame: CGRect(x: 20, y: 200, width: 280, height: 200))
        view.addSubview(graphView)
    }
    
    @objc func frequencySliderChanged(_ sender: UISlider) {
        currentFrequency = sender.value
    }
    
    // Update the FFT graph
    func updateGraph() {
        if let graph = self.graph {
            let startIdx: Int = 150 * AudioConstants.AUDIO_BUFFER_SIZE / audio.samplingRate
            let subArray: [Float] = Array(self.audio.fftData[startIdx...startIdx + AudioConstants.FFT_ZOOM_SIZE])
            graph.updateGraph(data: subArray, forKey: "fftZoomed")
        }
    }
    
    // Detect Doppler shift to recognize gestures
    func detectDopplerShift() {
        let fftData = audio.fftData
        let threshold: Float = 4.0
        let peakFrequency = findPeakInFFT(fftData)
        
        // Doppler shift detection: compare peak frequency with the set frequency
        let frequencyShift = peakFrequency - currentFrequency
        
        if frequencyShift > threshold {
            gestureLabel.text = "Gesture Toward"
        } else if frequencyShift < -threshold {
            gestureLabel.text = "Gesture Away"
        } else {
            gestureLabel.text = "No Gesture"
        }
    }
    
    // Find the peak frequency in the FFT data
    func findPeakInFFT(_ fftData: [Float]) -> Float {
        var maxIndex = 0
        var maxMagnitude: Float = 0
        
        for (index, magnitude) in fftData.enumerated() {
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                maxIndex = index
            }
        }
        
        let frequencyResolution = Float(audio.samplingRate) / Float(AudioConstants.AUDIO_BUFFER_SIZE)
        return Float(maxIndex) * frequencyResolution
    }
}
