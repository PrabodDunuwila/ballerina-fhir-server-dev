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
        if 'transaction.backupReferences is record {|anydata...;|}[] {
            record {|anydata...;|}[] backupRefs = <record {|anydata...;|}[]>'transaction.backupReferences;
            foreach var ref in backupRefs {
                error? restoreResult = self.restoreReference(jdbcClient, ref);
                if restoreResult is error {
                    log:printError(string `Failed to restore reference: ${restoreResult.message()}`);
                } else {
                    int refId = check int:fromString(ref.get("ID").toString());
                    log:printInfo(string `Restored reference: ${refId}`);
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
    private isolated function restoreReference(jdbc:Client? jdbcClient, record {|anydata...;|} ref) returns error? {
        if jdbcClient is () {
            return error("JDBC Client is not initialized");
        }

        // Extract and escape string values
        string sourceResType = ref.get("SOURCE_RESOURCE_TYPE").toString();
        string sourceResId = ref.get("SOURCE_RESOURCE_ID").toString();
        string sourceExpr = ref.get("SOURCE_EXPRESSION").toString();
        string targetResType = ref.get("TARGET_RESOURCE_TYPE").toString();
        string targetResId = ref.get("TARGET_RESOURCE_ID").toString();
        string displayValue = ref.get("DISPLAY_VALUE").toString();
        
        string escapedSourceResType = regex:replaceAll(sourceResType, "'", "''");
        string escapedSourceResId = regex:replaceAll(sourceResId, "'", "''");
        string escapedSourceExpr = regex:replaceAll(sourceExpr, "'", "''");
        string escapedTargetResType = regex:replaceAll(targetResType, "'", "''");
        string escapedTargetResId = regex:replaceAll(targetResId, "'", "''");
        string escapedDisplayValue = regex:replaceAll(displayValue, "'", "''");

        // Format timestamps
        anydata createdAtData = ref.get("CREATED_AT");
        anydata updatedAtData = ref.get("UPDATED_AT");
        anydata lastUpdatedData = ref.get("LAST_UPDATED");
        
        string createdAt = createdAtData is time:Civil ? formatTimestamp(createdAtData) : createdAtData.toString();
        string updatedAt = updatedAtData is time:Civil ? formatTimestamp(updatedAtData) : updatedAtData.toString();
        string lastUpdated = lastUpdatedData is time:Civil ? formatTimestamp(lastUpdatedData) : lastUpdatedData.toString();

        // Get reference ID
        int refId = check int:fromString(ref.get("ID").toString());

        // Build INSERT query
        string insertQuery = string `INSERT INTO "REFERENCES" (ID, SOURCE_RESOURCE_TYPE, SOURCE_RESOURCE_ID, SOURCE_EXPRESSION, TARGET_RESOURCE_TYPE, TARGET_RESOURCE_ID, DISPLAY_VALUE, CREATED_AT, UPDATED_AT, LAST_UPDATED) VALUES (${refId}, '${escapedSourceResType}', '${escapedSourceResId}', '${escapedSourceExpr}', '${escapedTargetResType}', '${escapedTargetResId}', '${escapedDisplayValue}', '${createdAt}', '${updatedAt}', '${lastUpdated}')`;

        _ = check jdbcClient->execute(new RawSQLQuery(insertQuery));
    }

    // Helper to format a value for SQL (delegates to commons utility)
    public isolated function formatValue(anydata value) returns string {
        return formatSqlValue(value);
    }
}
