//
//  ContentView.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/05/26.
//
//
//  ContentView.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/05/26.
//
import AppIntents
import UserNotifications
import SwiftUI
import ActivityKit
import Charts
import Combine
import WidgetKit
import MediaPlayer
import RealityKit
import SceneKit
extension Date: Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
// MARK: - PRESET PER ICONE E COLORI

struct Presets {
    static let icons = [
        // Studio
        "book.fill", "books.vertical.fill", "book.closed.fill", "graduationcap.fill",
        "pencil.and.outline", "pencil", "doc.fill", "doc.text.fill", "note.text",
        "folder.fill", "tray.fill", "archivebox.fill", "paperclip", "text.book.closed.fill",
        // Scienze
        "atom", "function", "sum", "percent", "chart.line.uptrend.xyaxis",
        "chart.pie.fill", "chart.bar.fill", "globe.europe.africa.fill", "globe.americas.fill",
        "leaf.fill", "brain.head.profile", "flask.fill", "testtube.2", "pills.fill",
        // Tech
        "desktopcomputer", "display", "laptopcomputer", "keyboard", "cpu.fill",
        "wifi", "antenna.radiowaves.left.and.right", "network", "server.rack",
        // Arte e musica
        "music.note", "music.note.list", "guitars.fill", "pianokeys", "paintbrush.fill",
        "paintpalette.fill", "camera.fill", "film.fill", "photo.fill",
        // Sport e salute
        "figure.walk", "figure.run", "figure.strengthtraining.traditional",
        "heart.fill", "cross.case.fill", "bandage.fill",
        // Varie
        "star.fill", "crown.fill", "trophy.fill", "target", "flame.fill",
        "bolt.fill", "map.fill", "mappin", "house.fill", "building.2.fill",
        "building.columns.fill", "gift.fill", "cart.fill", "bag.fill",
        "fork.knife", "cup.and.saucer.fill", "creditcard.fill",
        "headphones", "airpodspro", "speaker.wave.3.fill",
        "pawprint.fill", "tortoise.fill", "hare.fill",
        "moon.stars.fill", "sun.max.fill", "cloud.fill", "umbrella.fill",
        "bookmark.fill", "tag.fill", "bell.fill", "clock.fill", "calendar",
        "person.fill", "person.2.fill", "person.crop.circle.fill"
    ]

    static let colorNames: [String] = [
        "blue", "brown", "gray", "green", "indigo", "orange",
        "red", "purple", "pink", "cyan", "mint", "teal"
    ]

    static var colors: [Color] { colorNames.map { color(from: $0) } }

    static func color(from name: String) -> Color {
        switch name {
        case "blue":   return .blue
        case "brown":  return .brown
        case "gray":   return .gray
        case "green":  return .green
        case "indigo": return .indigo
        case "orange": return .orange
        case "red":    return .red
        case "purple": return .purple
        case "pink":   return .pink
        case "cyan":   return .cyan
        case "mint":   return .mint
        case "teal":   return .teal
        default:       return .blue
        }
    }

    static func name(from color: Color) -> String {
        switch color {
        case .blue:   return "blue"
        case .brown:  return "brown"
        case .gray:   return "gray"
        case .green:  return "green"
        case .indigo: return "indigo"
        case .orange: return "orange"
        case .red:    return "red"
        case .purple: return "purple"
        case .pink:   return "pink"
        case .cyan:   return "cyan"
        case .mint:   return "mint"
        case .teal:   return "teal"
        default:      return "blue"
        }
    }
}

// MARK: - MODELLO DATI
struct StudyCourse: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var colorName: String
    var studyGoalHoursWeekly: Int?

    var color: Color { Presets.color(from: colorName) }

    init(id: UUID = UUID(), name: String, icon: String, color: Color, studyGoalHoursWeekly: Int? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = Presets.name(from: color)
        self.studyGoalHoursWeekly = studyGoalHoursWeekly
    }

    init(id: UUID = UUID(), name: String, icon: String, colorName: String, studyGoalHoursWeekly: Int? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.studyGoalHoursWeekly = studyGoalHoursWeekly
    }
}

import SwiftUI



// MARK: - LOGICA DI SISTEMA (ViewModel)
class StudyManager: NSObject, ObservableObject {
    @Published var courses: [StudyCourse] = [] {
        didSet { saveCourses(); saveCoursesForWidget() }
    }
    
    // OGNI VOLTA CHE SI AGGIUNGE O RIMUOVE UNA SESSIONE, RICALCOLA AUTOMATICAMENTE LE MEDAGLIE
    @Published var completedSessions: [CompletedSession] = [] {
        didSet {
            saveSessions()
            recalculateMedalsRetroactively()
            syncStateToWatch()
        }
    }
    
    // Vettore pubblicato per le medaglie
    @Published var medals: [StudyMedal] = []

    override init() {
        self.courses = Self.load([StudyCourse].self, key: "savedCourses") ?? [
            StudyCourse(name: "Matematica", icon: "function", color: .blue, studyGoalHoursWeekly: 10),
            StudyCourse(name: "Storia", icon: "book.closed.fill", color: .orange, studyGoalHoursWeekly: 5)
        ]
        self.completedSessions = Self.load([CompletedSession].self, key: "savedSessions") ?? []
        super.init()
        saveCoursesForWidget()
        
        loadMedals()
        recalculateMedalsRetroactively()
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
   
    
    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func saveCourses()  { save(courses,           key: "savedCourses") }
    func saveSessions() { save(completedSessions, key: "savedSessions") }

    var totalMinutesToday: Int {
        completedSessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
    }

    func minutesStudiedThisWeek(for courseName: String) -> Int {
        guard let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return completedSessions
            .filter { $0.courseName == courseName && $0.date >= startOfWeek }
            .reduce(0) { $0 + $1.minutes }
    }

    func saveCoursesForWidget() {
        let widgetCourses = courses.map { WidgetCourse(name: $0.name, icon: $0.icon, colorName: $0.colorName) }
        guard let defaults = UserDefaults(suiteName: "group.com.niccolo.studio"),
              let data = try? JSONEncoder().encode(widgetCourses) else { return }
        defaults.set(data, forKey: "widgetCourses")
        WidgetCenter.shared.reloadAllTimelines()
        syncStateToWatch()   // ← aggiungi questa riga
    }
    
    // MARK: - MOTORE MEDAGLIE E SFONDI (CORRETTO)
    
    func loadMedals() {
        let defaults = [
            StudyMedal(id: "sessions_10", title: "Prime 10 Sessioni", subtitle: "Hai completato 10 sessioni in Focus", requirement: "Completa 10 sessioni in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: false),
            StudyMedal(id: "sessions_50", title: "Prime 50 Sessioni", subtitle: "Hai completato 50 sessioni in Focus", requirement: "Completa 50 sessioni in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: false),
            StudyMedal(id: "sessions_100", title: "Prime 100 Sessioni", subtitle: "Hai completato 100 sessioni in Focus", requirement: "Completa 100 sessioni in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: false),
            StudyMedal(id: "consecutive_1h", title: "1 Ora Consecutiva", subtitle: "Hai studiato per oltre 1 ora di fila!", requirement: "Sessione singola di oltre 1 ora in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: true),
            StudyMedal(id: "consecutive_2h", title: "2 Ore Consecutive", subtitle: "Hai studiato per oltre 2 ore di fila!", requirement: "Sessione singola di oltre 2 ore in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: true),
            StudyMedal(id: "consecutive_3h", title: "3 Ore Consecutive", subtitle: "Hai studiato per oltre 3 ore di fila!", requirement: "Sessione singola di oltre 3 ore in modalità Focus", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: true),
            StudyMedal(id: "weekly_goals", title: "Campione Settimanale", subtitle: "Hai raggiunto tutti i tuoi obiettivi", requirement: "Raggiungi tutti gli obiettivi di questa settimana", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: true),
            StudyMedal(id: "average_5h", title: "Stacanovista", subtitle: "Media superiore alle 5 ore giornaliere", requirement: "Media giornaliera di studio superiore a 5 ore", modelName: "MEDAGLIA_PRIMA_SESSIONE", isRepeatable: true)
        ]
        
        if let data = UserDefaults.standard.data(forKey: "studyMedals"),
           let decoded = try? JSONDecoder().decode([StudyMedal].self, from: data) {
            let loadedMap = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0.unlockCount) })
            self.medals = defaults.map { var m = $0; m.unlockCount = loadedMap[$0.id] ?? 0; return m }
        } else {
            self.medals = defaults
        }
    }

    func saveMedals() {
        if let data = try? JSONEncoder().encode(medals) {
            UserDefaults.standard.set(data, forKey: "studyMedals")
        }
    }

    // Analizza tutta la cronologia
    func recalculateMedalsRetroactively() {
        // Calendar condiviso (lunedì come primo giorno)
        var cal = Calendar.current
        cal.firstWeekday = 2

        // Conta solo le sessioni valide (Focus Mode attivo o vecchie sessioni senza il parametro)
        let focusSessions = completedSessions.filter { $0.wasFocusModeActive == true || $0.wasFocusModeActive == nil }
        let focusSessionsTotal = focusSessions.count

        var modified = false

        // 1. SBLOCCO PER NUMERO DI SESSIONI (10, 50, 100)
        if let idx = medals.firstIndex(where: { $0.id == "sessions_10" }), focusSessionsTotal >= 10, medals[idx].unlockCount == 0 {
            medals[idx].unlockCount = 1; modified = true
        }
        if let idx = medals.firstIndex(where: { $0.id == "sessions_50" }), focusSessionsTotal >= 50, medals[idx].unlockCount == 0 {
            medals[idx].unlockCount = 1; modified = true
        }
        if let idx = medals.firstIndex(where: { $0.id == "sessions_100" }), focusSessionsTotal >= 100, medals[idx].unlockCount == 0 {
            medals[idx].unlockCount = 1; modified = true
        }

        // 2. SBLOCCO PER DURATA DELLA SINGOLA SESSIONE (1h, 2h, 3h)
        // FIX: minutes è in MINUTI → soglie 60, 120, 180
        let count1h = focusSessions.filter { $0.minutes >= 60 }.count
        let count2h = focusSessions.filter { $0.minutes >= 120 }.count
        let count3h = focusSessions.filter { $0.minutes >= 180 }.count

        if let idx = medals.firstIndex(where: { $0.id == "consecutive_1h" }), medals[idx].unlockCount != count1h {
            medals[idx].unlockCount = count1h; modified = true
        }
        if let idx = medals.firstIndex(where: { $0.id == "consecutive_2h" }), medals[idx].unlockCount != count2h {
            medals[idx].unlockCount = count2h; modified = true
        }
        if let idx = medals.firstIndex(where: { $0.id == "consecutive_3h" }), medals[idx].unlockCount != count3h {
            medals[idx].unlockCount = count3h; modified = true
        }

        // 3. OBIETTIVI SETTIMANALI — conta quante settimane distinte tutti gli obiettivi erano soddisfatti
        let activeGoals = courses.filter { $0.studyGoalHoursWeekly != nil }
        if !activeGoals.isEmpty {
            let sessionsByWeek = Dictionary(grouping: focusSessions) { session -> Date in
                cal.dateInterval(of: .weekOfYear, for: session.date)?.start ?? cal.startOfDay(for: session.date)
            }
            var weeklyGoalCount = 0
            for (_, weekSessions) in sessionsByWeek {
                let allMet = activeGoals.allSatisfy { course in
                    let minutesInWeek = weekSessions
                        .filter { $0.courseName == course.name }
                        .reduce(0) { $0 + $1.minutes }
                    return minutesInWeek >= (course.studyGoalHoursWeekly! * 60)
                }
                if allMet { weeklyGoalCount += 1 }
            }
            if let idx = medals.firstIndex(where: { $0.id == "weekly_goals" }), medals[idx].unlockCount != weeklyGoalCount {
                medals[idx].unlockCount = weeklyGoalCount; modified = true
            }
        }

        // 4. MEDIA GIORNALIERA (5 ORE) — solo sessioni Focus
        let totalFocusMinutes = focusSessions.reduce(0) { $0 + $1.minutes }
        let uniqueDays = Set(focusSessions.map { cal.startOfDay(for: $0.date) }).count
        let avg5hCount = (uniqueDays > 0 && (totalFocusMinutes / uniqueDays) >= 300) ? 1 : 0
        if let idx = medals.firstIndex(where: { $0.id == "average_5h" }), medals[idx].unlockCount != avg5hCount {
            medals[idx].unlockCount = avg5hCount; modified = true
        }

        if modified { saveMedals() }
        
    }
    func requestFocusActivation(for courseName: String) {
            let intent = StudioFocusFilterIntent()
            intent.courseName = courseName
            Task {
                try? await intent.donate()
            }
        }
}
import WatchConnectivity

extension StudyManager: WCSessionDelegate {

    func activateWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        syncStateToWatch()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleWatchMessage(message) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { self.handleWatchMessage(userInfo) }
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard UserDefaults.standard.bool(forKey: "watchCompatibilityEnabled") else { return }
        guard let action = message["action"] as? String else { return }
        let defaults = WatchSync.defaults

        switch action {
        case "start":
            guard let courseName = message["courseName"] as? String,
                  let sessionID  = message["sessionID"] as? String,
                  let startDate  = message["startDate"] as? Double else { return }

            defaults?.set(courseName, forKey: WatchSync.keyCourseName)
            defaults?.set(true,       forKey: WatchSync.keySessionActive)
            defaults?.set(sessionID,  forKey: WatchSync.keySessionID)
            defaults?.set(startDate,  forKey: WatchSync.keyStartDate)
            defaults?.set(false,      forKey: WatchSync.keyIsPaused)
            defaults?.set(0,          forKey: WatchSync.keyPausedSeconds)
            defaults?.set(false,      forKey: WatchSync.keyStopRequested)

            NotificationCenter.default.post(
                name: .startSessionFromWatch, object: nil,
                userInfo: ["courseName": courseName]
            )

        case "stop":
            guard let sessionID = message["sessionID"] as? String else { return }
            defaults?.set(true,      forKey: WatchSync.keyStopRequested)
            defaults?.set(sessionID, forKey: WatchSync.keyStopSessionID)

            if UIApplication.shared.applicationState != .active {
                scheduleWatchStopNotification()
            }

        default: break
        }
    }

    private func scheduleWatchStopNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sessione interrotta"
        content.body = "Hai fermato la sessione da Apple Watch. Tocca per terminarla."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "watchStopSession", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Sincronizzazione iPhone → Watch (materie + grafico settimanale)
    func syncStateToWatch() {
        pushFullStateToWatch()
    }
    
}
func pushFullStateToWatch() {
    guard UserDefaults.standard.bool(forKey: "watchCompatibilityEnabled"),
          WCSession.isSupported(),
          WCSession.default.activationState == .activated
    else { return }

    let coursesRaw = UserDefaults.standard.data(forKey: "savedCourses")
    let courses = coursesRaw.flatMap { try? JSONDecoder().decode([StudyCourse].self, from: $0) } ?? []
    let watchCourses = courses.map { WatchCourseLite(name: $0.name, icon: $0.icon, colorName: $0.colorName) }
    guard let coursesData = try? JSONEncoder().encode(watchCourses) else { return }

    let sessionsRaw = UserDefaults.standard.data(forKey: "savedSessions")
    let sessions = sessionsRaw.flatMap { try? JSONDecoder().decode([CompletedSession].self, from: $0) } ?? []

    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let weeklyMinutes: [Int] = (0..<7).reversed().map { offset in
        guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
        return sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
    }

    let defaults = WatchSync.defaults
    let sessionActive = defaults?.bool(forKey: WatchSync.keySessionActive) ?? false
    let courseName    = defaults?.string(forKey: WatchSync.keyCourseName) ?? ""
    let sessionID     = defaults?.string(forKey: WatchSync.keySessionID) ?? ""
    let startDate     = defaults?.double(forKey: WatchSync.keyStartDate) ?? 0

    let context: [String: Any] = [
        "courses": coursesData,
        "weeklyMinutes": weeklyMinutes,
        "sessionActive": sessionActive,
        "courseName": courseName,
        "sessionID": sessionID,
        "startDate": startDate
    ]
    try? WCSession.default.updateApplicationContext(context)
}
extension Notification.Name {
    static let startSessionFromWatch = Notification.Name("startSessionFromWatch")
}
// MARK: - STRUCT DI SUPPORTO
struct PendingSession: Identifiable {
    let id = UUID()
    let course: StudyCourse
    let minutes: Int
}

// MARK: - VISTA PRINCIPALE
struct ContentView: View {
    // ECCO LE VARIABILI CHE ERANO SPARITE!
    @StateObject var manager = StudyManager()
    @State private var selectedCourse: StudyCourse?
    @State private var pendingSession: PendingSession?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView(manager: manager)
                .tabItem { Label("Riepilogo", systemImage: "chart.pie.fill") }
                .tag(0)

            LibraryView(manager: manager, selectedCourse: $selectedCourse)
                .tabItem { Label("Studia", systemImage: "book.fill") }
                .tag(1)

            SessionsView(manager: manager)
                .tabItem { Label("Sessioni", systemImage: "clock.fill") }
                .tag(2)

            ObiettiviView(manager: manager)
                .tabItem { Label("Bacheca", systemImage: "trophy.fill") }
                .tag(3)
        }
        .tint(.blue)
        .fullScreenCover(item: $selectedCourse) { course in
            ActiveWorkoutView(course: course) { minutes in
                selectedCourse = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    pendingSession = PendingSession(course: course, minutes: minutes)
                }
            }
        }
        .fullScreenCover(item: $pendingSession) { pending in
            // QUI RICEVIAMO I 5 PARAMETRI
            EndSessionView(course: pending.course, minutes: pending.minutes) { topic, comment, effort, concentration, satisfaction in
                let focusEnabled = UserDefaults.standard.bool(forKey: "isFocusModeEnabled")
                
                manager.completedSessions.append(CompletedSession(
                    courseIcon: pending.course.icon,
                    courseName: pending.course.name,
                    courseColor: pending.course.color,
                    minutes: pending.minutes,
                    date: Date(),
                    topic: topic,
                    comment: comment,
                    effort: effort,
                    concentration: concentration,
                    satisfaction: satisfaction,
                    wasFocusModeActive: focusEnabled
                ))
                pendingSession = nil
            }
        }
        .onOpenURL { url in
            if url.scheme == "studio" && url.host == "complete" {
                let defaults = AppConstants.sharedDefaults
                if let sessionData = defaults.dictionary(forKey: AppConstants.sharedSessionEndedToCompleteKey),
                   let courseName = sessionData["courseName"] as? String,
                   let minutes = sessionData["minutes"] as? Int,
                   let course = manager.courses.first(where: { $0.name == courseName }) {
                    
                    defaults.removeObject(forKey: AppConstants.sharedSessionEndedToCompleteKey)
                    
                    selectedTab = 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        pendingSession = PendingSession(course: course, minutes: minutes)
                    }
                }
                return
            }
            
