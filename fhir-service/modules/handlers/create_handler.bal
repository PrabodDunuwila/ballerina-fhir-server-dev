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
            log:printInfo(string `Mapping ${resourceType} to insert model`);
            record {|anydata...;|}|error? insertModel = mapper.mapToInsertModel(
                validatedClient, resourceType, resourceJson
            );

            if insertModel is () {
                return error(string `Failed to create insert model for ${resourceType}`);
            }

            if insertModel is error {
                return insertModel;
            }

            // Get extracted references after mapping
            json[] references = mapper.getReferences();

            // Validate all references BEFORE saving main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}`);
            error? validationResult = utils:validateReferences(self.jdbcClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                return validationResult;
            }

            // Save main resource
            log:printInfo(string `Saving main ${resourceType} record`);
            string resourceId = check self.saveMainResource(resourceType, insertModel);
            'transaction.mainResourceId = resourceId;

            log:printInfo(string `Saved ${resourceType} with ID: ${resourceId}`);

            // Save all references
            log:printInfo(string `Saving references for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(self.jdbcClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                // Rollback on reference save failure
                log:printError(string `Reference save failed: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackCreateTransaction(self.jdbcClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(`Rollback Status: ${rollbackResult.toString()}`);
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully saved ${resourceType}/${resourceId} with all references`);
            return resourceId;

        } on fail error e {
            // Rollback on any failure
            log:printError(string `Transaction failed for ${resourceType}: ${e.message()}`);
            error? rollbackResult = check self.transactionHandler.rollbackCreateTransaction(self.jdbcClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(`Rollback Status: ${rollbackResult.toString()}`);
            }
            return e;
        }
    }

    // Generic insert method
    private isolated function saveMainResource(string resourceType, record {|anydata...;|} insertModel) returns string|error {
        
        // Get table name
        string tableName = mapperUtils:getTableName(resourceType);
        log:printInfo(string `Saving ${resourceType} to table: ${tableName}`);
        
        // Validate JDBC client
        jdbc:Client jdbcClient = check utils:getValidatedJdbcClient(self.jdbcClient);
        
        // Extract column names and values from insertModel
        string[] columnNames = insertModel.keys();
        anydata[] columnValues = insertModel.toArray();
        
        log:printInfo(string `Extracted ${columnNames.length()} columns and ${columnValues.length()} values from insertModel`);
        
        // Print column names and values
        foreach int i in 0 ..< columnNames.length() {
            string colName = columnNames[i];
            any colValue = columnValues[i];
            log:printInfo(string `Column[${i}]: ${colName} = ${colValue.toString()}`);
        }
        
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
        log:printInfo(string `Executing query: ${completeQueryStr}`);
        
        // Execute raw SQL by creating a custom ParameterizedQuery implementation
        utils:RawSQLQuery rawQuery = new(completeQueryStr);
        sql:ExecutionResult|error result = jdbcClient->execute(rawQuery);
        
        if result is error {
            log:printError(string `DB Insert Error for ${resourceType}: ${result.message()}`);
            return result;
        }
        
        log:printInfo(string `Insert successful`);

        // 5. Get primary key value
        string primaryKeyColumn = mapperUtils:getPrimaryKeyColumn(resourceType);
        any resourceIdValue = insertModel[primaryKeyColumn];
        string resourceId = resourceIdValue is string ? resourceIdValue : resourceIdValue.toString();

        log:printInfo(string `Successfully inserted ${resourceType} with ID: ${resourceId}`);
        return resourceId;
    }
}


