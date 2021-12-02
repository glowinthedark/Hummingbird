//
//  Trial.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 04/08/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Foundation


enum Status {
    case inTrial
    case noLicenseKey
    case invalidLicenseKey
    case validLicenseKey
    case error(Error)
}


enum ValidationError: Error {
    case postDataEncodingError
}


struct License: Equatable {
    let key: String
}


extension License: Defaultable {
    static var defaultValue: Any {
        return ""
    }

    init?(forKey defaultsKey: DefaultsKeys, defaults: UserDefaults) {
        guard let value = defaults.string(forKey: defaultsKey.rawValue) else { return nil }
        self = License(key: value)
    }

    func save(forKey defaultsKey: DefaultsKeys, defaults: UserDefaults) throws {
        defaults.set(key, forKey: defaultsKey.rawValue)
    }
}


struct LicenseInfo {
    static let length = DateComponents(day: 14)

    let firstLaunched: Date
    let license: License?

    var trialEnd: Date { return Calendar.current.date(byAdding: LicenseInfo.length, to: firstLaunched)! }
    var inTrialPeriod: Bool { return Current.date() <= trialEnd }
}


typealias ResponseHandler = (Data?, URLResponse?, Error?) -> Void
typealias DataTaskHandler = (URLRequest, @escaping ResponseHandler) -> URLSessionDataTask


public struct Gumroad {
    var dataTask: DataTaskHandler = URLSession.shared.dataTask

    func validate(license: License, completion: @escaping (Result<Bool, Error>) -> Void) {
        var request = URLRequest(url: Links.gumroadLicenseVerification)
        request.httpMethod = "POST"
        let body = [
            "product_permalink": "hummingbirdapp",
            "license_key": license.key,
        ]

        guard let postData = try? JSONEncoder().encode(body) else {
            completion(.failure(ValidationError.postDataEncodingError))
            return
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        self.dataTask(request) { data, urlResponse, error in
            if let error = error {
                completion(.failure(error))
            } else {
                if
                    let urlResponse = urlResponse,
                    let httpResponse = urlResponse as? HTTPURLResponse,
                    httpResponse.statusCode == 200 {
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            }
        }.resume()
    }
}


func validate(_ licenseInfo: LicenseInfo, completion: @escaping (Status) -> ()) {
    completion(.validLicenseKey)

//    if let licenseKey = licenseInfo.license {
        
            
//        Current.gumroad.validate(license: licenseKey) { result in
//            DispatchQueue.main.async {
//                switch result {
//                case .success():
//                    completion(.validLicenseKey)
//                case .failure(let error):
//                    completion(.error(error))
//                }
//            }
//        }
//    } else {
//        if licenseInfo.inTrialPeriod {
//            completion(.inTrial)
//        } else {
//            completion(.noLicenseKey)
//        }
//    }
}

