import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var playingUrl: String?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            print("DEBUG [AudioManager]: Failed to set up audio session. \(error)")
        }
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch {
            print("DEBUG [AudioManager]: Could not start recording. \(error)")
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.isRecording = false
        }
        return audioRecorder?.url
    }
    
    func playAudio(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        if isPlaying {
            stopAudio()
        }
        
        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        playingUrl = urlString
        audioPlayer?.play()
        isPlaying = true
        
        // Add progress observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let item = self.audioPlayer?.currentItem else { return }
            let duration = item.duration.seconds
            if duration > 0, duration.isFinite {
                self.progress = time.seconds / duration
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    func stopAudio() {
        audioPlayer?.pause()
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer = nil
        isPlaying = false
        progress = 0.0
        playingUrl = nil
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        DispatchQueue.main.async {
            self.stopAudio()
        }
    }
    
    func isPlaying(url: String) -> Bool {
        return isPlaying && playingUrl == url
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
