//
//  ResultsStreamHandler.swift
//  blinkid_flutter
//
//  Created by Ionut-Vlad Alboiu on 10/05/2023.
//

import Flutter

class ResultsStreamHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink? = nil
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func add(_ results:   [MBRecognizer]){
        let  serializedResults = results.map({ return $0.serializeResult()! })
        let data = try? JSONSerialization.data(withJSONObject: serializedResults, options: .prettyPrinted)
        
        if let sink = sink, let data = data { sink(String(data: data, encoding: .utf8)) }
        
    }
}