            guard url.scheme == "studio",
                  url.host == "start",
                  let name = url.pathComponents.dropFirst().first?.removingPercentEncoding,
                  let course = manager.courses.first(where: { $0.name == name })
            else { return }
            
            let defaults = AppConstants.sharedDefaults
            let isSessionActive = defaults.bool(forKey: "sharedSessionActive")
            
            selectedTab = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if isSessionActive {
                    attemptToResumeSession()
                } else {
                    selectedCourse = course
                }
            }
        }
        .onAppear {
            checkPendingShortcut()
            attemptToResumeSession()
            manager.activateWatchConnectivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkPendingShortcut()
            attemptToResumeSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSessionFromWatch)) { notification in
            guard let courseName = notification.userInfo?["courseName"] as? String,
                  let course = manager.courses.first(where: { $0.name == courseName })
            else { return }
            selectedCourse = course
        }
    }
        
    private func attemptToResumeSession() {
        let defaults = AppConstants.sharedDefaults
        if defaults.bool(forKey: "sharedSessionActive") {
            let courseName = defaults.string(forKey: "sharedCourseName") ?? ""
            if let course = manager.courses.first(where: { $0.name == courseName }) {
                selectedCourse = course
            }
        }
    }

    private func checkPendingShortcut() {
        guard
            let defaults = UserDefaults(suiteName: AppConstants.suiteName),
            let name = defaults.string(forKey: "shortcutPendingCourse"),
            !name.isEmpty,
            let course = manager.courses.first(where: { $0.name == name })
        else { return }
        defaults.removeObject(forKey: "shortcutPendingCourse")
        selectedTab = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectedCourse = course
        }
    }
}
struct StudyMedal: Identifiable, Codable {
    var id: String
    var title: String
    var subtitle: String
    var requirement: String // <- REINSERITA
    var modelName: String
    var unlockCount: Int = 0
    var isRepeatable: Bool

    var isUnlocked: Bool {
        unlockCount > 0
    }
}

// MARK: - BACHECA MEDAGLIE
struct ObiettiviView: View {
    @ObservedObject var manager: StudyManager

    private var unlockedMedals: [StudyMedal] { manager.medals.filter { $0.isUnlocked } }
    private var lockedMedals:   [StudyMedal] { manager.medals.filter { !$0.isUnlocked } }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Sommario in cima ──────────────────────────────────
                    HStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(unlockedMedals.count)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                            Text("sbloccate")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Divider().frame(height: 40)
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(manager.medals.count)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("totali")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)

                    // ── Medaglie sbloccate ────────────────────────────────
                    if !unlockedMedals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Sbloccate", systemImage: "trophy.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                                .padding(.horizontal, 20)

                            VStack(spacing: 10) {
                                ForEach(unlockedMedals) { medal in
                                    MedalRowView(medal: medal)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }

                    // ── Medaglie bloccate ─────────────────────────────────
                    if !lockedMedals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Da sbloccare", systemImage: "lock.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 10) {
                                ForEach(lockedMedals) { medal in
                                    MedalRowView(medal: medal)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }

                    Text("Le medaglie si sbloccano completando sessioni in modalità Focus.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Bacheca")
            .onAppear {
                if manager.medals.isEmpty { manager.loadMedals() }
            }
        }
    }
}

// MARK: - RIGA MEDAGLIA
struct MedalRowView: View {
    let medal: StudyMedal
    @State private var showDetail = false

    private var medalGradient: LinearGradient {
        medal.isUnlocked
            ? LinearGradient(colors: [Color.yellow.opacity(0.28), Color.orange.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(.systemGray5).opacity(0.6), Color(.systemGray6).opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button {
            guard medal.isUnlocked else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showDetail = true
        } label: {
            HStack(spacing: 14) {

                // Icona medaglia
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(medalGradient)
                        .frame(width: 58, height: 58)

                    if medal.isUnlocked {
                        Image(systemName: "rosette")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: .orange.opacity(0.35), radius: 4, y: 2)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(.systemGray3))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if medal.isRepeatable && medal.unlockCount > 1 {
                        Text("×\(medal.unlockCount)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }

                // Testo
                VStack(alignment: .leading, spacing: 4) {
                    Text(medal.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(medal.isUnlocked ? .primary : .secondary)
                    Text(medal.isUnlocked ? medal.subtitle : medal.requirement)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if medal.isUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassEffect(
            medal.isUnlocked ? .regular.interactive() : .regular,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .sheet(isPresented: $showDetail) {
            MedalDetailSheet(medal: medal)
        }
    }
}

import SwiftUI
import SceneKit
import simd

// MARK: - SHEET DETTAGLIO MEDAGLIA 3D (TRACKBALL 360°, INERZIA PURA, NO GIMBAL LOCK)
struct MedalDetailSheet: View {
    let medal: StudyMedal
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    
    // Scena in memoria
    @State private var scene: SCNScene? = nil
    
    // Variabili per il nuovo motore fisico (Quaternioni)
    @State private var baseOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) // Rotazione neutrale di partenza
    @State private var isDragging: Bool = false
    
    // Timer per il rientro automatico
    @State private var resetWorkItem: DispatchWorkItem? = nil

    var body: some View {
        NavigationView {
            ZStack {
                // Sfondo scuro premium
                Color(red: 0.04, green: 0.04, blue: 0.06)
                    .ignoresSafeArea()

                if let activeScene = scene {
                    // Visualizzatore 3D
                    SceneView(
                        scene: activeScene,
                        options: []
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .contentShape(Rectangle()) // Rende tutto lo schermo "toccabile"
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let rotationNode = scene?.rootNode.childNode(withName: "rotationContainer", recursively: true) else { return }
                                
                                // Se abbiamo appena toccato lo schermo, fermiamo l'inerzia o il reset
                                if !isDragging {
                                    isDragging = true
                                    resetWorkItem?.cancel()
                                    
                                    // "Catturiamo" la rotazione esatta in cui si trova la medaglia a mezz'aria
                                    // "Catturiamo" la rotazione esatta in cui si trova la medaglia a mezz'aria
                                    baseOrientation = rotationNode.presentation.simdOrientation
                                }
                                
                                let sensitivity: Float = 0.008
                                let dragX = Float(value.translation.width) * sensitivity
                                let dragY = Float(value.translation.height) * sensitivity
                                
                                // Creiamo le rotazioni sui due assi dello schermo
                                let rotY = simd_quatf(angle: dragX, axis: SIMD3<Float>(0, 1, 0)) // Destra-Sinistra
                                let rotX = simd_quatf(angle: dragY, axis: SIMD3<Float>(1, 0, 0)) // Su-Giù
                                let combined = rotY * rotX
                                
                                // Moltiplichiamo per la posizione base catturata
                                // SCNTransaction a 0 rende il tocco del dito super reattivo e incollato
                                SCNTransaction.begin()
                                SCNTransaction.animationDuration = 0.0
                                rotationNode.simdOrientation = combined * baseOrientation
                                SCNTransaction.commit()
                            }
                            .onEnded { value in
                                isDragging = false
                                guard let rotationNode = scene?.rootNode.childNode(withName: "rotationContainer", recursively: true) else { return }
                                
                                // 2. FASE DI INERZIA (Calcolo del punto d'arrivo tramite predictedEndTranslation)
                                let sensitivity: Float = 0.008
                                let dragX = Float(value.predictedEndTranslation.width) * sensitivity
                                let dragY = Float(value.predictedEndTranslation.height) * sensitivity
                                
                                let rotY = simd_quatf(angle: dragX, axis: SIMD3<Float>(0, 1, 0))
                                let rotX = simd_quatf(angle: dragY, axis: SIMD3<Float>(1, 0, 0))
                                let combined = rotY * rotX
                                
                                // Rotazione finale calcolata per l'inerzia
                                let finalOrientation = combined * baseOrientation
                                
                                // Aggiorniamo la base in modo che il prossimo tocco parta da qui
                                baseOrientation = finalOrientation
                                
                                // Applichiamo l'animazione di attrito fisico
                                SCNTransaction.begin()
                                SCNTransaction.animationDuration = 1.0 // Durata rotolamento
                                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                                rotationNode.simdOrientation = finalOrientation
                                SCNTransaction.commit()
                                
                                // 3. PROGRAMMA IL RITORNO AUTOMATICO FRONTALMENTE
                                scheduleAutoReset(delay: 1.5)
                            }
                    )
                } else {
                    // Fallback errore
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.orange)
                        Text("Modello 3D non trovato").font(.headline).foregroundColor(.white)
                        Text("Controlla il file '\(medal.modelName).usdz'").font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                }

                // Card informativa
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text(medal.title).font(.system(.title2, design: .rounded).bold()).foregroundColor(.white)
                        Text(medal.subtitle).font(.system(.body, design: .rounded)).foregroundColor(.white.opacity(0.75)).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20).frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial).cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .padding(.horizontal, 20).padding(.bottom, 30)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
            }
            .navigationTitle("Medaglia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }.font(.headline).foregroundColor(.white)
                }
            }
            .environment(\.colorScheme, .dark)
            .onAppear {
                if scene == nil { scene = makeStudioScene() }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true }
            }
        }
    }
    
    // MARK: - MOTORE DI RITORNO AUTOMATICO (RESET 100% FLUIDO)
    private func scheduleAutoReset(delay: Double) {
        resetWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            guard let rotationNode = scene?.rootNode.childNode(withName: "rotationContainer", recursively: true) else { return }
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0 // Torna dritta dolcemente in 1 secondo
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // L'identità (r: 1, xyz: 0) è il valore di partenza frontale
            let identityQuat = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            rotationNode.simdOrientation = identityQuat
            
            SCNTransaction.commit()
            
            // Azzeriamo la memoria del tocco per essere allineati all'identità
            baseOrientation = identityQuat
        }
        
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - COSTRUZIONE DELLA SCENA E LUCI RADENTI
    private func makeStudioScene() -> SCNScene? {
        guard let baseScene = SCNScene(named: "\(medal.modelName).usdz") ?? SCNScene(named: medal.modelName) else {
            return nil
        }
        
        baseScene.background.contents = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
        
        // 1. IL NODO CHE RUOTERÀ IN 3D
        let rotationContainer = SCNNode()
        rotationContainer.name = "rotationContainer"
        
        // 2. LA MEDAGLIA INTERNA (Scala fissa 70%)
        let medalWrapper = SCNNode()
        let originalNodes = baseScene.rootNode.childNodes
        for node in originalNodes { medalWrapper.addChildNode(node) }
        
        medalWrapper.eulerAngles.x = Float.pi / 2
        medalWrapper.scale = SCNVector3(x: 0.7, y: 0.7, z: 0.7)
        
        rotationContainer.addChildNode(medalWrapper)
        baseScene.rootNode.addChildNode(rotationContainer)
        
        // 3. SET LUCI FOTOGRAFICHE RADENTI DI TRAVERSO (Non cambiate)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 150
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        baseScene.rootNode.addChildNode(ambientNode)
        
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 2200
        keyLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 3, 0)
        baseScene.rootNode.addChildNode(keyNode)
        
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 800
        fillLight.color = UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1.0)
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.eulerAngles = SCNVector3(Float.pi / 8, Float.pi / 3, 0)
        baseScene.rootNode.addChildNode(fillNode)
        
        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 1500
        rimLight.color = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.eulerAngles = SCNVector3(Float.pi / 6, Float.pi * 0.8, 0)
        baseScene.rootNode.addChildNode(rimNode)
        
        baseScene.lightingEnvironment.intensity = 1.5
        
        return baseScene
    }
}


// MARK: - RIEPILOGO
struct SummaryView: View {
    @ObservedObject var manager: StudyManager
    @State private var period = "G"
    let periods = ["G", "S", "M", "A"]

    @State private var showingSettings = false
    @State private var showingStudyDetail = false
    @State private var showingGradesDetail = false
    @State private var showingGoalsDetail = false

