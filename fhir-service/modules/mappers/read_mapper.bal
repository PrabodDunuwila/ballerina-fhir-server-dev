import ballerina_fhir_server.utils;

import ballerina/sql;
import ballerina/lang.regexp;
import ballerinax/java.jdbc;

public class ReadMapper {

    public isolated function init() {
    }

    // Main function to read a single resource by ID
    public isolated function readResourceById(jdbc:Client? jdbcClient, string resourceType, string resourceId) returns json|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string sqlQuery = string `SELECT RESOURCE_JSON FROM "${tableName}" WHERE ${primaryKey} = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON;|}, sql:Error?> resultStream = jdbcClient->query(query);

        record {|byte[] RESOURCE_JSON;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found`);
        }

        byte[] resourceJsonBytes = results[0].RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = check resourceJsonString.fromJsonString();

        return resourceJson;
    }

    // Search resources with filters - basic implementation
    public isolated function searchResources(jdbc:Client? jdbcClient, string resourceType, map<string[]> queryParams) returns json|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        // Check for reference parameters and query the REFERENCES table
        string[]? matchingResourceIds = ();
        boolean hasReferenceParams = false;

        foreach var [paramName, paramValues] in queryParams.entries() {
            if paramValues.length() == 0 {
                continue;
            }

            string paramValue = paramValues[0];
            
            // Check if this is a reference parameter
            // Either: 1) paramName contains "/" (e.g., "Patient/123" as key)
            //     or: 2) paramValue contains "/" (e.g., patient=Patient/123)
            boolean isReferenceParam = paramName.includes("/") || paramValue.includes("/");
            
            if isReferenceParam {
                hasReferenceParams = true;
                string refValue = "";
                string refParamName = "";
                
                // Case 1: paramName is "Patient/123" (old format)
                if paramName.includes("/") {
                    refValue = paramName;
                    refParamName = ""; // Unknown which field it maps to
                } 
                // Case 2: patient=Patient/123 (proper FHIR search format)
                else {
                    refValue = paramValue;
                    refParamName = paramName;
                }
                
                string[] parts = regexp:split(re `/`, refValue);
                if parts.length() == 2 {
                    string targetType = parts[0];
                    string targetId = parts[1];

                    // Build query without SOURCE_EXPRESSION filter
                    // The TARGET_RESOURCE_TYPE already provides the specificity we need
                    // (e.g., searching patient=Patient/123 matches any reference to that Patient,
                    //  whether stored as "actor", "patient", "subject", etc.)
                    string refQuery = string `SELECT DISTINCT SOURCE_RESOURCE_ID FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND TARGET_RESOURCE_TYPE = '${utils:escapeSql(targetType)}' AND TARGET_RESOURCE_ID = '${utils:escapeSql(targetId)}'`;
                    
                    sql:ParameterizedQuery query = new utils:RawSQLQuery(refQuery);

                    stream<record {|string SOURCE_RESOURCE_ID;|}, sql:Error?> refStream = jdbcClient->query(query);
                    record {|string SOURCE_RESOURCE_ID;|}[] refResults = check from var ref in refStream
                        select ref;

                    if refResults.length() == 0 {
                        // No matches found for this reference parameter
                        matchingResourceIds = [];
                        break;
                    }

                    string[] ids = from var ref in refResults
                        select ref.SOURCE_RESOURCE_ID;

                    if matchingResourceIds is () {
                        matchingResourceIds = ids;
                    } else {
                        // Intersect with previously found IDs
                        string[] intersection = [];
                        foreach string id in ids {
                            if self.arrayContains(matchingResourceIds, id) {
                                intersection.push(id);
                            }
                        }
                        matchingResourceIds = intersection;
                    }
                }
            }
        }

        // If reference parameters were used but no matches found, return empty bundle
        if hasReferenceParams && (matchingResourceIds is string[] && matchingResourceIds.length() == 0) {
            json bundle = {
                "resourceType": "Bundle",
                "type": "searchset",
                "total": 0,
                "entry": []
            };
            return bundle;
        }

        // Build WHERE clause for ID filtering if we have reference matches
        string whereClause = "";
        if matchingResourceIds is string[] && matchingResourceIds.length() > 0 {
            string idList = string:'join("', '", ...matchingResourceIds);
            whereClause = string ` WHERE ${primaryKey} IN ('${idList}')`;
        }

        // Handle _id parameter
        if queryParams.hasKey("_id") {
            string[] idValues = queryParams.get("_id");
            if idValues.length() > 0 {
                if whereClause == "" {
                    whereClause = string ` WHERE ${primaryKey} = '${idValues[0]}'`;
                } else {
                    whereClause = whereClause + string ` AND ${primaryKey} = '${idValues[0]}'`;
                }
            }
        }

        // Handle other search parameters (map to database columns)
        foreach var [paramName, paramValues] in queryParams.entries() {
            if paramValues.length() == 0 {
                continue;
            }

            string paramValue = paramValues[0];
            
            // Skip already processed parameters
            if paramName == "_id" {
                continue;
            }
            
            // Skip reference parameters (already processed above)
            // Reference params either have "/" in name OR value contains "/"
            if paramName.includes("/") || paramValue.includes("/") {
                continue;
            }

            // Skip _count parameter (sent by default) and other unsupported FHIR control parameters
            if paramName == "_count" {
                continue;
            }

            // Handle other unsupported FHIR control parameters that start with _
            if paramName.startsWith("_") && paramName != "_lastUpdated" {
                return error(string `Unsupported search parameter: ${paramName}. Only common resource parameters of _id and _lastUpdated are currently supported.`);
            }

            string operator = "=";
            string searchValue = paramValue;
            boolean isTokenParam = false;
            string? tokenSystem = ();
            string? tokenCode = ();

            // Check if this is a token parameter (contains | for system|code format)
            // Token parameters: identifier, status, code, etc.
            if paramValue.includes("|") {
                isTokenParam = true;
                // For system|code format, we need to search for both system and code separately
                string[] tokenParts = regexp:split(re `\|`, paramValue);
                if tokenParts.length() == 2 {
                    // If system is empty (|code), just search for code
                    if tokenParts[0] == "" {
                        tokenCode = tokenParts[1];
                    } else {
                        // Both system and code provided
                        tokenSystem = tokenParts[0];
                        tokenCode = tokenParts[1];
                    }
                }
            }

            // Parse prefix for date/time and numeric parameters (not applicable to token params)
            if !isTokenParam {
                if paramValue.startsWith("gt") {
                    operator = ">";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("ge") {
                    operator = ">=";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("lt") {
                    operator = "<";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("le") {
                    operator = "<=";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("ne") {
                    operator = "!=";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("eq") {
                    operator = "=";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("sa") {
                    // starts after (same as gt)
                    operator = ">";
                    searchValue = paramValue.substring(2);
                } else if paramValue.startsWith("eb") {
                    // ends before (same as lt)
                    operator = "<";
                    searchValue = paramValue.substring(2);
                }
            }

            // Map FHIR search parameter names to database column names
            string? columnName = self.mapSearchParamToColumn(paramName);
            
            if columnName is string {
                // For token parameters with system|code format
                // Token columns contain JSON like [{"coding":[{"system":"...","code":"..."}]}]
                if isTokenParam {
                    if tokenSystem is string && tokenCode is string {
                        // Search for both system and code with proper JSON field names
                        // Handle optional whitespace after colon in JSON
                        string sanitizedSystem = utils:escapeSql(tokenSystem);
                        string sanitizedCode = utils:escapeSql(tokenCode);
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%') AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%') AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        }
                    } else if tokenCode is string {
                        // Only code provided (|code format) - search for "code":"value" or "code": "value"
                        string sanitizedCode = utils:escapeSql(tokenCode);
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        }
                    }
                }
                // Use LIKE for string columns to support partial matching
                else if operator == "=" {
                    string sanitizedValue = utils:escapeSql(searchValue);
                    if whereClause == "" {
                        whereClause = string ` WHERE ${columnName} LIKE '%${sanitizedValue}%'`;
                    } else {
                        whereClause = whereClause + string ` AND ${columnName} LIKE '%${sanitizedValue}%'`;
                    }
                } else {
                    // Use exact comparison for date/numeric operators
                    string sanitizedValue = utils:escapeSql(searchValue);
                    if whereClause == "" {
                        whereClause = string ` WHERE ${columnName} ${operator} '${sanitizedValue}'`;
                    } else {
                        whereClause = whereClause + string ` AND ${columnName} ${operator} '${sanitizedValue}'`;
                    }
                }
            }
        }

        string sqlQuery = string `SELECT ${primaryKey}, RESOURCE_JSON FROM "${tableName}"${whereClause}`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON; string...;|}, sql:Error?> resultStream = jdbcClient->query(query);

        record {|byte[] RESOURCE_JSON; string...;|}[] results = check from var result in resultStream
            select result;

        // Convert to FHIR Bundle
        json[] entries = [];
        foreach var result in results {
            byte[] resourceJsonBytes = result.RESOURCE_JSON;
            string resourceJsonString = check string:fromBytes(resourceJsonBytes);
            json resourceJson = check resourceJsonString.fromJsonString();

            // Get the resource ID
            string resourceId = "";
            foreach var [key, value] in result.entries() {
                if key != "RESOURCE_JSON" && value is string {
                    resourceId = value;
                    break;
                }
            }

            json entry = {
                "fullUrl": string `https://example.com/fhir/${resourceType}/${resourceId}`,
                "resource": resourceJson,
                "search": {
                    "mode": "match"
                }
            };
            entries.push(entry);
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": entries.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read all resources of a given type (with optional limit)
    public isolated function readAllResources(jdbc:Client? jdbcClient, string resourceType, int? 'limit = ()) returns json|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string limitClause = 'limit is int ? string ` LIMIT ${'limit}` : "";
        string sqlQuery = string `SELECT ${primaryKey}, RESOURCE_JSON FROM "${tableName}"${limitClause}`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        stream<record {|byte[] RESOURCE_JSON; string...;|}, sql:Error?> resultStream = jdbcClient->query(query);

        record {|byte[] RESOURCE_JSON; string...;|}[] results = check from var result in resultStream
            select result;

        json[] entries = [];
        foreach var result in results {
            byte[] resourceJsonBytes = result.RESOURCE_JSON;
            string resourceJsonString = check string:fromBytes(resourceJsonBytes);
            json resourceJson = check resourceJsonString.fromJsonString();

            // Get the resource ID
            string resourceId = "";
            foreach var [key, value] in result.entries() {
                if key != "RESOURCE_JSON" && value is string {
                    resourceId = value;
                    break;
                }
            }

            json entry = {
                "fullUrl": string `https://example.com/fhir/${resourceType}/${resourceId}`,
                "resource": resourceJson
            };
            entries.push(entry);
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "collection",
            "total": entries.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read references for a specific resource
    public isolated function readReferences(jdbc:Client? jdbcClient, string resourceType, string resourceId) returns json[]|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string sqlQuery = string `SELECT ID, SOURCE_RESOURCE_TYPE, SOURCE_RESOURCE_ID, SOURCE_EXPRESSION, TARGET_RESOURCE_TYPE, TARGET_RESOURCE_ID, DISPLAY_VALUE FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${utils:escapeSql(resourceType)}' AND SOURCE_RESOURCE_ID = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|string ID; string SOURCE_RESOURCE_TYPE; string SOURCE_RESOURCE_ID; string SOURCE_EXPRESSION; string? TARGET_RESOURCE_TYPE; string? TARGET_RESOURCE_ID; string? DISPLAY_VALUE;|}, sql:Error?> resultStream = jdbcClient->query(query);

        record {|string ID; string SOURCE_RESOURCE_TYPE; string SOURCE_RESOURCE_ID; string SOURCE_EXPRESSION; string? TARGET_RESOURCE_TYPE; string? TARGET_RESOURCE_ID; string? DISPLAY_VALUE;|}[] results = check from var ref in resultStream
            select ref;

        json[] referenceList = [];
        foreach var ref in results {
            json referenceJson = {
                "id": ref.ID,
                "sourceResourceType": ref.SOURCE_RESOURCE_TYPE,
                "sourceResourceId": ref.SOURCE_RESOURCE_ID,
                "sourceExpression": ref.SOURCE_EXPRESSION,
                "targetResourceType": ref.TARGET_RESOURCE_TYPE,
                "targetResourceId": ref.TARGET_RESOURCE_ID,
                "display": ref.DISPLAY_VALUE
            };
            referenceList.push(referenceJson);
        }

        return referenceList;
    }

    // Check if a resource exists
    public isolated function resourceExists(jdbc:Client? jdbcClient, string resourceType, string resourceId) returns boolean|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        // Use the existing validateReferenceExists from commons
        return utils:validateReferenceExists(jdbcClient, resourceType, resourceId);
    }

    // Get resource count by type
    public isolated function getResourceCount(jdbc:Client? jdbcClient, string resourceType) returns int|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string tableName = utils:getTableName(resourceType);

        string sqlQuery = string `SELECT COUNT(*) AS COUNT FROM "${tableName}"`;
        sql:ParameterizedQuery query = new RawSQLQuery(sqlQuery);

        record {|int COUNT;|}? result = check jdbcClient->queryRow(query);

        if result is () {
            return 0;
        }

        return result.COUNT;
    }

    // Get resource metadata (without full RESOURCE_JSON)
    public isolated function getResourceMetadata(jdbc:Client? jdbcClient, string resourceType, string resourceId) returns record {|anydata...;|}|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        string tableName = utils:getTableName(resourceType);
        string primaryKey = utils:getPrimaryKeyColumn(resourceType);

        string sqlQuery = string `SELECT ${primaryKey}, VERSION_ID, LAST_UPDATED, CREATED_AT FROM "${tableName}" WHERE ${primaryKey} = '${utils:escapeSql(resourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

        stream<record {|anydata...;|}, sql:Error?> resultStream = jdbcClient->query(query);

        record {|anydata...;|}[] results = check from var result in resultStream
            select result;

        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found`);
        }

        return results[0];
    }

    // Helper function to check if array contains a string
    private isolated function arrayContains(string[] arr, string value) returns boolean {
        foreach string item in arr {
            if item == value {
                return true;
            }
        }
        return false;
    }

    // Map FHIR search parameter names to database column names
    private isolated function mapSearchParamToColumn(string searchParam) returns string? {
        // Handle special cases for FHIR standard parameters
        if searchParam == "_lastUpdated" {
            return "LAST_UPDATED";
        }
        
        // Convert to UPPER_SNAKE_CASE: uppercase and replace hyphens with underscores
        string upperParam = searchParam.toUpperAscii();
        string columnName = regexp:replaceAll(re `-`, upperParam, "_");
        return columnName;
    }
}

// RawSQLQuery class for dynamic SQL execution
class RawSQLQuery {
    *sql:ParameterizedQuery;
    public final string[] & readonly strings;
    public final sql:Value[] & readonly insertions;

    isolated function init(string sqlQuery) {
        self.strings = [sqlQuery].cloneReadOnly();
        self.insertions = [].cloneReadOnly();
    }
}
