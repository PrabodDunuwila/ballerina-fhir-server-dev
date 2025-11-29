import ballerina_fhir_server.db_store;
import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;
import ballerina_fhir_server.utils as mapperUtils;

import ballerina/log;
import ballerina/sql;
import ballerina/time;

import ballerinax/java.jdbc;

public class CreateHandler {
    private mappers:CreateMapper? createMapper = ();
    private utils:TransactionHandler transactionHandler;
    private final jdbc:Client? jdbcClient;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Main function to save resource
    public isolated function saveResourceWithTransaction(db_store:Client persistClient, string resourceType, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();

        do {
            // Create mapper with jdbcClient if available
            jdbc:Client? jdbcConn = self.jdbcClient;
            mappers:CreateMapper mapper = jdbcConn is jdbc:Client 
                ? new mappers:CreateMapper(jdbcConn) 
                : new mappers:CreateMapper();
            
            // Map resource to insert model
            log:printInfo(string `Mapping ${resourceType} to insert model`);
            record {|anydata...;|}|error? insertModel = mapper.mapToInsertModel(
                <jdbc:Client>self.jdbcClient, resourceType, resourceJson
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
            error? validationResult = utils:validateReferences(persistClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                return validationResult;
            }

            // Save main resource
            log:printInfo(string `Saving main ${resourceType} record`);
            string resourceId = check self.saveMainResource(persistClient, resourceType, insertModel);
            'transaction.mainResourceId = resourceId;

            log:printInfo(string `Saved ${resourceType} with ID: ${resourceId}`);

            // Save all references
            log:printInfo(string `Saving references for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(persistClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                // Rollback on reference save failure
                log:printError(string `Reference save failed: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackCreateTransaction(persistClient, 'transaction, resourceType);
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
            error? rollbackResult = check self.transactionHandler.rollbackCreateTransaction(persistClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(`Rollback Status: ${rollbackResult.toString()}`);
            }
            return e;
        }
    }

    // Generic insert method
    private isolated function saveMainResource(db_store:Client persistClient, string resourceType, record {|anydata...;|} insertModel) returns string|error {
        
        // Get table name
        string tableName = mapperUtils:getTableName(resourceType);
        log:printInfo(string `Saving ${resourceType} to table: ${tableName}`);
        
        // Validate JDBC client
        if self.jdbcClient is () {
            return error("JDBC Client is not initialized.");
        }
        jdbc:Client jdbcClient = <jdbc:Client>self.jdbcClient;
        
        // Extract column names and values from insertModel
        string[] columnNames = insertModel.keys();
        any[] columnValues = insertModel.toArray();
        
        log:printInfo(string `Extracted ${columnNames.length()} columns and ${columnValues.length()} values from insertModel`);
        
        // Print column names and values
        foreach int i in 0 ..< columnNames.length() {
            string colName = columnNames[i];
            any colValue = columnValues[i];
            log:printInfo(string `Column[${i}]: ${colName} = ${colValue.toString()}`);
        }
        
        // Build INSERT query string
        string columnNamesStr = string:'join(", ", ...columnNames);
        
        // Build values string with proper escaping
        string[] valueStrings = [];
        foreach any val in columnValues {
            if val is string {
                // Escape single quotes by doubling them
                string escapedVal = self.replaceAll(val, "'", "''");
                valueStrings.push(string `'${escapedVal}'`);
            } else if val is int|float|decimal {
                valueStrings.push(val.toString());
            } else if val is boolean {
                valueStrings.push(val ? "TRUE" : "FALSE");
            } else if val is byte[] {
                // byte[] maps to BINARY LARGE OBJECT - use H2 binary literal format X'hexstring'
                byte[] byteVal = <byte[]>val;
                string hexStr = byteVal.toBase16();
                valueStrings.push(string `X'${hexStr}'`);
            } else if val is time:Date {
                // time:Date maps to DATE format: 'YYYY-MM-DD'
                time:Date dateVal = <time:Date>val;
                string dateStr = string `${dateVal.year}-${self.padZero(dateVal.month)}-${self.padZero(dateVal.day)}`;
                valueStrings.push(string `'${dateStr}'`);
            } else if val is time:Civil {
                // time:Civil maps to TIMESTAMP format: 'YYYY-MM-DD HH:MM:SS.ms'
                time:Civil civilTime = <time:Civil>val;
                decimal seconds = civilTime.second ?: 0.0d;
                string timestampStr = string `${civilTime.year}-${self.padZero(civilTime.month)}-${self.padZero(civilTime.day)} ${self.padZero(civilTime.hour)}:${self.padZero(civilTime.minute)}:${self.formatSeconds(seconds)}`;
                valueStrings.push(string `'${timestampStr}'`);
            } else if val is () {
                valueStrings.push("NULL");
            } else {
                // Convert any other type to string and escape
                string strVal = val.toString();
                string escapedVal = self.replaceAll(strVal, "'", "''");
                valueStrings.push(string `'${escapedVal}'`);
            }
        }
        
        string valuesStr = string:'join(", ", ...valueStrings);
        
        // Build complete INSERT query string with table name in double quotes
        string completeQueryStr = "INSERT INTO \"" + tableName + "\"(" + columnNamesStr + ") VALUES (" + valuesStr + ")";
        log:printInfo(string `Executing query: ${completeQueryStr}`);
        
        // Execute raw SQL by creating a custom ParameterizedQuery implementation
        RawSQLQuery rawQuery = new(completeQueryStr);
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

    // Helper function for string replacement
    private isolated function replaceAll(string input, string search, string replace) returns string {
        int startPos = 0;
        string result = "";
        int? idx = input.indexOf(search, startPos);
        while idx is int {
            result += input.substring(startPos, idx) + replace;
            startPos = idx + search.length();
            idx = input.indexOf(search, startPos);
        }
        result += input.substring(startPos);
        return result;
    }

    // Helper function to pad numbers with leading zero
    private isolated function padZero(int num) returns string {
        return num < 10 ? string `0${num}` : num.toString();
    }

    // Helper function to format seconds with decimals
    private isolated function formatSeconds(decimal seconds) returns string {
        // Format to 2 decimal places
        int wholePart = <int>seconds;
        decimal fractionalPart = seconds - <decimal>wholePart;
        int milliseconds = <int>(fractionalPart * 100);
        return string `${self.padZero(wholePart)}.${milliseconds}`;
    }
}

// Custom class to execute raw SQL queries
class RawSQLQuery {
    *sql:ParameterizedQuery;
    public final string[] & readonly strings;
    public final sql:Value[] & readonly insertions;

    isolated function init(string sqlQuery) {
        self.strings = [sqlQuery].cloneReadOnly();
        self.insertions = [].cloneReadOnly();
    }
}