    // MARK: - DATI GRAFICO PRINCIPALE (riusato nello sheet espanso "Materie")
    var chartData: [CompletedSession] {
        let cal = Calendar.current
        let now = Date()
        let filtered: [CompletedSession]
        switch period {
        case "G": filtered = manager.completedSessions.filter { cal.isDateInToday($0.date) }
        case "S":
            guard let s = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            filtered = manager.completedSessions.filter { $0.date >= s }
        case "M":
            guard let s = cal.dateInterval(of: .month, for: now)?.start else { return [] }
            filtered = manager.completedSessions.filter { $0.date >= s }
        case "A":
            guard let s = cal.dateInterval(of: .year, for: now)?.start else { return [] }
            filtered = manager.completedSessions.filter { $0.date >= s }
        default: filtered = []
        }

        func bucket(for date: Date) -> Date {
            if period == "G" { return cal.dateInterval(of: .hour, for: date)?.start ?? date }
            if period == "S" || period == "M" { return cal.startOfDay(for: date) }
            return cal.dateInterval(of: .month, for: date)?.start ?? date
        }

        var aggregated: [String: CompletedSession] = [:]
        for session in filtered {
            let bDate = bucket(for: session.date)
            let key = "\(bDate.timeIntervalSince1970)_\(session.courseName)"
            if let existing = aggregated[key] {
                aggregated[key] = CompletedSession(
                    courseIcon: existing.courseIcon,
                    courseName: existing.courseName,
                    courseColor: existing.courseColor,
                    minutes: existing.minutes + session.minutes,
                    date: bDate
                )
            } else {
                aggregated[key] = CompletedSession(
                    courseIcon: session.courseIcon,
                    courseName: session.courseName,
                    courseColor: session.courseColor,
                    minutes: session.minutes,
                    date: bDate
                )
            }
        }
        return aggregated.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.courseName < $1.courseName
        }
    }

    var maxY: Int {
        var totals: [Date: Int] = [:]
        for s in chartData { totals[s.date, default: 0] += s.minutes }
        return max(60, Int(Double(totals.values.max() ?? 0) * 1.2))
    }

    var statTitle: String {
        switch period {
        case "G": return "Oggi"
        case "A": return "Media mensile"
        default:  return "Media giornaliera"
        }
    }

    var statValue: Int {
        let total = chartData.reduce(0) { $0 + $1.minutes }
        switch period {
        case "G": return total
        case "S": return total / 7
        case "M": return total / (Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30)
        case "A": return total / 12
        default:  return 0
        }
    }

    var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case "G":
            let s = cal.startOfDay(for: now)
            return s...cal.date(byAdding: .hour, value: 24, to: s)!
        case "S":
            let s = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return s...cal.date(byAdding: .day, value: 7, to: s)!
        case "M":
            let s = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let cnt = cal.range(of: .day, in: .month, for: now)!.count
            return s...cal.date(byAdding: .day, value: cnt, to: s)!
        case "A":
            let s = cal.date(from: cal.dateComponents([.year], from: now))!
            return s...cal.date(byAdding: .month, value: 12, to: s)!
        default: return now...now
        }
    }

    func formatTimeText(_ minutes: Int) -> String {
        let h = minutes / 60; let m = minutes % 60
        return h > 0 ? "\(h) h \(m) min" : "\(m) min"
    }

    // MARK: - DATI VOTI (per periodo, riusato nello sheet espanso "Voti")
    var gradesData: [CompletedSession] {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case "G": return manager.completedSessions.filter { cal.isDateInToday($0.date) }
        case "S":
            guard let s = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            return manager.completedSessions.filter { $0.date >= s }
        case "M":
            guard let s = cal.dateInterval(of: .month, for: now)?.start else { return [] }
            return manager.completedSessions.filter { $0.date >= s }
        case "A":
            guard let s = cal.dateInterval(of: .year, for: now)?.start else { return [] }
            return manager.completedSessions.filter { $0.date >= s }
        default: return []
        }
    }

    func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    // MARK: - BODY
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        weekStudyCardCompact
                        weekGradesCardCompact
                    }

                    weekComparisonCard
                    monthComparisonCard

                    goalsCardCompact
                }
                .padding(.horizontal)
                .padding(.top, 5)
            }
            .navigationTitle("Riepilogo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(manager: manager)
            }
            .sheet(isPresented: $showingStudyDetail) {
                studyDetailExpanded
            }
            .sheet(isPresented: $showingGradesDetail) {
                gradesDetailExpanded
            }
            .sheet(isPresented: $showingGoalsDetail) {
                goalsDetailExpanded
            }
        }
    }

    // MARK: - BADGE TREND
    private func trendBadge(deltaText: String, isUp: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(deltaText)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(isUp ? .green : .orange)
    }

    // MARK: - CARD COMPATTA 1: MATERIE — ULTIMA SETTIMANA
    private var weekStudyCardCompact: some View {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let prevWeekStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        let prevWeekEnd = weekStart

        let weekSessions = manager.completedSessions.filter { $0.date >= weekStart }
        let prevWeekSessions = manager.completedSessions.filter { $0.date >= prevWeekStart && $0.date < prevWeekEnd }

        let totalWeek = weekSessions.reduce(0) { $0 + $1.minutes }
        let totalPrevWeek = prevWeekSessions.reduce(0) { $0 + $1.minutes }

        let byCourse = Dictionary(grouping: weekSessions, by: { $0.courseName })
            .mapValues { $0.reduce(0) { $0 + $1.minutes } }
        let topCourseName = byCourse.max(by: { $0.value < $1.value })?.key

        // Totale minuti per ciascuno dei 7 giorni — sempre 7 valori, anche a 0
        let dailyTotals: [Int] = (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            return weekSessions.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
        }

        let delta = totalWeek - totalPrevWeek
        let percentChange: Double? = totalPrevWeek > 0 ? (Double(delta) / Double(totalPrevWeek)) * 100 : nil
        let isUp = delta >= 0

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingStudyDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Materie", systemImage: "book.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatTimeText(totalWeek))
                        .font(.system(size: 22, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if let percentChange = percentChange {
                        trendBadge(deltaText: "\(isUp ? "+" : "")\(Int(percentChange))%", isUp: isUp)
                    }
                }

                if let topCourseName = topCourseName {
                    Text("Più studiata: \(topCourseName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if weekSessions.isEmpty {
                    Text("Nessuna sessione questa settimana")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(height: 70)
                } else {
                    Chart {
                        ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, minutes in
                            BarMark(x: .value("Giorno", index), y: .value("Min", minutes))
                                .foregroundStyle(.blue)
                                .cornerRadius(3)
                        }
                    }
                    .chartXScale(domain: -0.5...6.5)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 70)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CARD COMPATTA 2: VOTI — ULTIMA SETTIMANA
    private var weekGradesCardCompact: some View {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let prevWeekStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        let prevWeekEnd = weekStart

        let weekSessions = manager.completedSessions.filter { $0.date >= weekStart }.sorted { $0.date < $1.date }
        let prevWeekSessions = manager.completedSessions.filter { $0.date >= prevWeekStart && $0.date < prevWeekEnd }

        let overallAverage = average(weekSessions.flatMap { [$0.effort, $0.concentration, $0.satisfaction] })
        let prevAverage = average(prevWeekSessions.flatMap { [$0.effort, $0.concentration, $0.satisfaction] })

        // Una media per ciascuno dei 7 giorni — sempre 7 valori (0 = nessuna sessione quel giorno)
        let dailyAverages: [Double] = (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            let daySessions = weekSessions.filter { cal.isDate($0.date, inSameDayAs: day) }
            return average(daySessions.flatMap { [$0.effort, $0.concentration, $0.satisfaction] })
        }
        let daysWithData = dailyAverages.filter { $0 > 0 }

        let avgEffort = average(weekSessions.map { $0.effort })
        let avgConcentration = average(weekSessions.map { $0.concentration })
        let avgSatisfaction = average(weekSessions.map { $0.satisfaction })
        let topStrength = [("Impegno", avgEffort), ("Concentrazione", avgConcentration), ("Soddisfazione", avgSatisfaction)]
            .max(by: { $0.1 < $1.1 })?.0

        let delta = overallAverage - prevAverage
        let hasPrev = !prevWeekSessions.isEmpty
        let isUp = delta >= 0

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingGradesDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Voti", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if weekSessions.isEmpty {
                        Text("—")
                            .font(.system(size: 22, design: .rounded).weight(.bold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: "%.1f / 10", overallAverage))
                            .font(.system(size: 22, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }

                    if hasPrev {
                        trendBadge(deltaText: "\(isUp ? "+" : "")\(String(format: "%.1f", delta))", isUp: isUp)
                    }
                }

                if let topStrength = topStrength, !weekSessions.isEmpty {
                    Text("Punto forte: \(topStrength)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if daysWithData.count < 2 {
                    Text(weekSessions.isEmpty ? "Nessun voto questa settimana" : "Servono più giorni")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(height: 70)
                } else {
                    Chart {
                        ForEach(Array(dailyAverages.enumerated()), id: \.offset) { index, value in
                            if value > 0 {
                                LineMark(x: .value("Giorno", index), y: .value("Media", value))
                                    .foregroundStyle(.yellow)
                                    .interpolationMethod(.catmullRom)
                                PointMark(x: .value("Giorno", index), y: .value("Media", value))
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .chartXScale(domain: -0.5...6.5)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 0...10)
                    .frame(height: 70)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CONFRONTO SETTIMANALE
    private var weekComparisonCard: some View {
        let cal = Calendar.current
        let now = Date()

        var calMon = cal
        calMon.firstWeekday = 2
        let thisWeekStart = calMon.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let daysSinceMonday = cal.dateComponents([.day], from: thisWeekStart, to: now).day ?? 0

        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: thisWeekStart) ?? now
        let lastWeekEquivalentEnd = cal.date(byAdding: .day, value: daysSinceMonday + 1, to: lastWeekStart) ?? now

        let thisWeekMinutes = manager.completedSessions
            .filter { $0.date >= thisWeekStart && $0.date <= now }
            .reduce(0) { $0 + $1.minutes }

        let lastWeekMinutes = manager.completedSessions
            .filter { $0.date >= lastWeekStart && $0.date < lastWeekEquivalentEnd }
            .reduce(0) { $0 + $1.minutes }

        let delta = thisWeekMinutes - lastWeekMinutes
        let percentChange: Double? = lastWeekMinutes > 0
            ? (Double(delta) / Double(lastWeekMinutes)) * 100
            : nil
        let isUp = delta >= 0

        return HStack(spacing: 16) {
            Image(systemName: isUp ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(isUp ? .green : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Rispetto alla scorsa settimana")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let percentChange = percentChange {
                    Text("\(isUp ? "+" : "")\(Int(percentChange))%  ·  \(formatTimeText(thisWeekMinutes)) finora")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                } else if thisWeekMinutes > 0 {
                    Text("\(formatTimeText(thisWeekMinutes)) finora, nessun dato la scorsa settimana")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                } else {
                    Text("Nessuna sessione questa settimana")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - CONFRONTO MENSILE
    private var monthComparisonCard: some View {
        let cal = Calendar.current
        let now = Date()

        let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
        let daysSinceMonthStart = cal.dateComponents([.day], from: thisMonthStart, to: now).day ?? 0

        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
        let lastMonthEquivalentEnd = cal.date(byAdding: .day, value: daysSinceMonthStart + 1, to: lastMonthStart) ?? now

        let thisMonthMinutes = manager.completedSessions
            .filter { $0.date >= thisMonthStart && $0.date <= now }
            .reduce(0) { $0 + $1.minutes }

        let lastMonthMinutes = manager.completedSessions
            .filter { $0.date >= lastMonthStart && $0.date < lastMonthEquivalentEnd }
            .reduce(0) { $0 + $1.minutes }

        let delta = thisMonthMinutes - lastMonthMinutes
        let percentChange: Double? = lastMonthMinutes > 0
            ? (Double(delta) / Double(lastMonthMinutes)) * 100
            : nil
        let isUp = delta >= 0

        return HStack(spacing: 16) {
            Image(systemName: isUp ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(isUp ? .green : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Rispetto al mese scorso")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let percentChange = percentChange {
                    Text("\(isUp ? "+" : "")\(Int(percentChange))%  ·  \(formatTimeText(thisMonthMinutes)) finora")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                } else if thisMonthMinutes > 0 {
                    Text("\(formatTimeText(thisMonthMinutes)) finora, nessun dato il mese scorso")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                } else {
                    Text("Nessuna sessione questo mese")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - CARD COMPATTA 3: OBIETTIVI (solo materie studiate oggi)
    private var goalsCardCompact: some View {
        let activeToday = manager.courses.filter { totalMinutesToday(for: $0.name) > 0 }

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingGoalsDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Obiettivi", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                if activeToday.isEmpty {
                    Text("Nessuna materia studiata oggi")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(activeToday) { course in
                            compactGoalRow(for: course)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func compactGoalRow(for course: StudyCourse) -> some View {
        let studiedMinutesWeek = manager.minutesStudiedThisWeek(for: course.name)
        let studiedHours = Double(studiedMinutesWeek) / 60.0
        let goal = course.studyGoalHoursWeekly
        let progress = goal != nil ? min(studiedHours / Double(goal!), 1.0) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(course.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let goal = goal {
                    Text(String(format: "%.1f/%d h", studiedHours, goal))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(course.color)
                } else {
                    Text(formatTimeText(totalMinutesToday(for: course.name)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(course.color)
                }
            }
            if goal != nil {
                GeometryReader { geo in
                    Capsule().fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Rectangle().fill(course.color).frame(width: geo.size.width * CGFloat(progress)),
                            alignment: .leading
                        )
                        .clipShape(Capsule())
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - FUNZIONI DI CALCOLO
    private func totalMinutesToday(for courseName: String) -> Int {
        manager.completedSessions
            .filter { Calendar.current.isDateInToday($0.date) && $0.courseName == courseName }
            .reduce(0) { $0 + $1.minutes }
    }

    // MARK: - SHEET ESPANSO 1: MATERIE (grafico completo, tutti i periodi)
    private var studyDetailExpanded: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Periodo", selection: $period) {
                        ForEach(periods, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 15)

                    Text(statTitle).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                    Text(formatTimeText(statValue))
                        .font(.system(size: 32, design: .rounded).weight(.bold))
                        .padding(.bottom, 20)

                    Chart {
                        ForEach(chartData) { session in
                            chartMark(for: session)
                        }
                    }
                    .chartForegroundStyleScale(
                        domain: manager.courses.map { $0.name },
                        range: manager.courses.map { $0.color }
                    )
                    .chartXScale(domain: xDomain)
                    .chartYScale(domain: 0...maxY)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { value in
                            AxisGridLine()
                            if let min = value.as(Int.self) {
                                AxisValueLabel {
                                    if min == 0 { Text("0") }
                                    else if min >= 60 {
                                        let h = min / 60; let r = min % 60
                                        Text(r == 0 ? "\(h)h" : "\(h)h\(r)m")
                                    } else { Text("\(min)m") }
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        switch period {
                        case "G": AxisMarks(values: .stride(by: .hour, count: 6)) { _ in AxisValueLabel(format: .dateTime.hour()); AxisGridLine() }
                        case "S": AxisMarks(values: .stride(by: .day, count: 1)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)); AxisGridLine() }
                        case "M": AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()); AxisGridLine() }
                        case "A": AxisMarks(values: .stride(by: .month, count: 1)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)); AxisGridLine() }
                        default: AxisMarks()
                        }
                    }
                    .frame(height: 200)

                    let periodTotals = Dictionary(grouping: chartData, by: { $0.courseName })
                        .mapValues { $0.reduce(0) { $0 + $1.minutes } }
                    if !periodTotals.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 15) {
                            ForEach(manager.courses) { course in
                                if let total = periodTotals[course.name], total > 0 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.name).font(.caption.bold()).foregroundColor(course.color)
                                        Text(formatTimeText(total)).font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(.top, 15)
                    }
                }
                .padding()
            }
            .navigationTitle("Materie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { showingStudyDetail = false }
                }
            }
        }
    }

    @ChartContentBuilder
    private func chartMark(for session: CompletedSession) -> some ChartContent {
        let date = session.date
        let minutes = session.minutes
        let course = session.courseName

        switch period {
        case "G":
            BarMark(x: .value("Ora", date, unit: .hour), y: .value("Min", minutes))
                .foregroundStyle(by: .value("Materia", course))
        case "S", "M":
            BarMark(x: .value("Giorno", date, unit: .day), y: .value("Min", minutes))
                .foregroundStyle(by: .value("Materia", course))
        default:
            BarMark(x: .value("Mese", date, unit: .month), y: .value("Min", minutes))
                .foregroundStyle(by: .value("Materia", course))
        }
    }

    // MARK: - SHEET ESPANSO 2: VOTI (generale, concentrazione, soddisfazione — tutti i periodi)
    private var gradesDetailExpanded: some View {
        let sessions = gradesData.sorted { $0.date < $1.date }
        let avgEffort = average(sessions.map { $0.effort })
        let avgConcentration = average(sessions.map { $0.concentration })
        let avgSatisfaction = average(sessions.map { $0.satisfaction })
        let avgOverall = average(sessions.flatMap { [$0.effort, $0.concentration, $0.satisfaction] })

        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Periodo", selection: $period) {
                        ForEach(periods, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 15)

                    Text("Voto medio generale").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                    Text(sessions.isEmpty ? "—" : String(format: "%.1f / 10", avgOverall))
                        .font(.system(size: 32, design: .rounded).weight(.bold))
                        .padding(.bottom, 20)

                    if sessions.isEmpty {
                        Text("Nessuna sessione in questo periodo.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        Chart {
                            ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                                LineMark(x: .value("Sessione", index), y: .value("Impegno", session.effort))
                                    .foregroundStyle(by: .value("Voto", "Impegno"))
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("Sessione", index), y: .value("Concentrazione", session.concentration))
                                    .foregroundStyle(by: .value("Voto", "Concentrazione"))
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("Sessione", index), y: .value("Soddisfazione", session.satisfaction))
                                    .foregroundStyle(by: .value("Voto", "Soddisfazione"))
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartForegroundStyleScale([
                            "Impegno": Color.orange,
                            "Concentrazione": Color.green,
                            "Soddisfazione": Color.blue
                        ])
                        .chartYScale(domain: 0...10)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: [0, 2, 4, 6, 8, 10])
                        }
                        .frame(height: 200)

                        HStack(spacing: 12) {
                            gradeStatBox(title: "Impegno", value: avgEffort, color: .orange)
                            gradeStatBox(title: "Concentrazione", value: avgConcentration, color: .green)
                            gradeStatBox(title: "Soddisfazione", value: avgSatisfaction, color: .blue)
                        }
                        .padding(.top, 15)
                    }
                }
                .padding()
            }
            .navigationTitle("Voti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { showingGradesDetail = false }
                }
            }
        }
    }

    private func gradeStatBox(title: String, value: Double, color: Color, fullWidth: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.system(size: 20, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        .frame(minWidth: fullWidth ? nil : 80)
        .background(color.opacity(0.12))
        .cornerRadius(14)
    }

    // MARK: - SHEET ESPANSO 3: OBIETTIVI (tutte le materie)
    private var goalsDetailExpanded: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if manager.courses.isEmpty {
                        Text("Nessuna materia registrata.").foregroundColor(.secondary)
                    } else {
                        ForEach(manager.courses) { course in
                            courseProgressRow(for: course)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Obiettivi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { showingGoalsDetail = false }
                }
            }
        }
    }

    private func courseProgressRow(for course: StudyCourse) -> some View {
        let totalMinToday = totalMinutesToday(for: course.name)
        let goalHours = course.studyGoalHoursWeekly
        let studiedMinutesWeek = manager.minutesStudiedThisWeek(for: course.name)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle().fill(course.color).frame(width: 15, height: 15)
                    Text(course.name).font(.headline)
                }
                Spacer()
                if totalMinToday > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        let h = totalMinToday / 60
                        let m = totalMinToday % 60
                        if h > 0 {
                            Text("\(h)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(course.color)
                            Text("H").font(.caption.bold()).foregroundColor(course.color).padding(.trailing, 2)
                        }
                        Text("\(m)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(course.color)
                        Text("MIN").font(.caption.bold()).foregroundColor(course.color)
                    }
                } else {
                    Text("Oggi: 0 min").font(.subheadline).foregroundColor(.secondary)
                }
            }

            if let goal = goalHours {
                let studiedHours = Double(studiedMinutesWeek) / 60.0
                let progress = min(studiedHours / Double(goal), 1.0)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Obiettivo settimanale").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f / %d ORE", studiedHours, goal))
                            .font(.caption.bold()).foregroundColor(course.color)
                    }
                    GeometryReader { geo in
                        Capsule().fill(Color.secondary.opacity(0.2))
                            .overlay(
                                Rectangle().fill(course.color).frame(width: geo.size.width * CGFloat(progress)),
                                alignment: .leading
                            )
                            .clipShape(Capsule())
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    }
                    .frame(height: 20)
                }
            }
        }
        .padding(.vertical, 4)
    }
}



