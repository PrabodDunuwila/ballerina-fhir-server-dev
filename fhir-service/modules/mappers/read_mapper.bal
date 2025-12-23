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
                
                // Case 1: paramName is "Patient/123" (old format)
                if paramName.includes("/") {
                    refValue = paramName;
                } 
                // Case 2: patient=Patient/123 (proper FHIR search format)
                else {
                    refValue = paramValue;
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
            // Reference params have "/" BUT not token params (which use | for system|code)
            // Token example: identifier=http://hospital.org|12345 (has "/" but is NOT a reference)
            // Reference example: patient=Patient/123 (has "/" and IS a reference)
            boolean isTokenParam = paramValue.includes("|");
            boolean hasSlash = paramName.includes("/") || paramValue.includes("/");
            
            if hasSlash && !isTokenParam {
                continue;
            }

            // Skip _count parameter (sent by default) and _include parameter (handled separately after main search)
            if paramName == "_count" || paramName == "_include" {
                continue;
            }

            // Handle other unsupported FHIR control parameters that start with _
            if paramName.startsWith("_") && paramName != "_lastUpdated" && paramName != "_id" {
                return error(string `Unsupported search parameter: ${paramName}. Only common resource parameters of _id, _lastUpdated, and _include are currently supported.`);
            }

            string operator = "=";
            string searchValue = paramValue;
            string? tokenSystem = ();
            string? tokenCode = ();
            boolean tokenSystemEmpty = false;

            // Process token parameter (already detected above)
            // Token parameters support 4 formats per FHIR spec:
            // 1. [code]: Match code only, any system
            // 2. [system]|[code]: Match both system and code
            // 3. |[code]: Match code where system is absent
            // 4. [system]|: Match system only, any code
            if isTokenParam {
                string[] tokenParts = regexp:split(re `\|`, paramValue);
                if tokenParts.length() == 2 {
                    string systemPart = tokenParts[0];
                    string codePart = tokenParts[1];
                    
                    if systemPart == "" && codePart != "" {
                        // Case 3: |[code] - code with no system
                        tokenCode = codePart;
                        tokenSystemEmpty = true;
                    } else if systemPart != "" && codePart == "" {
                        // Case 4: [system]| - system only, any code
                        tokenSystem = systemPart;
                    } else if systemPart != "" && codePart != "" {
                        // Case 2: [system]|[code] - both system and code
                        tokenSystem = systemPart;
                        tokenCode = codePart;
                    }
                    // If both empty (just "|"), ignore this parameter
                } else {
                    // Case 1: No pipe, just [code] - will be handled as non-token param below
                    isTokenParam = false;
                    searchValue = paramValue;
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
                    string sanitizedSystem = tokenSystem is string ? utils:escapeSql(tokenSystem) : "";
                    string sanitizedCode = tokenCode is string ? utils:escapeSql(tokenCode) : "";
                    
                    if tokenSystem is string && tokenCode is string {
                        // Case 2: [system]|[code] - Both system and code must match
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%') AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%') AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        }
                    } else if tokenCode is string && tokenSystemEmpty {
                        // Case 3: |[code] - Code matches but system must be absent/null
                        // This is complex - for simplicity, just search for code (limitation)
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        }
                    } else if tokenCode is string {
                        // This shouldn't happen with current logic, but handle it
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"code":"${sanitizedCode}"%' OR ${columnName} LIKE '%"code": "${sanitizedCode}"%')`;
                        }
                    } else if tokenSystem is string {
                        // Case 4: [system]| - System matches, any code
                        if whereClause == "" {
                            whereClause = string ` WHERE (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%')`;
                        } else {
                            whereClause = whereClause + string ` AND (${columnName} LIKE '%"system":"${sanitizedSystem}"%' OR ${columnName} LIKE '%"system": "${sanitizedSystem}"%')`;
                        }
                    }
                }
                // Case 1: [code] only (no pipe) - Use LIKE for string columns to support partial matching
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
        string[] matchedResourceIds = [];
        
        foreach var result in results {
            byte[] resourceJsonBytes = result.RESOURCE_JSON;
            string resourceJsonString = check string:fromBytes(resourceJsonBytes);
            json resourceJson = check resourceJsonString.fromJsonString();

            // Get the resource ID
            string resourceId = "";
            foreach var [key, value] in result.entries() {
                if key != "RESOURCE_JSON" && value is string {
                    resourceId = value;
                    matchedResourceIds.push(resourceId);
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

        // Handle _include parameters
        if queryParams.hasKey("_include") {
            string[] includeParams = queryParams.get("_include");
            foreach string includeParam in includeParams {
                // Parse _include parameter: format is ResourceType:searchParam or ResourceType:searchParam:targetType
                // Example: Appointment:patient or Appointment:patient:Patient
                // Also support wildcard: _include=* (include all references)
                
                if includeParam == "*" {
                    // Include all referenced resources from matched results
                    foreach string sourceId in matchedResourceIds {
                        json[] includedResources = check self.fetchAllReferencedResources(jdbcClient, resourceType, sourceId);
                        foreach json includedEntry in includedResources {
                            entries.push(includedEntry);
                        }
                    }
                } else {
                    // Parse specific include parameter
                    string[] parts = regexp:split(re `:`, includeParam);
                    if parts.length() >= 2 {
                        string sourceResourceType = parts[0];
                        string searchParamName = parts[1];
                        string? targetResourceType = parts.length() > 2 ? parts[2] : ();
                        
                        // Only process if source type matches current search resource type
                        if sourceResourceType == resourceType {
                            foreach string sourceId in matchedResourceIds {
                                json[] includedResources = check self.fetchIncludedResources(jdbcClient, sourceResourceType, sourceId, searchParamName, targetResourceType);
                                foreach json includedEntry in includedResources {
                                    entries.push(includedEntry);
                                }
                            }
                        }
                    }
                }
            }
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

    // Fetch included resources based on _include parameter
    private isolated function fetchIncludedResources(jdbc:Client? jdbcClient, string sourceResourceType, string sourceResourceId, string searchParamName, string? targetResourceType) returns json[]|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        json[] includedEntries = [];
        
        // Query REFERENCES table to find target resources
        // The search parameter FHIRPath expressions now include complete where clauses:
        // - "Appointment.participant.actor.where(resolve() is Patient)" for patient references
        // - "ActivityDefinition.relatedArtifact.where(type='composed-of').resource" for related artifacts
        // - "Patient.telecom.where(system='email')" for telecom filters
        // We extract the reference field name (the part before .where) to match SOURCE_EXPRESSION
        
        // Get the FHIRPath expression for this search parameter from the search_param_res_expressions table
        string searchParamQuery = string `SELECT EXPRESSION FROM "SEARCH_PARAM_RES_EXPRESSIONS" WHERE RESOURCE_NAME = '${utils:escapeSql(sourceResourceType)}' AND SEARCH_PARAM_NAME = '${utils:escapeSql(searchParamName)}' AND SEARCH_PARAM_TYPE = 'reference'`;
        sql:ParameterizedQuery spQuery = new utils:RawSQLQuery(searchParamQuery);
        
        stream<record {|string EXPRESSION;|}, sql:Error?> spStream = jdbcClient->query(spQuery);
        record {|string EXPRESSION;|}[] spResults = check from var sp in spStream
            select sp;
        
        // If we can't find the search parameter, return empty (the search parameter might not exist for this resource type)
        if spResults.length() == 0 {
            return includedEntries;
        }
        
        // Build WHERE clause for REFERENCES table
        // Since SOURCE_EXPRESSION stores the actual JSON path leaf field (e.g., "actor"),
        // and we have the FHIRPath expression (e.g., "Appointment.participant.actor.where"),
        // we need to extract the actual reference field name (the last field before .where)
        string fhirPathExpr = spResults[0].EXPRESSION;
        
        // Extract the reference field name and target resource type from FHIRPath
        // Examples:
        //   "Appointment.participant.actor.where(resolve() is Patient)" -> field: "actor", type: "Patient"
        //   "ActivityDefinition.relatedArtifact.where(type='composed-of').resource" -> field: "relatedArtifact", type: null
        //   "Patient.telecom.where(system='email')" -> field: "telecom", type: null
        //   "Patient.generalPractitioner" -> field: "generalPractitioner", type: null
        string[] pathParts = regexp:split(re `\.`, fhirPathExpr);
        string? referenceField = ();
        string? extractedTargetType = ();
        
        // Find the last field before ".where" or the last field if no ".where"
        foreach int i in 0 ..< pathParts.length() {
            string part = pathParts[i];
            if part == "where" {
                // The field before "where" is our reference field
                if i > 0 {
                    referenceField = pathParts[i - 1];
                }
                break;
            } else if part.startsWith("where(") {
                // The field before "where(" is our reference field
                if i > 0 {
                    referenceField = pathParts[i - 1];
                }
                
                // Try to extract target resource type from "where(resolve() is ResourceType)"
                string wherePattern = "where(resolve() is ";
                if part.startsWith(wherePattern) {
                    string whereContent = part.substring(wherePattern.length()); // Skip "where(resolve() is "
                    int? closeParenPos = whereContent.indexOf(")");
                    if closeParenPos is int && closeParenPos > 0 {
                        extractedTargetType = whereContent.substring(0, closeParenPos).trim();
                    }
                }
                break;
            } else if i == pathParts.length() - 1 {
                // Last field and no "where" found
                referenceField = part;
            }
        }
        
        string whereClause = string `SOURCE_RESOURCE_TYPE = '${utils:escapeSql(sourceResourceType)}' AND SOURCE_RESOURCE_ID = '${utils:escapeSql(sourceResourceId)}'`;
        
        // Filter by SOURCE_EXPRESSION matching the reference field name
        if referenceField is string {
            whereClause = whereClause + string ` AND SOURCE_EXPRESSION = '${utils:escapeSql(referenceField)}'`;
        }
        
        // Filter by target resource type - use extracted type from expression if available, otherwise use provided targetResourceType
        string? finalTargetType = extractedTargetType is string ? extractedTargetType : targetResourceType;
        if finalTargetType is string {
            whereClause = whereClause + string ` AND TARGET_RESOURCE_TYPE = '${utils:escapeSql(finalTargetType)}'`;
        }
        
        string refQuery = string `SELECT DISTINCT TARGET_RESOURCE_TYPE, TARGET_RESOURCE_ID FROM "REFERENCES" WHERE ${whereClause}`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(refQuery);

        stream<record {|string TARGET_RESOURCE_TYPE; string TARGET_RESOURCE_ID;|}, sql:Error?> refStream = jdbcClient->query(query);
        record {|string TARGET_RESOURCE_TYPE; string TARGET_RESOURCE_ID;|}[] refResults = check from var ref in refStream
            select ref;

        // Fetch each referenced resource
        foreach var refRecord in refResults {
            string targetType = refRecord.TARGET_RESOURCE_TYPE;
            string targetId = refRecord.TARGET_RESOURCE_ID;
            
            // Use existing readResourceById to fetch the resource
            json|error resourceResult = self.readResourceById(jdbcClient, targetType, targetId);
            
            if resourceResult is json {
                json entry = {
                    "fullUrl": string `https://example.com/fhir/${targetType}/${targetId}`,
                    "resource": resourceResult,
                    "search": {
                        "mode": "include"
                    }
                };
                includedEntries.push(entry);
            }
            // Silently skip resources that can't be fetched (they may have been deleted)
        }

        return includedEntries;
    }

    // Fetch all referenced resources for wildcard _include=*
    private isolated function fetchAllReferencedResources(jdbc:Client? jdbcClient, string sourceResourceType, string sourceResourceId) returns json[]|error {
        if jdbcClient is () {
            return error("JDBC client is not initialized");
        }

        json[] includedEntries = [];
        
        // Query all references for this source resource
        string refQuery = string `SELECT DISTINCT TARGET_RESOURCE_TYPE, TARGET_RESOURCE_ID FROM "REFERENCES" WHERE SOURCE_RESOURCE_TYPE = '${utils:escapeSql(sourceResourceType)}' AND SOURCE_RESOURCE_ID = '${utils:escapeSql(sourceResourceId)}'`;
        sql:ParameterizedQuery query = new utils:RawSQLQuery(refQuery);

        stream<record {|string TARGET_RESOURCE_TYPE; string TARGET_RESOURCE_ID;|}, sql:Error?> refStream = jdbcClient->query(query);
        record {|string TARGET_RESOURCE_TYPE; string TARGET_RESOURCE_ID;|}[] refResults = check from var ref in refStream
            select ref;

        // Fetch each referenced resource
        foreach var refRecord in refResults {
            string targetType = refRecord.TARGET_RESOURCE_TYPE;
            string targetId = refRecord.TARGET_RESOURCE_ID;
            
            // Use existing readResourceById to fetch the resource
            json|error resourceResult = self.readResourceById(jdbcClient, targetType, targetId);
            
            if resourceResult is json {
                json entry = {
                    "fullUrl": string `https://example.com/fhir/${targetType}/${targetId}`,
                    "resource": resourceResult,
                    "search": {
                        "mode": "include"
                    }
                };
                includedEntries.push(entry);
            }
            // Silently skip resources that can't be fetched (they may have been deleted)
        }

        return includedEntries;
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
