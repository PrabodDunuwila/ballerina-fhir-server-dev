import ballerina_fhir_server.db_store;

import ballerina/log;
import ballerina/regex;
import ballerina/sql;
import ballerina/time;

import ballerinax/java.jdbc;

public type TransactionContext record {|
    string? mainResourceId = ();
    int[] savedReferenceIds = [];
    int[] deletedReferenceIds = [];
    record {|anydata...;|}? backupResource = ();
    record {|anydata...;|}[]? backupReferences = ();
    boolean committed = false;
|};

public class TransactionHandler {

    public isolated function beginTransaction() returns TransactionContext {
        log:printInfo("Beginning new transaction");
        return {
            mainResourceId: (),
            savedReferenceIds: [],
            deletedReferenceIds: [],
            backupResource: (),
            committed: false
        };
    }

    // Rollback for CREATE operations
    public isolated function rollbackCreateTransaction(jdbc:Client? jdbcClient, TransactionContext 'transaction, string resourceType) returns error? {
        if 'transaction.committed {
            log:printWarn("Cannot rollback a committed transaction");
            return;
        }

        log:printWarn(string `Rolling back ${resourceType} CREATE transaction`);

        int deletedRefs = 0;
        int failedRefs = 0;

        // Delete references
        int[] referenceIds = 'transaction.savedReferenceIds.reverse();
        error? refDeleteResult = deleteReferences(jdbcClient, referenceIds, 'transaction);
        if (refDeleteResult is error) {
            log:printError(refDeleteResult.toString());
        }

        // Delete main resource if it was saved
        if 'transaction.mainResourceId is string {
            string resourceId = <string>'transaction.mainResourceId;
            error? deleteResult = deleteResource(jdbcClient, resourceType, resourceId);

            if deleteResult is error {
                log:printError(string `Failed to delete main resource ${resourceId}: ${deleteResult.message()}`);
                return deleteResult;
            } else {
                log:printInfo(string `Deleted main resource: ${resourceType}/${resourceId}`);
            }
        }

