import UIKit
import Metal

class ViewController: UIViewController {
    
    @IBOutlet weak var userView: UIView!
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
        static let MIN_FREQUENCY_DIFFERENCE: Float = 50.0
        static let MAGNITUDE_THRESHOLD: Float = 0.5
        static let TIME_THRESHOLD: TimeInterval = 0.2
    }
    
    // Setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    var timer: Timer? = nil
    
    @IBOutlet weak var labelF1: UILabel!
    @IBOutlet weak var labelF2: UILabel!
    @IBOutlet weak var vowelLabel: UILabel!

    var lastLockedFrequencies: (Float, Float)? = nil
    var lastDetectedTime: Date? = nil
    var lastDetectedFrequencies: (Float, Float)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            graph.makeGrids()
        }
        
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()
        
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
        
        var peaks: [(frequency: Float, magnitude: Float)] = []
        
        for (index, magnitude) in fftData.enumerated() {
            let frequency = Float(index) * frequencyResolution
            if magnitude > AudioConstants.MAGNITUDE_THRESHOLD {
                peaks.append((frequency, magnitude))
            }
        }
        
        peaks.sort { $0.magnitude > $1.magnitude }
        
        if peaks.count >= 2 {
            let topTwoFrequencies = (peaks[0].frequency, peaks[1].frequency)
            
            if abs(topTwoFrequencies.0 - topTwoFrequencies.1) >= AudioConstants.MIN_FREQUENCY_DIFFERENCE {
                let now = Date()
                
                // Check if these frequencies are the same as the previously detected ones
                if let lastFrequencies = lastDetectedFrequencies, lastFrequencies == topTwoFrequencies {
                    // If the frequencies have been detected for more than 200ms, update the labels
                    if let lastTime = lastDetectedTime, now.timeIntervalSince(lastTime) >= AudioConstants.TIME_THRESHOLD {
                        updateFrequencyLabels(frequencies: topTwoFrequencies)
                    }
                } else {
                    // If new frequencies are detected, reset the detection time
                    lastDetectedFrequencies = topTwoFrequencies
                    lastDetectedTime = now
                }
            }
        } else if let lastLocked = lastLockedFrequencies {
            // Display locked frequencies if no new large-magnitude frequencies are found
            labelF1.text = String(format: "F1: %.2f Hz", lastLocked.0)
            labelF2.text = String(format: "F2: %.2f Hz", lastLocked.1)
        } else {
            // No significant frequencies found and no locked frequencies, show "N/A"
            labelF1.text = "F1: N/A"
            labelF2.text = "F2: N/A"
            vowelLabel.text = "Vowel: N/A"
        }
    }
    
    // Helper function to update the frequency labels and lock the frequencies
    func updateFrequencyLabels(frequencies: (Float, Float)) {
        labelF1.text = String(format: "F1: %.2f Hz", frequencies.0)
        labelF2.text = String(format: "F2: %.2f Hz", frequencies.1)
        lastLockedFrequencies = frequencies
        
        if isOooo(f1: frequencies.0, f2: frequencies.1) {
            vowelLabel.text = "Vowel: Ooooo"
        } else if isAhhhh(f1: frequencies.0, f2: frequencies.1) {
            vowelLabel.text = "Vowel: Ahhhh"
        } else {
            vowelLabel.text = "Vowel: Unknown"
        }
    }
    
    func isOooo(f1: Float, f2: Float) -> Bool {
        return (f1 >= 400 && f1 <= 600) && (f2 >= 700 && f2 <= 900)
    }

    func isAhhhh(f1: Float, f2: Float) -> Bool {
        return (f1 >= 600 && f1 <= 900) && (f2 >= 1200 && f2 <= 1400)
    }
}
