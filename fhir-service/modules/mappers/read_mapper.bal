import ballerina_fhir_server.db_store;

import ballerina/persist;
import ballerina/sql;
import ballerina/lang.regexp;
// import ballerinax/health.fhir.r4.international401;

// import ballerinax/health.fhir.r4.parser as fhirParser;

public class ReadMapper {

    public isolated function init() {
    }

    // Main function to read a single resource by ID
    public isolated function readResourceById(db_store:Client persistClient, string resourceType, string resourceId) returns json|error {
        match resourceType {
            "Appointment" => {
                json|error appointmentJson = (check self.readAppointment(persistClient, resourceId)).toJson();
                return appointmentJson;
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }


    // Search resources with filters
    public isolated function searchResources(db_store:Client persistClient, string resourceType, map<string[]> queryParams) returns json|error {
        match resourceType {
            "Appointment" => {
                return self.searchAppointments(persistClient, queryParams);
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }

    // Read a single Appointment resource
    private isolated function readAppointment(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

        db_store:AppointmentTable[] results = check from var appointment in appointmentStream
            where appointment.APPOINTMENTTABLE_ID == resourceId
            select appointment;

        if results.length() == 0 {
            return error(string `Appointment/${resourceId} not found`);
        }

        db_store:AppointmentTable appointment = results[0];
        json|error resourceJson = check self.mapFromAppointmentTable(appointment);

        return resourceJson;
    }

    // Search Appointments with query parameters
    private isolated function searchAppointments(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        // Build SQL WHERE clause from query parameters
        sql:ParameterizedQuery whereClause = self.buildWhereClause(queryParams);
        
        stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(
            targetType = db_store:AppointmentTable,
            whereClause = whereClause
        );

        // Convert stream to array
        db_store:AppointmentTable[] allAppointments = check from var appointment in appointmentStream
            select appointment;

        // Convert filtered results to FHIR Bundle
        json bundle = check self.createSearchBundle(allAppointments, queryParams);

        return bundle;
    }

    // Build SQL WHERE clause from query parameters
    private isolated function buildWhereClause(map<string[]> queryParams) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery[] conditions = [];

        // _id filter
        if queryParams.hasKey("_id") {
            string[] idValues = queryParams.get("_id");
            if idValues.length() > 0 {
                sql:ParameterizedQuery idCondition = `APPOINTMENTTABLE_ID = ${idValues[0]}`;
                conditions.push(idCondition);
            }
        }

        // Status filter
        if queryParams.hasKey("status") {
            string[] statusValues = queryParams.get("status");
            if statusValues.length() > 0 {
                sql:ParameterizedQuery statusCondition = `STATUS LIKE ${"%" + statusValues[0] + "%"}`;
                conditions.push(statusCondition);
            }
        }

        // Token type filters (CodeableConcept fields)
        sql:ParameterizedQuery? serviceCategoryCondition = self.buildTokenFilter(queryParams, "service-category");
        if serviceCategoryCondition is sql:ParameterizedQuery {
            conditions.push(serviceCategoryCondition);
        }

        sql:ParameterizedQuery? appointmentTypeCondition = self.buildTokenFilter(queryParams, "appointment-type");
        if appointmentTypeCondition is sql:ParameterizedQuery {
            conditions.push(appointmentTypeCondition);
        }

        sql:ParameterizedQuery? specialtyCondition = self.buildTokenFilter(queryParams, "specialty");
        if specialtyCondition is sql:ParameterizedQuery {
            conditions.push(specialtyCondition);
        }

        sql:ParameterizedQuery? reasonCodeCondition = self.buildTokenFilter(queryParams, "reason-code");
        if reasonCodeCondition is sql:ParameterizedQuery {
            conditions.push(reasonCodeCondition);
        }

        sql:ParameterizedQuery? serviceTypeCondition = self.buildTokenFilter(queryParams, "service-type");
        if serviceTypeCondition is sql:ParameterizedQuery {
            conditions.push(serviceTypeCondition);
        }

        sql:ParameterizedQuery? partStatusCondition = self.buildTokenFilter(queryParams, "part-status");
        if partStatusCondition is sql:ParameterizedQuery {
            conditions.push(partStatusCondition);
        }

        // Identifier filter (token type with "value" instead of "code")
        if queryParams.hasKey("identifier") {
            string[] identifierValues = queryParams.get("identifier");
            if identifierValues.length() > 0 {
                int? pipeIndex = identifierValues[0].indexOf("|");
                if pipeIndex is int {
                    // Both system and value provided: system|value
                    string systemToMatch = identifierValues[0].substring(0, pipeIndex);
                    string valueToMatch = identifierValues[0].substring(pipeIndex + 1);
                    string pattern = "%" + "\"system\":\"" + systemToMatch + "\"%\"value\":\"" + valueToMatch + "\"" + "%";
                    sql:ParameterizedQuery identifierCondition = `IDENTIFIER LIKE ${pattern}`;
                    conditions.push(identifierCondition);
                } else {
                    // Only value provided
                    string pattern = "%" + "\"value\":\"" + identifierValues[0] + "\"" + "%";
                    sql:ParameterizedQuery identifierCondition = `IDENTIFIER LIKE ${pattern}`;
                    conditions.push(identifierCondition);
                }
            }
        }

        // Date filter - simplified version (exact match for now)
        if queryParams.hasKey("date") {
            string[] dateValues = queryParams.get("date");
            if dateValues.length() > 0 {
                string dateValue = dateValues[0];
                // Parse date prefix if present
                string prefix = "eq";
                string actualDate = dateValue;
                if dateValue.length() > 2 {
                    string possiblePrefix = dateValue.substring(0, 2);
                    if possiblePrefix == "eq" || possiblePrefix == "ne" || possiblePrefix == "gt" || 
                        possiblePrefix == "ge" || possiblePrefix == "lt" || possiblePrefix == "le" {
                        prefix = possiblePrefix;
                        actualDate = dateValue.substring(2);
                    }
                }

                sql:ParameterizedQuery dateCondition;
                match prefix {
                    "eq" => {
                        dateCondition = `DATE = ${actualDate}`;
                    }
                    "ne" => {
                        dateCondition = `DATE != ${actualDate}`;
                    }
                    "gt" => {
                        dateCondition = `DATE > ${actualDate}`;
                    }
                    "ge" => {
                        dateCondition = `DATE >= ${actualDate}`;
                    }
                    "lt" => {
                        dateCondition = `DATE < ${actualDate}`;
                    }
                    "le" => {
                        dateCondition = `DATE <= ${actualDate}`;
                    }
                    _ => {
                        dateCondition = `DATE = ${actualDate}`;
                    }
                }
                conditions.push(dateCondition);
            }
        }

        // Combine all conditions with AND
        if conditions.length() == 0 {
            return ``;
        } else if conditions.length() == 1 {
            return conditions[0];
        } else {
            sql:ParameterizedQuery combined = conditions[0];
            foreach int i in 1 ..< conditions.length() {
                combined = sql:queryConcat(combined, ` AND `, conditions[i]);
            }
            return combined;
        }
    }

    // Helper method to build token filter conditions for CodeableConcept fields
    private isolated function buildTokenFilter(map<string[]> queryParams, string paramName) returns sql:ParameterizedQuery? {
        if !queryParams.hasKey(paramName) {
            return ();
        }

        string[] paramValues = queryParams.get(paramName);
        if paramValues.length() == 0 {
            return ();
        }

        // Convert param name to column name (e.g., "service-category" -> "SERVICE_CATEGORY")
        string columnName = regexp:replaceAll(re `-`, paramName.toUpperAscii(), "_");

        int? pipeIndex = paramValues[0].indexOf("|");
        if pipeIndex is int {
            // Both system and code provided: system|code
            string systemToMatch = paramValues[0].substring(0, pipeIndex);
            string codeToMatch = paramValues[0].substring(pipeIndex + 1);
            string pattern = "%" + "\"system\":\"" + systemToMatch + "\"%\"code\":\"" + codeToMatch + "\"" + "%";
            
            // Build the SQL condition dynamically based on column name
            if columnName == "SERVICE_CATEGORY" {
                return `SERVICE_CATEGORY LIKE ${pattern}`;
            } else if columnName == "APPOINTMENT_TYPE" {
                return `APPOINTMENT_TYPE LIKE ${pattern}`;
            } else if columnName == "SPECIALTY" {
                return `SPECIALTY LIKE ${pattern}`;
            } else if columnName == "REASON_CODE" {
                return `REASON_CODE LIKE ${pattern}`;
            } else if columnName == "SERVICE_TYPE" {
                return `SERVICE_TYPE LIKE ${pattern}`;
            } else if columnName == "PART_STATUS" {
                return `PART_STATUS LIKE ${pattern}`;
            }
        } else {
            // Only code provided
            string pattern = "%" + "\"code\":\"" + paramValues[0] + "\"" + "%";
            
            // Build the SQL condition dynamically based on column name
            if columnName == "SERVICE_CATEGORY" {
                return `SERVICE_CATEGORY LIKE ${pattern}`;
            } else if columnName == "APPOINTMENT_TYPE" {
                return `APPOINTMENT_TYPE LIKE ${pattern}`;
            } else if columnName == "SPECIALTY" {
                return `SPECIALTY LIKE ${pattern}`;
            } else if columnName == "REASON_CODE" {
                return `REASON_CODE LIKE ${pattern}`;
            } else if columnName == "SERVICE_TYPE" {
                return `SERVICE_TYPE LIKE ${pattern}`;
            } else if columnName == "PART_STATUS" {
                return `PART_STATUS LIKE ${pattern}`;
            }
        }

        return ();
    }

    // Convert AppointmentTable record to JSON
    private isolated function convertAppointmentToJson(db_store:AppointmentTable appointment) returns json|error {
        byte[] resourceJsonBytes = appointment.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = check resourceJsonString.fromJsonString();

        return resourceJson;
    }

    // Create FHIR Bundle for search results
    private isolated function createSearchBundle(db_store:AppointmentTable[] appointments, map<string[]> queryParams) returns json|error {
        json[] entries = [];

        foreach db_store:AppointmentTable appointment in appointments {
            json resourceJson = check self.convertAppointmentToJson(appointment);

            json entry = {
                "fullUrl": string `https://example.com/fhir/Appointment/${appointment.APPOINTMENTTABLE_ID}`,
                "resource": resourceJson,
                "search": {
                    "mode": "match"
                }
            };

            entries.push(entry);
        }

        // Construct FHIR Bundle
        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": entries.length(),
            "entry": entries
        };

        // Add pagination links if needed (can be enhanced)
        json link = [
            {
                "relation": "self",
                "url": self.constructSearchUrl(queryParams)
            }
        ];

        bundle = check bundle.mergeJson({"link": link});

        return bundle;
    }

    // Construct search URL from query parameters
    private isolated function constructSearchUrl(map<string[]> queryParams) returns string {
        string url = "https://example.com/fhir/Appointment?";
        string[] paramStrings = [];

        foreach var [key, values] in queryParams.entries() {
            foreach string value in values {
                paramStrings.push(string `${key}=${value}`);
            }
        }

        return url + string:'join("&", ...paramStrings);
    }

    // Read all resources of a given type (with optional limit)
    public isolated function readAllResources(db_store:Client persistClient, string resourceType, int? 'limit = ()) returns json|error {
        match resourceType {
            "Appointment" => {
                return self.readAllAppointments(persistClient, 'limit);
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }

    // Read all Appointments
    private isolated function readAllAppointments(db_store:Client persistClient, int? 'limit) returns json|error {
        stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

        db_store:AppointmentTable[] appointments = check from var appointment in appointmentStream
            select appointment;

        // Apply limit if specified
        if 'limit is int {
            int limitValue = 'limit;
            if appointments.length() > limitValue {
                appointments = appointments.slice(0, limitValue);
            }
        }

        json[] entries = [];

        foreach db_store:AppointmentTable appointment in appointments {
            json resourceJson = check self.convertAppointmentToJson(appointment);

            json entry = {
                "fullUrl": string `https://example.com/fhir/Appointment/${appointment.APPOINTMENTTABLE_ID}`,
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
    public isolated function readReferences(db_store:Client persistClient, string resourceType, string resourceId) returns json[]|error {
        stream<db_store:REFERENCES, persist:Error?> referencesStream = persistClient->/references(targetType = db_store:REFERENCES);

        db_store:REFERENCES[] references = check from var ref in referencesStream
            where ref.SOURCE_RESOURCE_TYPE == resourceType && ref.SOURCE_RESOURCE_ID == resourceId
            select ref;

        json[] referenceList = [];

        foreach db_store:REFERENCES ref in references {
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
    public isolated function resourceExists(db_store:Client persistClient, string resourceType, string resourceId) returns boolean|error {
        match resourceType {
            "Appointment" => {
                stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

                db_store:AppointmentTable[] results = check from var appointment in appointmentStream
                    where appointment.APPOINTMENTTABLE_ID == resourceId
                    select appointment;

                return results.length() > 0;
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }

    // Get resource count by type
    public isolated function getResourceCount(db_store:Client persistClient, string resourceType) returns int|error {
        match resourceType {
            "Appointment" => {
                stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

                db_store:AppointmentTable[] results = check from var appointment in appointmentStream
                    select appointment;

                return results.length();
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }

    // Get resource metadata (without full RESOURCE_JSON)
    public isolated function getResourceMetadata(db_store:Client persistClient, string resourceType, string resourceId) returns record {|anydata...;|}|error {
        match resourceType {
            "Appointment" => {
                stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

                db_store:AppointmentTable[] results = check from var appointment in appointmentStream
                    where appointment.APPOINTMENTTABLE_ID == resourceId
                    select appointment;

                if results.length() == 0 {
                    return error(string `Appointment/${resourceId} not found`);
                }

                db_store:AppointmentTable appointment = results[0];

                record {|anydata...;|} metadata = {
                    "id": appointment.APPOINTMENTTABLE_ID,
                    "versionId": appointment.VERSION_ID,
                    "lastUpdated": appointment.LAST_UPDATED,
                    "createdAt": appointment.CREATED_AT,
                    "status": appointment.STATUS,
                    "date": appointment.DATE
                };

                return metadata;
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }

    // Map from AppointmentTable to international401:Appointment record
    public isolated function mapFromAppointmentTable(db_store:AppointmentTable appointmentTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = appointmentTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        // Convert JSON to international401:Appointment record
        // international401:Appointment appointment = check fhirParser:parse(resourceJson, international401:Appointment).ensureType();

        return resourceJson;
    }
}
