import AppKit
import UserNotifications

// MARK: - Notification Delegate (forces banner display when app is foreground)

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

let notificationDelegate = NotificationDelegate()

// MARK: - Notification Delivery

func resolveNotificationSound(_ sound: String?) -> UNNotificationSound? {
    guard let rawSound = sound?.trimmingCharacters(in: .whitespacesAndNewlines), !rawSound.isEmpty else {
        return nil
    }

    if rawSound == "default" {
        return .default
    }

    let lower = rawSound.lowercased()
    let normalized: String
    switch lower {
    case "info", "warning", "complete", "end":
        normalized = "\(lower).aiff"
    default:
        normalized = lower.hasSuffix(".aiff") ? lower : "\(lower).aiff"
    }

    let resourceName = normalized.replacingOccurrences(of: ".aiff", with: "")
    guard Bundle.main.url(forResource: resourceName, withExtension: "aiff") != nil else {
        fputs("Notification sound not found in bundle: \(normalized)\n", stderr)
        return .default
    }

    return UNNotificationSound(named: UNNotificationSoundName(rawValue: normalized))
}

func deliverNotification(title: String, subtitle: String, message: String,
                         sound: String?, groupId: String?, iconURL: String?,
                         completion: ((Error?) -> Void)? = nil) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.subtitle = subtitle
    content.body = message

    if let resolvedSound = resolveNotificationSound(sound) {
        content.sound = resolvedSound
    }

    if let gid = groupId, !gid.isEmpty {
        content.threadIdentifier = gid
    }

    if let urlStr = iconURL, !urlStr.isEmpty,
       let url = URL(string: urlStr),
       FileManager.default.fileExists(atPath: url.path) {
        if let attachment = try? UNNotificationAttachment(
            identifier: "icon", url: url, options: nil) {
            content.attachments = [attachment]
        }
    }

    let id = UUID().uuidString
    // Use time-interval trigger instead of nil for reliable banner display
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            fputs("Notification error: \(error.localizedDescription)\n", stderr)
        }
        completion?(error)
    }
}

// MARK: - Authorization

func requestAuthorization(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            fputs("Authorization error: \(error.localizedDescription)\n", stderr)
        }
        completion(granted)
    }
}

// MARK: - Direct Mode

func runDirect(args: [String]) {
    var title = ""
    var subtitle = ""
    var message = ""
    var sound: String?
    var groupId: String?
    var iconURL: String?

    var i = 0
    while i < args.count {
        switch args[i] {
        case "-title":
            i += 1; if i < args.count { title = args[i] }
        case "-subtitle":
            i += 1; if i < args.count { subtitle = args[i] }
        case "-message":
            i += 1; if i < args.count { message = args[i] }
        case "-sound":
            i += 1; if i < args.count { sound = args[i] }
        case "-group":
            i += 1; if i < args.count { groupId = args[i] }
        case "-contentImage":
            i += 1; if i < args.count { iconURL = args[i] }
        default:
            break
        }
        i += 1
    }

    guard !title.isEmpty || !message.isEmpty else {
        fputs("Usage: CCNotifier -title TITLE -message MESSAGE [-subtitle SUB] [-sound SOUND]\n", stderr)
        exit(1)
    }

    NSApplication.shared.setActivationPolicy(.accessory)
    UNUserNotificationCenter.current().delegate = notificationDelegate

    requestAuthorization { granted in
        if !granted {
            fputs("Notification permission denied\n", stderr)
            DispatchQueue.main.async { exit(2) }
            return
        }
        deliverNotification(
            title: title, subtitle: subtitle, message: message,
            sound: sound, groupId: groupId, iconURL: iconURL
        ) { _ in
            // Keep process alive slightly longer so banner/sound dispatch is stable.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                exit(0)
            }
        }
    }

    NSApplication.shared.run()
}

// MARK: - Entry Point

let arguments = Array(CommandLine.arguments.dropFirst())

if !arguments.isEmpty {
    runDirect(args: arguments)
} else {
    fputs("Usage: CCNotifier -title T -message M [-sound S] [-subtitle SUB]\n", stderr)
    exit(1)
}
