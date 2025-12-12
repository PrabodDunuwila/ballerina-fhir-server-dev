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
        log:printDebug(string `Saving ${resourceType}/${resourceId} to history (operation: ${operation})`);
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        // Get RESOURCE_JSON from current version
        byte[] resourceJsonBytes = check currentVersion.get("RESOURCE_JSON").ensureType();
        
        // Get the latest VERSION_ID from history table for this resource and increment by 1
        string maxVersionQuery = string `SELECT MAX(VERSION_ID) as MAX_VERSION FROM "RESOURCE_HISTORY" WHERE RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND RESOURCE_ID = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery versionQuery = new utils:RawSQLQuery(maxVersionQuery);
        
        stream<record {|int? MAX_VERSION;|}, sql:Error?> versionStream = jdbcConn->query(versionQuery);
        record {|int? MAX_VERSION;|}[] versionResults = check from var result in versionStream
            select result;
        
        // If no history exists, start with version 1, otherwise increment the latest version
        int newVersionId = 1;
        if versionResults.length() > 0 && versionResults[0].MAX_VERSION is int {
            newVersionId = <int>versionResults[0].MAX_VERSION + 1;
        }
        
        log:printDebug(string `New history version for ${resourceType}/${resourceId}: ${newVersionId}`);
        
        // Get current timestamp
        time:Civil now = time:utcToCivil(time:utcNow());
        // Ensure seconds are within valid range (0-59)
        int seconds = <int>now.second;
        if seconds >= 60 {
            seconds = 59;
        }
        string timestamp = string `'${now.year}-${utils:padZero(now.month)}-${utils:padZero(now.day)} ${utils:padZero(now.hour)}:${utils:padZero(now.minute)}:${utils:padZero(seconds)}'`;
        
        // Insert into unified RESOURCE_HISTORY table with incremented version
        string sqlQuery = string `INSERT INTO "RESOURCE_HISTORY" (RESOURCE_TYPE, RESOURCE_ID, VERSION_ID, OPERATION, CREATED_AT, RESOURCE_JSON) VALUES ('${utils:escapeSql(resourceType)}', '${utils:escapeSql(resourceId)}', ${newVersionId}, '${operation}', ${timestamp}, X'${resourceJsonBytes.toBase16()}')`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);
        
        _ = check jdbcConn->execute(query);
        
        log:printDebug(string `Saved version ${newVersionId} of ${resourceType}/${resourceId} to unified history table`);
    }
    
    // Get a specific version of a resource from history
    public isolated function getResourceVersion(string resourceType, string resourceId, int versionId) returns map<json>|error {
        log:printDebug(string `Fetching ${resourceType}/${resourceId}/_history/${versionId}`);
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string sqlQuery = string `SELECT RESOURCE_JSON, OPERATION, CREATED_AT FROM "RESOURCE_HISTORY" WHERE RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND RESOURCE_ID = '${utils:escapeSql(resourceId)}' AND VERSION_ID = ${versionId}`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            log:printWarn(string `History version not found: ${resourceType}/${resourceId}/_history/${versionId}`);
            return error(string `${resourceType}/${resourceId}/_history/${versionId} not found`);
        }

        // Convert RESOURCE_JSON to json
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();

        // Format timestamp as ISO 8601 string
        time:Civil createdAt = results[0].CREATED_AT;
        string timestamp = string `${createdAt.year}-${utils:padZero(createdAt.month)}-${utils:padZero(createdAt.day)}T${utils:padZero(createdAt.hour)}:${utils:padZero(createdAt.minute)}:${utils:padZero(<int>createdAt.second)}.000Z`;

        log:printDebug(string `Retrieved version ${versionId} of ${resourceType}/${resourceId} from history`);
        return {"resource": resourceJson, "operation": results[0].OPERATION, "lastModified": timestamp};
    }
    
    // Get all history versions of a specific resource
    public isolated function getResourceHistory(string resourceType, string resourceId) returns map<json>[]|error {
        log:printDebug(string `Fetching all history for ${resourceType}/${resourceId}`);
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string sqlQuery = string `SELECT RESOURCE_JSON, OPERATION, CREATED_AT FROM "RESOURCE_HISTORY" WHERE RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND RESOURCE_ID = '${utils:escapeSql(resourceId)}' ORDER BY VERSION_ID DESC`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}[] results = check from var result in resultStream
            select result;

        map<json>[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            
            // Format timestamp as ISO 8601 string
            time:Civil createdAt = historyRecord.CREATED_AT;
            string timestamp = string `${createdAt.year}-${utils:padZero(createdAt.month)}-${utils:padZero(createdAt.day)}T${utils:padZero(createdAt.hour)}:${utils:padZero(createdAt.minute)}:${utils:padZero(<int>createdAt.second)}.000Z`;
            
            versions.push({"resource": resourceJson, "operation": historyRecord.OPERATION, "lastModified": timestamp});
        }

        log:printDebug(string `Retrieved ${versions.length()} history version(s) for ${resourceType}/${resourceId}`);
        return versions;
    }
    
    // Get all history for all resources of a type
    public isolated function getAllHistory(string resourceType) returns map<json>[]|error {
        log:printDebug(string `Fetching all history for resource type: ${resourceType}`);
        jdbc:Client jdbcConn = check utils:getValidatedJdbcClient(self.jdbcClient);

        string sqlQuery = string `SELECT RESOURCE_JSON, OPERATION, CREATED_AT FROM "RESOURCE_HISTORY" WHERE RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' ORDER BY CREATED_AT DESC`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}, sql:Error?> resultStream = jdbcConn->query(query);

        record {|byte[] RESOURCE_JSON; string OPERATION; time:Civil CREATED_AT;|}[] results = check from var result in resultStream
            select result;

        map<json>[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            
            // Format timestamp as ISO 8601 string
            time:Civil createdAt = historyRecord.CREATED_AT;
            string timestamp = string `${createdAt.year}-${utils:padZero(createdAt.month)}-${utils:padZero(createdAt.day)}T${utils:padZero(createdAt.hour)}:${utils:padZero(createdAt.minute)}:${utils:padZero(<int>createdAt.second)}.000Z`;
            
            versions.push({"resource": resourceJson, "operation": historyRecord.OPERATION, "lastModified": timestamp});
        }

        log:printDebug(string `Retrieved ${versions.length()} history version(s) for all ${resourceType} resources`);
        return versions;
    }
}
