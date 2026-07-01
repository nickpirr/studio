//
//  GroupStudyViews.swift
//  studio
//
//  UI delle sessioni di gruppo: crea una stanza con codice invito,
//  unisciti a quella di un amico, lobby con partecipanti in tempo reale.
//

import SwiftUI

// MARK: - SHEET PRINCIPALE

struct GroupStudySheet: View {
    @ObservedObject var manager: StudyManager
    @ObservedObject var controller: GroupSessionController
    @Environment(\.dismiss) private var dismiss

    @State private var joinCode = ""
    @State private var showingCoursePicker = false
    @State private var errorMessage: String?
    @State private var isWorking = false
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if controller.room != nil {
                    GroupLobbyView(controller: controller)
                } else {
                    startScreen
                }
            }
            .navigationTitle("Studia con amici")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(controller.room != nil)
    }

    // MARK: Schermata iniziale

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 72, height: 72)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Sessioni condivise")
                        .font(.title3.bold())
                    Text("Studiate insieme con lo stesso timer: se uno mette in pausa, la pausa vale per tutti.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .flatDashboardCard(cornerRadius: 24)

                // Nome visibile agli amici
                VStack(alignment: .leading, spacing: 8) {
                    Text("IL TUO NOME")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Come ti vedranno gli amici", text: $controller.displayName)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.semibold))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .flatDashboardCard(cornerRadius: 24)

                // Crea stanza
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingCoursePicker = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crea una stanza")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Genera un codice da condividere")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .flatDashboardCard(cornerRadius: 24)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                // Unisciti con codice
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unisciti a una stanza")
                                .font(.headline)
                            Text("Inserisci il codice ricevuto da un amico")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        TextField("CODICE", text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($codeFieldFocused)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                            .onChange(of: joinCode) { _, newValue in
                                let cleaned = GroupSessionController.normalizeCode(newValue)
                                joinCode = String(cleaned.prefix(6))
                            }

                        Button {
                            joinTapped()
                        } label: {
                            if isWorking {
                                ProgressView()
                                    .frame(width: 52, height: 48)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                                    .frame(width: 52, height: 48)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(joinCode.count != 6 || isWorking)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .flatDashboardCard(cornerRadius: 24)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingCoursePicker) {
            GroupCoursePickerSheet(manager: manager) { course in
                showingCoursePicker = false
                createRoom(with: course)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func createRoom(with course: StudyCourse) {
        isWorking = true
        errorMessage = nil
        Task { @MainActor in
            defer { isWorking = false }
            do {
                _ = try await controller.createRoom(course: course)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func joinTapped() {
        codeFieldFocused = false
        isWorking = true
        errorMessage = nil
        Task { @MainActor in
            defer { isWorking = false }
            do {
                _ = try await controller.joinRoom(code: joinCode)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - PICKER MATERIA PER LA STANZA

struct GroupCoursePickerSheet: View {
    @ObservedObject var manager: StudyManager
    var onPick: (StudyCourse) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(manager.courses) { course in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onPick(course)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(course.color.gradient)
                                .frame(width: 38, height: 38)
                            Image(systemName: course.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(course.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Scegli la materia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

// MARK: - LOBBY

struct GroupLobbyView: View {
    @ObservedObject var controller: GroupSessionController
    @State private var isStarting = false

    var body: some View {
        Group {
            if let room = controller.room {
                lobbyContent(room)
            } else {
                ProgressView()
            }
        }
        .onAppear { controller.startPolling() }
        .onDisappear {
            // Il polling continua solo se la sessione sta per partire/è in corso.
            if controller.room?.phase != .running { controller.stopPolling() }
        }
        .onChange(of: controller.room?.phase) { _, newPhase in
            // L'host ha chiuso la stanza mentre eravamo in lobby: torna all'inizio.
            if newPhase == .ended { controller.clearRoomLocally() }
        }
    }

    private func lobbyContent(_ room: GroupRoomState) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Materia
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(room.courseColor.gradient)
                            .frame(width: 68, height: 68)
                        Image(systemName: room.courseIcon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(room.courseName)
                        .font(.title3.bold())
                    Text(room.isHostedByMe
                         ? "Condividi il codice: quando ci siete tutti, avvia la sessione."
                         : "In attesa che \(room.hostName) avvii la sessione…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .flatDashboardCard(cornerRadius: 24)

                // Codice invito
                VStack(spacing: 12) {
                    Text("CODICE INVITO")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Array(room.code.enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .frame(width: 42, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                    }

                    ShareLink(item: "Studia con me su Studio! Codice stanza: \(room.code)") {
                        Label("Invita gli amici", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(room.courseColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .flatDashboardCard(cornerRadius: 24)

                // Partecipanti (aggiornati dal polling)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PARTECIPANTI")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 7, height: 7)
                            Text("\(room.participants.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }

                    ForEach(room.participants, id: \.self) { name in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(room.courseColor.opacity(0.18))
                                    .frame(width: 34, height: 34)
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(room.courseColor)
                            }
                            Text(name)
                                .font(.body.weight(.medium))
                            if name == room.hostName {
                                Text("HOST")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(room.courseColor.opacity(0.16)))
                                    .foregroundStyle(room.courseColor)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .flatDashboardCard(cornerRadius: 24)
                .animation(.snappy, value: room.participants)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if room.isHostedByMe {
                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        isStarting = true
                        Task { @MainActor in
                            await controller.startSessionForEveryone()
                            isStarting = false
                        }
                    } label: {
                        Group {
                            if isStarting {
                                ProgressView().tint(.white)
                            } else {
                                Label("Inizia per tutti", systemImage: "play.fill")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(room.courseColor)
                    .disabled(isStarting)
                }

                Button(role: .destructive) {
                    Task { @MainActor in
                        await controller.leaveLobby()
                    }
                } label: {
                    Text(room.isHostedByMe ? "Chiudi la stanza" : "Esci dalla stanza")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }
}
