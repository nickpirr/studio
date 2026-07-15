//
//  GroupStudySession.swift
//  studio
//
//  Sessioni di studio condivise tra amici tramite codice invito.
//  La "stanza" vive nel database PUBBLICO di CloudKit: chi ha il codice può
//  unirsi anche con un Apple ID diverso. Lo stato del timer (start, pausa,
//  secondi accumulati) è unico e condiviso: se uno mette in pausa, la pausa
//  vale per tutti; quando l'host termina, la sessione finisce per tutti.
//

import Foundation
import CloudKit
import SwiftUI
import UIKit
import Combine

// MARK: - STATO DELLA STANZA

struct GroupRoomState: Equatable {
    enum Phase: Int {
        case lobby = 0     // in attesa che l'host avvii
        case running = 1   // sessione in corso
        case ended = 2     // terminata dall'host
    }

    let code: String
    let hostID: String
    let hostName: String
    var phase: Phase
    var isPaused: Bool
    var startDate: Date
    var pausedSeconds: Int
    var participants: [String]
    var lastEventAt: Date

    var isHostedByMe: Bool { hostID == CloudSessionSync.localDeviceID }
}

// MARK: - ERRORI LEGGIBILI

enum GroupSessionError: LocalizedError {
    case roomNotFound
    case roomEnded
    case roomAlreadyRunning
    case cloudUnavailable

    var errorDescription: String? {
        switch self {
        case .roomNotFound: return "Nessuna stanza trovata con questo codice. Controlla e riprova."
        case .roomEnded: return "Questa sessione di gruppo è già terminata."
        case .roomAlreadyRunning: return "Questa sessione è già iniziata."
        case .cloudUnavailable: return "iCloud non è disponibile. Controlla la connessione e l'accesso a iCloud."
        }
    }
}

// MARK: - CONTROLLER

@MainActor
final class GroupSessionController: ObservableObject {
    static let shared = GroupSessionController()

    @Published private(set) var room: GroupRoomState?
    @Published private(set) var isBusy = false

    /// Nome mostrato agli amici (modificabile nelle viste di gruppo).
    @AppStorage("groupDisplayName") var displayName: String = ""

    /// Materia che QUESTO partecipante sta studiando: nella sessione condivisa
    /// il timer è comune ma ognuno studia la propria materia.
    @AppStorage("groupLocalCourseName") var localCourseName: String = ""

    private let container = CloudConfig.container
    private var database: CKDatabase { container.publicCloudDatabase }
    private var pollTask: Task<Void, Never>?

    private static let recordType = "StudyGroupRoom"

    private init() {}