// MARK: - STUDIA
struct LibraryView: View {
    @ObservedObject var manager: StudyManager
    @Binding var selectedCourse: StudyCourse?
    @State private var showingAddCourse = false
    @State private var editingCourse: StudyCourse?
    @State private var newCourseName = ""
    @State private var newCourseIcon = Presets.icons.first ?? "book.fill"
    @State private var newCourseColorName = Presets.colorNames.first ?? "blue"

    var body: some View {
        NavigationView {
            List {
                ForEach(manager.courses) { course in
                    CourseCardView(
                        course: course,
                        manager: manager,
                        onPlay: { selectedCourse = course },
                        onEdit: { editingCourse = course }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Button(action: { showingAddCourse = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundColor(.blue)
                        }
                        Text("Aggiungi materia")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(16)
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Studia")
            .sheet(item: $editingCourse) { course in
                EditCourseSheet(course: course, manager: manager)
            }
            .sheet(isPresented: $showingAddCourse) {
                AddCourseSheet(
                    manager: manager,
                    newCourseName: $newCourseName,
                    newCourseIcon: $newCourseIcon,
                    newCourseColorName: $newCourseColorName,
                    isPresented: $showingAddCourse
                )
            }
        }
    }
}

// MARK: - CARD CORSO
struct CourseCardView: View {
    let course: StudyCourse
    @ObservedObject var manager: StudyManager
    let onPlay: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icona Materia
            ZStack {
                Circle()
                    .fill(course.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: course.icon)
                    .foregroundColor(course.color)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(course.name).font(.system(.title3, design: .rounded).bold())
                if let goal = course.studyGoalHoursWeekly {
                    Text("Obiettivo: \(goal) ore/sett.").font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Nessun obiettivo").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    .frame(width: 34, height: 34).background(.ultraThinMaterial).clipShape(Circle())
            }
            .buttonStyle(.plain)                          // ← FIX
            .glassEffect(.regular.interactive(), in: Circle())

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(course.color)
                    .frame(width: 44, height: 44)
                    .background(course.color.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)                          // ← FIX
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        // ↓ RIMOSSO .contentShape — era la causa del problema di hit-testing
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { manager.courses.removeAll { $0.id == course.id } }
            } label: { Label("Elimina", systemImage: "trash") }
        }
    }
}

// MARK: - SHEET MODIFICA CORSO
struct EditCourseSheet: View {
    let course: StudyCourse
    @ObservedObject var manager: StudyManager
    @Environment(\.dismiss) private var dismiss

    @State private var tempGoal: Int
    @State private var tempIcon: String
    @State private var tempColorName: String
    @State private var tempName: String

    init(course: StudyCourse, manager: StudyManager) {
        self.course = course
        self.manager = manager
        _tempGoal      = State(initialValue: course.studyGoalHoursWeekly ?? 5)
        _tempIcon      = State(initialValue: course.icon)
        _tempColorName = State(initialValue: course.colorName)
        _tempName      = State(initialValue: course.name)
    }

    var tempColor: Color { Presets.color(from: tempColorName) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)
                    Text("Modifica materia").font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

                    ZStack {
                        Circle().fill(tempColor).frame(width: 90, height: 90)
                        Image(systemName: tempIcon).font(.system(size: 40)).foregroundColor(.white)
                    }.shadow(color: tempColor.opacity(0.4), radius: 12)

                    TextField("Nome materia", text: $tempName)
                        .multilineTextAlignment(.center)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .padding(14).background(.ultraThinMaterial).cornerRadius(14)
                        .padding(.horizontal, 40)

                    // Colori
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colore").font(.subheadline.bold()).foregroundColor(.secondary).padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(Presets.colorNames, id: \.self) { name in
                                Circle().fill(Presets.color(from: name)).frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: name == tempColorName ? 3 : 0).padding(-4))
                                    .onTapGesture { withAnimation { tempColorName = name } }
                            }
                        }
                    }.padding(.horizontal, 20)

                    // Icone
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icona").font(.subheadline.bold()).foregroundColor(.secondary).padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(Presets.icons, id: \.self) { icon in
                                ZStack {
                                    Circle().fill(icon == tempIcon ? tempColor : Color.secondary.opacity(0.1)).frame(width: 44, height: 44)
                                    Image(systemName: icon).font(.system(size: 18))
                                        .foregroundColor(icon == tempIcon ? .white : .secondary)
                                }
                                .overlay(Circle().stroke(tempColor, lineWidth: icon == tempIcon ? 2 : 0).padding(-3))
                                .onTapGesture { withAnimation { tempIcon = icon } }
                            }
                        }
                    }.padding(.horizontal, 20)

                    // Obiettivo
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Obiettivo settimanale").font(.subheadline.bold()).foregroundColor(.secondary).padding(.leading, 4)
                        HStack {
                            Button { if tempGoal > 1 { tempGoal -= 1 } } label: {
                                Image(systemName: "minus").font(.system(size: 16, weight: .bold))
                                    .frame(width: 44, height: 44).background(.ultraThinMaterial).clipShape(Circle())
                            }
                            Spacer()
                            Text("\(tempGoal) ore / settimana").font(.system(.title3, design: .rounded).bold())
                            Spacer()
                            Button { if tempGoal < 168 { tempGoal += 1 } } label: {
                                Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                                    .frame(width: 44, height: 44).background(.ultraThinMaterial).clipShape(Circle())
                            }
                        }
                        .padding(16).background(.ultraThinMaterial).cornerRadius(18)
                    }.padding(.horizontal, 20).padding(.bottom, 100)
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30).background(.ultraThinMaterial).clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4)
            }
            .padding(.top, 16).padding(.trailing, 20)
        }

        Button(action: {
            if let index = manager.courses.firstIndex(where: { $0.id == course.id }) {
                manager.courses[index].name = tempName
                manager.courses[index].icon = tempIcon
                manager.courses[index].colorName = tempColorName
                manager.courses[index].studyGoalHoursWeekly = tempGoal
            }
            dismiss()
        }) {
            Text("Salva").font(.headline.bold()).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(tempColor).cornerRadius(18)
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - SHEET AGGIUNGI CORSO
struct AddCourseSheet: View {
    @ObservedObject var manager: StudyManager
    @Binding var newCourseName: String
    @Binding var newCourseIcon: String
    @Binding var newCourseColorName: String
    @Binding var isPresented: Bool

    var newCourseColor: Color { Presets.color(from: newCourseColorName) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 16)
                    Text("Nuova materia").font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)

                    ZStack {
                        Circle().fill(newCourseColor).frame(width: 90, height: 90)
                        Image(systemName: newCourseIcon).font(.system(size: 40)).foregroundColor(.white)
                    }.shadow(color: newCourseColor.opacity(0.4), radius: 12)

                    TextField("Nome materia", text: $newCourseName)
                        .multilineTextAlignment(.center)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .padding(14).background(.ultraThinMaterial).cornerRadius(14)
                        .padding(.horizontal, 40)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colore").font(.subheadline.bold()).foregroundColor(.secondary).padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(Presets.colorNames, id: \.self) { name in
                                Circle().fill(Presets.color(from: name)).frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: name == newCourseColorName ? 3 : 0).padding(-4))
                                    .onTapGesture { withAnimation { newCourseColorName = name } }
                            }
                        }
                    }.padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icona").font(.subheadline.bold()).foregroundColor(.secondary).padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(Presets.icons, id: \.self) { icon in
                                ZStack {
                                    Circle().fill(icon == newCourseIcon ? newCourseColor : Color.secondary.opacity(0.1)).frame(width: 44, height: 44)
                                    Image(systemName: icon).font(.system(size: 18))
                                        .foregroundColor(icon == newCourseIcon ? .white : .secondary)
                                }
                                .overlay(Circle().stroke(newCourseColor, lineWidth: icon == newCourseIcon ? 2 : 0).padding(-3))
                                .onTapGesture { withAnimation { newCourseIcon = icon } }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 100)
                }
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30).background(.ultraThinMaterial).clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 4)
            }
            .padding(.top, 16).padding(.trailing, 20)
        }

        Button(action: {
            guard !newCourseName.isEmpty else { return }
            manager.courses.append(StudyCourse(name: newCourseName, icon: newCourseIcon, colorName: newCourseColorName, studyGoalHoursWeekly: 5))
            newCourseName = ""; newCourseIcon = Presets.icons.first ?? "book.fill"; newCourseColorName = Presets.colorNames.first ?? "blue"
            isPresented = false
        }) {
            Text("Crea materia").font(.headline.bold())
                .foregroundColor(newCourseName.isEmpty ? .gray : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(newCourseName.isEmpty ? Color.secondary.opacity(0.2) : newCourseColor)
                .cornerRadius(18)
        }
        .disabled(newCourseName.isEmpty)
        .padding(.horizontal, 20).padding(.bottom, 20)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - SCHERMATA SESSIONE ATTIVA
struct ActiveWorkoutView: View {
    let course: StudyCourse
    var onEnd: (Int) -> Void

    @AppStorage("useAlternativeViews") private var useAlternativeViews = false
    @AppStorage("selectedBackgroundId") private var selectedBackgroundId = "noir"
    @AppStorage("isFocusModeEnabled") private var isFocusModeEnabled: Bool = false
    @AppStorage("sharedIsPaused",      store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedIsPaused = false
    @AppStorage("sharedPausedSeconds", store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedPausedSeconds = 0
    @AppStorage("sharedStartDate",     store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedStartDate: Double = 0
    @AppStorage("sharedStopRequested", store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedStopRequested = false
    @AppStorage("sharedSessionActive", store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedSessionActive = false
    @AppStorage("sharedCourseName",    store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedCourseName = ""
    @AppStorage("sharedSessionID",     store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedSessionID = ""
    @AppStorage("sharedStopSessionID", store: UserDefaults(suiteName: "group.com.niccolo.studio")) var sharedStopSessionID = ""

    // MARK: - MOTORE TENDINA
    let compactHeight: CGFloat = 70
    let expandedHeight: CGFloat = 370

    @State private var targetHeight: CGFloat = 70
    @State private var dragTranslation: CGFloat = 0
    @State private var isExpanded: Bool = false
    @State private var safeAreaBottom: CGFloat = 34

    var currentHeight: CGFloat {
        let h = targetHeight - dragTranslation
        if h < compactHeight  { return compactHeight  - (compactHeight  - h) * 0.15 }
        if h > expandedHeight { return expandedHeight + (h - expandedHeight) * 0.15 }
        return h
    }

    var expansionProgress: CGFloat {
        max(0, min(1, (currentHeight - compactHeight) / (expandedHeight - compactHeight)))
    }

    private var cardHorizontalPadding: CGFloat { 28 - 16 * expansionProgress }
    private let screenCornerRadius: CGFloat = 44
    private var cardCornerRadius: CGFloat { max(8, screenCornerRadius - cardHorizontalPadding) }
    private var cardBottomPadding: CGFloat { cardHorizontalPadding - safeAreaBottom - 33 }

    // MARK: - TIMER
    @State private var startDate: Date = Date()
    @State private var pausedSeconds: Int = 0
    @State private var liveActivity: Activity<StudyActivityAttributes>? = nil
    @State private var secondsElapsed = 0
    @State private var isPaused = false
    @State private var hasStartedThisView = false

    // MARK: - PAUSA TIMER
    @State private var pauseEndDate: Date? = nil
    @State private var pauseTotalSeconds: Int = 0
    @State private var pauseRemainingSeconds: Int = 0
    @State private var activePauseMinutes: Int? = nil
    @State private var timeWithoutInteraction = 0
    @State private var isScreensaverActive = false

    @Environment(\.scenePhase) var scenePhase
    private let fluidSpring = Animation.interpolatingSpring(stiffness: 300, damping: 25)

    private var currentColorScheme: ColorScheme {
        if !useAlternativeViews { return .dark }
        return selectedBackgroundId == "light" ? .light : .dark
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            GeometryReader { geo in
                Color.clear
                    .onAppear { safeAreaBottom = geo.safeAreaInsets.bottom }
            }
            .ignoresSafeArea()

            // MARK: SFONDO
            Group {
                if useAlternativeViews,
                   let bg = AlternativeBackground.allBackgrounds.first(where: { $0.id == selectedBackgroundId }) {
                    if let img = bg.imageName {
                        Image(img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                            .clipped()
                            .ignoresSafeArea()
                    } else {
                        bg.color.ignoresSafeArea()
                    }
                } else {
                    Color.black.ignoresSafeArea()
                }
            }

            // MARK: CARD LIQUID GLASS
            VStack(spacing: 0) {

                Capsule()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 36, height: 5 * expansionProgress)
                    .padding(.top,    10 * expansionProgress)
                    .padding(.bottom, 12 * expansionProgress)
                    .opacity(Double(expansionProgress))

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatTime(secondsElapsed))
                            .font(.system(size: 46, weight: .semibold, design: .rounded).monospacedDigit())
                            .scaleEffect(0.70 + 0.30 * expansionProgress, anchor: .leading)
                            .foregroundColor(isPaused ? .primary : .yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(height: 46)

                        Text(course.name.uppercased())
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(course.color)
                            .frame(height: 18 * expansionProgress)
                            .opacity(Double(expansionProgress))
                            .clipped()
                    }

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isPaused.toggle()
                        if isPaused {
                            pausedSeconds = secondsElapsed
                            withAnimation(fluidSpring) { targetHeight = expandedHeight; isExpanded = true }
                        } else {
                            startDate = Date()
                            pauseEndDate = nil; activePauseMinutes = nil
                            withAnimation(fluidSpring) { targetHeight = compactHeight; isExpanded = false }
                        }
                        updateLiveActivity()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 50, height: 50)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())
                }
                .padding(.horizontal, 18)
                .padding(.top,    10 * (1 - expansionProgress))
                .padding(.bottom, 10 +  6 * expansionProgress)

                VStack(spacing: 10) {
                    pauseButton(minutes: 5,  icon: "cup.and.saucer.fill", label: "Pausa 5 minuti")
                    pauseButton(minutes: 10, icon: "cup.and.saucer.fill", label: "Pausa 10 minuti")
                    pauseButton(minutes: 15, icon: "cup.and.saucer.fill", label: "Pausa 15 minuti")

                    Button {
                        endSessionCleanly()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("Termina sessione")
                        }
                        .font(.headline.bold())
                        .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .glassEffect(
                        .regular.tint(.red.opacity(0.25)).interactive(),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .padding(.horizontal, 16)
                .opacity(Double(expansionProgress))

                Spacer(minLength: 0)
            }
            .frame(height: expandedHeight, alignment: .top)
            .frame(height: currentHeight,  alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .glassEffect(
                .regular.tint(.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            )
            .padding(.horizontal, cardHorizontalPadding)
            .padding(.bottom, cardBottomPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isExpanded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(fluidSpring) { targetHeight = expandedHeight; isExpanded = true }
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in dragTranslation = value.translation.height }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height
                        let projected = targetHeight - value.translation.height - velocity * 0.2
                        let threshold = (compactHeight + expandedHeight) / 2
                        withAnimation(fluidSpring) {
                            if projected > threshold { targetHeight = expandedHeight; isExpanded = true }
                            else                     { targetHeight = compactHeight;  isExpanded = false }
                            dragTranslation = 0
                        }
                    }
            )
            .environment(\.colorScheme, currentColorScheme)

            // MARK: SCREENSAVER ✅
            if isScreensaverActive {
                ZStack(alignment: .bottom) {
                    Color.black.ignoresSafeArea()

                    // Timer + icona nella STESSA posizione del timer nella card compatta.
                    //
                    // Derivazione geometrica:
                    //   Nel main ZStack (bottom = safeArea = 34pt dal bordo fisico):
                    //     cardBottomPadding = 28 - safeAreaBottom - 33 → card bottom = safeArea + |padding|
                    //     = 34 + (safeAreaBottom + 33 - 28) = 34 + safeAreaBottom + 5 - safeAreaBottom = 34 + 5
                    //     Indipendente dalla safeArea → card bottom è sempre 5pt SOTTO il bordo fisico.
                    //   Nello screensaver ZStack (ignoresSafeArea, bottom = bordo fisico = 0pt extra):
                    //     Per replicare "card bottom 5pt sotto bordo fisico" → padding(.bottom, -5).
                    //
                    //   padding(.horizontal, 28)  = cardHorizontalPadding in compact
                    //   padding(.horizontal, 18) interno = stesso inner padding dell'HStack del card
                    //   frame(height: compactHeight, alignment: .center) = stessa altezza card compatta
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: course.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(course.color.opacity(0.28))
                            .frame(height: 50) // stessa altezza del bottone nell'HStack originale

                        Text(formatTime(secondsElapsed))
                            .font(.system(size: 46, weight: .semibold, design: .rounded).monospacedDigit())
                            .scaleEffect(0.70, anchor: .leading) // identico alla card compatta
                            .foregroundColor(Color(white: 0.22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(height: 46)

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(height: compactHeight, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10) // card bottom è 5pt sotto il bordo fisico
                }
                .ignoresSafeArea()
                .zIndex(100)
                .transition(.opacity)
                .onTapGesture { wakeUpScreen() }
            }
        }
        // ✅ Nasconde orologio, batteria e segnale durante lo screensaver
        .statusBarHidden(isScreensaverActive)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isScreensaverActive { timeWithoutInteraction = 0 } }
        )
        .onAppear {
            guard !hasStartedThisView else { return }
            hasStartedThisView = true
            restoreOrStartSession()
            pushFullStateToWatch()
            Task {
                var intent = StudioFocusFilterIntent()
                intent.courseName = course.name
                try? await intent.donate()
            }
            if isFocusModeEnabled {
                UIApplication.perform(NSSelectorFromString("sharedApplication"))?
                    .takeUnretainedValue()
                    .perform(NSSelectorFromString("setIdleTimerDisabled:"), with: NSNumber(value: true))
            }
        }
        .onDisappear {
            UIApplication.perform(NSSelectorFromString("sharedApplication"))?
                .takeUnretainedValue()
                .perform(NSSelectorFromString("setIdleTimerDisabled:"), with: NSNumber(value: false))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { syncWithLiveActivityBackgroundChanges() }
            else if newPhase == .background {
                if isFocusModeEnabled && !isPaused {
                    isPaused = true; pausedSeconds = secondsElapsed
                    withAnimation(fluidSpring) { targetHeight = expandedHeight; isExpanded = true }
                    updateLiveActivity()
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isFocusModeEnabled {
                timeWithoutInteraction += 1
                if timeWithoutInteraction >= 180 && !isScreensaverActive {
                    withAnimation(.easeInOut(duration: 1.5)) { isScreensaverActive = true }
                }
            }
            if let endDate = pauseEndDate {
                let remaining = max(0, Int(endDate.timeIntervalSinceNow))
                pauseRemainingSeconds = remaining
                if remaining <= 0 {
                    pauseEndDate = nil; activePauseMinutes = nil
                    pauseTotalSeconds = 0; pauseRemainingSeconds = 0
                    isPaused = false; startDate = Date()
                    withAnimation(fluidSpring) { targetHeight = compactHeight; isExpanded = false }
                    updateLiveActivity()
                }
            }
            guard !isPaused else { return }
            syncWithLiveActivityBackgroundChanges()
            secondsElapsed = pausedSeconds + Int(Date().timeIntervalSince(startDate))
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.pauseSession)) { _ in
            Task { @MainActor in
                isPaused = true; pausedSeconds = secondsElapsed
                withAnimation(fluidSpring) { targetHeight = expandedHeight; isExpanded = true }
                updateLiveActivity()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.resumeSession)) { _ in
            Task { @MainActor in
                isPaused = false; startDate = Date()
                pauseEndDate = nil; activePauseMinutes = nil
                withAnimation(fluidSpring) { targetHeight = compactHeight; isExpanded = false }
                updateLiveActivity()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.stopSession)) { _ in
            Task { @MainActor in endSessionCleanly() }
        }
    }

    // MARK: - PULSANTE PAUSA
    @ViewBuilder
    private func pauseButton(minutes: Int, icon: String, label: String) -> some View {
        let isActive = activePauseMinutes == minutes
        let progress: Double = isActive && pauseTotalSeconds > 0
            ? max(0, 1.0 - Double(pauseRemainingSeconds) / Double(pauseTotalSeconds)) : 0.0

        Button { impostaPausaTimer(minuti: minutes) } label: {
            ZStack(alignment: .leading) {
                if isActive {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.blue.opacity(0.35))
                            .frame(width: geo.size.width * CGFloat(progress))
                            .animation(.linear(duration: 0.9), value: progress)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "timer" : icon)
                    Text(label)
                    Spacer()
                    if isActive && pauseRemainingSeconds > 0 {
                        Text(formatPauseTime(pauseRemainingSeconds))
                            .font(.system(.subheadline, design: .rounded).bold().monospacedDigit())
                            .foregroundColor(.blue.opacity(0.9))
                    }
                }
                .font(.headline.bold())
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .frame(height: 52)
        }
        .glassEffect(
            .regular.tint(isActive ? .blue.opacity(0.25) : .blue.opacity(0.08)).interactive(),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    // MARK: - FORMATTERS
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    private func formatPauseTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - LOGICA PAUSA TIMER
    private func impostaPausaTimer(minuti: Int) {
        isPaused = true; pausedSeconds = secondsElapsed
        activePauseMinutes = minuti; pauseTotalSeconds = minuti * 60
        pauseRemainingSeconds = minuti * 60
        pauseEndDate = Date().addingTimeInterval(TimeInterval(minuti * 60))
        updateLiveActivity()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "Pausa Terminata 📚"
        content.body = "La tua pausa di \(minuti) minuti è finita. Torna a concentrarti!"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "pause_reminder", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minuti * 60), repeats: false)
            ), withCompletionHandler: nil
        )
    }

    private func wakeUpScreen() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.5)) { isScreensaverActive = false }
        timeWithoutInteraction = 0
    }

    // MARK: - SESSION LOGIC
    func restoreOrStartSession() {
        let defaults = UserDefaults(suiteName: "group.com.niccolo.studio")
        if defaults?.bool(forKey: "sharedSessionActive") == true,
           defaults?.string(forKey: "sharedCourseName") == course.name {
            sharedIsPaused = defaults?.bool(forKey: "sharedIsPaused") ?? false
            sharedPausedSeconds = defaults?.integer(forKey: "sharedPausedSeconds") ?? 0
            sharedStartDate = defaults?.double(forKey: "sharedStartDate") ?? Date().timeIntervalSince1970
            isPaused = sharedIsPaused; pausedSeconds = sharedPausedSeconds
            if !isPaused {
                startDate = Date(timeIntervalSince1970: sharedStartDate)
                secondsElapsed = pausedSeconds + Int(Date().timeIntervalSince(startDate))
            } else { secondsElapsed = pausedSeconds }
            isExpanded = isPaused
            targetHeight = isPaused ? expandedHeight : compactHeight
            if let existing = Activity<StudyActivityAttributes>.activities.first { liveActivity = existing }
            else { requestNewLiveActivity() }
        } else { startFreshSession() }
    }

    func startFreshSession() {
        secondsElapsed = 0; isPaused = false; pausedSeconds = 0
        startDate = Date(); isExpanded = false; targetHeight = compactHeight
        let defaults = UserDefaults(suiteName: "group.com.niccolo.studio")
        let newID = UUID().uuidString
        defaults?.set(false,                        forKey: "sharedIsPaused")
        defaults?.set(0,                            forKey: "sharedPausedSeconds")
        defaults?.set(Date().timeIntervalSince1970, forKey: "sharedStartDate")
        defaults?.set(false,                        forKey: "sharedStopRequested")
        defaults?.set("",                           forKey: "sharedStopSessionID")
        defaults?.set(course.name,                  forKey: "sharedCourseName")
        defaults?.set(newID,                        forKey: "sharedSessionID")
        defaults?.set(true,                         forKey: "sharedSessionActive")
        sharedIsPaused = false; sharedPausedSeconds = 0
        sharedStartDate = Date().timeIntervalSince1970
        sharedStopRequested = false; sharedStopSessionID = ""
        sharedCourseName = course.name; sharedSessionID = newID; sharedSessionActive = true
        requestNewLiveActivity()
    }

    func requestNewLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task {
            for activity in Activity<StudyActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            let state = StudyActivityAttributes.ContentState(
                startDate: isPaused ? nil : startDate, accumulatedSeconds: pausedSeconds)
            do {
                liveActivity = try Activity.request(
                    attributes: StudyActivityAttributes(
                        courseName: course.name, courseColorHex: course.colorName,
                        courseIcon: course.icon, isFocusModeActive: isFocusModeEnabled),
                    content: .init(state: state, staleDate: nil))
            } catch { print("Errore Live Activity") }
        }
    }

    func endSessionCleanly() {
        Task { await liveActivity?.end(nil, dismissalPolicy: .immediate) }
        let defaults = UserDefaults(suiteName: "group.com.niccolo.studio")
        defaults?.set(false, forKey: "sharedSessionActive")
        defaults?.set(false, forKey: "sharedStopRequested")
        defaults?.set("",    forKey: "sharedCourseName")
        sharedSessionActive = false; sharedStopRequested = false
        onEnd(max(1, secondsElapsed / 60))
        pushFullStateToWatch()
    }

    func syncWithLiveActivityBackgroundChanges() {
        if sharedStopRequested && sharedStopSessionID == sharedSessionID { endSessionCleanly(); return }
        if sharedIsPaused != isPaused {
            isPaused = sharedIsPaused; pausedSeconds = sharedPausedSeconds
            if !isPaused { startDate = Date(timeIntervalSince1970: sharedStartDate) }
            secondsElapsed = isPaused ? pausedSeconds : pausedSeconds + Int(Date().timeIntervalSince(startDate))
            withAnimation(fluidSpring) {
                isExpanded = isPaused
                targetHeight = isPaused ? expandedHeight : compactHeight
            }
        }
    }

    func updateLiveActivity() {
        sharedIsPaused = isPaused; sharedPausedSeconds = pausedSeconds
        sharedStartDate = startDate.timeIntervalSince1970
        Task {
            await liveActivity?.update(.init(
                state: StudyActivityAttributes.ContentState(
                    startDate: isPaused ? nil : startDate, accumulatedSeconds: pausedSeconds),
                staleDate: nil))
        }
    }
}
struct SessionScoreRing: View {
    let effort: Int
    let concentration: Int
    let satisfaction: Int
    let score: Int
    var size: CGFloat = 45
    private var ringLineWidth: CGFloat { max(5, size * 0.075) }
    