        log:printInfo(string `Rollback completed: deleted ${deletedRefs} references, failed ${failedRefs}`);
    }

    // Rollback for DELETE operations (restore deleted items)
    public isolated function rollbackDeleteTransaction(jdbc:Client? jdbcClient, TransactionContext 'transaction, string resourceType) returns error? {

        if 'transaction.committed {
            log:printWarn("Cannot rollback a committed transaction");
            return;
        }

        log:printWarn(string `Rolling back ${resourceType} DELETE transaction`);

        // Restore main resource
        if 'transaction.backupResource is record {|anydata...;|} {
            string resourceId = <string>'transaction.mainResourceId;
            error? restoreResult = self.restoreResource(jdbcClient, resourceType, resourceId, 'transaction.backupResource);

            if restoreResult is error {
                log:printError(string `Failed to restore resource: ${restoreResult.message()}`);
                return restoreResult;
            } else {
                log:printInfo(string `Restored ${resourceType}/${resourceId}`);
            }
        }

        // Restore deleted references using JDBC
        if 'transaction.backupReferences is db_store:REFERENCES[] {
            db_store:REFERENCES[] backupRefs = <db_store:REFERENCES[]>'transaction.backupReferences;
            foreach db_store:REFERENCES ref in backupRefs {
                error? restoreResult = self.restoreReference(jdbcClient, ref);
                if restoreResult is error {
                    log:printError(string `Failed to restore reference: ${restoreResult.message()}`);
                } else {
                    log:printInfo(string `Restored reference: ${ref.ID}`);
                }
            }
        }

        log:printInfo("Delete rollback completed successfully");
    }

    public isolated function commitTransaction(TransactionContext 'transaction, string resourceType, string resourceId) {
        'transaction.committed = true;
        log:printInfo(string `Transaction committed successfully for ${resourceType}/${resourceId}`);

        if 'transaction.savedReferenceIds.length() > 0 {
            log:printInfo(string `   - Main resource: ${<string>'transaction.mainResourceId}`);
            log:printInfo(string `   - References saved: ${'transaction.savedReferenceIds.length()}`);
        }

        if 'transaction.deletedReferenceIds.length() > 0 {
            log:printInfo(string `   - Main resource: ${<string>'transaction.mainResourceId}`);
            log:printInfo(string `   - References deleted: ${'transaction.deletedReferenceIds.length()}`);
        }
    }

    // Rollback for UPDATE operations (restore from backup)
    public isolated function rollbackUpdateTransaction(jdbc:Client? jdbcClient, TransactionContext 'transaction, string resourceType) returns error? {

        if 'transaction.committed {
            log:printWarn("Cannot rollback a committed transaction");
            return;
        }

        log:printWarn(string `Rolling back ${resourceType} UPDATE transaction`);

        // Restore backed up resource
        if 'transaction.backupResource is record {|anydata...;|} {
            string resourceId = <string>'transaction.mainResourceId;
            error? restoreResult = self.restoreResource(jdbcClient, resourceType, resourceId, 'transaction.backupResource);
            if restoreResult is error {
                log:printError(string `Failed to restore resource: ${restoreResult.message()}`);
            } else {
                log:printInfo(string `Restored ${resourceType}/${resourceId} from backup`);
            }
        }

        // Delete newly created references using JDBC
        if jdbcClient is jdbc:Client {
            foreach int refId in 'transaction.savedReferenceIds.reverse() {
                string deleteQuery = string `DELETE FROM "REFERENCES" WHERE ID = ${refId}`;
                sql:ExecutionResult|error result = jdbcClient->execute(new RawSQLQuery(deleteQuery));
                if result is error {
                    log:printError(string `Failed to delete reference ${refId}: ${result.message()}`);
                }
            }
        }

        log:printInfo("Update rollback completed");
    }

    private isolated function restoreResource(jdbc:Client? jdbcClient, string resourceType, string resourceId, record {|anydata...;|}? backup) returns error? {
        if backup is () {
            return error("No backup available for restore");
        }

        if jdbcClient is () {
            return error("JDBC Client is not initialized");
        }

        // Get table name and primary key
        string tableName = getTableName(resourceType);
        string primaryKeyColumn = getPrimaryKeyColumn(resourceType);

        // Build UPDATE SET clause dynamically from backup record
        string[] setClauses = [];
        foreach var [columnName, value] in backup.entries() {
            string columnValue = self.formatValue(value);
            setClauses.push(string `${columnName} = ${columnValue}`);
        }

        if setClauses.length() == 0 {
            return error("No data to restore");
        }

        // Build and execute UPDATE query
        string updateQuery = string `UPDATE "${tableName}" SET ${string:'join(", ", ...setClauses)} WHERE ${primaryKeyColumn} = '${resourceId}'`;
        sql:ExecutionResult result = check jdbcClient->execute(new RawSQLQuery(updateQuery));

        if result.affectedRowCount == 0 {
            return error(string `Failed to restore ${resourceType}/${resourceId} - resource not found`);
        }

        log:printInfo(string `Restored ${resourceType}/${resourceId} with ${setClauses.length()} fields`);
    }

    // Helper to restore a single reference using JDBC
    private isolated function restoreReference(jdbc:Client? jdbcClient, db_store:REFERENCES ref) returns error? {
        if jdbcClient is () {
            return error("JDBC Client is not initialized");
        }

        // Escape string values
        string escapedSourceResType = regex:replaceAll(ref.SOURCE_RESOURCE_TYPE, "'", "''");
        string escapedSourceResId = regex:replaceAll(ref.SOURCE_RESOURCE_ID, "'", "''");
        string escapedSourceExpr = regex:replaceAll(ref.SOURCE_EXPRESSION, "'", "''");
        string escapedTargetResType = regex:replaceAll(ref.TARGET_RESOURCE_TYPE, "'", "''");
        string escapedTargetResId = regex:replaceAll(ref.TARGET_RESOURCE_ID, "'", "''");
        string displayValue = ref.DISPLAY_VALUE is string ? ref.DISPLAY_VALUE : "";
        string escapedDisplayValue = regex:replaceAll(displayValue, "'", "''");

        // Format timestamps
        string createdAt = self.formatTimestamp(ref.CREATED_AT);
        string updatedAt = self.formatTimestamp(ref.UPDATED_AT);
        string lastUpdated = self.formatTimestamp(ref.LAST_UPDATED);

        // Build INSERT query
        string insertQuery = string `INSERT INTO "REFERENCES" (ID, SOURCE_RESOURCE_TYPE, SOURCE_RESOURCE_ID, SOURCE_EXPRESSION, TARGET_RESOURCE_TYPE, TARGET_RESOURCE_ID, DISPLAY_VALUE, CREATED_AT, UPDATED_AT, LAST_UPDATED) VALUES (${ref.ID}, '${escapedSourceResType}', '${escapedSourceResId}', '${escapedSourceExpr}', '${escapedTargetResType}', '${escapedTargetResId}', '${escapedDisplayValue}', '${createdAt}', '${updatedAt}', '${lastUpdated}')`;

        _ = check jdbcClient->execute(new RawSQLQuery(insertQuery));
    }

    // Helper to format a value for SQL
    public isolated function formatValue(anydata value) returns string {
        if value is () {
            return "NULL";
        } else if value is string {
            string escaped = regex:replaceAll(value, "'", "''");
            return string `'${escaped}'`;
        } else if value is int|float|decimal {
            return value.toString();
        } else if value is boolean {
            return value ? "TRUE" : "FALSE";
        } else if value is time:Date {
            time:Date dateVal = <time:Date>value;
            return string `'${dateVal.year}-${self.padZero(dateVal.month)}-${self.padZero(dateVal.day)}'`;
        } else if value is time:Civil {
            return string `'${self.formatTimestamp(value)}'`;
        } else if value is byte[] {
            byte[] bytes = <byte[]>value;
            return string `X'${bytes.toBase16()}'`;
        } else {
            string escaped = regex:replaceAll(value.toString(), "'", "''");
            return string `'${escaped}'`;
        }
    }

    // Helper to format timestamp
    private isolated function formatTimestamp(time:Civil timestamp) returns string {
        decimal seconds = timestamp.second ?: 0.0d;
        return string `${timestamp.year}-${self.padZero(timestamp.month)}-${self.padZero(timestamp.day)} ${self.padZero(timestamp.hour)}:${self.padZero(timestamp.minute)}:${formatSeconds(seconds)}`;
    }

    // Helper to pad numbers with zero
    private isolated function padZero(int value) returns string {
        return value < 10 ? string `0${value}` : value.toString();
    }
}
