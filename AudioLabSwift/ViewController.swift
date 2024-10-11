import UIKit
import Metal


class ViewController: UIViewController {
    
    @IBOutlet weak var userView: UIView!
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
        static let MIN_FREQUENCY_DIFFERENCE: Float = 50.0
        static let MAGNITUDE_THRESHOLD: Float = 0.5 // Set based on your testing
    }
    
    // Setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    var timer: Timer? = nil
    
    @IBOutlet weak var labelF1: UILabel!
    @IBOutlet weak var labelF2: UILabel!
    
    var lastLockedFrequencies: (Float, Float)? = nil // Stores last significant frequencies
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // Add in graphs for display
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            graph.makeGrids() // Add grids to graph
        }
        
        audio.startMicrophoneProcessing(withFps: 20)
        
        audio.play()
        
        // Start the timer for graph updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
            self.updateLabelsWithPeakFrequencies()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        timer?.invalidate()
        graph?.teardown()
        graph = nil
        audio.stop()
        super.viewDidDisappear(animated)
    }
    
    // Periodically update the graph with refreshed FFT data
    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: self.audio.fftData, forKey: "fft")
        }
    }
    
    // Find and display the two loudest frequencies
    func updateLabelsWithPeakFrequencies() {
        let fftData = audio.fftData
        let frequencyResolution = Float(audio.samplingRate) / Float(AudioConstants.AUDIO_BUFFER_SIZE)
        
        // Find the two loudest peaks in the FFT data
        var peaks: [(frequency: Float, magnitude: Float)] = []
        
        for (index, magnitude) in fftData.enumerated() {
            let frequency = Float(index) * frequencyResolution
            if magnitude > AudioConstants.MAGNITUDE_THRESHOLD {
                peaks.append((frequency, magnitude))
            }
        }
        
        // Sort peaks by magnitude in descending order
        peaks.sort { $0.magnitude > $1.magnitude }
        
        if peaks.count >= 2 {
            let topTwoFrequencies = (peaks[0].frequency, peaks[1].frequency)
            
            // Check if they are at least 50Hz apart and have large magnitudes
            if abs(topTwoFrequencies.0 - topTwoFrequencies.1) >= AudioConstants.MIN_FREQUENCY_DIFFERENCE {
                labelF1.text = String(format: "F1: %.2f Hz", topTwoFrequencies.0)
                labelF2.text = String(format: "F2: %.2f Hz", topTwoFrequencies.1)
                
                // Lock the frequencies in place
                lastLockedFrequencies = topTwoFrequencies
            }
        } else if let lastLocked = lastLockedFrequencies {
            // Display locked frequencies if no new large-magnitude frequencies are found
            labelF1.text = String(format: "F1: %.2f Hz", lastLocked.0)
            labelF2.text = String(format: "F2: %.2f Hz", lastLocked.1)
        } else {
            // No significant frequencies found and no locked frequencies, show "N/A"
            labelF1.text = "F1: N/A"
            labelF2.text = "F2: N/A"
        }
    }
}
