import ballerina/log;
import ballerina/time;
import ballerinax/java.jdbc;
import ballerina/sql;
import ballerina_fhir_server.utils;

// Handler for managing resource version history
public class HistoryHandler {
    private final jdbc:Client? jdbcClient;
    private utils:TransactionHandler transactionHandler;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Save current version to history before update/delete
    public isolated function saveToHistory(string resourceType, string resourceId, 
                                          record {|anydata...;|} currentVersion, string operation) returns error? {
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string tableName = utils:getTableName(resourceType);
        string historyTableName = tableName + "History";
        string primaryKeyColumn = utils:getPrimaryKeyColumn(resourceType);
        
        // History table uses a different column name for the resource ID (e.g., APPOINTMENTTABLE_ID)
        string historyResourceIdColumn = string `${tableName}_ID`;
        
        // Columns to exclude from history (ID is auto-generated, CREATED_AT is added separately, LAST_UPDATED and UPDATED_AT don't exist in history)
        string[] excludedColumns = ["ID", "CREATED_AT", "LAST_UPDATED", "UPDATED_AT"];
        
        // Get all column names and values from the current version
        string[] columns = [];
        string[] values = [];
        
        foreach var [key, value] in currentVersion.entries() {
            // Skip excluded columns
            if excludedColumns.indexOf(key) is int {
                continue;
            }
            
            // Map primary key column to history table's foreign key column name
            string columnName = key;
            if key == primaryKeyColumn {
                columnName = historyResourceIdColumn;
            }
            
            columns.push(columnName);
            string formattedValue = self.transactionHandler.formatValue(value);
            values.push(formattedValue);
        }
        
        // Add OPERATION and CREATED_AT columns
        columns.push("OPERATION");
        values.push(string `'${operation}'`);
        
        columns.push("CREATED_AT");
        time:Civil now = time:utcToCivil(time:utcNow());
        string timestamp = string `'${now.year}-${utils:padZero(now.month)}-${utils:padZero(now.day)} ${utils:padZero(now.hour)}:${utils:padZero(now.minute)}:${utils:padZero(<int>now.second)}'`;
        values.push(timestamp);
        
        string columnList = string:'join(", ", ...columns);
        string valueList = string:'join(", ", ...values);
        
        string sqlQuery = string `INSERT INTO "${historyTableName}" (${columnList}) VALUES (${valueList})`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);
        
        _ = check jdbcConn->execute(query);
        
        int versionId = check int:fromString(currentVersion.get("VERSION_ID").toString());
        log:printInfo(string `Saved version ${versionId} of ${resourceType}/${resourceId} to history`);
    }
    
    // Get a specific version of a resource from history
    public isolated function getResourceVersion(string resourceType, string resourceId, int versionId) returns json|error {
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string tableName = utils:getTableName(resourceType);
        string historyTableName = tableName + "History";
        string historyResourceIdColumn = string `${tableName}_ID`;

        string sqlQuery = string `SELECT RESOURCE_JSON FROM "${historyTableName}" WHERE ${historyResourceIdColumn} = '${utils:escapeSql(resourceId)}' AND VERSION_ID = ${versionId}`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId}/_history/${versionId} not found`);
        }

        // Convert RESOURCE_JSON to json
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();

        return resourceJson;
    }
    
    // Get all history versions of a specific resource
    public isolated function getResourceHistory(string resourceType, string resourceId) returns json[]|error {
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string tableName = utils:getTableName(resourceType);
        string historyTableName = tableName + "History";
        string historyResourceIdColumn = string `${tableName}_ID`;

        string sqlQuery = string `SELECT RESOURCE_JSON FROM "${historyTableName}" WHERE ${historyResourceIdColumn} = '${utils:escapeSql(resourceId)}' ORDER BY VERSION_ID DESC`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON;|}[] results = check from var result in resultStream
            select result;

        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }

        return versions;
    }
    
    // Get all history for all resources of a type
    public isolated function getAllHistory(string resourceType) returns json[]|error {
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string tableName = utils:getTableName(resourceType);
        string historyTableName = tableName + "History";

        string sqlQuery = string `SELECT RESOURCE_JSON FROM "${historyTableName}" ORDER BY CREATED_AT DESC`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON;|}[] results = check from var result in resultStream
            select result;

        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }

        return versions;
    }
}