    var effectiveDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UIDevice.current.name : trimmed
    }

    // MARK: - Creazione / ingresso

    /// Crea una stanza in fase "lobby" e ritorna il codice invito.
    /// La stanza non ha una materia: coordina solo il timer condiviso.
    func createRoom() async throws -> GroupRoomState {
        isBusy = true
        defer { isBusy = false }

        let code = Self.generateInviteCode()
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: code))
        record["code"] = code as CKRecordValue
        record["hostID"] = CloudSessionSync.localDeviceID as CKRecordValue
        record["hostName"] = effectiveDisplayName as CKRecordValue
        record["phase"] = GroupRoomState.Phase.lobby.rawValue as CKRecordValue
        record["isPaused"] = 0 as CKRecordValue
        record["startDate"] = Date() as CKRecordValue
        record["pausedSeconds"] = 0 as CKRecordValue
        record["participants"] = [effectiveDisplayName] as CKRecordValue
        record["lastEventAt"] = Date() as CKRecordValue

        do {
            let saved = try await database.save(record)
            guard let state = Self.roomState(from: saved) else { throw GroupSessionError.cloudUnavailable }
            room = state
            startPolling()
            return state
        } catch let error as GroupSessionError {
            throw error
        } catch {
            print("Group room create failed: \(error.localizedDescription)")
            throw GroupSessionError.cloudUnavailable
        }
    }

    /// Si unisce a una stanza esistente tramite codice invito.
    func joinRoom(code rawCode: String) async throws -> GroupRoomState {
        isBusy = true
        defer { isBusy = false }

        let code = Self.normalizeCode(rawCode)
        guard code.count == 6 else { throw GroupSessionError.roomNotFound }

        let name = effectiveDisplayName
        do {
            let state = try await mutateRoomRecord(code: code) { record in
                let phase = GroupRoomState.Phase(rawValue: record["phase"] as? Int ?? 0) ?? .lobby
                guard phase != .ended else { throw GroupSessionError.roomEnded }

                // Stanze abbandonate da più di un giorno: considerale scadute.
                if let lastEvent = record["lastEventAt"] as? Date,
                   Date().timeIntervalSince(lastEvent) > 60 * 60 * 24 {
                    throw GroupSessionError.roomEnded
                }

                var participants = record["participants"] as? [String] ?? []
                if !participants.contains(name) {
                    participants.append(name)
                    record["participants"] = participants as CKRecordValue
                    record["lastEventAt"] = Date() as CKRecordValue
                }
            }
            room = state
            startPolling()
            return state
        } catch let error as CKError where error.code == .unknownItem {
            throw GroupSessionError.roomNotFound
        } catch let error as GroupSessionError {
            throw error
        } catch {
            print("Group room join failed: \(error.localizedDescription)")
            throw GroupSessionError.cloudUnavailable
        }
    }

    // MARK: - Azioni sulla sessione

    /// L'host avvia la sessione per tutti i partecipanti.
    func startSessionForEveryone() async {
        guard let current = room, current.isHostedByMe else { return }
        await mutateCurrentRoom { record in
            record["phase"] = GroupRoomState.Phase.running.rawValue as CKRecordValue
            record["startDate"] = Date() as CKRecordValue
            record["isPaused"] = 0 as CKRecordValue
            record["pausedSeconds"] = 0 as CKRecordValue
            record["lastEventAt"] = Date() as CKRecordValue
        }
    }

    /// Pausa/ripresa condivisa: chiunque nel gruppo può farlo, vale per tutti.
    func setPaused(_ paused: Bool, pausedSeconds: Int, startDate: Date) {
        guard let current = room, current.phase == .running else { return }
        guard current.isPaused != paused
                || (paused && current.pausedSeconds != pausedSeconds)
                || (!paused && abs(current.startDate.timeIntervalSince(startDate)) > 1.5)
        else { return }

        // Aggiornamento ottimistico: la UI locale non deve aspettare la rete.
        var optimistic = current
        optimistic.isPaused = paused
        optimistic.pausedSeconds = pausedSeconds
        optimistic.startDate = startDate
        optimistic.lastEventAt = Date()
        room = optimistic

        Task {
            await mutateCurrentRoom { record in
                record["isPaused"] = (paused ? 1 : 0) as CKRecordValue
                record["pausedSeconds"] = pausedSeconds as CKRecordValue
                record["startDate"] = startDate as CKRecordValue
                record["lastEventAt"] = Date() as CKRecordValue
            }
        }
    }

    /// Chiamata quando l'utente termina la sessione dalla vista attiva:
    /// l'host chiude la stanza per tutti, un partecipante si limita a uscire.
    func endOrLeave(elapsedSeconds: Int) async {
        guard let current = room else { return }

        if current.isHostedByMe {
            await mutateCurrentRoom { record in
                record["phase"] = GroupRoomState.Phase.ended.rawValue as CKRecordValue
                record["isPaused"] = 1 as CKRecordValue
                record["pausedSeconds"] = elapsedSeconds as CKRecordValue
                record["lastEventAt"] = Date() as CKRecordValue
            }
        } else {
            let name = effectiveDisplayName
            await mutateCurrentRoom { record in
                var participants = record["participants"] as? [String] ?? []
                participants.removeAll { $0 == name }
                record["participants"] = participants as CKRecordValue
                record["lastEventAt"] = Date() as CKRecordValue
            }
        }
        clearRoomLocally()
    }

    /// Esce dalla lobby (prima dell'avvio). L'host che esce chiude la stanza.
    func leaveLobby() async {
        guard let current = room else { return }

        if current.isHostedByMe {
            stopPolling()
            let id = Self.recordID(for: current.code)
            room = nil
            _ = try? await database.deleteRecord(withID: id)
        } else {
            await endOrLeave(elapsedSeconds: 0)
        }
    }

    /// Dimentica la stanza senza toccare il cloud (usata a fine sessione).
    func clearRoomLocally() {
        stopPolling()
        room = nil
    }

    // MARK: - Polling

    /// Aggiorna lo stato della stanza dal server (chiamata anche dal timer della sessione).
    func refresh() async {
        guard let current = room else { return }
        do {
            let record = try await database.record(for: Self.recordID(for: current.code))
            if let state = Self.roomState(from: record), state != room {
                room = state
            }
        } catch let error as CKError where error.code == .unknownItem {
            // La stanza è stata cancellata: per i partecipanti equivale a "terminata".
            if var current = room {
                current.phase = .ended
                room = current
            }
        } catch {
            // Errore di rete transitorio: mantieni lo stato corrente.
        }
    }

    /// Polling leggero per la lobby (partecipanti che entrano, avvio dell'host).
    func startPolling(every seconds: TimeInterval = 3) {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Mutazioni con gestione conflitti

    /// Fetch → modifica → salva, con retry sui conflitti (`serverRecordChanged`):
    /// più partecipanti possono scrivere contemporaneamente sullo stesso record.
    @discardableResult
    private func mutateRoomRecord(
        code: String,
        _ mutate: (CKRecord) throws -> Void
    ) async throws -> GroupRoomState {
        let recordID = Self.recordID(for: code)
        var attempts = 0

        while true {
            attempts += 1
            let record = try await database.record(for: recordID)
            try mutate(record)

            do {
                let saved = try await database.save(record)
                guard let state = Self.roomState(from: saved) else {
                    throw GroupSessionError.cloudUnavailable
                }
                return state
            } catch let error as CKError where error.code == .serverRecordChanged && attempts < 4 {
                // Qualcun altro ha scritto prima di noi: riparti dal record aggiornato.
                continue
            }
        }
    }

    private func mutateCurrentRoom(_ mutate: @escaping (CKRecord) throws -> Void) async {
        guard let current = room else { return }
        do {
            let state = try await mutateRoomRecord(code: current.code, mutate)
            room = state
        } catch {
            print("Group room update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func recordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "studyRoom_\(code)")
    }

    /// Codice a 6 caratteri senza simboli ambigui (niente 0/O, 1/I, 8/B).
    static func generateInviteCode() -> String {
        let alphabet = Array("ACDEFGHJKLMNPQRSTUVWXYZ2345679")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    static func normalizeCode(_ raw: String) -> String {
        raw.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func roomState(from record: CKRecord) -> GroupRoomState? {
        guard let code = record["code"] as? String,
              let hostID = record["hostID"] as? String,
              let startDate = record["startDate"] as? Date
        else { return nil }

        return GroupRoomState(
            code: code,
            hostID: hostID,
            hostName: record["hostName"] as? String ?? "Host",
            phase: GroupRoomState.Phase(rawValue: record["phase"] as? Int ?? 0) ?? .lobby,
            isPaused: (record["isPaused"] as? Int ?? 0) == 1,
            startDate: startDate,
            pausedSeconds: record["pausedSeconds"] as? Int ?? 0,
            participants: record["participants"] as? [String] ?? [],
            lastEventAt: record["lastEventAt"] as? Date ?? .distantPast
        )
    }
}
