import BlinkID

let blinkIdLicenseErrorCode = "blinkid_license_error"

func isBlinkIdLicenseError(_ error: Error) -> Bool {
  if error is InvalidLicenseKeyError { return true }
  if let initError = error as? SDKInitError {
    switch initError {
    case .licenseError: return true
    case .resourceLoad(let loadError): return loadError.error == .invalidLicense
    default: break
    }
  }
  if let modelError = error as? ModelLoadError, modelError == .invalidLicense { return true }
  let description = "\(error) \(error.localizedDescription)".lowercased()
  return description.contains("license") || description.contains("licence")
}
