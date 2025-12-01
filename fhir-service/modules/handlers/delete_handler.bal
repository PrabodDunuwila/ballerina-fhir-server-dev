import ballerina_fhir_server.utils;

import ballerina/log;
import ballerina/sql;
import ballerinax/java.jdbc;

public class DeleteHandler {
    private utils:TransactionHandler transactionHandler;
    private HistoryHandler historyHandler;
    private final jdbc:Client? jdbcClient;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.transactionHandler = new utils:TransactionHandler();
        self.historyHandler = new HistoryHandler(jdbcClient);
    }

    // Main function to delete resource with full transaction support
    public isolated function deleteResourceWithTransaction(string resourceType, string resourceId) returns boolean|error {

        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Check if resource exists
            log:printInfo(string `Checking if ${resourceType}/${resourceId} exists`);
            boolean exists = check self.checkResourceExists(resourceType, resourceId);

            if !exists {
                return error(string `${resourceType}/${resourceId} not found`);
            }

            // Backup before delete
            log:printInfo(string `Backing up ${resourceType}/${resourceId} before deletion`);
            record {|anydata...;|}? backup = check self.backupResource(resourceType, resourceId);
            'transaction.backupResource = backup;
            'transaction.backupReferences = check self.backupReferences(resourceType, resourceId);

            // Save to history before deletion
            if backup is record {|anydata...;|} {
                int versionId = check int:fromString(backup.get("VERSION_ID").toString());
                log:printInfo(string `Saving version ${versionId} of ${resourceType}/${resourceId} to history before deletion`);
                error? historyResult = self.historyHandler.saveToHistory(resourceType, resourceId, backup, "DELETE");
                if historyResult is error {
                    log:printError(string `Failed to save history: ${historyResult.message()}`);
                    error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(
                        self.jdbcClient, 'transaction, resourceType
                    );
                    if (rollbackResult is error) {
                        log:printError(rollbackResult.toString());
                    }
                    return historyResult;
                }
            }

            // Find references
            log:printInfo(string `Finding references for ${resourceType}/${resourceId}`);
            int[] referenceIds = check self.findSourceReferences(resourceType, resourceId);

            // Delete references
            error? refResult = utils:deleteReferences(self.jdbcClient, referenceIds, 'transaction);

            if refResult is error {
                error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Delete main resource
            log:printInfo(string `Deleting main ${resourceType}/${resourceId} record`);
            error? deleteResult = utils:deleteResource(self.jdbcClient, resourceType, resourceId);

            if deleteResult is error {
                error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteResult;
            }

            // Commit Transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully deleted ${resourceType}/${resourceId}`);
            return true;

        } on fail error e {
            error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(self.jdbcClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(rollbackResult.toString());
            }
            return e;
        }
    }

    // Check if resource exists
    private isolated function checkResourceExists(string resourceType, string resourceId) returns boolean|error {
        return utils:validateReferenceExists(self.jdbcClient, resourceType, resourceId);
    }

    // Find all references where this resource is the SOURCE
    private isolated function findSourceReferences(string resourceType, string resourceId) returns int[]|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string sqlQuery = string `SELECT ID FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND SOURCE_RESOURCE_ID = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|int ID;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|int ID;|}[] results = check from var result in resultStream
            select result;

        int[] referenceIds = from var ref in results
            select ref.ID;

        return referenceIds;
    }

    // Add backup methods to DeleteHandler
    private isolated function backupResource(string resourceType, string resourceId) returns record {|anydata...;|}|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string sqlQuery = string `SELECT * FROM "${tableName}" WHERE ${primaryKey} = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|anydata...;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|anydata...;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found for backup`);
        }

        return results[0];
    }

    private isolated function backupReferences(string resourceType, string resourceId) returns record {|anydata...;|}[]|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string sqlQuery = string `SELECT * FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND SOURCE_RESOURCE_ID = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|anydata...;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|anydata...;|}[] results = check from var ref in resultStream
            select ref;

        return results;
    }
}
