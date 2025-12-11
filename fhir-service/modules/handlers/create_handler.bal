import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;
import ballerina_fhir_server.utils as mapperUtils;

import ballerina/log;
import ballerina/sql;

import ballerinax/java.jdbc;

public class CreateHandler {
    private utils:TransactionHandler transactionHandler;
    private final jdbc:Client? jdbcClient;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Main function to save resource
    public isolated function saveResourceWithTransaction(string resourceType, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();

        do {
            // Create mapper with jdbcClient
            jdbc:Client validatedClient = check utils:getValidatedJdbcClient(self.jdbcClient);
            mappers:CreateMapper mapper = new mappers:CreateMapper(validatedClient);
            
            // Map resource to insert model
            log:printDebug(string `Mapping ${resourceType} to insert model`);
            record {|anydata...;|}|error? insertModel = mapper.mapToInsertModel(
                validatedClient, resourceType, resourceJson
            );

            if insertModel is () {
                log:printError(string `Failed to create insert model for ${resourceType}: mapper returned null`);
                return error(string `Failed to create insert model for ${resourceType}`);
            }

            if insertModel is error {
                log:printError(string `Mapping failed for ${resourceType}: ${insertModel.message()}`);
                return insertModel;
            }

            // Get extracted references after mapping
            json[] references = mapper.getReferences();
            log:printDebug(string `Extracted ${references.length()} reference(s) from ${resourceType}`);

            // Validate all references BEFORE saving main resource
            log:printDebug(string `Validating ${references.length()} reference(s) for ${resourceType}`);
            error? validationResult = utils:validateReferences(self.jdbcClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                return validationResult;
            }

            // Save main resource
            log:printDebug(string `Saving main ${resourceType} record`);
            string resourceId = check self.saveMainResource(resourceType, insertModel);
            'transaction.mainResourceId = resourceId;

            log:printDebug(string `Created ${resourceType} with ID: ${resourceId}`);

            // Save all references
            log:printDebug(string `Saving ${references.length()} reference(s) for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(self.jdbcClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                // Rollback on reference save failure
                log:printError(string `Failed to save references for ${resourceType}/${resourceId}: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackCreateTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(string `Rollback failed for ${resourceType}/${resourceId}: ${rollbackResult.message()}`);
                }
                return refResult;
            }

            // Commit transaction
            log:printDebug(string `Committing transaction for ${resourceType}/${resourceId}`);
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully created ${resourceType}/${resourceId} with ${references.length()} reference(s)`);
            return resourceId;

        } on fail error e {
            // Rollback on any failure
            log:printError(string `Create transaction failed for ${resourceType}: ${e.message()}`);
            error? rollbackResult = check self.transactionHandler.rollbackCreateTransaction(self.jdbcClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(string `Rollback failed during create transaction cleanup for ${resourceType}: ${rollbackResult.message()}`);
            }
            return e;
        }
    }

    // Generic insert method
    private isolated function saveMainResource(string resourceType, record {|anydata...;|} insertModel) returns string|error {
        
        // Get table name
        string tableName = mapperUtils:getTableName(resourceType);
        log:printDebug(string `Target table for ${resourceType}: ${tableName}`);
        
        // Validate JDBC client
        jdbc:Client jdbcClient = check utils:getValidatedJdbcClient(self.jdbcClient);
        
        // Get primary key value to check for duplicates
        string primaryKeyColumn = mapperUtils:getPrimaryKeyColumn(resourceType);
        any resourceIdValue = insertModel[primaryKeyColumn];
        string resourceId = resourceIdValue is string ? resourceIdValue : resourceIdValue.toString();
        
        // Check if resource already exists
        log:printDebug(string `Checking if ${resourceType}/${resourceId} already exists`);
        boolean exists = check utils:validateReferenceExists(self.jdbcClient, resourceType, resourceId);
        if exists {
            log:printWarn(string `Duplicate resource creation attempted: ${resourceType}/${resourceId}`);
            return error(string `Resource already exists: ${resourceType}/${resourceId}. Use PUT to update the resource.`);
        }
        
        // Extract column names and values from insertModel
        string[] columnNames = insertModel.keys();
        anydata[] columnValues = insertModel.toArray();
        
        log:printDebug(string `Prepared insert with ${columnNames.length()} columns for ${resourceType}/${resourceId}`);
        
        // Build INSERT query string
        string columnNamesStr = string:'join(", ", ...columnNames);
        
        // Build values string using consolidated formatting utility
        string[] valueStrings = [];
        foreach any val in columnValues {
            valueStrings.push(utils:formatSqlValue(val));
        }
        
        string valuesStr = string:'join(", ", ...valueStrings);
        
        // Build complete INSERT query string with table name in double quotes
        string completeQueryStr = "INSERT INTO \"" + tableName + "\"(" + columnNamesStr + ") VALUES (" + valuesStr + ")";
        log:printDebug(string `Executing INSERT query for ${resourceType}/${resourceId}`);
        
        // Execute raw SQL by creating a custom ParameterizedQuery implementation
        utils:RawSQLQuery rawQuery = new(completeQueryStr);
        sql:ExecutionResult|error result = jdbcClient->execute(rawQuery);
        
        if result is error {
            log:printError(string `Database insert failed for ${resourceType}/${resourceId}: ${result.message()}`);
            return result;
        }
        
        log:printDebug(string `Successfully inserted ${resourceType}/${resourceId} into database`);
        return resourceId;
    }
}


