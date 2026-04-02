import Foundation
import SQLite3

extension Notification.Name {
    static let pingerNewData = Notification.Name("com.pinger.newData")
}

// MARK: - PingDataPoint

struct PingDataPoint {
    let timestamp: Date
    let avgLatency: Double?
    let minLatency: Double?
    let maxLatency: Double?
    let sampleCount: Int
    let unreachableCount: Int
    let vpnActiveCount: Int   // how many samples had VPN on
}

// MARK: - PingStore

final class PingStore {

    static let shared = PingStore()

    private let queue = DispatchQueue(label: "com.pinger.store")
    private var db: OpaquePointer?
    private var lastRollup: Date = .distantPast

    // MARK: - Init / Setup

    private init() {
        queue.async { [self] in
            self.openDatabase()
            self.createTables()
        }
    }

    private func dbPath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Pinger", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pinger.db").path
    }

    private func openDatabase() {
        let path = dbPath()
        if sqlite3_open(path, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func createTables() {
        let ddl = """
        CREATE TABLE IF NOT EXISTS ping_seconds (
            ts      INTEGER NOT NULL,
            latency REAL,
            PRIMARY KEY (ts)
        );
        CREATE TABLE IF NOT EXISTS ping_minutes (
            ts                INTEGER NOT NULL,
            avg_latency       REAL,
            min_latency       REAL,
            max_latency       REAL,
            sample_count      INTEGER NOT NULL,
            unreachable_count INTEGER NOT NULL,
            PRIMARY KEY (ts)
        );
        CREATE TABLE IF NOT EXISTS ping_hours (
            ts                INTEGER NOT NULL,
            avg_latency       REAL,
            min_latency       REAL,
            max_latency       REAL,
            sample_count      INTEGER NOT NULL,
            unreachable_count INTEGER NOT NULL,
            PRIMARY KEY (ts)
        );
        """
        execSQL(ddl)

        // Migration: add vpn_active column if absent (error is harmless if already exists)
        sqlite3_exec(db, "ALTER TABLE ping_seconds ADD COLUMN vpn_active INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE ping_minutes ADD COLUMN vpn_active_count INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE ping_hours ADD COLUMN vpn_active_count INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
    }

    // MARK: - Public API

    func record(latency: Double?, vpnActive: Bool) {
        queue.async { [self] in
            guard let db = self.db else { return }
            let ts = Int64(Date().timeIntervalSince1970)
            let latencySQL = latency.map { "\($0)" } ?? "NULL"
            let sql = "INSERT OR REPLACE INTO ping_seconds (ts, latency, vpn_active) VALUES (\(ts), \(latencySQL), \(vpnActive ? 1 : 0));"
            self.execSQL(sql, on: db)
            self.rollupIfNeeded()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .pingerNewData, object: nil)
            }
        }
    }

    func query(resolution: String, since: Date) -> [PingDataPoint] {
        var results: [PingDataPoint] = []
        queue.sync { [self] in
            guard let db = self.db else { return }
            let sinceTs = Int64(since.timeIntervalSince1970)
            switch resolution {
            case "seconds":
                results = self.querySeconds(since: sinceTs, on: db)
            case "minutes":
                results = self.queryAggregated(table: "ping_minutes", since: sinceTs, on: db)
            case "hours":
                results = self.queryAggregated(table: "ping_hours", since: sinceTs, on: db)
            default:
                break
            }
        }
        return results
    }

    func clearAll() {
        queue.async { [self] in
            guard let db = self.db else { return }
            self.execSQL("DELETE FROM ping_seconds;", on: db)
            self.execSQL("DELETE FROM ping_minutes;", on: db)
            self.execSQL("DELETE FROM ping_hours;", on: db)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .pingerNewData, object: nil)
            }
        }
    }

    // MARK: - Query Helpers

    private func querySeconds(since sinceTs: Int64, on db: OpaquePointer) -> [PingDataPoint] {
        let sql = "SELECT ts, latency, vpn_active FROM ping_seconds WHERE ts >= \(sinceTs) ORDER BY ts ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var points: [PingDataPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts = sqlite3_column_int64(stmt, 0)
            let latency: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL
                ? nil
                : sqlite3_column_double(stmt, 1)
            let vpnActiveCount = Int(sqlite3_column_int64(stmt, 2))
            let point = PingDataPoint(
                timestamp: Date(timeIntervalSince1970: Double(ts)),
                avgLatency: latency,
                minLatency: latency,
                maxLatency: latency,
                sampleCount: 1,
                unreachableCount: latency == nil ? 1 : 0,
                vpnActiveCount: vpnActiveCount
            )
            points.append(point)
        }
        return points
    }

    private func queryAggregated(table: String, since sinceTs: Int64, on db: OpaquePointer) -> [PingDataPoint] {
        let sql = """
        SELECT ts, avg_latency, min_latency, max_latency, sample_count, unreachable_count, vpn_active_count
        FROM \(table) WHERE ts >= \(sinceTs) ORDER BY ts ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var points: [PingDataPoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts          = sqlite3_column_int64(stmt, 0)
            let avg: Double? = sqlite3_column_type(stmt, 1) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 1)
            let min: Double? = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 2)
            let max: Double? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
            let sampleCount      = Int(sqlite3_column_int64(stmt, 4))
            let unreachableCount = Int(sqlite3_column_int64(stmt, 5))
            let vpnActiveCount   = Int(sqlite3_column_int64(stmt, 6))
            let point = PingDataPoint(
                timestamp: Date(timeIntervalSince1970: Double(ts)),
                avgLatency: avg,
                minLatency: min,
                maxLatency: max,
                sampleCount: sampleCount,
                unreachableCount: unreachableCount,
                vpnActiveCount: vpnActiveCount
            )
            points.append(point)
        }
        return points
    }

    // MARK: - Rollup

    private func rollupIfNeeded() {
        guard let db = self.db else { return }
        let now = Date()
        guard now.timeIntervalSince(lastRollup) >= 60 else { return }
        lastRollup = now

        let nowTs = Int64(now.timeIntervalSince1970)
        let secondsCutoff: Int64 = nowTs - 86400
        let minutesCutoff: Int64 = nowTs - 86400 * 30
        let hoursCutoff: Int64   = nowTs - 86400 * 365

        rollupSecondsToMinutes(cutoff: secondsCutoff, on: db)
        rollupMinutesToHours(cutoff: minutesCutoff, on: db)
        execSQL("DELETE FROM ping_hours WHERE ts < \(hoursCutoff);", on: db)
    }

    private func rollupSecondsToMinutes(cutoff: Int64, on db: OpaquePointer) {
        let insertSql = """
        INSERT OR REPLACE INTO ping_minutes
            (ts, avg_latency, min_latency, max_latency, sample_count, unreachable_count, vpn_active_count)
        SELECT
            ts / 60 * 60,
            AVG(latency),
            MIN(latency),
            MAX(latency),
            COUNT(*),
            SUM(CASE WHEN latency IS NULL THEN 1 ELSE 0 END),
            SUM(vpn_active) AS vpn_active_count
        FROM ping_seconds
        WHERE ts < \(cutoff)
        GROUP BY ts / 60 * 60;
        """
        execSQL(insertSql, on: db)
        execSQL("DELETE FROM ping_seconds WHERE ts < \(cutoff);", on: db)
    }

    private func rollupMinutesToHours(cutoff: Int64, on db: OpaquePointer) {
        // Merge aggregated minutes into existing hour buckets using weighted average.
        let insertSql = """
        INSERT OR REPLACE INTO ping_hours
            (ts, avg_latency, min_latency, max_latency, sample_count, unreachable_count, vpn_active_count)
        SELECT
            new.ts,
            CASE WHEN (new.reachable_count + COALESCE(old.reachable_count, 0)) = 0
                 THEN NULL
                 ELSE (COALESCE(new.weighted_sum, 0) + COALESCE(old.weighted_sum, 0))
                      / (new.reachable_count + COALESCE(old.reachable_count, 0))
            END,
            CASE WHEN new.min_lat IS NULL THEN old.min_latency
                 WHEN old.min_latency IS NULL THEN new.min_lat
                 ELSE MIN(new.min_lat, old.min_latency)
            END,
            CASE WHEN new.max_lat IS NULL THEN old.max_latency
                 WHEN old.max_latency IS NULL THEN new.max_lat
                 ELSE MAX(new.max_lat, old.max_latency)
            END,
            new.sample_count + COALESCE(old.sample_count, 0),
            new.unreachable_count + COALESCE(old.unreachable_count, 0),
            new.vpn_active_count + COALESCE(old.vpn_active_count, 0)
        FROM (
            SELECT
                ts / 3600 * 3600 AS ts,
                SUM(CASE WHEN avg_latency IS NOT NULL
                         THEN avg_latency * (sample_count - unreachable_count)
                         ELSE 0 END)             AS weighted_sum,
                SUM(sample_count - unreachable_count) AS reachable_count,
                MIN(min_latency)                 AS min_lat,
                MAX(max_latency)                 AS max_lat,
                SUM(sample_count)                AS sample_count,
                SUM(unreachable_count)           AS unreachable_count,
                SUM(vpn_active_count)            AS vpn_active_count
            FROM ping_minutes
            WHERE ts < \(cutoff)
            GROUP BY ts / 3600 * 3600
        ) AS new
        LEFT JOIN ping_hours AS old ON old.ts = new.ts;
        """
        execSQL(insertSql, on: db)
        execSQL("DELETE FROM ping_minutes WHERE ts < \(cutoff);", on: db)
    }

    // MARK: - SQLite Helpers

    @discardableResult
    private func execSQL(_ sql: String) -> Int32 {
        guard let db = self.db else { return SQLITE_ERROR }
        return execSQL(sql, on: db)
    }

    @discardableResult
    private func execSQL(_ sql: String, on db: OpaquePointer) -> Int32 {
        return sqlite3_exec(db, sql, nil, nil, nil)
    }
}
