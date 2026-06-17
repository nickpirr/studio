//
//  WatchContentView.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//
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
import SwiftUI
import WatchConnectivity

struct WatchContentView: View {
    @EnvironmentObject var connector: WatchConnector
    
    private var stateDescription: String {
        switch WCSession.default.activationState {
        case .activated:   return "Connesso — in attesa di dati"
        case .inactive:    return "Inattivo"
        case .notActivated: return "Non attivato"
        @unknown default:  return "Stato sconosciuto"
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                if connector.sessionActive {
                    ActiveSessionWatchView()
                } else {
                    List(connector.courses) { course in
                        Button {
                            connector.startSession(course: course)
                        } label: {
                            HStack {
                                Image(systemName: course.icon)
                                    .foregroundStyle(Presets.color(from: course.colorName))
                                Text(course.name)
                            }
                        }
                    }
                    .overlay {
                        if connector.courses.isEmpty {
                            VStack(spacing: 6) {
                                ContentUnavailableView("Nessuna materia", systemImage: "book.closed")
                                Text(WCSession.default.activationState == .activated ? "Sessione attiva" : "Non attivata")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Studio")
                }
            }
        }
    }
}
