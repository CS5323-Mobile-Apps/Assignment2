import UIKit
import Metal

class ModuleBViewController: UIViewController {

    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var frequencySlider: UISlider!
    @IBOutlet weak var frequencyLabel: UILabel!
    
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var timer: Timer? = nil
    var currentFrequency: Float = 18000 {
        didSet {
            frequencyLabel.text = "Frequency: \(currentFrequency) Hz"
            audio.sineFrequency1 = currentFrequency // Set inaudible tone frequency
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set default frequency and setup slider
        currentFrequency = 18000
        frequencySlider.minimumValue = 17000
        frequencySlider.maximumValue = 20000
        frequencySlider.value = currentFrequency
        
        audio.startMicrophoneProcessing(withFps: 20) // Start the microphone input
        audio.play() // Play the inaudible tone
        
        // Setup timer to periodically detect gestures via Doppler shift
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
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
    }

    // Detect Doppler shift based on microphone FFT data
    func detectDopplerShift() {
        let fftData = audio.fftData
        let positiveThreshold: Float = 4.0
        let negativeThreshold: Float = -4.0
        
        // Here you would need to implement the logic to detect frequency shifts
        // Doppler shift detection: change in frequency index indicates gesture
            let currentPeak = findPeakInFFT(fftData) // Now this returns a frequency (Float)
            
            // Print the frequency shift for debugging
            print("Frequency Shift Detected: \(currentPeak)")
            
            // Compare the frequency with thresholds
            if currentPeak > positiveThreshold {
                gestureLabel.text = "Gesture Toward"
            } else if currentPeak < negativeThreshold {
                gestureLabel.text = "Gesture Away"
            } else {
                gestureLabel.text = "No Gesture"
            }
        }
    
    // Helper function to find the peak frequency in the FFT data
    // Sampling rate (adjust to match your setup)
    let samplingRate: Float = 44100.0 // in Hz
    
    func findPeakInFFT(_ fftData: [Float]) -> Float {
        var maxIndex = 0
        var maxMagnitude: Float = 0
        
        // Find the index of the largest peak in the FFT data
        for i in 0..<fftData.count {
            if fftData[i] > maxMagnitude {
                maxMagnitude = fftData[i]
                maxIndex = i
            }
        }
        
        // Convert the index to a frequency
        let frequency = Float(maxIndex) * (samplingRate / Float(AudioConstants.AUDIO_BUFFER_SIZE))
        return frequency
    }
}
