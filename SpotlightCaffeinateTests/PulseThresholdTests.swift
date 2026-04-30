import Foundation
import Testing

struct PulseThresholdTests {
    @Test
    func defaultIsMinute1() {
        #expect(PulseThreshold.default == .minute1)
    }

    @Test
    func allCasesPreserveExpectedOrder() {
        #expect(PulseThreshold.allCases == [.off, .seconds30, .minute1, .minutes5])
    }

    @Test
    func rawValuesAreStable() {
        #expect(PulseThreshold.off.rawValue == "off")
        #expect(PulseThreshold.seconds30.rawValue == "seconds30")
        #expect(PulseThreshold.minute1.rawValue == "minute1")
        #expect(PulseThreshold.minutes5.rawValue == "minutes5")
    }

    @Test
    func secondsValuesMatchLabels() {
        #expect(PulseThreshold.off.seconds == nil)
        #expect(PulseThreshold.seconds30.seconds == 30)
        #expect(PulseThreshold.minute1.seconds == 60)
        #expect(PulseThreshold.minutes5.seconds == 300)
    }

    @Test
    func shouldPulseRespectsThreshold() {
        #expect(PulseThreshold.minute1.shouldPulse(remainingSeconds: 30))
        #expect(PulseThreshold.minute1.shouldPulse(remainingSeconds: 60))
        #expect(!PulseThreshold.minute1.shouldPulse(remainingSeconds: 61))
        #expect(!PulseThreshold.minute1.shouldPulse(remainingSeconds: 0))
        #expect(!PulseThreshold.off.shouldPulse(remainingSeconds: 5))
        #expect(PulseThreshold.seconds30.shouldPulse(remainingSeconds: 1))
        #expect(!PulseThreshold.seconds30.shouldPulse(remainingSeconds: 31))
        #expect(PulseThreshold.minutes5.shouldPulse(remainingSeconds: 299))
        #expect(PulseThreshold.minutes5.shouldPulse(remainingSeconds: 300))
        #expect(!PulseThreshold.minutes5.shouldPulse(remainingSeconds: 301))
    }

    @Test
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for threshold in PulseThreshold.allCases {
            let data = try encoder.encode(threshold)
            let decoded = try decoder.decode(PulseThreshold.self, from: data)
            #expect(decoded == threshold)
        }
    }
}
