import Foundation
import EventKit
import Flutter

class SmartReminderService {
    static let shared = SmartReminderService()
    private let eventStore = EKEventStore()
    
    func setupChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.braindump.reminders", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "requestPermissions":
                self.requestPermissions(result: result)
            case "checkPermissions":
                self.checkPermissions(result: result)
            case "createReminder":
                if let args = call.arguments as? [String: Any] {
                    self.createReminder(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
                }
            case "openSettings":
                self.openSettings(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func requestPermissions(result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(granted)
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        result(granted)
                    }
                }
            }
        }
    }
    
    private func checkPermissions(result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            result("authorized")
        case .denied, .restricted:
            result("denied")
        case .notDetermined:
            result("notDetermined")
        @unknown default:
            result("unknown")
        }
    }
    
    private func createReminder(args: [String: Any], result: @escaping FlutterResult) {
        let title = args["title"] as? String ?? "Reminder"
        let triggerTimeStr = args["trigger_time"] as? String
        let recurrenceData = args["recurrence"] as? [String: Any]
        
        // Use a background queue for EventKit processing to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = title
            reminder.calendar = self.eventStore.defaultCalendarForNewReminders()
            
            // Parse date
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var parsedDate: Date? = nil
            if let timeStr = triggerTimeStr {
                print("[SmartReminderService] Incoming trigger_time: \(timeStr)")
                parsedDate = dateFormatter.date(from: timeStr)
                
                // Fallback for strings without fractional seconds if needed
                if parsedDate == nil {
                    let fallbackFormatter = ISO8601DateFormatter()
                    fallbackFormatter.formatOptions = [.withInternetDateTime]
                    parsedDate = fallbackFormatter.date(from: timeStr)
                }
            }

            if let date = parsedDate {
                let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                reminder.dueDateComponents = dueDateComponents
                
                // Add alarm
                let alarm = EKAlarm(absoluteDate: date)
                reminder.addAlarm(alarm)
            } else {
                print("[SmartReminderService] ERROR: Failed to parse date string: \(triggerTimeStr ?? "nil")")
            }
            
            // Handle recurrence
            if let rec = recurrenceData, let freqStr = rec["frequency"] as? String {
                let frequency: EKRecurrenceFrequency
                switch freqStr {
                case "daily": frequency = .daily
                case "weekly": frequency = .weekly
                case "monthly": frequency = .monthly
                default: frequency = .daily
                }
                
                let interval = rec["interval"] as? Int ?? 1
                
                var daysOfTheWeek: [EKRecurrenceDayOfWeek]? = nil
                if let days = rec["days_of_week"] as? [Int] {
                    daysOfTheWeek = days.compactMap { dayInt -> EKRecurrenceDayOfWeek? in
                        let ekWeekday: Int
                        if dayInt == 7 { ekWeekday = 1 } // Sun
                        else { ekWeekday = dayInt + 1 } // Mon(1)->2, Sat(6)->7
                        
                        if let weekday = EKWeekday(rawValue: ekWeekday) {
                            return EKRecurrenceDayOfWeek(weekday)
                        }
                        return nil
                    }
                }
                
                let rule = EKRecurrenceRule(
                    recurrenceWith: frequency,
                    interval: interval,
                    daysOfTheWeek: daysOfTheWeek,
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: nil
                )
                reminder.addRecurrenceRule(rule)
            }
            
            do {
                try self.eventStore.save(reminder, commit: true)
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func openSettings(result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            DispatchQueue.main.async {
                result(true)
            }
        } else {
            DispatchQueue.main.async {
                result(false)
            }
        }
    }
}
