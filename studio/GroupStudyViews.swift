//
//  GroupStudyViews.swift
//  studio
//
//  UI delle sessioni di gruppo: crea una stanza con codice invito o unisciti
//  a quella di un amico. La stanza coordina solo il TIMER condiviso — ognuno
//  studia la propria materia, scelta personalmente nella lobby.
//

import SwiftUI

// Accento neutro delle sessioni di gruppo (la stanza non ha una materia).
private let groupAccent = Color.indigo

// MARK: - SHEET PRINCIPALE

struct GroupStudySheet: View {
    @ObservedObject var manager: StudyManager
    @ObservedObject var controller: GroupSessionController
    @Environment(\.dismiss) private var dismiss

    @State private var joinCode = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if controller.room != nil {
                    GroupLobbyView(manager: manager, controller: controller)
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
            VStack(spacing: 18) {
                // Hero
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(groupAccent.gradient)
                            .frame(width: 76, height: 76)
                            .shadow(color: groupAccent.opacity(0.3), radius: 10, y: 4)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Sessioni condivise")
                        .font(.title3.bold())
                    Text("Un timer unico per tutti: se uno mette in pausa, la pausa vale per tutti. Ognuno studia la propria materia.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)

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
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Crea stanza (nessuna scelta materia: la stanza è solo il timer)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    createRoom()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, groupAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crea una stanza")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Genera un codice da condividere")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.footnote.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                // Unisciti con codice
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unisciti a una stanza")
                                .font(.headline)
                            Text("Inserisci il codice ricevuto")
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
                                    .fill(Color(.tertiarySystemGroupedBackground))
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
                        .tint(.teal)
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
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private func createRoom() {
        isWorking = true
        errorMessage = nil
        Task { @MainActor in
            defer { isWorking = false }
            do {
                _ = try await controller.createRoom()
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

// MARK: - LOBBY

struct GroupLobbyView: View {
    @ObservedObject var manager: StudyManager
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
        .onAppear {
            controller.startPolling()
            ensureLocalCourseSelected()
        }
        .onDisappear {
            if controller.room?.phase != .running { controller.stopPolling() }
        }
        .onChange(of: controller.room?.phase) { _, newPhase in
            if newPhase == .ended { controller.clearRoomLocally() }
        }
    }

    /// Materia personale selezionata (default: la prima materia).
    private var selectedCourse: StudyCourse? {
        manager.courses.first(where: { $0.name == controller.localCourseName }) ?? manager.courses.first
    }

    private func ensureLocalCourseSelected() {
        if manager.courses.first(where: { $0.name == controller.localCourseName }) == nil {
            controller.localCourseName = manager.courses.first?.name ?? ""
        }
    }

    private func lobbyContent(_ room: GroupRoomState) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header stanza
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(groupAccent.gradient)
                            .frame(width: 70, height: 70)
                            .shadow(color: groupAccent.opacity(0.3), radius: 8, y: 3)
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(room.isHostedByMe ? "La tua stanza" : "Stanza di \(room.hostName)")
                        .font(.title3.bold())
                    Text(room.isHostedByMe
                         ? "Condividi il codice: quando ci siete tutti, avvia la sessione."
                         : "In attesa che \(room.hostName) avvii la sessione…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)

                // Codice invito
                VStack(spacing: 14) {
                    Text("CODICE INVITO")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Array(room.code.enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .frame(width: 42, height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemGroupedBackground))
                                )
                        }
                    }

                    ShareLink(item: "Studia con me su Studio! Codice stanza: \(room.code)") {
                        Label("Invita gli amici", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(groupAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // La materia di QUESTO partecipante
                mySubjectCard

                // Partecipanti
                participantsCard(room)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            bottomBar(room)
        }
    }

    // MARK: Card "la tua materia"
    private var mySubjectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LA TUA MATERIA")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("solo per te")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if manager.courses.isEmpty {
                Text("Aggiungi una materia per iniziare a studiare.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(manager.courses) { course in
                            subjectChip(course)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func subjectChip(_ course: StudyCourse) -> some View {
        let isSelected = selectedCourse?.id == course.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            controller.localCourseName = course.name
        } label: {
            HStack(spacing: 8) {
                Image(systemName: course.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : course.color)
                Text(course.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(course.color.gradient) : AnyShapeStyle(Color(.tertiarySystemGroupedBackground)))
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
    }

    // MARK: Card partecipanti
    private func participantsCard(_ room: GroupRoomState) -> some View {
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
                            .fill(groupAccent.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Text(String(name.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(groupAccent)
                    }
                    Text(name)
                        .font(.body.weight(.medium))
                    if name == room.hostName {
                        Text("HOST")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(groupAccent.opacity(0.16)))
                            .foregroundStyle(groupAccent)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .animation(.snappy, value: room.participants)
    }

    // MARK: Barra inferiore
    private func bottomBar(_ room: GroupRoomState) -> some View {
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
                .tint(groupAccent)
                .disabled(isStarting || manager.courses.isEmpty)
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