    var body: some View {
        ZStack {
            ZStack {
                // Anello Impegno (Verde/Ciano)
                Circle()
                    .trim(from: 0.025, to: 0.308333333)
                    .stroke(Color.mint.opacity(0.2), style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0.025, to: 0.3083333333 * (Double(effort)/10.0))
                    .stroke(Color.mint, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                
                // Anello Concentrazione (Arancio/Rosso)
                Circle()
                    .trim(from: 0.358333333, to: 0.641666666)
                    .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0.358333333, to: 0.358333333 + (0.2833333333 * (Double(concentration)/10.0)))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                
                // Anello Soddisfazione (Blu/Indigo)
                Circle()
                    .trim(from: 0.69166666666, to: 0.975)
                    .stroke(Color.blue.opacity(0.2), style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0.6916666666, to: 0.691666666 + (0.2833333333 * (Double(satisfaction)/10.0)))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
            }
            .rotationEffect(.degrees(-90))
            
            Text("\(score)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
    }
}
// MARK: - SESSIONI PASSATE
import SwiftUI
// MARK: - DETTAGLIO GIORNATA CALENDARIO
// MARK: - DETTAGLIO GIORNATA CALENDARIO
// MARK: - DETTAGLIO GIORNATA CALENDARIO
struct DayDetailSheet: View {
    let day: Date
    let sessions: [CompletedSession]
    @ObservedObject var manager: StudyManager
    @Environment(\.dismiss) private var dismiss

    private func dayTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date).capitalized
    }

