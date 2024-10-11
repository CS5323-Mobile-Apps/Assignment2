import UIKit
import Metal

class ModuleBViewController: UIViewController {

    var gestureLabel: UILabel!
    var frequencySlider: UISlider!
    var frequencyLabel: UILabel!
    var userView: UIView!
    var dBLabel: UILabel!

    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }

    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    var timer: Timer? = nil
    var currentFrequency: Float = 17000 {
        didSet {
            frequencyLabel.text = "Frequency: \(Int(currentFrequency)) Hz"
            audio.sineFrequency1 = currentFrequency
        }
    }
    
    var previousPeakFrequency: Float = 0.0
    let samplingRate: Float = 44100.0
    var smoothedFrequencyShift: Float = 0.0

    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        currentFrequency = 17000
        previousPeakFrequency = currentFrequency

        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()

        if let graph = self.graph {
            graph.addGraph(withName: "fftZoomed", shouldNormalizeForFFT: true, numPointsInGraph: 300)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            self.updateFFTGraph()
            self.detectDopplerShift()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        audio.stop()
    }

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

        dBLabel = UILabel(frame: CGRect(x: 20, y: 420, width: 280, height: 40))
        dBLabel.text = "dB: N/A"
        view.addSubview(dBLabel)
    }

    @objc func frequencySliderChanged(_ sender: UISlider) {
        currentFrequency = sender.value
        previousPeakFrequency = currentFrequency
    }

    func updateFFTGraph() {
        if let graph = self.graph {
            let fftData = self.audio.fftData
            let frequencyResolution = samplingRate / Float(AudioConstants.AUDIO_BUFFER_SIZE)
            let startIdx = max(0, Int(150 / frequencyResolution))
            let endIdx = min(startIdx + 300, fftData.count - 1)

            let subArray = Array(fftData[startIdx...endIdx])
            let fftDataInDb = subArray.map { 20 * log10(max($0, 0.0001)) }

            if let peakDb = fftDataInDb.max() {
                dBLabel.text = String(format: "dB: %.2f", peakDb)
            }

            graph.updateGraph(data: fftDataInDb, forKey: "fftZoomed")
        }
    }

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
