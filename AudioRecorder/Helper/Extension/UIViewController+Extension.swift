//
//  UIViewController+Extension.swift
//  AudioRecorder
//
//  Created by Rahul Garg on 30/10/20.
//

import UIKit

extension UIViewController {
    func showAlert(title: String = "Alert",
                   message: ErrorMessage,
                   buttonTitle: String = "Ok",
                   buttonHandler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title,
                                      message: message.rawValue,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: buttonTitle,
                                   style: .default,
                                   handler: buttonHandler)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
}
