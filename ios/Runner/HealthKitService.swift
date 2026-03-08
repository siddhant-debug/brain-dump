import Foundation
import HealthKit
import Flutter

class HealthKitService {
    static let shared = HealthKitService()
    let healthStore = HKHealthStore()
    
    // Define the types we want to read
    private lazy var readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        // Adding dietaryWater to force the prompt to show up again
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(weight) }
        if let height = HKObjectType.quantityType(forIdentifier: .height) { types.insert(height) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        types.insert(HKObjectType.workoutType())
        return types
    }()
    
    init() {
        // Version-based re-auth migration.
        // Bump this number any time readTypes expands with new HK types.
        // When the stored version is lower, we reset the auth flag so the
        // next "Connect" tap fires a fresh HealthKit prompt with the full set.
        let currentReadTypesVersion = 3
        let storedVersion = UserDefaults.standard.integer(forKey: "healthkit_read_types_version")
        if storedVersion < currentReadTypesVersion {
            UserDefaults.standard.removeObject(forKey: "healthkit_auth_requested")
            UserDefaults.standard.set(currentReadTypesVersion, forKey: "healthkit_read_types_version")
            print("[HealthKitService] readTypes version bumped to \(currentReadTypesVersion) — auth reset, will re-prompt on next Connect tap.")
        }
    }
    
    func setupChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.braindump.health", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            if !HKHealthStore.isHealthDataAvailable() {
                result(FlutterError(code: "UNAVAILABLE", message: "HealthKit is not available on this device", details: nil))
                return
            }
            
            switch call.method {
            case "requestAuthorization":
                self.requestAuthorization(result: result)
            case "checkAuthorizationStatus":
                self.checkAuthorizationStatus(result: result)
            case "getHeartRate":
                self.getHeartRate(result: result)
            case "getHRV":
                self.getHRV(result: result)
            case "getSleep":
                self.getSleep(result: result)
            case "getSteps":
                self.getSteps(result: result)
            case "getActiveEnergy":
                self.getActiveEnergy(result: result)
            case "getWorkouts":
                self.getWorkouts(result: result)
            case "getMindfulness":
                self.getMindfulness(result: result)
            case "getRestingHeartRate":
                self.getRestingHeartRate(result: result)
            case "getWeight":
                self.getWeight(result: result)
            case "getHeight":
                self.getHeight(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func requestAuthorization(result: @escaping FlutterResult) {
        let types = readTypes
        
        healthStore.requestAuthorization(toShare: nil, read: types) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errMsg = "[HealthKitService] Auth error: \(error.localizedDescription)"
                    print(errMsg)
                    result(FlutterError(code: "AUTH_ERROR", message: errMsg, details: nil))
                } else {
                    // Critical: Mark that the prompt has been shown so checks pass from now on
                    UserDefaults.standard.set(true, forKey: "healthkit_auth_requested")
                    result(success)
                }
            }
        }
    }
    
    private func checkAuthorizationStatus(result: @escaping FlutterResult) {
        var statuses: [String: String] = [:]
        
        let hasPrompted = UserDefaults.standard.bool(forKey: "healthkit_auth_requested")
        if !hasPrompted {
            result(statuses) // Return empty so Dart knows it's not authorized
            return
        }

        for type in readTypes {
            let typeName = type.identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
                .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
                .replacingOccurrences(of: "HKWorkoutTypeIdentifier", with: "Workout")
            
            // We just assume authorized since the prompt was shown
            statuses[typeName] = "authorized"
        }
        
        result(statuses)
    }
    
    // MARK: - Queries
    
    private func isAuthorized() -> Bool {
        return UserDefaults.standard.bool(forKey: "healthkit_auth_requested")
    }
    
    private func getHeartRate(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getHeartRate skipped — not authorized yet")
            result(nil)
            return
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return result(nil) }
        
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        var finalResult: [String: Any] = [:]
        let group = DispatchGroup()
        
        // 1. Latest
        group.enter()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("[HealthKitService] getHeartRate (latest) error: \(error.localizedDescription)")
            }
            if let sample = samples?.first as? HKQuantitySample {
                finalResult["current"] = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }
            group.leave()
        }
        healthStore.execute(sampleQuery)
        
        // 2. Average
        group.enter()
        let statisticsQuery = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
            if let avg = statistics?.averageQuantity() {
                finalResult["avg_24h"] = avg.doubleValue(for: HKUnit(from: "count/min"))
            }
            group.leave()
        }
        healthStore.execute(statisticsQuery)
        
        group.notify(queue: .main) {
            print("[HealthKitService] getHeartRate -> \(finalResult)")
            result(finalResult.isEmpty ? nil : finalResult)
        }
    }
    
    private func getHRV(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getHRV skipped — not authorized yet")
            result(nil)
            return
        }
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return result(nil) }
        
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        var finalResult: [String: Any] = [:]
        let group = DispatchGroup()
        
        // 1. Latest
        group.enter()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                finalResult["current"] = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            }
            group.leave()
        }
        healthStore.execute(sampleQuery)
        
        // 2. Average
        group.enter()
        let statisticsQuery = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
            if let avg = statistics?.averageQuantity() {
                finalResult["avg_7d"] = avg.doubleValue(for: HKUnit.secondUnit(with: .milli))
            }
            group.leave()
        }
        healthStore.execute(statisticsQuery)
        
        group.notify(queue: .main) {
            print("[HealthKitService] getHRV -> \(finalResult)")
            result(finalResult.isEmpty ? nil : finalResult)
        }
    }
    
    private func getSleep(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getSleep skipped — not authorized yet")
            result(nil)
            return
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return result(nil) }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Apple Watch writes sleep data anchored to the previous night.
        // Use a 6pm-yesterday → noon-today window to reliably capture it
        // regardless of what time the user wakes up.
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 12  // noon today
        let windowEnd = calendar.date(from: components) ?? now
        let windowStart = calendar.date(byAdding: .hour, value: -18, to: windowEnd)! // 6pm yesterday
        
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            print("[HealthKitService] getSleep raw samples count: \(samples.count)")
            
            var total: TimeInterval = 0
            var deep: TimeInterval = 0
            var rem: TimeInterval = 0
            var awake: TimeInterval = 0
            
            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                if #available(iOS 16.0, *) {
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deep += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        rem += duration
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awake += duration
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                         HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        total += duration
                    default:
                        break
                    }
                } else {
                    if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        total += duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                        awake += duration
                    }
                }
            }
            total += deep + rem  // total = all sleep stages combined
            
            DispatchQueue.main.async {
                if total == 0 && awake == 0 {
                    print("[HealthKitService] getSleep -> nil (no samples in window \(windowStart) – \(windowEnd))")
                    result(nil)
                } else {
                    let dict: [String: Double] = [
                        "total_hours": total / 3600,
                        "deep_hours": deep / 3600,
                        "rem_hours": rem / 3600,
                        "awake_hours": awake / 3600
                    ]
                    print("[HealthKitService] getSleep -> \(dict)")
                    result(dict)
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func getSteps(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getSteps skipped — not authorized yet")
            result(nil)
            return
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return result(nil) }
        
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
            if let error = error {
                print("[HealthKitService] getSteps error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                if let sum = statistics?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    print("[HealthKitService] getSteps -> \(steps)")
                    result(steps)
                } else {
                    print("[HealthKitService] getSteps -> nil")
                    result(nil)
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func getActiveEnergy(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getActiveEnergy skipped — not authorized yet")
            result(nil)
            return
        }
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return result(nil) }
        
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
            DispatchQueue.main.async {
                if let sum = statistics?.sumQuantity() {
                    let kcal = sum.doubleValue(for: HKUnit.kilocalorie())
                    print("[HealthKitService] getActiveEnergy -> \(kcal) kcal")
                    result(kcal)
                } else {
                    print("[HealthKitService] getActiveEnergy -> nil")
                    result(nil)
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func getMindfulness(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getMindfulness skipped — not authorized yet")
            result(nil)
            return
        }
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return result(nil) }
        
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            let lastSession = samples.first!
            let lastDuration = lastSession.endDate.timeIntervalSince(lastSession.startDate) / 60
            
            let weeklyTotal = samples.reduce(0.0) { result, sample in
                result + sample.endDate.timeIntervalSince(sample.startDate)
            } / 60
            
            DispatchQueue.main.async {
                let dict: [String: Double] = [
                    "last_session_minutes": lastDuration,
                    "weekly_total_minutes": weeklyTotal
                ]
                print("[HealthKitService] getMindfulness -> \(dict)")
                result(dict)
            }
        }
        healthStore.execute(query)
    }
    
    private func getWorkouts(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getWorkouts skipped — not authorized yet")
            result(nil)
            return
        }
        let type = HKObjectType.workoutType()
        
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let workout = samples?.first as? HKWorkout else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            var calories: Double? = nil
            if let energy = workout.totalEnergyBurned {
                calories = energy.doubleValue(for: HKUnit.kilocalorie())
            }
            
            let name = self.workoutName(for: workout.workoutActivityType)
            let duration = workout.duration / 60 // minutes
            
            DispatchQueue.main.async {
                let dict: [String: Any] = [
                    "type": name,
                    "duration_minutes": duration,
                    "calories": calories as Any
                ]
                print("[HealthKitService] getWorkouts -> \(dict)")
                result(dict)
            }
        }
        healthStore.execute(query)
    }
    
    private func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Functional Training"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }

    private func getRestingHeartRate(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getRestingHeartRate skipped — not authorized yet")
            result(nil)
            return
        }
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return result(nil) }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    print("[HealthKitService] getRestingHeartRate -> \(bpm)")
                    result(bpm)
                } else {
                    result(nil)
                }
            }
        }
        healthStore.execute(query)
    }

    private func getWeight(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getWeight skipped — not authorized yet")
            result(nil)
            return
        }
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return result(nil) }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let kg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    print("[HealthKitService] getWeight -> \(kg) kg")
                    result(kg)
                } else {
                    result(nil)
                }
            }
        }
        healthStore.execute(query)
    }

    private func getHeight(result: @escaping FlutterResult) {
        guard isAuthorized() else {
            print("[HealthKitService] getHeight skipped — not authorized yet")
            result(nil)
            return
        }
        guard let type = HKObjectType.quantityType(forIdentifier: .height) else { return result(nil) }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let cm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                    print("[HealthKitService] getHeight -> \(cm) cm")
                    result(cm)
                } else {
                    result(nil)
                }
            }
        }
        healthStore.execute(query)
    }
}