    var body: some View {
        NavigationView {
            List {
                if !sessions.isEmpty {
                    Section {
                        ForEach(sessions) { session in
                            SessionRowView(session: session, onDelete: {
                                withAnimation {
                                    manager.completedSessions.removeAll { $0.id == session.id }
                                }
                            })
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text(dayTitle(day))
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Nessuna sessione")
                            .font(.headline)
                        Text("Non hai studiato il \(dayTitle(day))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle(dayTitle(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
struct SessionsView: View {
    @State private var selectedDayForDetail: Date? = nil
    @ObservedObject var manager: StudyManager
    @State private var showingAddManual = false
    @State private var selectedMode: SessionCalendarMode = .week
    @State private var selectedDay = Date()
    @State private var visibleMonth = Date()
    @State private var visibleWeek = Date()

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "it_IT")
        cal.firstWeekday = 2
        return cal
    }

    private var daySessions: [CompletedSession] {
        manager.completedSessions
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    private var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: visibleWeek) ?? DateInterval(start: visibleWeek, duration: 7 * 24 * 60 * 60)
    }

    private var weekSessions: [CompletedSession] {
        manager.completedSessions
            .filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            // Il contenitore principale che occupa lo schermo
            ZStack(alignment: .top) {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                Group {
                    if selectedMode == .week {
                        weekBody
                            .transition(.opacity)
                    } else {
                        monthBody
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedMode)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Visualizzazione", selection: $selectedMode) {
                        ForEach(SessionCalendarMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingAddManual = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            
            // MARK: HEADERS FLUTTUANTI FISSATI AL FONDO
            // L'overlay non si deforma MAI, a prescindere dal calendario
            .overlay(alignment: .bottom) {
                Group {
                    if selectedMode == .week {
                        SessionWeekHeader(visibleWeek: $visibleWeek, interval: weekInterval)
                    } else if selectedMode == .month {
                        SessionMonthHeader(visibleMonth: $visibleMonth)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            .sheet(isPresented: $showingAddManual) {
                AddManualSessionSheet(manager: manager)
            }
            .sheet(item: $selectedDayForDetail) { day in
                let daySessions = manager.completedSessions
                    .filter { calendar.isDate($0.date, inSameDayAs: day) }
                    .sorted { $0.date > $1.date }
                
                DayDetailSheet(day: day, sessions: daySessions, manager: manager)
            }
        }
    }
   
    
    // MARK: - VISTA SETTIMANE
    private var weekBody: some View {
        List {
            

            let days = weekDays(in: weekInterval)
            ForEach(days, id: \.self) { day in
                let sessions = weekSessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
                if !sessions.isEmpty {
                    Section {
                        ForEach(sessions) { session in
                            SessionRowView(session: session, onDelete: {
                                withAnimation {
                                    manager.completedSessions.removeAll { $0.id == session.id }
                                }
                            })
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text(dayTitle(day))
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .padding(.bottom, 4)
                    }
                }
            }

            if weekSessions.isEmpty {
                EmptySessionsGlassView(
                    title: "Nessuna sessione in questa settimana",
                    subtitle: "Usa le frecce in basso per scorrere."
                )
                .padding(.top, 28)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Color.clear.frame(height: 120)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden) // Rende la List trasparente!
    }

    
    // MARK: - VISTA MESI (CALENDARIO SPOSTATO IN ALTO)
    private var monthBody: some View {
        VStack(spacing: 0) {
            // Ridotto al minimo lo spazio superiore per far risalire il calendario immediatamente sotto la barra di navigazione
            Color.clear.frame(height: 15)

            SessionMonthCalendar(
                sessions: manager.completedSessions,
                visibleMonth: $visibleMonth,
                selectedDay: $selectedDay,
                calendar: calendar,
                onDayTap: { day, daySessions in
                    selectedDayForDetail = day
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 15)

            Divider().opacity(0.1)

            List {
                
                
                // Spazio finale per non coprire le righe con i pulsanti fluttuanti in basso
                Color.clear.frame(height: 100)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    // MARK: - HELPERS
    private func weekDays(in interval: DateInterval) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func dayTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMM"
        return f.string(from: date).capitalized
    }
}

// MARK: - COMPONENTE CALENDARIO MENSILE FISSO
struct SessionMonthCalendar: View {
    let sessions: [CompletedSession]
    @Binding var visibleMonth: Date
    @Binding var selectedDay: Date
    let calendar: Calendar
    var onDayTap: ((Date, [CompletedSession]) -> Void)? = nil
    private let daysInWeek = 7
    private var today: Date { Date() }

    var body: some View {
        VStack(spacing: 0) {
            // Intestazione giorni della settimana
            HStack(spacing: 0) {
                let symbols = ["L", "M", "M", "G", "V", "S", "D"]
                ForEach(symbols.indices, id: \.self) { i in
                    Text(symbols[i])
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)

            Divider().opacity(0.15)

            // Griglia giorni
            let weeks = generateWeeks(for: visibleMonth)
            VStack(spacing: 0) {
                ForEach(weeks.indices, id: \.self) { wi in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<7) { di in
                            let day = weeks[wi][di]
                            CalendarDayCell(
                                    day: day,
                                    sessions: day.map { d in
                                        sessions.filter { calendar.isDate($0.date, inSameDayAs: d) }
                                    } ?? [],
                                    isSelected: day.map { calendar.isDate($0, inSameDayAs: selectedDay) } ?? false,
                                    isToday: day.map { calendar.isDate($0, inSameDayAs: today) } ?? false,
                                    isCurrentMonth: day.map { calendar.isDate($0, equalTo: visibleMonth, toGranularity: .month) } ?? false,
                                    onTap: { tappedDay in
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedDay = tappedDay
                                        let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: tappedDay) }
                                        onDayTap?(tappedDay, daySessions)
                                    }
                                )
                            
                        }
                    }

                    if wi < weeks.count - 1 {
                        Divider().opacity(0.1)
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Genera settimane come array di [Date?]
    private func generateWeeks(for date: Date) -> [[Date?]] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (weekday + 5) % 7

        var allDays: [Date?] = Array(repeating: nil, count: offset)
        for day in 0..<range.count {
            if let d = calendar.date(byAdding: .day, value: day, to: firstOfMonth) {
                allDays.append(d)
            }
        }

        // Riempi fino a multiplo di 7
        while allDays.count % 7 != 0 { allDays.append(nil) }

        return stride(from: 0, to: allDays.count, by: 7).map {
            Array(allDays[$0..<min($0 + 7, allDays.count)])
        }
    }
}

// MARK: - Cella giorno stile Apple Calendar
// MARK: - Cella giorno stile Apple Calendar
struct CalendarDayCell: View {
    let day: Date?
    let sessions: [CompletedSession]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    var onTap: ((Date) -> Void)? = nil

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Numero del giorno
            if let day = day {
                let num = Calendar.current.component(.day, from: day)
                Text("\(num)")
                    .font(.system(size: 13, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 26, height: 26)
                    .background {
                        if isToday {
                            Circle().fill(.red)
                        } else if isSelected {
                            Circle().fill(Color.primary.opacity(0.15))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Color.clear.frame(width: 26, height: 26)
            }

            // Pill sessioni
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(sessions.prefix(maxVisible).enumerated()), id: \.offset) { _, session in
                    SessionPill(session: session)
                }
                if sessions.count > maxVisible {
                    Text("+\(sessions.count - maxVisible) altre")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 113, alignment: .topLeading)
        .opacity(isCurrentMonth ? 1.0 : 0.3)
        .contentShape(Rectangle())                          // ← tutta la cella è tappabile
        .onTapGesture {
            if let day = day {
                onTap?(day)
            }
        }
    }
}

// MARK: - Pill singola sessione (stile Apple Calendar)
struct SessionPill: View {
    let session: CompletedSession

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(session.courseColor)
                .frame(width: 6, height: 6)

            Text(session.courseName)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(session.courseColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - ENUM CONVENIENTE
private enum SessionCalendarMode: String, CaseIterable, Identifiable, Hashable {
    case week = "Settimane"
    case month = "Mesi"
    var id: String { rawValue }
}

// MARK: - HEADERS FLUTTUANTI
private struct SessionWeekHeader: View {
    @Binding var visibleWeek: Date
    let interval: DateInterval
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian); cal.locale = Locale(identifier: "it_IT"); cal.firstWeekday = 2; return cal
    }
    var body: some View {
        HStack(spacing: 10) {
            Button { moveWeek(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                    .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            }.buttonStyle(.plain)
            
            Text(title).font(.system(.headline, design: .rounded).bold()).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 18).padding(.vertical, 10).background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.16), lineWidth: 1) }.shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            
            Button { moveWeek(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                    .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).background(Color.clear)
    }
    private var title: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateFormat = "d MMM"
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(f.string(from: interval.start)) – \(f.string(from: end))"
    }
    private func moveWeek(_ value: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        visibleWeek = calendar.date(byAdding: .weekOfYear, value: value, to: visibleWeek) ?? visibleWeek
    }
}

private struct SessionMonthHeader: View {
    @Binding var visibleMonth: Date
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian); cal.locale = Locale(identifier: "it_IT"); cal.firstWeekday = 2; return cal
    }
    var body: some View {
        HStack(spacing: 10) {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                    .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            }.buttonStyle(.plain)
            
            Text(title).font(.system(.headline, design: .rounded).bold()).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 18).padding(.vertical, 10).background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.16), lineWidth: 1) }.shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            
            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                    .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).background(Color.clear)
    }
    private var title: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth).capitalized
    }
    private func moveMonth(_ value: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }
}

// MARK: - ALTRI COMPONENTI DI SUPPORTO
private struct EmptySessionsGlassView: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.xmark").font(.system(size: 42, weight: .semibold)).foregroundStyle(.secondary)
            Text(title).font(.system(.headline, design: .rounded).bold())
            Text(subtitle).font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}

private struct HorizontalDayStrip: View {
    @Binding var selectedDay: Date
    let anchorDate: Date
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian); cal.locale = Locale(identifier: "it_IT"); cal.firstWeekday = 2; return cal
    }
    private var days: [Date] { (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: anchorDate) } }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(); selectedDay = day
                    } label: {
                        VStack(spacing: 7) {
                            Text(weekday(day)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                            Text("\(calendar.component(.day, from: day))")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(calendar.isDate(day, inSameDayAs: selectedDay) ? .white : .primary)
                                .frame(width: 42, height: 42)
                                .background { if calendar.isDate(day, inSameDayAs: selectedDay) { Circle().fill(Color.red.gradient) } }
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
    private func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateFormat = "E"
        return String(f.string(from: date).prefix(1)).uppercased()
    }
}

// Cella in stile APPLE CALENDAR per il MESE
private struct MonthDayCell: View {
    let day: Date
    let visibleMonth: Date
    let selectedDay: Date
    let sessions: [CompletedSession]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 14, weight: calendar.isDate(day, inSameDayAs: selectedDay) ? .bold : .medium, design: .rounded))
                .foregroundStyle(dayNumberColor)
                .frame(width: 24, height: 24)
                .background {
                    if calendar.isDate(day, inSameDayAs: selectedDay) {
                        Circle().fill(Color.red.opacity(0.85))
                    }
                }
                .padding(.top, 4).padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(sessions.prefix(3)) { session in
                    Text(compactSessionLabel(session))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 4).padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(session.courseColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                if sessions.count > 3 {
                    Text("+\(sessions.count - 3) altri")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary).padding(.leading, 4)
                }
            }
            .padding(.horizontal, 2)
            Spacer(minLength: 0)
        }
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(calendar.isDate(day, inSameDayAs: selectedDay) ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(calendar.isDate(day, inSameDayAs: selectedDay) ? Color.white.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 0.5)
        }
        .opacity(calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month) ? 1 : 0.38)
    }

    private var dayNumberColor: Color {
        if calendar.isDate(day, inSameDayAs: selectedDay) { return .white }
        return calendar.isDateInWeekend(day) ? .secondary : .primary
    }

    private func compactSessionLabel(_ session: CompletedSession) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: session.date)
        return "\(session.courseName)\n\(timeStr)"
    }
}
// MARK: - FOGLIO AGGIUNTA MANUALE
// MARK: - FOGLIO AGGIUNTA MANUALE
struct AddManualSessionSheet: View {
    @ObservedObject var manager: StudyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCourseId: UUID
    @State private var date = Date()
    @State private var hours = 1
    @State private var minutes = 0
    @State private var topic = ""
    @State private var comment = ""
    
    // Nuovi stati Apple-style
    @State private var effort = 5
    @State private var concentration = 5
    @State private var satisfaction = 5
    
    init(manager: StudyManager) {
        self.manager = manager
        _selectedCourseId = State(initialValue: manager.courses.first?.id ?? UUID())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Materia")) {
                    Picker("Materia", selection: $selectedCourseId) {
                        ForEach(manager.courses) { course in
                            Text(course.name).tag(course.id)
                        }
                    }
                    DatePicker("Data e Ora", selection: $date)
                }
                
                Section(header: Text("Durata")) {
                    Stepper("\(hours) ore", value: $hours, in: 0...24)
                    Stepper("\(minutes) minuti", value: $minutes, in: 0...59, step: 5)
                }
                
                Section(header: Text("Appunti")) {
                    TextField("Argomento (opzionale)", text: $topic)
                    TextField("Commento (opzionale)", text: $comment)
                }
                
                Section(header: Text("Valutazione (1-10)")) {
                    Stepper("Impegno: \(effort)", value: $effort, in: 1...10)
                    Stepper("Concentrazione: \(concentration)", value: $concentration, in: 1...10)
                    Stepper("Soddisfazione: \(satisfaction)", value: $satisfaction, in: 1...10)
                }
            }
            .navigationTitle("Aggiungi Manualmente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveSession()
                        dismiss()
                    }
                    .disabled(hours == 0 && minutes == 0)
                }
            }
        }
    }
    
    private func saveSession() {
        guard let course = manager.courses.first(where: { $0.id == selectedCourseId }) else { return }
        let totalMinutes = (hours * 60) + minutes
        
        manager.completedSessions.append(CompletedSession(
            courseIcon: course.icon,
            courseName: course.name,
            courseColor: course.color,
            minutes: totalMinutes,
            date: date,
            topic: topic,
            comment: comment,
            effort: effort,
            concentration: concentration,
            satisfaction: satisfaction
        ))
    }
}

