//
//  RecorderViewController.swift
//  AudioRecorder
//
//  Created by Rahul Garg on 29/10/20.
//

import UIKit
import AVFoundation
import SwiftSiriWaveformView

final class RecorderViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var waveformView: SwiftSiriWaveformView! {
        didSet {
            waveformView.numberOfWaves = Constants.Waveform.numberOfMiniWaves
            waveformView.amplitude = 0
        }
    }
    @IBOutlet private weak var timerLabel: UILabel! {
        didSet {
            timerLabel.isHidden = true
        }
    }
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var playButton: UIButton!
    
    
    // MARK: - Enum
    private enum RecordingState {
        case notInitiated           //user lands on the screen
        case recording              //recording is in progress
        case recordingStopped       //recording is stopped
        case playing                //recorded audio is played
        case playingStopped         //recorded audio finished playing
    }
    

    // MARK: - Properties
    private var viewModel = RecorderViewModel()
    
    // MARK: Audio
    private lazy var audioEngine = AVAudioEngine()
    private lazy var audioMixerNode: AVAudioMixerNode = {
        let node = AVAudioMixerNode()
        node.volume = 0
        return node
    }()
    private lazy var audioPlayer = AVAudioPlayer()
    
    // MARK: Helper Variables
    private var recorderState: RecordingState = .notInitiated
    // save audio sets in this variable
    private var audioBuffer = [AVAudioPCMBuffer]()
    private var timerStart: Date?
    private var audioDuration: Float64? {
        guard let audioFileUrl = viewModel.getAudioFileURL else { return nil }
        
        let audioAsset = AVURLAsset(url: audioFileUrl)
        let audioDuration = CMTimeGetSeconds(audioAsset.duration)
        return audioDuration
    }
    
    // MARK: Timer
    private var durationTimer: Timer?
    private var displayLink: CADisplayLink?

    
    // MARK: - Overriden Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initAudioSession()
        initAudioEngine()
    }
}

// MARK: - Permission Helpers
extension RecorderViewController {
    private func checkRecordPermission(completion: @escaping ((_ isGranted: Bool) -> Void)) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSessionRecordPermission.granted:
            completion(true)

        case AVAudioSessionRecordPermission.denied:
            completion(false)

        case AVAudioSessionRecordPermission.undetermined:
            requestRecordPermission(completion: completion)

        default:
            break
        }
    }

    private func requestRecordPermission(completion: @escaping ((_ isGranted: Bool) -> Void)) {
        AVAudioSession.sharedInstance().requestRecordPermission() { (allowed) in
            completion(allowed)
        }
    }
}


// MARK: - Timer Helpers
extension RecorderViewController {
    private func initTimer() {
        timerLabel.isHidden = false
        
        timerStart = Date()
        durationTimer = Timer.scheduledTimer(timeInterval: 1,
                                             target: self,
                                             selector: #selector(runDurationTimerCode),
                                             userInfo: nil,
                                             repeats: true)
        runDurationTimerCode()
    }
    
