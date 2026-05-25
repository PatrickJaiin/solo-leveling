import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Pulls today's step count + workout sample, used to auto-complete fitness quests.
@MainActor
final class HealthKitService {
    struct TodaySummary {
        var steps: Int
        var workoutMinutes: Int
        var activeEnergyKcal: Int
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private(set) var authorized = false

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: read)
            authorized = true
        } catch {
            authorized = false
        }
    }

    func todaySummary() async -> TodaySummary {
        async let steps = stepsToday()
        async let energy = activeEnergyToday()
        async let workout = workoutMinutesToday()
        return await TodaySummary(steps: steps, workoutMinutes: workout, activeEnergyKcal: energy)
    }

    private func stepsToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sumQuantity(type: type, unit: .count())
    }

    private func activeEnergyToday() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sumQuantity(type: type, unit: .kilocalorie())
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit) async -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let v = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: Int(v))
            }
            store.execute(q)
        }
    }

    private func workoutMinutesToday() async -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let mins = workouts.reduce(0.0) { $0 + $1.duration / 60 }
                cont.resume(returning: Int(mins))
            }
            store.execute(q)
        }
    }
    #else
    var authorized = false
    func requestAuthorization() async {}
    func todaySummary() async -> TodaySummary { TodaySummary(steps: 0, workoutMinutes: 0, activeEnergyKcal: 0) }
    #endif
}