// MARK: - RIGA SESSIONE
struct SessionRowView: View {
    let session: CompletedSession
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 15) {
            // Icona Materia
            ZStack {
                Circle()
                    .fill(session.courseColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: session.courseIcon)
                    .foregroundColor(session.courseColor)
                    .font(.title3)
            }

            // Dettagli Materia
            VStack(alignment: .leading, spacing: 4) {
                Text(session.courseName)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack {
                    Text("\(session.minutes) min")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(session.date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            SessionScoreRing(
                effort: session.effort,
                concentration: session.concentration,
                satisfaction: session.satisfaction,
                score: session.difficulty
            )
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingDetail = true
        }
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            SessionDetailView(session: session, onDelete: onDelete)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Elimina", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - DETTAGLIO SESSIONE
struct SessionDetailView: View {
    let session: CompletedSession
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Materia
                    VStack(spacing: 12) {
                        Image(systemName: session.courseIcon)
                            .font(.system(size: 50))
                            .foregroundColor(session.courseColor)
                        Text(session.courseName)
                            .font(.title.bold())
                        Text("\(session.minutes) minuti")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // IL NUOVO PANNELLO VALUTAZIONE
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Valutazione Sessione", systemImage: "chart.pie.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 30) {
                            SessionScoreRing(
                                effort: session.effort,
                                concentration: session.concentration,
                                satisfaction: session.satisfaction,
                                score: session.difficulty,
                                size: 90
                            )
                            
                            VStack(alignment: .leading, spacing: 12) {
                                DetailMetricRow(label: "Impegno", value: session.effort, color: .mint)
                                DetailMetricRow(label: "Concentrazione", value: session.concentration, color: .orange)
                                DetailMetricRow(label: "Soddisfazione", value: session.satisfaction, color: .blue)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)

                    // Argomento e Commenti (Se presenti)
                    if !session.topic.isEmpty || !session.comment.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            if !session.topic.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Argomento").font(.caption).foregroundColor(.secondary)
                                    Text(session.topic).font(.body)
                                }
                            }
                            if !session.comment.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Note").font(.caption).foregroundColor(.secondary)
                                    Text(session.comment).font(.body)
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    }

                    if onDelete != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Elimina sessione", systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .confirmationDialog("Eliminare questa sessione?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Elimina sessione", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Annulla", role: .cancel) { }
            }
        }
    }
}

// Sub-componente per le righine dei valori nel DetailView
struct DetailMetricRow: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(value)/10")
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }
}
// MARK: - MINI GRAFICO
struct MiniEffortGraph: View {
    let difficulty: Int
    
    let blocks = [3, 3, 2, 2]
    let gap: CGFloat = 2
    
    // Il raggio degli angoli, da cui deduciamo la larghezza della pila per un incastro perfetto
    let cornerRadius: CGFloat = 3
    var thumbW: CGFloat { cornerRadius * 2 } // 6px

    var thumbColor: Color {
        switch difficulty {
        case 1...2: return .cyan; case 3...4: return .teal
        case 5...6: return .purple; case 7...8: return .pink
        default: return .red
        }
    }

    func heightAt(x: CGFloat, w: CGFloat, h: CGFloat) -> CGFloat {
        let minH = h * 0.35
        return minH + (h - minH) * (x / w)
    }

    func blockInfo(for index: Int, unitW: CGFloat) -> (x: CGFloat, w: CGFloat) {
        var currentX: CGFloat = 0
        for i in 0..<index { currentX += CGFloat(blocks[i]) * unitW + gap }
        return (currentX, CGFloat(blocks[index]) * unitW)
    }

    // Nuova logica: i centri sono distanziati dai bordi esattamente del raggio dell'angolo!
    func stepCenter(for step: Int, unitW: CGFloat) -> CGFloat {
        let s = max(1, min(10, step))
        var currentStepCount = 0
        for i in 0..<blocks.count {
            let blockSteps = blocks[i]
            if s <= currentStepCount + blockSteps {
                let info = blockInfo(for: i, unitW: unitW)
                let positionInBlock = CGFloat(s - currentStepCount - 1)
                
                if blockSteps == 1 {
                    return info.x + info.w / 2
                } else {
                    let availableInnerW = info.w - (cornerRadius * 2)
                    let stepSpacing = availableInnerW / CGFloat(blockSteps - 1)
                    return info.x + cornerRadius + (positionInBlock * stepSpacing)
                }
            }
            currentStepCount += blockSteps
        }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let totalGaps = CGFloat(blocks.count - 1) * gap
            let unitW = (w - totalGaps) / 10.0

            ZStack(alignment: .bottomLeading) {
                ForEach(0..<blocks.count, id: \.self) { i in
                    let info = blockInfo(for: i, unitW: unitW)
                    let leftH = heightAt(x: info.x, w: w, h: h)
                    let rightH = heightAt(x: info.x + info.w, w: w, h: h)

                    SlantedRoundedRect(leftHeight: leftH, rightHeight: rightH, cornerRadius: cornerRadius)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: info.w, height: h)
                        .offset(x: info.x)
                }

                // Pila in miniatura
                let currentStep = max(1, min(10, difficulty))
                let thumbX = stepCenter(for: currentStep, unitW: unitW)
                let thumbH = heightAt(x: thumbX, w: w, h: h)

                Capsule()
                    .fill(thumbColor)
                    .frame(width: thumbW, height: thumbH)
                    .position(x: thumbX, y: h - thumbH / 2)
            }
        }
        .frame(width: 46, height: 22)
    }
}

// MARK: - EFFORT SLIDER
struct EffortSliderView: View {
    @Binding var difficulty: Int
    var isReadOnly: Bool = false

    let blocks = [3, 3, 2, 2]
    let gap: CGFloat = 8
    
    let cornerRadius: CGFloat = 14
    var thumbW: CGFloat { cornerRadius * 2 }

    var difficultyColor: Color {
        switch difficulty {
        case 1...2: return .cyan
        case 3...4: return .teal
        case 5...6: return .purple
        case 7...8: return .pink
        default: return .red
        }
    }

    func labelForDifficulty(_ d: Int) -> String {
        switch d {
        case 1, 2: return "Molto facile"
        case 3, 4: return "Facile"
        case 5, 6: return "Moderato"
        case 7, 8: return "Difficile"
        case 9: return "Estremo"
        case 10: return "Al massimo!"
        default: return "Facile"
        }
    }

    func heightAt(x: CGFloat, w: CGFloat, h: CGFloat) -> CGFloat {
        let minH = h * 0.30
        return minH + (h - minH) * (x / w)
    }

    func blockInfo(for index: Int, unitW: CGFloat) -> (x: CGFloat, w: CGFloat) {
        var currentX: CGFloat = 0
        for i in 0..<index { currentX += CGFloat(blocks[i]) * unitW + gap }
        return (currentX, CGFloat(blocks[index]) * unitW)
    }

    func stepCenter(for step: Int, unitW: CGFloat) -> CGFloat {
        let s = max(1, min(10, step))
        var currentStepCount = 0
        for i in 0..<blocks.count {
            let blockSteps = blocks[i]
            if s <= currentStepCount + blockSteps {
                let info = blockInfo(for: i, unitW: unitW)
                let positionInBlock = CGFloat(s - currentStepCount - 1)
                
                if blockSteps == 1 {
                    return info.x + info.w / 2
                } else {
                    let availableInnerW = info.w - (cornerRadius * 2)
                    let stepSpacing = availableInnerW / CGFloat(blockSteps - 1)
                    return info.x + cornerRadius + (positionInBlock * stepSpacing)
                }
            }
            currentStepCount += blockSteps
        }
        return 0
    }

    var body: some View {
        VStack(spacing: 30) {
            if !isReadOnly {
                Text("Valuta il tuo sforzo")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    // FORZATO AL BIANCO
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let totalGaps = CGFloat(blocks.count - 1) * gap
                let unitW = (w - totalGaps) / 10.0

                ZStack(alignment: .bottomLeading) {
                    // Blocchi Sfondo
                    ForEach(0..<blocks.count, id: \.self) { i in
                        let info = blockInfo(for: i, unitW: unitW)
                        let leftH = heightAt(x: info.x, w: w, h: h)
                        let rightH = heightAt(x: info.x + info.w, w: w, h: h)

                        SlantedRoundedRect(leftHeight: leftH, rightHeight: rightH, cornerRadius: cornerRadius)
                            // FORZATO AL BIANCO
                            .fill(isReadOnly ? difficultyColor.opacity(0.15) : Color.white.opacity(0.12))
                            .frame(width: info.w, height: h)
                            .offset(x: info.x)
                    }

                    // Puntini
                    ForEach(1...10, id: \.self) { s in
                        let cx = stepCenter(for: s, unitW: unitW)
                        Circle()
                            // FORZATO AL BIANCO
                            .fill(isReadOnly ? difficultyColor.opacity(0.35) : Color.white.opacity(0.25))
                            .frame(width: 4, height: 4)
                            .position(x: cx, y: h - 14)
                    }

                    // Pila Animata / Statica
                    let currentStep = max(1, min(10, difficulty))
                    let thumbX = stepCenter(for: currentStep, unitW: unitW)
                    let thumbH = heightAt(x: thumbX, w: w, h: h)

                    Capsule()
                        // FORZATO AL BIANCO
                        .fill(isReadOnly ? difficultyColor : Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .frame(width: thumbW, height: thumbH)
                        .position(x: thumbX, y: h - thumbH / 2)
                        .animation(isReadOnly ? .none : .spring(response: 0.35, dampingFraction: 0.75), value: difficulty)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !isReadOnly else { return }
                            let dragX = value.location.x
                            var closestStep = 1
                            var minD = CGFloat.infinity
                            
                            for s in 1...10 {
                                let cx = stepCenter(for: s, unitW: unitW)
                                let dist = abs(cx - dragX)
                                if dist < minD {
                                    minD = dist
                                    closestStep = s
                                }
                            }
                            
                            if difficulty != closestStep {
                                difficulty = closestStep
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            }
            .frame(height: 160)

            // Box Testuale Inferiore
            HStack(spacing: 12) {
                Text("\(max(1, difficulty))")
                    .font(.headline.bold())
                    // FORZATO AL BIANCO
                    .foregroundColor(isReadOnly ? difficultyColor : .white)
                    .frame(width: 32, height: 32)
                    // FORZATO AL BIANCO
                    .background(isReadOnly ? difficultyColor.opacity(0.2) : Color.white.opacity(0.2))
                    .clipShape(Circle())

                Text(labelForDifficulty(difficulty))
                    .font(.title3.weight(.medium))
                    // FORZATO AL BIANCO
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "info.circle")
                    // FORZATO AL BIANCO
                    .foregroundColor(isReadOnly ? difficultyColor.opacity(0.8) : Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // FORZATO AL BIANCO
            .background(isReadOnly ? difficultyColor.opacity(0.15) : Color.white.opacity(0.1))
            .cornerRadius(16)
        }
    }
}
// MARK: - FORMA GEOMETRICA: RETTANGOLO INCLINATO (Arrotondato Perfettamente)
struct SlantedRoundedRect: Shape {
    var leftHeight: CGFloat
    var rightHeight: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.width / 2)
        
        // Definiamo i 4 vertici ideali (spigolosi) del nostro blocco
        let bl = CGPoint(x: rect.minX, y: rect.maxY)                 // Bottom-Left
        let br = CGPoint(x: rect.maxX, y: rect.maxY)                 // Bottom-Right
        let tr = CGPoint(x: rect.maxX, y: rect.maxY - rightHeight)   // Top-Right
        let tl = CGPoint(x: rect.minX, y: rect.maxY - leftHeight)    // Top-Left
        
        // Partiamo dal centro della base inferiore
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        
        // SwiftUI calcolerà in automatico l'arco perfetto tra le due linee
        // indipendentemente dall'inclinazione del tetto. Niente più spigoli!
        path.addArc(tangent1End: br, tangent2End: tr, radius: r)
        path.addArc(tangent1End: tr, tangent2End: tl, radius: r)
        path.addArc(tangent1End: tl, tangent2End: bl, radius: r)
        path.addArc(tangent1End: bl, tangent2End: br, radius: r)
        
        path.closeSubpath()
        return path
    }
}
import SwiftUI

// MARK: - SLIDER CORRETTO
struct AppleStylePillSlider: View {
    @Binding var value: Int
    let label: String
    let color: Color
    let icon: String

    private let stepCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Label + valore numerico
            HStack {
                Image(systemName: icon)
                    .font(.system(.footnote, design: .rounded).bold())
                    .foregroundColor(color)
                Text(label)
                    .font(.system(.callout, design: .rounded).bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(value)/10")
                    .font(.system(.callout, design: .rounded).bold().monospacedDigit())
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                let thumbSize: CGFloat = 32
                let trackHeight: CGFloat = 32
                // ✅ trackWidth = spazio di viaggio effettivo del thumb
                let trackWidth = geo.size.width - thumbSize
                let step = trackWidth / CGFloat(stepCount)
                let positionIndex = value / 2
                let currentOffset = CGFloat(positionIndex) * step

                ZStack(alignment: .leading) {

                    // 1. Traccia sfondo
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    // 2. Traccia colorata
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: thumbSize + currentOffset, height: trackHeight)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: value)

                    // 3. ✅ PALLINI ALLINEATI PERFETTAMENTE:
                    // Centro pallino i = i*step + thumbSize/2
                    // = stesso del centro thumb alla posizione i
                    // Leading edge pallino (6pt) = i*step + thumbSize/2 - 3
                    ForEach(0...stepCount, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(i > positionIndex ? 0.55 : 0.0))
                            .frame(width: 6, height: 6)
                            .offset(x: CGFloat(i) * step + thumbSize / 2 - 3)
                    }

                    // 4. Thumb (sopra tutto)
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: currentOffset)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: value)
                }
                .frame(height: trackHeight)
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let adjustedX = v.location.x - thumbSize / 2
                            let percent = adjustedX / trackWidth
                            let snappedIndex = Int(round(percent * CGFloat(stepCount)))
                            let clamped = max(0, min(stepCount, snappedIndex))
                            let newValue = clamped * 2
                            if newValue != value {
                                value = newValue
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            }
            .frame(height: 32)
        }
    }
}

// MARK: - END SESSION VIEW
struct EndSessionView: View {
    let course: StudyCourse
    let minutes: Int
    var onSave: (String, String, Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var topic = ""
    @State private var comment = ""
    @State private var effort = 5
    @State private var concentration = 5
    @State private var satisfaction = 5

    private var dynamicVividColor: Color {
        let e = Double(effort)
        let c = Double(concentration)
        let s = Double(satisfaction)
        let total = e + c + s
        if total == 0 { return Color.blue }
        let r = ((e * 0.1) + (c * 0.6) + (s * 0.05)) / total
        let g = (0.9+(e * 0.6) + (c * 0.20) + (s * 0.10)) / total
        let b = ((e * 0.10) + (c * 0.2) + (s * 0.60)) / total
        let maxChannel = max(r, max(g, b))
        let boost = maxChannel > 0 ? (1.0 / maxChannel) : 1.0
        return Color(red: r * boost * 0.85, green: g * boost * 0.85, blue: b * boost * 0.85)
    }

    private var averageScore: Int { (effort + concentration + satisfaction) / 3 }

    private var formattedDuration: String {
        if minutes >= 60 {
            let h = minutes / 60; let m = minutes % 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        return "\(minutes) min"
    }

    var body: some View {
        ZStack {

            // MARK: SFONDO
            LinearGradient(
                colors: [
                    dynamicVividColor.opacity(0.90),
                    dynamicVividColor.opacity(0.85),
                    dynamicVividColor.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: dynamicVividColor)

            VStack(spacing: 0) {

                // MARK: HEADER
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())

                    Spacer()

                    Text("Fine Sessione")
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        onSave(topic, comment, effort, concentration, satisfaction)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(
                        .regular.tint(dynamicVividColor.opacity(0.5)).interactive(),
                        in: Circle()
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {

                        // MARK: CARD SOMMARIO
                        HStack(spacing: 16) {
                            // Icona corso
                            ZStack {
                                Image(systemName: course.icon)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.75))
                                Text(formattedDuration)
                                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                           
                            
                        }
                        .padding(20)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )

                        // MARK: CARD SLIDER
                        VStack(spacing: 26) {
                            AppleStylePillSlider(
                                value: $effort,
                                label: "Impegno",
                                color: .green,
                                icon: ""
                                
                            )
                            // Divider glass
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                            AppleStylePillSlider(
                                value: $concentration,
                                label: "Concentrazione",
                                color: .orange,
                                icon: ""
                            )
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                            AppleStylePillSlider(
                                value: $satisfaction,
                                label: "Soddisfazione",
                                color: .blue,
                                icon: ""
                            )
                        }
                        .padding(22)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )

                        // MARK: CAMPO ARGOMENTO
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.callout.bold())
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("Argomento trattato...", text: $topic)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white)
                                .tint(.white)
                                
                        }
                        .padding(18)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                        

                        // MARK: CAMPO NOTE
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "pencil")
                                .font(.callout.bold())
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.top, 2)
                            TextField("Note o commenti...", text: $comment, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.white)
                                .tint(.white)
                        }
                        .padding(18)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
