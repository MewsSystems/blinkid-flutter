//
//  DetectionStatusStreamHandler.swift
//  blinkid_flutter
//
//  Created by Ionut-Vlad Alboiu on 10/05/2023.
//

import Flutter

class DetectionStatusStreamHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink? = nil
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func add(_ status: MBDetectionStatus){
        let encodedStatus: String = {switch status {
        case .cameraAtAngle:
            return "CAMERA_AT_ANGLE"
        case .fail:
            return "FAIL"
        case .success:
            return "SUCCESS"
        case .cameraTooHigh:
            return "CAMERA_TOO_HIGH"
        case .fallbackSuccess:
            return "FALLBACK_SUCCESS"
        case .partialForm:
            return "PARTIAL_OBJECT"
        case .cameraTooNear:
            return "CAMERA_TOO_NEAR"
        case .documentTooCloseToEdge:
            return "DOCUMENT_TOO_CLOSE_TO_EDGE"
        default:
            return ""
        }}()
        
        if encodedStatus.isEmpty {
            return
        }
        
        if let sink = sink {
            sink("{\"detectionStatus\": \"\(encodedStatus)\"}")
        }
        
    }
}
