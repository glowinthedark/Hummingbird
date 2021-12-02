//
//  AppDelegate+StateMachine.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 16/09/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa


protocol DidTransitionDelegate: class {
    func didTransition(from: AppStateMachine.State, to: AppStateMachine.State)
}


typealias AppStateMachineDelegate = (
    DidTransitionDelegate &
    ShowRegistrationControllerDelegate &
    ShowTrialExpiredAlertDelegate &
    ShouldTermindateDelegate &
    PresentPurchaseViewDelegate
)


class AppStateMachine {
    var stateMachine: StateMachine<AppStateMachine>!
    weak var delegate: AppStateMachineDelegate?

    var state: State {
        get {
            return stateMachine.state
        }
        set {
            stateMachine.state = newValue
        }
    }

    init() {
        stateMachine = StateMachine<AppStateMachine>(initialState: .launching, delegate: self)
    }
}


extension AppStateMachine {
    func toggleEnabled() {
//        switch state {
//            case .activated:
//                // deactivate()
//            case .deactivated:
//                checkLicense()
//            default:
//                break
//        }
    }
}


// MARK:- StateMachineDelegate

extension AppStateMachine: StateMachineDelegate {
    enum State: TransitionDelegate {
        case launching
        case validatingLicense
        case unregistered
        case activating
        case activated
        case deactivated

        func shouldTransition(from: State, to: State) -> Decision<State> {
            log(.debug, "Transition: \(from) -> \(to)")

            switch (from, to) {
                case (.launching, .validatingLicense):
                    return .continue
                case (.activated, .activating):
                    // license check succeeded while already active (i.e. when in trial)
                    return .continue
                case (.validatingLicense, .activating),  (.unregistered, .activating):
                    return .continue
                case (.validatingLicense, .deactivated):
                    // validating error
                    return .continue
                case (.validatingLicense, .unregistered):
                    return .continue
                case (.activating, .activated), (.deactivated, .activated):
                    return .continue
                case (.activating, .deactivated), (.activated, .deactivated):
                    return .continue
                case (.unregistered, .unregistered):
                    // license check failed while already unregistered
                    return .continue
                case (.activated, .unregistered):
                    // license check failed while on trial
                    return .continue
                case (.deactivated, .activating):
                    return .continue
                case (.deactivated, .deactivated):
                    // activation error (lack of permissions)
                    return .continue
                default:
                    assertionFailure("💣 Unhandled state transition: \(from) -> \(to)")
                    return .abort
            }

        }
    }

    func didTransition(from: State, to: State) {
        delegate?.didTransition(from: from, to: to)

        switch (from, to) {
            case (.launching, .validatingLicense):
                checkLicense()
            case (.validatingLicense, .activating),  (.unregistered, .activating), (.deactivated, .activating):
                activate(showAlert: true, keepTrying: true)
            case (.validatingLicense, .unregistered):
                Tracker.disable()
                delegate?.showTrialExpiredAlert { result in
                    switch result {
                        case .alertFirstButtonReturn:
                            delegate?.presentPurchaseView()
                        case .alertSecondButtonReturn:
                            delegate?.showRegistrationController()
                        default:
                            delegate?.shouldTerminate()
                    }
                }
            default:
                break
        }
    }
}


// MARK:- State transition helpers


extension AppStateMachine {

    func checkLicense() {
        // Yes, it is really that simple to circumvent the license check. But if you can build it from source
        // it's free of charge anyway. Although it'd be great if you'd send a coffee!
        log(.debug, "OK: valid license")
        self.stateMachine.state = .activating
        
//        if Current.featureFlags.commercial {
//            log(.debug, "Commercial version")
//            let firstLaunched = Date(forKey: .firstLaunched, defaults: Current.defaults()) ?? Current.date()
//            let license = License(forKey: .license, defaults: Current.defaults())
//            let licenseInfo = LicenseInfo(firstLaunched: firstLaunched, license: license)
//            validate(licenseInfo) { status in
//                switch status {
//                    case .validLicenseKey:
//                        log(.debug, "OK: valid license")
//                        self.stateMachine.state = .activating
//                    case .inTrial:
//                        log(.debug, "OK: in trial")
//                        self.stateMachine.state = .activating
//                    case .noLicenseKey:
//                        log(.debug, "⚠️ no license")
//                        self.stateMachine.state = .unregistered
//                    case .invalidLicenseKey:
//                        log(.debug, "⚠️ invalid license")
//                        self.stateMachine.state = .unregistered
//                    case .error(let error):
//                        // TODO: allow a number of errors but eventually lock (to prevent someone from blocking the network calls)
//                        log(.debug, "⚠️ \(error)")
//                        // We're graceful here to avoid nagging folks with a license who are offline.
//                        // Yes, you can block the app from connecting but if you can figure that out you can probably also build
//                        // and run the free app. Please support indie software :)
//                        self.stateMachine.state = .activating
//                }
//            }
//        } else {
//            log(.debug, "Open source version")
//            stateMachine.state = .activating
//        }
    }

    func activate(showAlert: Bool, keepTrying: Bool) {
        Tracker.enable()
        if Tracker.isActive {
            stateMachine.state = .activated
        } else {
            if showAlert {
                showAccessibilityAlert()
            }
            if keepTrying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.activate(showAlert: false, keepTrying: true)
                }
            } else {
                stateMachine.state = .deactivated
            }
        }
    }

    func deactivate() {
        Tracker.disable()
        stateMachine.state = .deactivated
    }

}


