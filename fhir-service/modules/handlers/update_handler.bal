import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;

import ballerina/log;
import ballerina/sql;
import ballerinax/java.jdbc;

public class UpdateHandler {
    private mappers:UpdateMapper updateMapper;
    private utils:TransactionHandler transactionHandler;
    private HistoryHandler historyHandler;
    private final jdbc:Client? jdbcClient;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.updateMapper = new mappers:UpdateMapper();
        self.transactionHandler = new utils:TransactionHandler();
        self.historyHandler = new HistoryHandler(jdbcClient);
    }

    // Main function for PUT (full update)
    public isolated function updateResourceWithTransaction(string resourceType, string resourceId, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Get JDBC client
            jdbc:Client? jdbcConn = self.jdbcClient;
            if jdbcConn is () {
                return error("JDBC client not initialized");
            }

            // Check if resource exists
            log:printInfo(string `Checking if ${resourceType}/${resourceId} exists`);
            boolean exists = check self.checkResourceExists(resourceType, resourceId);

            if !exists {
                return error(string `${resourceType}/${resourceId} not found`);
            }

            // Backup existing resource (for rollback)
            log:printInfo(string `Backing up existing ${resourceType}/${resourceId}`);
            record {|anydata...;|} backup = check self.backupResource(resourceType, resourceId);
            'transaction.backupResource = backup;

            // Delete old references (they will be recreated)
            log:printInfo(string `Deleting old references for ${resourceType}/${resourceId}`);
            int[] oldReferenceIds = check self.findSourceReferences(resourceType, resourceId);
            error? deleteRefsResult = utils:deleteReferences(self.jdbcClient, oldReferenceIds, 'transaction);

            if deleteRefsResult is error {
                log:printError(string `Failed to delete old references: ${deleteRefsResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteRefsResult;
            }

            // Save current version to history before updating
            log:printInfo(string `Saving current version of ${resourceType}/${resourceId} to history`);
            error? historyResult = self.historyHandler.saveToHistory(resourceType, resourceId, backup, "UPDATE");
            if historyResult is error {
                log:printError(string `Failed to save history: ${historyResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return historyResult;
            }

            // Get current VERSION_ID and increment it
            int currentVersion = check self.getCurrentVersionFromBackup(backup, resourceType);
            int newVersion = currentVersion + 1;

            // Map updated resource to update model
            log:printInfo(string `Mapping updated ${resourceType} to model (version ${newVersion})`);
            record {|anydata...;|}|error? updateModel = self.updateMapper.mapToUpdateModel(jdbcConn, resourceType, resourceJson, newVersion);

            if updateModel is () || updateModel is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateModel is error ? updateModel : error("Failed to create update model");
            }

            // Get extracted references after mapping
            json[] references = self.updateMapper.getReferences();

            // Validate all references BEFORE patching main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}/${resourceId}`);
            error? validationResult = utils:validateReferences(self.jdbcClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return validationResult;
            }

            // Update main resource
            log:printInfo(string `Updating main ${resourceType}/${resourceId} record`);
            error? updateResult = self.updateMainResource(resourceType, resourceId, updateModel);

            if updateResult is error {
                log:printError(string `Main resource update failed: ${updateResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateResult;
            }

            // Save new references
            log:printInfo(string `Saving new references for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(self.jdbcClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                log:printError(string `Reference save failed: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully updated ${resourceType}/${resourceId}`);
            return resourceId;

        } on fail error e {
            log:printError(string `Update transaction failed for ${resourceType}/${resourceId}: ${e.message()}`);
            error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                self.jdbcClient, 'transaction, resourceType
            );
            if (rollbackResult is error) {
                log:printError(rollbackResult.toString());
            }
            return e;
        }
    }

    // Main function for PATCH (partial update) with transaction support
    public isolated function patchResourceWithTransaction(string resourceType, string resourceId, json patchJson) returns json|error {
        // Get JDBC client
        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Check if resource exists and get current data
            log:printInfo(string `Fetching existing ${resourceType}/${resourceId}`);
            json existingResource = check self.getResourceAsJson(resourceType, resourceId);

            // Backup for rollback
            log:printInfo(string `Backing up existing resource`);
            record {|anydata...;|} backup = check self.backupResource(resourceType, resourceId);
            'transaction.backupResource = backup;

            // Apply patch to existing resource
            log:printInfo(string `Applying patch to ${resourceType}/${resourceId}`);
            json mergedResource = check self.applyPatch(existingResource, patchJson);

            // Delete old references
            log:printInfo(string `Deleting old references`);
            int[] oldReferenceIds = check self.findSourceReferences(resourceType, resourceId);
            error? deleteRefsResult = utils:deleteReferences(self.jdbcClient, oldReferenceIds, 'transaction);

            if deleteRefsResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteRefsResult;
            }

            // Map merged resource to update model
            log:printInfo(string `Mapping patched resource to model`);
            record {|anydata...;|}|error? updateModel = self.updateMapper.mapToUpdateModel(jdbcConn, resourceType, mergedResource);

            if updateModel is () || updateModel is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateModel is error ? updateModel : error("Failed to create update model");
            }

            // Get extracted references after mapping
            json[] references = self.updateMapper.getReferences();

            // Validate all references BEFORE updating main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}/${resourceId}`);
            error? validationResult = utils:validateReferences(self.jdbcClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return validationResult;
            }

            // Update main resource
            log:printInfo(string `Updating main resource`);
            error? updateResult = self.updateMainResource(resourceType, resourceId, updateModel);

            if updateResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateResult;
            }

            // Save new references
            log:printInfo(string `Saving new references`);
            error? refResult = utils:saveReferences(self.jdbcClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully patched ${resourceType}/${resourceId}`);
            return mergedResource;

        } on fail error e {
            log:printError(string `Patch transaction failed: ${e.message()}`);
            error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                self.jdbcClient, 'transaction, resourceType
            );
            if (rollbackResult is error) {
                log:printError(rollbackResult.toString());
            }
            return e;
        }
    }

    // Check if resource exists
    private isolated function checkResourceExists(string resourceType, string resourceId) returns boolean|error {
        // Use generic JDBC validation
        return utils:validateReferenceExists(self.jdbcClient, resourceType, resourceId);
    }

    // Backup resource for rollback
    private isolated function backupResource(string resourceType,
            string resourceId) returns record {|anydata...;|}|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string sqlQuery = string `SELECT * FROM "${tableName}" WHERE ${primaryKey} = '${resourceId}'`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        stream<record {|anydata...;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|anydata...;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found for backup`);
        }

        return results[0];
    }

    // Get resource as JSON (for PATCH operations)
    private isolated function getResourceAsJson(string resourceType, string resourceId) returns json|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string sqlQuery = string `SELECT RESOURCE_JSON FROM "${tableName}" WHERE ${primaryKey} = '${resourceId}'`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found`);
        }

        byte[] resourceBlob = results[0].RESOURCE_JSON;
        string jsonString = check string:fromBytes(resourceBlob);
        json resourceJson = check jsonString.fromJsonString();

        return resourceJson;
    }

    // Apply JSON patch
    private isolated function applyPatch(json existing, json patch) returns json|error {
        if !(existing is map<json>) {
            return error(string `Existing resource is not a JSON object: ${existing.toString()}`);
        }

        if !(patch is map<json>) {
            return error(string `Patch is not a JSON object: ${patch.toString()}`);
        }

        map<json> existingMap = <map<json>>existing;
        map<json> patchMap = <map<json>>patch;

        // Create a new map to hold merged values
        map<json> mergedMap = existingMap.clone();

        // Patch values override existing values
        foreach var [key, value] in patchMap.entries() {
            mergedMap[key] = value;
        }

        return mergedMap;
    }

    // Find source references
    private isolated function findSourceReferences(string resourceType, string resourceId) returns int[]|error {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string sqlQuery = string `SELECT ID FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${resourceType}' AND SOURCE_RESOURCE_ID = '${resourceId}'`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        stream<record {|int ID;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|int ID;|}[] results = check from var result in resultStream
            select result;

        int[] referenceIds = from var ref in results
            select ref.ID;

        return referenceIds;
    }

    private isolated function updateMainResource(string resourceType, string resourceId, record {|anydata...;|} updateModel) returns error? {

        jdbc:Client? jdbcConn = self.jdbcClient;
        if jdbcConn is () {
            return error("JDBC client not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        // Build UPDATE SET clause dynamically from updateModel fields
        string[] setClauses = [];
        foreach var [key, value] in updateModel.entries() {
            string formattedValue = self.transactionHandler.formatValue(value);
            setClauses.push(string `${key} = ${formattedValue}`);
        }

        if setClauses.length() == 0 {
            return error("No fields to update");
        }

        string setClause = string:'join(", ", ...setClauses);
        string sqlQuery = string `UPDATE "${tableName}" SET ${setClause} WHERE ${primaryKey} = '${resourceId}'`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        sql:ExecutionResult|sql:Error result = jdbcConn->execute(query);

        if result is sql:Error {
            return error(string `Failed to update ${resourceType}/${resourceId}: ${result.message()}`);
        }

        return;
    }

    // Extract current VERSION_ID from backup
    private isolated function getCurrentVersionFromBackup(record {|anydata...;|} backup, string resourceType) returns int|error {
        // Generic extraction - all resource tables have VERSION_ID
        anydata versionField = backup["VERSION_ID"];
        if versionField is int {
            return versionField;
        }
        return error(string `Could not extract VERSION_ID for ${resourceType}: field is ${versionField.toString()}`);
    }
}
