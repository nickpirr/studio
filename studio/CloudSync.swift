//
//  CloudSync.swift
//  studio
//
//  Sincronizzazione CloudKit (database privato):
//  - sessioni completate condivise tra i dispositivi con lo stesso Apple ID
//    (upload in batch, cancellazioni propagate con tombstone, niente re-upload inutili)
//  - sessione attiva pubblicata con heartbeat e "proprietario" (deviceID),
//    così un altro dispositivo può rilevarla e chiederne il trasferimento.
//

import Foundation
import CloudKit
import SwiftUI
import UIKit
import Combine

// MARK: - CONTAINER CLOUDKIT CONDIVISO

enum CloudConfig {
    /// Identificatore esplicito del container (deve combaciare con
    /// `com.apple.developer.icloud-container-identifiers` nelle entitlements).
    /// Usare l'identificatore esplicito invece di `CKContainer.default()` evita
    /// che, per differenze di risoluzione, l'app punti a un container sbagliato
    /// e riporti l'account come "non disponibile".
    static let containerIdentifier = "iCloud.Politecnico-di-milano.studioso"

    static var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }
}

// MARK: - SESSIONE ATTIVA SU CLOUD

struct CloudActiveSession: Equatable, Identifiable {
    var id: String { sessionID }

    let sessionID: String
    let courseName: String
    let startDate: Date
    let isPaused: Bool
    let pausedSeconds: Int
    let lastHeartbeatAt: Date
    let deviceID: String
    let deviceName: String

    var isRecent: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) < 180
    }

    var isOwnedByThisDevice: Bool {
        deviceID == CloudSessionSync.localDeviceID
    }

    var elapsedSeconds: Int {
        isPaused ? pausedSeconds : max(0, Int(Date().timeIntervalSince(startDate)))
    }
}

// MARK: - STATO ACCOUNT

enum CloudAccountState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case unavailable(String)

    var title: String {
        switch self {
        case .checking: return "Controllo account..."
        case .available: return "iCloud collegato"
        case .noAccount: return "Nessun account iCloud"
        case .restricted: return "iCloud limitato"
        case .couldNotDetermine: return "Stato iCloud non disponibile"
        case .unavailable: return "iCloud non disponibile"
        }
    }

    var detail: String {
        switch self {
        case .checking:
            return "Studio sta verificando l'account usato per la sincronizzazione."
        case .available:
            return "Le sessioni attive possono essere rilevate dagli altri dispositivi con lo stesso Apple ID."
        case .noAccount:
            return "Accedi a iCloud nelle Impostazioni di sistema per sincronizzare tra iPhone e iPad."
        case .restricted:
            return "Questo dispositivo non puo usare iCloud per restrizioni di sistema o account."
        case .couldNotDetermine:
            return "Non e stato possibile leggere lo stato dell'account iCloud."
        case .unavailable(let message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .available: return "checkmark.icloud.fill"
        case .checking: return "icloud"
        case .noAccount: return "person.crop.circle.badge.exclamationmark"
        case .restricted: return "lock.icloud.fill"
        case .couldNotDetermine, .unavailable: return "exclamationmark.icloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .available: return .green
        case .checking: return .blue
        case .noAccount, .restricted, .couldNotDetermine, .unavailable: return .orange
        }
    }
}

// MARK: - MOTORE DI SINCRONIZZAZIONE

@MainActor
final class CloudSessionSync: ObservableObject {
    static let shared = CloudSessionSync()

