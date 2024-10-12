import UIKit
import Metal

class ModuleBViewController: UIViewController {

    var gestureLabel: UILabel!
    var frequencySlider: UISlider!
    var frequencyLabel: UILabel!
    var userView: UIView!

    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }

    // Initialize the audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var timer: Timer? = nil
    var currentFrequency: Float = 17000 {
        didSet {
            frequencyLabel.text = "Frequency: \(Int(currentFrequency)) Hz"
            audio.sineFrequency1 = currentFrequency  // Set frequency for inaudible tone
        }
    }

    var previousPeakFrequency: Float = 0.0
    let samplingRate: Float = 44100.0
    var smoothedFrequencyShift: Float = 0.0

    // Lazy initialization for the graph
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        setupUI()
        currentFrequency = 17000  // Set the initial frequency to 17kHz
        previousPeakFrequency = currentFrequency

        // Start microphone processing and play the inaudible tone
        audio.startMicrophoneProcessingOne(withFps: 20)  // Capture FFT at 20 FPS
        audio.play()  // Play tone to speakers (inaudible 17-20kHz)

        if let graph = self.graph {
            // Add the FFT graph for zoomed FFT visualization
            graph.addGraph(withName: "fftZoomed", shouldNormalizeForFFT: true, numPointsInGraph: 300)
        }

        // Set up the timer to periodically update the FFT graph and detect gestures
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            self.updateFFTGraph()
            self.detectDopplerShift()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        audio.stop()  // Stop audio when leaving the view
    }

    // Programmatically setup the UI
    func setupUI() {
        frequencySlider = UISlider(frame: CGRect(x: 20, y: 80, width: 280, height: 40))
        frequencySlider.minimumValue = 17000
        frequencySlider.maximumValue = 20000
        frequencySlider.value = currentFrequency
        frequencySlider.addTarget(self, action: #selector(frequencySliderChanged), for: .valueChanged)
        view.addSubview(frequencySlider)

        frequencyLabel = UILabel(frame: CGRect(x: 20, y: 120, width: 280, height: 40))
        frequencyLabel.text = "Frequency: \(Int(currentFrequency)) Hz"
        view.addSubview(frequencyLabel)

        gestureLabel = UILabel(frame: CGRect(x: 20, y: 160, width: 280, height: 40))
        gestureLabel.text = "No Gesture"
        view.addSubview(gestureLabel)

        userView = UIView(frame: CGRect(x: 20, y: 200, width: 280, height: 200))
        view.addSubview(userView)
    }

    // Update the slider when the frequency is changed
    @objc func frequencySliderChanged(_ sender: UISlider) {
        currentFrequency = sender.value
        previousPeakFrequency = currentFrequency
    }

    func updateFFTGraph() {
        guard let graph = self.graph else {
            print("Graph is not initialized.")
            return
        }
        
        let minfreq = currentFrequency
        let startIdx = max(0, (Int(minfreq) - 50) * AudioConstants.AUDIO_BUFFER_SIZE / Int(audio.samplingRate))
        let endIdx = min(startIdx + 300, audio.fftData.count - 1) // Ensure the subarray doesn't go out of bounds
        
        // Extract a portion of the FFT data
        let subArray = Array(audio.fftData[startIdx...endIdx])
        
        // Update the MetalGraph with the zoomed FFT data
        graph.updateGraph(data: subArray, forKey: "fftZoomed")
    }

    // Function to detect Doppler shift based on the difference in frequencies
    func detectDopplerShift() {
        let fftData = audio.fftData
        let frequencyResolution = samplingRate / Float(AudioConstants.AUDIO_BUFFER_SIZE)
        let currentPeakFrequency = findPeakFrequency(fftData: fftData, frequencyResolution: frequencyResolution)
        let frequencyShift = currentPeakFrequency - previousPeakFrequency
        
        let shiftThreshold: Float = 10.0
        let minMagnitude: Float = -50.0
        let peakIndex = Int(currentPeakFrequency / frequencyResolution)
        let peakMagnitude = fftData[peakIndex]
        
        if peakMagnitude < minMagnitude {
            gestureLabel.text = "No Gesture"
            return
        }
        
        let smoothingFactor: Float = 0.2
        smoothedFrequencyShift = smoothingFactor * frequencyShift + (1 - smoothingFactor) * smoothedFrequencyShift
        
        if abs(smoothedFrequencyShift) < shiftThreshold {
            gestureLabel.text = "No Gesture"
        } else if smoothedFrequencyShift > 0 {
            gestureLabel.text = "Gesture Toward"
        } else {
            gestureLabel.text = "Gesture Away"
        }
        
        previousPeakFrequency = currentPeakFrequency
    }

    // Helper function to find the peak frequency from the FFT data
    func findPeakFrequency(fftData: [Float], frequencyResolution: Float) -> Float {
        var maxMagnitude: Float = -Float.infinity
        var maxIndex: Int = 0

        let targetFrequency = currentFrequency
        let frequencyTolerance: Float = 1000.0
        let startIndex = max(Int((targetFrequency - frequencyTolerance) / frequencyResolution), 0)
        let endIndex = min(Int((targetFrequency + frequencyTolerance) / frequencyResolution), fftData.count - 1)

        for i in startIndex...endIndex {
            if fftData[i] > maxMagnitude {
                maxMagnitude = fftData[i]
                maxIndex = i
            }
        }

        return Float(maxIndex) * frequencyResolution
    }
}