    private func invalidateTimer() {
        timerLabel.isHidden = true
        timerStart = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    @objc private func runDurationTimerCode() {
        switch recorderState {
        case .notInitiated, .recording:
            timerLabel.text = viewModel.getElapsedTime(startDate: timerStart)
        case .recordingStopped, .playing, .playingStopped:
            timerLabel.text = viewModel.getRemainingTime(startDate: timerStart, duration: audioDuration)
        }
    }
    
    @objc private func audioPlayerUpdate() {
        var scale: Float = Constants.Waveform.defaultScale
        
        if audioPlayer.isPlaying == true {
            audioPlayer.updateMeters()
            
            let power = viewModel.getAudioPlayerPower(audioPlayer: audioPlayer)
            let level = viewModel.getMeteredValue(of: power)
            scale = level * 3
        }
        
        waveformView.amplitude = CGFloat(scale)
    }
}


// MARK: - IBActions
extension RecorderViewController {
    @IBAction private func didTapRecord(_ sender: UIButton) {
        stopAudioPlayer()
        
        switch recorderState {
        case .notInitiated:
            checkRecordPermission { [weak self] granted in
                if granted {
                    self?.initTimer()
                    self?.audioBuffer.removeAll()
                    self?.startAudioRecorder()
                } else {
                    self?.showAlert(message: .permissionDenied, buttonTitle: "Grant Permission") { _ in
                        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                              UIApplication.shared.canOpenURL(settingsUrl)
                            else { return }
                        
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
            
        case .recording:
            invalidateTimer()
            recorderState = .recordingStopped
            recordButton.setImage(.recorderRecord, for: .normal)
            stopAudioRecorder()
            
        case .recordingStopped, .playing, .playingStopped:
            audioBuffer.removeAll()
            startAudioRecorder()
            initTimer()
            recorderState = .recording
            recordButton.setImage(.recorderStop, for: .normal)
        }
    }
    
    @IBAction private func didTapPlay(_ sender: UIButton) {
        switch recorderState {
        case .notInitiated:
            showAlert(message: .noRecordingPlayTapped)
            
        case .recording:
            showAlert(message: .inRecordingPlayTapped)
            
        case .recordingStopped:
            //coinvert and write only if user has recorded a video and just after that plays the recording
            guard let audioFileURL = writeToFile() else {
                showAlert(message: .writingAudioToFileFail)
                return
            }
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
                startAudioPlayer()
            } catch {
                showAlert(message: .audioPlayerError)
            }
            
        case .playing:
            break
            
        case .playingStopped:
            //not writing to file as it is already converted to wav and written. We don't have to convert and write everytime the same recording
            startAudioPlayer()
        }
    }
}


// MARK: - Audio Helpers
extension RecorderViewController {
    private func initAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        try? session.setActive(true)
    }
    
    private func initAudioEngine() {
        audioEngine.attach(audioMixerNode)
        makeConnections()
        audioEngine.prepare()
    }
    
    private func makeConnections() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        audioEngine.connect(inputNode,
                            to: audioMixerNode,
                            format: inputFormat)
        
        let mainMixerNode = audioEngine.mainMixerNode
        let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                        sampleRate: inputFormat.sampleRate,
                                        channels: inputFormat.channelCount,
                                        interleaved: false)
        audioEngine.connect(audioMixerNode, to: mainMixerNode, format: mixerFormat)
    }
}


// MARK: - Audio Player Helpers
extension RecorderViewController {
    private func startAudioPlayer() {
        audioPlayer.play()
        recorderState = .playing
        initTimer()
        
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.isMeteringEnabled = true
        audioPlayer.play()
        
        displayLink = CADisplayLink(target: self, selector: #selector(audioPlayerUpdate))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    private func stopAudioPlayer() {
        audioPlayer.stop()
        displayLink?.remove(from: .current, forMode: .common)
        displayLink = nil
        invalidateTimer()
        waveformView.amplitude = 0
    }
    
    private func writeToFile() -> URL? {
        guard let audioFileURL = viewModel.getAudioFileURL else {
            showAlert(message: .storageFileUrl)
            return nil
        }
        
        let tapNode: AVAudioNode = audioMixerNode
        let format = tapNode.outputFormat(forBus: 0)
        
        var audioFile: AVAudioFile?
        do {
            audioFile = try viewModel.getAudioFile(audioFileURL: audioFileURL, settings: format.settings)
        } catch {
            showAlert(message: .audioFileNotCreated)
            return nil
        }
        
        for audioBuffer in audioBuffer {
            do {
                try viewModel.writeToAudioFile(audioFile, audioBuffer: audioBuffer)
            } catch {
                print(error)
            }
        }
        
        return audioFileURL
    }
}


// MARK: - Audio Recorder Helpers
extension RecorderViewController {
    private func startAudioRecorder() {
        let tapNode: AVAudioNode = audioMixerNode
        let format = tapNode.outputFormat(forBus: 0)
        
        tapNode.installTap(onBus: 0,
                           bufferSize: AVAudioFrameCount(Constants.Audio.bufferSize),
                           format: format) { [weak self] (buffer, time) in
            self?.audioBuffer.append(buffer)
        }
        
        do {
            try audioEngine.start()
            recorderState = .recording

            recordButton.setImage(.recorderStop, for: .normal)
        } catch {
            showAlert(message: .audioEngineNotStarted)
        }
    }

    private func stopAudioRecorder() {
        audioMixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        recorderState = .recordingStopped
    }
}


// MARK: - AVAudioPlayerDelegate
extension RecorderViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            stopAudioPlayer()
            recorderState = .playingStopped
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        showAlert(message: .audioPlayerError)
    }
}
