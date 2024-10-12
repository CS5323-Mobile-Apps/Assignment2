import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE: Int
    var timeData: [Float]
    var fftData: [Float]
    lazy var samplingRate: Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    var sineFrequency1: Float = 300.0 // This frequency will be controlled by the slider
    private var phase1: Float = 0.0
    private var phaseIncrement1: Float = 0.0
    private var sineWaveRepeatMax: Float = Float(2 * Double.pi)
    
    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE / 2)
    }
    
    func startMicrophoneProcessing(withFps: Double) {
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
//            manager.outputBlock = self.handleSpeakerQueryWithSinusoids
            
            // Repeat this fps times per second using the timer class
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    func startMicrophoneProcessingOne(withFps: Double) {
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
            manager.outputBlock = self.handleSpeakerQueryWithSinusoids
            
            // Repeat this fps times per second using the timer class
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    func play() {
        if let manager = self.audioManager {
            manager.play()
        }
    }

    func stop(){
        if let manager = self.audioManager{
            manager.pause()
            manager.inputBlock = nil
            manager.outputBlock = nil
        }
        
        if let buffer = self.inputBuffer{
            buffer.clear() // just makes zeros
        }
        inputBuffer = nil
        fftHelper = nil
    
    }
    
    
    // MARK: Private Properties
    private lazy var audioManager: Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper: FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer: CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    // MARK: Model Callback Methods
    private func runEveryInterval() {
        if inputBuffer != nil {
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
        }
    }
    
    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    private func handleSpeakerQueryWithSinusoids(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let arrayData = data, let manager = self.audioManager {
            // Calculate the phase increment for the current frequency
            phaseIncrement1 = Float(2 * Double.pi * Double(sineFrequency1) / Double(manager.samplingRate))
            
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            
            if chan == 1 {
                while i < frame {
                    arrayData[i] = sin(phase1) // Generate the sine wave based on the frequency
                    phase1 += phaseIncrement1
                    if phase1 >= sineWaveRepeatMax { phase1 -= sineWaveRepeatMax }
                    i += 1
                }
            } else if chan == 2 {
                let len = frame * chan
                while i < len {
                    arrayData[i] = sin(phase1)
                    arrayData[i + 1] = arrayData[i] // Stereo output, same on both channels
                    phase1 += phaseIncrement1
                    if phase1 >= sineWaveRepeatMax { phase1 -= sineWaveRepeatMax }
                    i += 2
                }
            }
        }
    }
}
