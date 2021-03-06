//
//  Copyright © 2019 Simon Kågedal Reimer. See LICENSE.
//

import CommonCrypto
import Foundation
import Basic
import SQLite

struct TrustStore {
    let uuid: String
    let path: AbsolutePath

    init(uuid: String) {
        self.uuid = uuid
        self.path = XcodeSimulator.trustStore(forDeviceWithUUID: uuid)
    }

    var exists: Bool {
        return localFileSystem.exists(path)
    }

    func createParentDirectories() throws {
        try localFileSystem.createDirectory(path.parentDirectory, recursive: true)
    }

    func open() throws -> Connection {
        return try Connection(openingPath: path)
    }

    class Connection {
        private let connection: SQLite.Connection
        private let sqliteMaster = Table("sqlite_master")
        private let tsettings = Table("tsettings")

        private let sha1Column = Expression<Blob>("sha1")
        private let subjColumn = Expression<Blob>("subj")
        private let tsetColumn = Expression<Blob?>("tset")
        private let dataColumn = Expression<Blob?>("data")

        private let needsCreation: Bool

        fileprivate init(openingPath path: AbsolutePath) throws {
            needsCreation = !localFileSystem.exists(path)
            connection = try SQLite.Connection(path.pathString)
        }

        func setupDatabaseIfNeeded(reporter: Reporter) throws {
            guard needsCreation else { return }
            try connection.execute("""
                BEGIN TRANSACTION;
                CREATE TABLE tsettings (
                    sha1 BLOB NOT NULL DEFAULT '',
                    subj BLOB NOT NULL DEFAULT '',
                    tset BLOB,
                    data BLOB,
                    PRIMARY KEY(sha1)
                );
                CREATE INDEX isubj ON tsettings(subj);
                COMMIT TRANSACTION;
                """
            )
        }

        func isValid() -> Bool {
            do {
                guard let count = try connection.scalar(
                    "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='tsettings'"
                ) as? Int64 else {
                    return false
                }
                return count > 0
            } catch {
                return false
            }
        }

        func rows() throws -> [TrustStoreRow] {
            return try connection.prepare(tsettings).compactMap { row in
                TrustStoreRow(
                    subj: row[subjColumn].data,
                    sha1: row[sha1Column].data,
                    tset: row[tsetColumn]?.data,
                    data: row[dataColumn]?.data
                )
            }
        }

        func certificates() throws -> [Certificate] {
            return try connection.prepare(tsettings).compactMap { row in
                try row[dataColumn].map { blob in
                    try Certificate(Data(blob.bytes))
                }
            }
        }

        func removeCertificate(with sha1: Data) throws {
            let query = tsettings.where(sha1Column == sha1.datatypeValue).delete()
            try connection.run(query)
        }

        func addCertificate(_ certificate: Certificate) throws {
            let row = try TrustStoreRow(certificate)
            let insert = tsettings.insert(
                subjColumn <- row.subj.datatypeValue,
                sha1Column <- row.sha1.datatypeValue,
                tsetColumn <- row.tset?.datatypeValue,
                dataColumn <- row.data?.datatypeValue
            )
            try connection.run(insert)
        }

        func hasCertificate(with sha1: Data) throws -> Bool {
            return try connection.pluck(tsettings.where(sha1Column == sha1.datatypeValue)) != nil
        }
    }
}
