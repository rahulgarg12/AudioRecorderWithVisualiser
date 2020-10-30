//
//  ErrorMessage.swift
//  AudioRecorder
//
//  Created by Rahul Garg on 30/10/20.
//

enum ErrorMessage: String {
    case storageFileUrl = "Couldn't create a placeholder in the file system"
    case audioFileNotCreated = "Couldn't create audio file"
    case writingAudioToFileFail = "Audio couldn't be written into the file"
    case audioEngineNotStarted = "Couldn't start the Audio Engine"
    case audioPlayerError = "Audio Player Error"
    case noRecordingPlayTapped = "Record an audio first"
    case inRecordingPlayTapped = "Stop the recording first"
    
    case permissionDenied = "Permission Denied"
}