    /// Identità stabile del dispositivo: serve a capire chi "possiede" la sessione attiva.
    static let localDeviceID: String = {
        let key = "cloudLocalDeviceID"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()

    enum PublishOutcome {
        case published
        case skipped
        case transferredAway
        case unavailable
    }

    @Published private(set) var accountState: CloudAccountState = .checking
    @Published private(set) var accountIdentifier: String = "Account iCloud del dispositivo"
    /// Sessione attiva su un ALTRO dispositivo con lo stesso Apple ID (per il banner di trasferimento).
    @Published private(set) var remoteActiveSession: CloudActiveSession?
    @Published private(set) var isSyncingSessions = false
    @Published private(set) var lastSessionSyncAt: Date?

    private let container = CloudConfig.container
    private var database: CKDatabase { container.privateCloudDatabase }

    private let activeSessionRecordID = CKRecord.ID(recordName: "currentActiveSession")
    private let heartbeatMinimumInterval: TimeInterval = 30
    private var lastPublishedAt: Date?

    private let syncedIDsKey = "cloudSyncedSessionIDs"
    private let tombstonesKey = "cloudSessionTombstones"
    private let tombstoneRetention: TimeInterval = 60 * 60 * 24 * 90 // 90 giorni

    /// ID già presenti sul server: non vanno ricaricati a ogni sync.
    private var syncedSessionIDs: Set<String>
    /// Sessioni cancellate localmente (id -> data cancellazione), da propagare agli altri dispositivi.
    private var tombstones: [String: Date]

    private var isFullSyncRunning = false
    private var lastFullSyncAttempt: Date?
    private var ignoredRemoteSessionIDs: Set<String> = []
    private var accountChangeObserver: NSObjectProtocol?

    private init() {
        syncedSessionIDs = Set(UserDefaults.standard.stringArray(forKey: syncedIDsKey) ?? [])
        tombstones = (UserDefaults.standard.dictionary(forKey: tombstonesKey) as? [String: Date]) ?? [:]

        // Quando l'utente accede/esce da iCloud mentre l'app è aperta,
        // il sistema notifica: riaggiorna subito lo stato dell'account.
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshAccountStatus() }
        }
    }

    // MARK: - Account

    func refreshAccountStatus() async {
        if accountState != .available { accountState = .checking }

        // Subito dopo il lancio l'account può risultare "non determinabile" o
        // "temporaneamente non disponibile" mentre il demone CloudKit si avvia:
        // riprova qualche volta prima di dichiarare un errore.
        for attempt in 0..<3 {
            let result = await cloudAccountStatus()

            switch result.status {
            case .available:
                accountState = .available
                await refreshAccountIdentifier()
                return
            case .noAccount:
                accountState = .noAccount
                return
            case .restricted:
                accountState = .restricted
                return
            case .couldNotDetermine, .temporarilyUnavailable:
                // Transitorio: attendi e riprova (backoff breve).
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    continue
                }
                if result.status == .couldNotDetermine {
                    accountState = result.error.map { .unavailable($0.localizedDescription) } ?? .couldNotDetermine
                } else {
                    accountState = .unavailable(result.error?.localizedDescription ?? "iCloud e temporaneamente non disponibile.")
                }
                return
            @unknown default:
                accountState = .couldNotDetermine
                return
            }
        }
    }

    private func isAccountAvailable() async -> Bool {
        if accountState == .available { return true }
        await refreshAccountStatus()
        return accountState == .available
    }

    private func refreshAccountIdentifier() async {
        do {
            let userRecordID = try await container.userRecordID()
            accountIdentifier = "iCloud \(userRecordID.recordName.prefix(8))"
        } catch {
            accountIdentifier = "Account iCloud collegato"
        }
    }

    private func cloudAccountStatus() async -> (status: CKAccountStatus, error: Error?) {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                continuation.resume(returning: (status, error))
            }
        }
    }

    // MARK: - Sessione attiva: pubblicazione e ownership

    /// Pubblica lo stato della sessione in corso. Se un altro dispositivo ha preso
    /// possesso della stessa sessione, NON sovrascrive e risponde `.transferredAway`.
    @discardableResult
    func publishActiveSession(
        sessionID: String,
        courseName: String,
        startDate: Date,
        isPaused: Bool,
        pausedSeconds: Int,
        force: Bool = false
    ) async -> PublishOutcome {
        guard await isAccountAvailable() else { return .unavailable }
        if !force,
           let lastPublishedAt,
           Date().timeIntervalSince(lastPublishedAt) < heartbeatMinimumInterval {
            return .skipped
        }

        func fill(_ record: CKRecord) {
            record["sessionID"] = sessionID as CKRecordValue
            record["courseName"] = courseName as CKRecordValue
            record["startDate"] = startDate as CKRecordValue
            record["isPaused"] = (isPaused ? 1 : 0) as CKRecordValue
            record["pausedSeconds"] = pausedSeconds as CKRecordValue
            record["lastHeartbeatAt"] = Date() as CKRecordValue
            record["deviceID"] = Self.localDeviceID as CKRecordValue
            record["deviceName"] = UIDevice.current.name as CKRecordValue
        }

        func isTransferredAway(_ record: CKRecord) -> Bool {
            guard let recordSessionID = record["sessionID"] as? String,
                  recordSessionID == sessionID,
                  let owner = record["deviceID"] as? String
            else { return false }
            return owner != Self.localDeviceID
        }

        do {
            let record = try await fetchOrCreateActiveSessionRecord()
            if isTransferredAway(record) { return .transferredAway }
            fill(record)

            do {
                _ = try await database.save(record)
            } catch let error as CKError where error.code == .serverRecordChanged {
                guard let server = error.serverRecord else { throw error }
                if isTransferredAway(server) { return .transferredAway }
                fill(server)
                _ = try await database.save(server)
            }

            lastPublishedAt = Date()
            return .published
        } catch {
            print("CloudKit active session save failed: \(error.localizedDescription)")
            return .unavailable
        }
    }

    /// Prende possesso della sessione attiva pubblicata da un altro dispositivo.
    /// Ritorna lo stato più aggiornato letto dal server, o nil se non è più disponibile.
    func takeoverActiveSession(_ session: CloudActiveSession) async -> CloudActiveSession? {
        guard await isAccountAvailable() else { return nil }

        do {
            let record = try await database.record(for: activeSessionRecordID)
            guard let latest = activeSession(from: record),
                  latest.sessionID == session.sessionID
            else { return nil }

            record["deviceID"] = Self.localDeviceID as CKRecordValue
            record["deviceName"] = UIDevice.current.name as CKRecordValue
            record["lastHeartbeatAt"] = Date() as CKRecordValue
            _ = try await database.save(record)

            lastPublishedAt = Date()
            remoteActiveSession = nil
            return latest
        } catch {
            print("CloudKit takeover failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Aggiorna `remoteActiveSession`: valorizzata solo se esiste una sessione
    /// recente di un ALTRO dispositivo e l'utente non l'ha già ignorata.
    func refreshRemoteActiveSession() async {
        guard await isAccountAvailable() else {
            remoteActiveSession = nil
            return
        }

        guard let session = await fetchActiveSession(),
              session.isRecent,
              !session.isOwnedByThisDevice,
              !ignoredRemoteSessionIDs.contains(session.sessionID)
        else {
            remoteActiveSession = nil
            return
        }
        remoteActiveSession = session
    }

    /// L'utente ha scelto di ignorare la sessione remota: non riproporla.
    func ignoreRemoteActiveSession() {
        if let id = remoteActiveSession?.sessionID {
            ignoredRemoteSessionIDs.insert(id)
        }
        remoteActiveSession = nil
    }

    func fetchActiveSession() async -> CloudActiveSession? {
        guard await isAccountAvailable() else { return nil }

        do {
            let record = try await database.record(for: activeSessionRecordID)
            return activeSession(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            print("CloudKit active session fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    func clearActiveSession(sessionID: String?) async {
        guard await isAccountAvailable() else { return }

        do {
            if let sessionID,
               let existing = try? await database.record(for: activeSessionRecordID) {
                // Non cancellare la sessione di qualcun altro (es. già trasferita).
                if existing["sessionID"] as? String != sessionID { return }
                if let owner = existing["deviceID"] as? String, owner != Self.localDeviceID { return }
            }
            _ = try await database.deleteRecord(withID: activeSessionRecordID)
            lastPublishedAt = nil
        } catch let error as CKError where error.code == .unknownItem {
            lastPublishedAt = nil
        } catch {
            print("CloudKit active session delete failed: \(error.localizedDescription)")
        }
    }

    private func activeSession(from record: CKRecord) -> CloudActiveSession? {
        guard let sessionID = record["sessionID"] as? String,
              let courseName = record["courseName"] as? String,
              let startDate = record["startDate"] as? Date,
              let pausedSeconds = record["pausedSeconds"] as? Int,
              let lastHeartbeatAt = record["lastHeartbeatAt"] as? Date
        else { return nil }

        return CloudActiveSession(
            sessionID: sessionID,
            courseName: courseName,
            startDate: startDate,
            isPaused: (record["isPaused"] as? Int ?? 0) == 1,
            pausedSeconds: pausedSeconds,
            lastHeartbeatAt: lastHeartbeatAt,
            deviceID: record["deviceID"] as? String ?? "",
            deviceName: record["deviceName"] as? String ?? "altro dispositivo"
        )
    }

    private func fetchOrCreateActiveSessionRecord() async throws -> CKRecord {
        do {
            return try await database.record(for: activeSessionRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: "ActiveSession", recordID: activeSessionRecordID)
        }
    }

    // MARK: - Sessioni completate: sync bidirezionale

    /// Sync completa: scarica le sessioni remote, unisce, propaga cancellazioni
    /// e carica solo ciò che manca sul server. Ritorna l'elenco unito, o nil se
    /// il cloud non è raggiungibile (in quel caso non toccare i dati locali).
    func syncCompletedSessions(local sessions: [CompletedSession], force: Bool = false) async -> [CompletedSession]? {
        guard !isFullSyncRunning else { return nil }
        if !force,
           let lastFullSyncAttempt,
           Date().timeIntervalSince(lastFullSyncAttempt) < 15 {
            return nil
        }
        guard await isAccountAvailable() else { return nil }

        isFullSyncRunning = true
        isSyncingSessions = true
        lastFullSyncAttempt = Date()
        defer {
            isFullSyncRunning = false
            isSyncingSessions = false
        }

        pruneTombstones()

        // 1. Scarica sessioni e tombstone remoti.
        guard let remoteRecords = await fetchAllRecords(ofType: "CompletedSession"),
              let remoteTombstoneRecords = await fetchAllRecords(ofType: "DeletedSession")
        else { return nil }

        let remoteSessions = remoteRecords.compactMap(completedSession(from:))
        var remoteTombstones: [String: Date] = [:]
        for record in remoteTombstoneRecords {
            if let id = record["sessionID"] as? String {
                remoteTombstones[id] = record["deletedAt"] as? Date ?? Date()
            }
        }

        // 2. Unisci i tombstone remoti a quelli locali.
        for (id, date) in remoteTombstones where tombstones[id] == nil {
            tombstones[id] = date
        }
        persistTombstones()

        // 3. Merge: unione per id (il locale vince), meno tutte le cancellate.
        var mergedByID: [UUID: CompletedSession] = [:]
        for session in remoteSessions { mergedByID[session.id] = session }
        for session in sessions { mergedByID[session.id] = session }
        for idString in tombstones.keys {
            if let uuid = UUID(uuidString: idString) {
                mergedByID.removeValue(forKey: uuid)
            }
        }
        let merged = mergedByID.values.sorted { $0.date > $1.date }

        // 4. Carica solo le sessioni nuove; cancella dal server quelle con tombstone.
        let remoteIDs = Set(remoteSessions.map { $0.id.uuidString })
        syncedSessionIDs.formUnion(remoteIDs)

        let toUpload = merged.filter { !syncedSessionIDs.contains($0.id.uuidString) }
        let sessionIDsToDelete = remoteIDs.intersection(Set(tombstones.keys))
        let tombstonesToUpload = tombstones.filter { remoteTombstones[$0.key] == nil }

        let savedIDs = await modifyCompletedSessions(
            saving: toUpload,
            savingTombstones: tombstonesToUpload,
            deletingSessionIDs: sessionIDsToDelete
        )
        syncedSessionIDs.formUnion(savedIDs)
        syncedSessionIDs.subtract(tombstones.keys)
        persistSyncedIDs()

        lastSessionSyncAt = Date()
        return merged
    }

    /// Push incrementale dopo una modifica locale: carica le sessioni nuove e
    /// propaga le cancellazioni, senza scaricare nulla.
    func pushLocalChanges(sessions: [CompletedSession], deletedIDs: Set<UUID>) async {
        // Registra subito i tombstone: anche offline, la prossima sync li propaga.
        for id in deletedIDs {
            tombstones[id.uuidString] = Date()
            syncedSessionIDs.remove(id.uuidString)
        }
        if !deletedIDs.isEmpty {
            persistTombstones()
            persistSyncedIDs()
        }

        guard await isAccountAvailable() else { return }

        let toUpload = sessions.filter {
            !syncedSessionIDs.contains($0.id.uuidString) && tombstones[$0.id.uuidString] == nil
        }
        let deletedIDStrings = Set(deletedIDs.map(\.uuidString))
        let tombstonesToSave = tombstones.filter { deletedIDStrings.contains($0.key) }

        guard !toUpload.isEmpty || !deletedIDStrings.isEmpty else { return }

        let savedIDs = await modifyCompletedSessions(
            saving: toUpload,
            savingTombstones: tombstonesToSave,
            deletingSessionIDs: deletedIDStrings
        )
        syncedSessionIDs.formUnion(savedIDs)
        persistSyncedIDs()
    }

    // MARK: - Operazioni batch

    /// Salva/cancella in batch. Ritorna gli id delle sessioni salvate con successo.
    private func modifyCompletedSessions(
        saving sessionsToSave: [CompletedSession],
        savingTombstones: [String: Date],
        deletingSessionIDs: Set<String>
    ) async -> Set<String> {
        var recordsToSave: [CKRecord] = sessionsToSave.map { session in
            let record = CKRecord(recordType: "CompletedSession", recordID: completedSessionRecordID(for: session.id.uuidString))
            write(session: session, to: record)
            return record
        }
        recordsToSave += savingTombstones.map { id, date in
            let record = CKRecord(recordType: "DeletedSession", recordID: tombstoneRecordID(for: id))
            record["sessionID"] = id as CKRecordValue
            record["deletedAt"] = date as CKRecordValue
            return record
        }
        let recordIDsToDelete = deletingSessionIDs.map { completedSessionRecordID(for: $0) }

        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else { return [] }

        var confirmedSessionIDs: Set<String> = []
        let chunkSize = 200

        var saveChunks = stride(from: 0, to: recordsToSave.count, by: chunkSize).map {
            Array(recordsToSave[$0..<min($0 + chunkSize, recordsToSave.count)])
        }
        var deleteChunks = stride(from: 0, to: recordIDsToDelete.count, by: chunkSize).map {
            Array(recordIDsToDelete[$0..<min($0 + chunkSize, recordIDsToDelete.count)])
        }
        if saveChunks.isEmpty { saveChunks = [[]] }
        if deleteChunks.isEmpty { deleteChunks = [[]] }

        for (index, chunk) in saveChunks.enumerated() {
            let deletions = index < deleteChunks.count ? deleteChunks[index] : []
            await modifyChunk(saving: chunk, deleting: deletions, confirmed: &confirmedSessionIDs)
        }
        // Eventuali chunk di sole cancellazioni rimasti.
        if deleteChunks.count > saveChunks.count {
            for deletions in deleteChunks[saveChunks.count...] {
                await modifyChunk(saving: [], deleting: deletions, confirmed: &confirmedSessionIDs)
            }
        }

        return confirmedSessionIDs
    }

    private func modifyChunk(
        saving records: [CKRecord],
        deleting recordIDs: [CKRecord.ID],
        confirmed: inout Set<String>
    ) async {
        guard !records.isEmpty || !recordIDs.isEmpty else { return }
        do {
            // .allKeys: le sessioni completate sono immutabili, l'ultima scrittura vince.
            let (saveResults, _) = try await database.modifyRecords(
                saving: records,
                deleting: recordIDs,
                savePolicy: .allKeys,
                atomically: false
            )
            for (_, result) in saveResults {
                if case .success(let record) = result,
                   record.recordType == "CompletedSession",
                   let id = record["sessionID"] as? String {
                    confirmed.insert(id)
                }
            }
        } catch {
            print("CloudKit batch modify failed: \(error.localizedDescription)")
        }
    }

    /// Scarica tutti i record di un tipo, seguendo il cursore di paginazione.
    /// Ritorna nil in caso di errore di rete (per non scambiare un errore per "nessun dato").
    private func fetchAllRecords(ofType type: String) async -> [CKRecord]? {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var results: [CKRecord] = []

        do {
            var response = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
            results += response.matchResults.compactMap { try? $0.1.get() }
            while let cursor = response.queryCursor {
                response = try await database.records(continuingMatchFrom: cursor)
                results += response.matchResults.compactMap { try? $0.1.get() }
            }
            return results
        } catch let error as CKError where error.code == .unknownItem || error.code == .invalidArguments {
            // Il tipo di record non esiste ancora nello schema: nessun dato remoto.
            return []
        } catch {
            print("CloudKit fetch \(type) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Record helpers

    private func completedSessionRecordID(for idString: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "completedSession_\(idString)")
    }

    private func tombstoneRecordID(for idString: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "deletedSession_\(idString)")
    }

    private func write(session: CompletedSession, to record: CKRecord) {
        record["sessionID"] = session.id.uuidString as CKRecordValue
        record["courseIcon"] = session.courseIcon as CKRecordValue
        record["courseName"] = session.courseName as CKRecordValue
        record["courseColorName"] = session.courseColorName as CKRecordValue
        record["minutes"] = session.minutes as CKRecordValue
        record["date"] = session.date as CKRecordValue
        record["topic"] = session.topic as CKRecordValue
        record["comment"] = session.comment as CKRecordValue
        record["effort"] = session.effort as CKRecordValue
        record["concentration"] = session.concentration as CKRecordValue
        record["satisfaction"] = session.satisfaction as CKRecordValue
        record["wasFocusModeActive"] = ((session.wasFocusModeActive ?? false) ? 1 : 0) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
    }

    private func completedSession(from record: CKRecord) -> CompletedSession? {
        guard let idString = record["sessionID"] as? String,
              let id = UUID(uuidString: idString),
              let courseIcon = record["courseIcon"] as? String,
              let courseName = record["courseName"] as? String,
              let courseColorName = record["courseColorName"] as? String,
              let minutes = record["minutes"] as? Int,
              let date = record["date"] as? Date
        else { return nil }

        return CompletedSession(
            id: id,
            courseIcon: courseIcon,
            courseName: courseName,
            courseColor: Presets.color(from: courseColorName),
            minutes: minutes,
            date: date,
            topic: record["topic"] as? String ?? "",
            comment: record["comment"] as? String ?? "",
            effort: record["effort"] as? Int ?? 5,
            concentration: record["concentration"] as? Int ?? 5,
            satisfaction: record["satisfaction"] as? Int ?? 5,
            wasFocusModeActive: (record["wasFocusModeActive"] as? Int ?? 0) == 1
        )
    }

    // MARK: - Persistenza stato sync

    private func persistSyncedIDs() {
        UserDefaults.standard.set(Array(syncedSessionIDs), forKey: syncedIDsKey)
    }

    private func persistTombstones() {
        UserDefaults.standard.set(tombstones, forKey: tombstonesKey)
    }

    private func pruneTombstones() {
        let cutoff = Date().addingTimeInterval(-tombstoneRetention)
        let pruned = tombstones.filter { $0.value > cutoff }
        if pruned.count != tombstones.count {
            tombstones = pruned
            persistTombstones()
        }
    }
}