// MARK: - IMPOSTAZIONI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: StudyManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    SettingsRow(title: "Notifiche", icon: "bell.fill", color: .red, destination: NotificationsSettingsView())
                    SettingsRow(title: "Focus", icon: "flame.fill", color: .orange, destination: focusSettingsView())
         
                    SettingsRow(title: "Vista studio", icon: "stopwatch.fill", color: .blue, destination: StudySettingsView(manager: manager))
                    SettingsRow(title: "Apple Watch", icon: "applewatch", color: .gray, destination: WatchSettingsView())
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
}
struct WatchSettingsView: View {
    @AppStorage("watchCompatibilityEnabled") private var watchCompatibilityEnabled = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $watchCompatibilityEnabled) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.gray)
                                .frame(width: 32, height: 32)
                            Image(systemName: "applewatch")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Compatibilità Apple Watch")
                            .font(.system(.body, design: .rounded))
                    }
                }
                .tint(.green)
            } footer: {
                Text("Avvia, ferma e monitora le sessioni di studio direttamente da Apple Watch. Il timer si sincronizza automaticamente in entrambe le direzioni.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - RIGA IMPOSTAZIONI STILE APPLE (AGGIORNATA)
struct SettingsRow<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(.body, design: .rounded))
            }
            .padding(.vertical, 4)
        }
    }
}


// MARK: - SCHERMATA NOTIFICHE CON MOTORE INTEGRATO (LIQUID GLASS FIX)
struct NotificationsSettingsView: View {
    // 1. ECCO LA SOLUZIONE NATIVA PER I WIDGET
    @Environment(\.openURL) var openURL
    
    @State private var isNotificationsEnabled = false
    @State private var showPermissionDeniedAlert = false
    
    var body: some View {
        ZStack {
            // Sfondo standard del raggruppamento per far risaltare il liquid glass
            
            List {
                Section {
                    Toggle(isOn: $isNotificationsEnabled) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.red)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Notifiche")
                                .font(.system(.body, design: .rounded))
                        }
                    }
                    .tint(.green)
                    .onChange(of: isNotificationsEnabled) { _, newValue in
                        handleToggleChange(newValue)
                    }
                } footer: {
                    Text("Ricevi promemoria giornalieri per ricordarti di studiare e rimanere in pari con i tuoi obiettivi settimanali.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notifiche")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkNotificationStatus()
            }
            .alert("Notifiche Disattivate", isPresented: $showPermissionDeniedAlert) {
                Button("Impostazioni") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        // 3. SOSTITUZIONE DI UIApplication.shared CON openURL
                        openURL(url)
                    }
                }
                Button("Annulla", role: .cancel) {
                    isNotificationsEnabled = false
                }
            } message: {
                Text("Le notifiche per l'app Studio sono disabilitate nelle impostazioni di sistema. Desideri abilitarle?")
            }
        }
    }
    // Controlla lo stato attuale del sistema operativo
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.isNotificationsEnabled = true
                } else {
                    self.isNotificationsEnabled = false
                }
            }
        }
    }
    
    // Gestisce lo switch dell'interruttore e l'aptica
    private func handleToggleChange(_ enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .denied {
                        self.showPermissionDeniedAlert = true
                        self.isNotificationsEnabled = false
                    } else if settings.authorizationStatus == .notDetermined {
                        self.requestNotificationPermission()
                    } else {
                        self.scheduleDailyReminder()
                    }
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // Richiesta nativa Apple dei permessi
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    self.isNotificationsEnabled = true
                    self.scheduleDailyReminder()
                } else {
                    self.isNotificationsEnabled = false
                }
            }
        }
    }
    
    // LOGICA DI PROGRAMMAZIONE
    private func scheduleDailyReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Ora di studiare! 📚"
        content.body = "Prenditi un momento oggi per far avanzare i tuoi obiettivi settimanali su Studio."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_study_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Errore inserimento notifica: \(error.localizedDescription)")
            }
        }
    }
}
struct focusSettingsView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("focusModeAutoActivate") private var focusModeAutoActivate = false

    var body: some View {
        List {
            // Sezione esistente — toggle Focus Mode
            Section {
                // ... il tuo toggle isFocusModeEnabled esistente
            }

            // NUOVA SEZIONE — Focus di sistema
            Section {
                Toggle(isOn: $focusModeAutoActivate) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.indigo)
                                .frame(width: 32, height: 32)
                            Image(systemName: "moon.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Attiva Focus di sistema")
                            .font(.system(.body, design: .rounded))
                    }
                }
                .tint(.indigo)

                if focusModeAutoActivate {
                    Button {
                        // Apre direttamente le impostazioni Focus del sistema
                        if let url = URL(string: "App-prefs:FOCUS") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            Text("Configura Focus nelle Impostazioni")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Focus di sistema")
            } footer: {
                Text("Quando avvii una sessione, Studio suggerisce al sistema di attivare il Focus che hai associato all'app. Configura il Focus 'Studio' nelle Impostazioni di sistema e aggiungi Studio alle app consentite per abilitarlo.")
                    .font(.system(.footnote, design: .rounded))
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct musicSeetingsView: View {
    // Usiamo AppStorage così la scelta si salva nel telefono e viene letta dalla sessione
    @AppStorage("showMusicPlayer") private var showMusicPlayer: Bool = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            List {
                Section {
                    Toggle(isOn: $showMusicPlayer) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.pink)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Mostra controlli musicali")
                                .font(.system(.body, design: .rounded))
                        }
                    }
                    .tint(.pink)
                } footer: {
                    Text("La musica può aiutare a concentrarsi. Se questa funzione è attiva, apparirà un player nativo in stile Liquid Glass durante la sessione di studio per controllare l'audio del telefono (Apple Music, Spotify, ecc.).")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Musica")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
// MODELLO PER GESTIRE GLI SFONDI ALTERNATIVI
// MODELLO PER GESTIRE GLI SFONDI ALTERNATIVI
// MODELLO PER GESTIRE GLI SFONDI ALTERNATIVI CON IMMAGINI E SBLOCCHI
struct AlternativeBackground: Identifiable {
    let id: String
    let name: String
    let color: Color
    let isLight: Bool
    var imageName: String? = nil // Nome della foto caricata nel progetto
    var requiredMedalId: String? = nil // ID della medaglia necessaria (nil = sempre sbloccato)
    
    static let allBackgrounds: [AlternativeBackground] = [
        AlternativeBackground(id: "noir", name: "Sfondo Scuro", color: .black, isLight: false),
        AlternativeBackground(id: "light", name: "Sfondo Chiaro", color: .white, isLight: true),
        
        // --- LA TUA FOTO PERSONALE SBLOCCATA CON LE PRIME 10 SESSIONI ---
        AlternativeBackground(
            id: "bg_miao",
            name: "Giove",
            color: .white,
            isLight: true,
            imageName: "VETRO", // IL NOME ESATTO DEL TUO FILE
            requiredMedalId: "sessions_10"
        ),
        
        // Puoi aggiungere qui sotto le altre foto man mano che le inserisci su Xcode:
        AlternativeBackground(
            id: "bg_50",
            name: "marea",
            color: .black.opacity(0),
            isLight: false,
            imageName: "ONDE", // Metti il nome della tua foto per le 50 sessioni
            requiredMedalId: "sessions_50"
        ),
        AlternativeBackground(
            id: "bg_100",
            name: "onde luminose",
            color: .black.opacity(0),
            isLight: false,
            imageName: "violanero", // Metti il nome della tua foto per le 50 sessioni
            requiredMedalId: "sessions_100"
        ),
        AlternativeBackground(
            id: "bg_1hr",
            name: "Notte stellata",
            color: .black.opacity(0),
            isLight: false,
            imageName: "STELLE", // Metti il nome della tua foto per le 50 sessioni
            requiredMedalId: "consecutive_1h"
        )
        ,
        AlternativeBackground(
            id: "bg_2hr",
            name: "Costa",
            color: .black.opacity(0),
            isLight: true,
            imageName: "COSTA", // Metti il nome della tua foto per le 50 sessioni
            requiredMedalId: "consecutive_2h"
        )
        ,
        AlternativeBackground(
            id: "bg_3hr",
            name: "miao?",
            color: .black.opacity(0),
            isLight: true,
            imageName: "MIAO", // Metti il nome della tua foto per le 50 sessioni
            requiredMedalId: "consecutive_3h"
        ),
        AlternativeBackground(
            id: "bg_giallo",
            name: "onde gialle",
            color: .white,
            isLight: true,
            imageName: "giallo", // IL NOME ESATTO DEL TUO FILE
            requiredMedalId: "sessions_10"
        ),
        AlternativeBackground(
            id: "bg_ledviola",
            name: "neon",
            color: .white,
            isLight: true,
            imageName: "ledviola", // IL NOME ESATTO DEL TUO FILE
            requiredMedalId: "sessions_10"
        ),
        AlternativeBackground(
            id: "bg_deserto",
            name: "albero",
            color: .white,
            isLight: true,
            imageName: "deserto5scuro", // IL NOME ESATTO DEL TUO FILE
            requiredMedalId: "sessions_10"
        ),
        AlternativeBackground(
            id: "bg_sahara",
            name: "deserto",
            color: .white,
            isLight: true,
            imageName: "deserto1", // IL NOME ESATTO DEL TUO FILE
            requiredMedalId: "sessions_10"
        )
    ]
}
// MARK: - SCHERMATA IMPOSTAZIONI VISTA STUDIO
struct StudySettingsView: View {
    @ObservedObject var manager: StudyManager // <-- Il cervello che legge le medaglie
    
    @AppStorage("useAlternativeViews") private var useAlternativeViews = false
    @AppStorage("selectedBackgroundId") private var selectedBackgroundId = "noir"
    @State private var previewingBackground: AlternativeBackground? = nil
    
    // Configurazione Griglia a 3 colonne
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            List {
                Section {
                    Toggle(isOn: $useAlternativeViews) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.blue).frame(width: 32, height: 32)
                                Image(systemName: "photo.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            }
                            Text("Sfondi personalizzati")
                                .font(.system(.body, design: .rounded))
                        }
                    }
                    .tint(.blue)
                } footer: {
                    Text("Attiva per cambiare lo sfondo delle tue sessioni di studio in corso.")
                        .font(.system(.footnote, design: .rounded))
                }
                
                if useAlternativeViews {
                    Section(header: Text("I tuoi Sfondi").font(.system(.caption, design: .rounded).bold()),
                            footer: Text("Ogni volta che ottieni una nuova Medaglia in Focus Mode, sbloccherai automaticamente un nuovo sfondo per le tue sessioni!").font(.system(.footnote, design: .rounded))) {
                        
                        // Sostituita la ScrollView orizzontale con una Griglia Verticale
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(AlternativeBackground.allBackgrounds) { bg in
                                let isUnlocked = bg.requiredMedalId == nil || (manager.medals.first(where: { $0.id == bg.requiredMedalId })?.isUnlocked ?? false)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    previewingBackground = bg
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Color.clear
                                                                                        .aspectRatio(1170.0 / 2532.0, contentMode: .fit)
                                                                                        .overlay(
                                                                                            Group {
                                                                                                if let img = bg.imageName, isUnlocked {
                                                                                                    Image(img)
                                                                                                        .resizable()
                                                                                                        .scaledToFill()
                                                                                                } else {
                                                                                                    bg.color
                                                                                                }
                                                                                            }
                                                                                        )
                                                                                        .overlay(
                                                                                            Group {
                                                                                                if !isUnlocked {
                                                                                                    ZStack {
                                                                                                        Color.black.opacity(0.6)
                                                                                                        Image(systemName: "lock.fill").font(.title3).foregroundColor(.white)
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        )
                                                                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                                                                        .overlay(
                                                                                            Group {
                                                                                                if selectedBackgroundId == bg.id {
                                                                                                    Image(systemName: "checkmark.circle.fill")
                                                                                                        .font(.body).foregroundColor(.green).background(Circle().fill(.white)).padding(6)
                                                                                                }
                                                                                            }, alignment: .topTrailing
                                                                                        )
                                        
                                        Text(bg.name)
                                            .font(.system(.caption, design: .rounded).weight(.semibold))
                                            .foregroundColor(isUnlocked ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!isUnlocked)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
            }
            .navigationTitle("Sfondi")
            .navigationBarTitleDisplayMode(.inline)
            
            .fullScreenCover(item: $previewingBackground) { bg in
                BackgroundPreviewCover(background: bg, selectedBackgroundId: $selectedBackgroundId)
            }
        }
    }
}

import SwiftUI

// MARK: - MODELLO COMPLETEDSESSION
struct CompletedSession: Identifiable, Codable {
    var id: UUID = UUID()
    var courseIcon: String
    var courseName: String
    var courseColorName: String
    var minutes: Int
    var date: Date
    var topic: String
    var comment: String
    
    // Nuovi valori 0-10
    var effort: Int          // Impegno
    var concentration: Int   // Concentrazione
    var satisfaction: Int    // Soddisfazione
    
    // Punteggio medio calcolato (per ring in stile Apple Watch)
    var difficulty: Int {
        let average = Double(effort + concentration + satisfaction) / 30.0
        return Int(average * 100)
    }
    
    var wasFocusModeActive: Bool?

    var courseColor: Color { Presets.color(from: courseColorName) }

    init(id: UUID = UUID(), courseIcon: String = "book.fill", courseName: String,
         courseColor: Color, minutes: Int, date: Date,
         topic: String = "", comment: String = "",
         effort: Int = 5, concentration: Int = 5, satisfaction: Int = 5,
         wasFocusModeActive: Bool? = false) {
        
        self.id = id
        self.courseIcon = courseIcon
        self.courseName = courseName
        self.courseColorName = Presets.name(from: courseColor)
        self.minutes = minutes
        self.date = date
        self.topic = topic
        self.comment = comment
        self.effort = effort
        self.concentration = concentration
        self.satisfaction = satisfaction
        self.wasFocusModeActive = wasFocusModeActive
    }
}

// MARK: - SCHERMATA DI PREVIEW (COMPATIBILE CON CHIARO E SCURO)
struct BackgroundPreviewCover: View {
    let background: AlternativeBackground
    @Binding var selectedBackgroundId: String
    @Environment(\.dismiss) private var dismiss
    
    let mockCourseName = "Matematica"
    let mockCourseIcon = "function"
    let mockCourseColor = Color.blue
    
    var body: some View {
        NavigationView {
                    ZStack(alignment: .bottom) {
                        // RENDERING IMMAGINE O COLORE
                        if let img = background.imageName {
                            GeometryReader { geo in
                                Image(img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                            .ignoresSafeArea()
                            
                            // Filtro scurito per far leggere i testi bianchi sopra la foto
                           
                        } else {
                            background.color.ignoresSafeArea()
                        }

            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedBackgroundId = background.id
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        // Forza la modalità della preview a seconda del colore dello sfondo (testi scuri su sfondo chiaro, testi chiari su sfondo scuro)
        .environment(\.colorScheme, background.isLight ? .light : .dark)
    }
}
import AppIntents

// MARK: - ENTITÀ MATERIA
