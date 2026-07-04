import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private init() {}

    func configure(forPlayback: Bool = false) throws {
        let session = AVAudioSession.sharedInstance()
        if forPlayback {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        } else {
            try session.setCategory(.record, mode: .measurement, options: [])
        }
        try session.setPreferredSampleRate(Double(AudioConstants.sampleRate))
        try session.setPreferredIOBufferDuration(AudioConstants.preferredIOBufferDuration)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    /// Low-latency configuration for the practice timing analyser.
    /// `useHeadphones` avoids routing the metronome click to the speaker (so it
    /// doesn't bleed into the mic).
    func configureForPractice(useHeadphones: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
        if !useHeadphones {
            options.insert(.defaultToSpeaker)
        }
        try session.setCategory(.playAndRecord, mode: .measurement, options: options)
        try session.setPreferredSampleRate(48000)
        try session.setPreferredIOBufferDuration(0.005)   // ~5 ms hardware I/O latency
    }

    func activate() throws {
        try AVAudioSession.sharedInstance().setActive(true, options: [])
    }

    func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            let shouldResume = options.map {
                AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
            } ?? false
            onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        // Route changes (e.g. headphones plugged in) are handled automatically
        // by AVAudioEngine reconnecting its taps.
    }
}
