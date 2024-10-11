import UIKit
import Metal

class ModuleBViewController: UIViewController {

    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var frequencySlider: UISlider!
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var userView: UIView!

    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }

    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var timer: Timer? = nil
    var currentFrequency: Float = 18000 {
        didSet {
            frequencyLabel.text = "Frequency: \(Int(currentFrequency)) Hz"
            audio.sineFrequency1 = currentFrequency // Set inaudible tone frequency
        }
    }
    
    var previousPeakFrequency: Float = 0.0
    let samplingRate: Float = 44100.0 // Adjust if your sampling rate is different

    // For displaying FFT graph
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set default frequency and setup slider
        currentFrequency = 18000
        frequencySlider.minimumValue = 17000
        frequencySlider.maximumValue = 20000
        frequencySlider.value = currentFrequency
        frequencyLabel.text = "Frequency: \(Int(currentFrequency)) Hz"

        // Initialize previous peak frequency
        previousPeakFrequency = currentFrequency

        // Start microphone processing
        audio.startMicrophoneProcessing(withFps: 60)
        audio.play() // Play the inaudible tone

        // Initialize FFT graph
        if let graph = self.graph {
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
        }

        // Setup timer to periodically detect gestures via Doppler shift
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            self.updateFFTGraph()
            self.detectDopplerShift()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate() // Stop the timer when view disappears
        audio.stop() // Stop audio processing
    }

    // Action when the frequency slider is changed
    @IBAction func frequencySliderChanged(_ sender: UISlider) {
        currentFrequency = sender.value
        previousPeakFrequency = currentFrequency // Reset previous frequency
    }

    // Update FFT graph
    func updateFFTGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: self.audio.fftData, forKey: "fft")
        }
    }

    // Detect Doppler shift based on microphone FFT data
    func detectDopplerShift() {
        let fftData = audio.fftData
        let frequencyResolution = samplingRate / Float(AudioConstants.AUDIO_BUFFER_SIZE)

        // Find the peak frequency in the current FFT data
        let currentPeakFrequency = findPeakFrequency(fftData: fftData, frequencyResolution: frequencyResolution)

        // Calculate the frequency shift
        let frequencyShift = currentPeakFrequency - previousPeakFrequency

        // Update the previous peak frequency
        previousPeakFrequency = currentPeakFrequency

        // Thresholds for detecting gestures (adjust based on testing)
        let shiftThreshold: Float = 5.0 // Hz
        let minMagnitude: Float = -40.0 // dB, since FFT data is in dB

        // Get the magnitude at the peak frequency
        let peakIndex = Int(currentPeakFrequency / frequencyResolution)
        let peakMagnitude = fftData[peakIndex]

        if peakMagnitude < minMagnitude {
            // No significant frequency detected
            gestureLabel.text = "No Gesture"
            return
        }

        if frequencyShift > shiftThreshold {
            gestureLabel.text = "Gesture Toward"
        } else if frequencyShift < -shiftThreshold {
            gestureLabel.text = "Gesture Away"
        } else {
            gestureLabel.text = "No Gesture"
        }
    }

    // Helper function to find the peak frequency in the FFT data
    func findPeakFrequency(fftData: [Float], frequencyResolution: Float) -> Float {
        var maxMagnitude: Float = -Float.infinity
        var maxIndex: Int = 0

        // Focus on frequencies around the played tone to reduce noise
        let targetFrequency = currentFrequency
        let frequencyTolerance: Float = 1000.0 // Hz
        let startIndex = max(Int((targetFrequency - frequencyTolerance) / frequencyResolution), 0)
        let endIndex = min(Int((targetFrequency + frequencyTolerance) / frequencyResolution), fftData.count - 1)

        for i in startIndex...endIndex {
            if fftData[i] > maxMagnitude {
                maxMagnitude = fftData[i]
                maxIndex = i
            }
        }

        let peakFrequency = Float(maxIndex) * frequencyResolution
        return peakFrequency
    }
}

