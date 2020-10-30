//
//  RecorderViewModel.swift
//  AudioRecorder
//
//  Created by Rahul Garg on 30/10/20.
//

import AVFoundation

final class RecorderViewModel {
    
    // MARK: - Properties
    var getAudioFileURL: URL? {
        let docDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docDirURL?.appendingPathComponent("\(Constants.AudioFile.name).\(Constants.AudioFile.fileExtension)", isDirectory: false)
    }
    
    
    // MARK: - Timer Helpers
    func getElapsedTime(startDate: Date?) -> String? {
        guard let date = startDate else { return nil }
        
        return getTimerLabelText(fromDate: date, endDate: Date())
    }
    
    func getRemainingTime(startDate: Date?, duration: Float64?) -> String? {
        guard let duration = duration,
              let date = startDate?.addingTimeInterval(duration)
            else { return nil }

        return getTimerLabelText(fromDate: Date(), endDate: date)
    }
    
    private func getTimerLabelText(fromDate: Date, endDate: Date) -> String {
        let dateComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: fromDate, to: endDate)
        
        var text = ""
        if let hour = dateComponents.hour, hour > 0 {
            text = "\(hour):"
        }
        if let min = dateComponents.minute {
            if min < 10 {
                text += "0\(min):"
            } else {
                text += "\(min):"
            }
        }
        if let sec = dateComponents.second {
            if sec < 10 {
                text += "0\(sec)"
            } else {
                text += "\(sec)"
            }
        }
        
        return text
    }
    
    
    // MARK: - Audio Helpers
    func getAudioPlayerPower(audioPlayer: AVAudioPlayer) -> Float {
        let channelCount = audioPlayer.numberOfChannels
        var power: Float = 0
        
        for i in 0..<channelCount {
            power += audioPlayer.averagePower(forChannel: i)
        }
        
        power /= Float(channelCount)
        return power
    }
    
    func getMeteredValue(of power: Float) -> Float {
        let meter = MeterTableOC()
        return meter.value(at: power)
    }
    
    func getAudioFile(audioFileURL: URL, settings: [String: Any]) throws -> AVAudioFile? {
        return try AVAudioFile(forWriting: audioFileURL,
                               settings: settings,
                               commonFormat: .pcmFormatFloat32,
                               interleaved: false)
    }
    
    func writeToAudioFile(_ audioFile: AVAudioFile?, audioBuffer: AVAudioPCMBuffer) throws {
        try audioFile?.write(from: audioBuffer)
    }
}
