import ballerina_fhir_server.db_store;

import ballerina/persist;
import ballerina/time;
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
        stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);

        // Convert stream to array for filtering
        db_store:AppointmentTable[] allAppointments = check from var appointment in appointmentStream
            select appointment;

        // Apply filters based on query parameters
        db_store:AppointmentTable[] filteredAppointments = check self.filterAppointments(allAppointments, queryParams);

        // Convert filtered results to FHIR Bundle
        json bundle = check self.createSearchBundle(filteredAppointments, queryParams);

        return bundle;
    }

    // Filter appointments based on query parameters
    private isolated function filterAppointments(db_store:AppointmentTable[] appointments, map<string[]> queryParams) returns db_store:AppointmentTable[]|error {
        db_store:AppointmentTable[] filtered = [];

        foreach db_store:AppointmentTable appointment in appointments {
            boolean matches = true;

            // Common FHIR search parameters

            // Filter by _id (logical ID of the resource)
            if queryParams.hasKey("_id") && matches {
                string[] idValues = queryParams.get("_id");
                if idValues.indexOf(appointment.APPOINTMENTTABLE_ID) == () {
                    matches = false;
                }
            }

            // Filter by _lastUpdated
            if queryParams.hasKey("_lastUpdated") && matches {
                string[] lastUpdatedValues = queryParams.get("_lastUpdated");
                // Convert Civil to string for comparison (format: YYYY-MM-DDTHH:MM:SS)
                time:Civil lastUpdated = appointment.LAST_UPDATED;
                
                boolean dateMatches = false;
                foreach string searchDate in lastUpdatedValues {
                    boolean|error comparison = self.compareDateWithPrefix(lastUpdated, searchDate);
                    if comparison is boolean && comparison {
                        dateMatches = true;
                        break;
                    }
                }
                if !dateMatches {
                    matches = false;
                }
            }

            // Filter by _tag
            if queryParams.hasKey("_tag") && matches {
                string[] tagValues = queryParams.get("_tag");
                // Parse RESOURCE_JSON to check for tags in meta.tag
                json|error resourceJson = self.convertAppointmentToJson(appointment);
                if resourceJson is json {
                    boolean|error tagMatches = self.matchesTags(resourceJson, tagValues);
                    if tagMatches is boolean && !tagMatches {
                        matches = false;
                    } else if tagMatches is error {
                        matches = false;
                    }
                } else {
                    matches = false;
                }
            }

            // Filter by _profile
            if queryParams.hasKey("_profile") && matches {
                string[] profileValues = queryParams.get("_profile");
                // Parse RESOURCE_JSON to check for profiles in meta.profile
                json|error resourceJson = self.convertAppointmentToJson(appointment);
                if resourceJson is json {
                    boolean|error profileMatches = self.matchesProfiles(resourceJson, profileValues);
                    if profileMatches is boolean && !profileMatches {
                        matches = false;
                    } else if profileMatches is error {
                        matches = false;
                    }
                } else {
                    matches = false;
                }
            }

            // Filter by _security
            if queryParams.hasKey("_security") && matches {
                string[] securityValues = queryParams.get("_security");
                // Parse RESOURCE_JSON to check for security labels in meta.security
                json|error resourceJson = self.convertAppointmentToJson(appointment);
                if resourceJson is json {
                    boolean|error securityMatches = self.matchesSecurity(resourceJson, securityValues);
                    if securityMatches is boolean && !securityMatches {
                        matches = false;
                    } else if securityMatches is error {
                        matches = false;
                    }
                } else {
                    matches = false;
                }
            }

            // Resource-specific search parameters

            // Filter by status
            if queryParams.hasKey("status") && matches {
                string[] statusValues = queryParams.get("status");
                if appointment.STATUS is string && statusValues.indexOf(<string>appointment.STATUS) == () {
                    matches = false;
                }
            }

            // Filter by date
            if queryParams.hasKey("date") && matches {
                // Date filtering logic can be enhanced based on FHIR search parameter prefixes
                // For now, simple equality check
                string[] dateValues = queryParams.get("date");
                if appointment.DATE is () || dateValues.length() == 0 {
                    matches = false;
                }
            }

            // Filter by identifier
            if queryParams.hasKey("identifier") && matches {
                string[] identifierValues = queryParams.get("identifier");
                if appointment.IDENTIFIER is string && identifierValues.indexOf(<string>appointment.IDENTIFIER) == () {
                    matches = false;
                }
            }

            // Filter by service-category
            if queryParams.hasKey("service-category") && matches {
                string[] serviceCategoryValues = queryParams.get("service-category");
                if appointment.SERVICE_CATEGORY is string && serviceCategoryValues.indexOf(<string>appointment.SERVICE_CATEGORY) == () {
                    matches = false;
                }
            }

            // Filter by appointment-type
            if queryParams.hasKey("appointment-type") && matches {
                string[] appointmentTypeValues = queryParams.get("appointment-type");
                if appointment.APPOINTMENT_TYPE is string && appointmentTypeValues.indexOf(<string>appointment.APPOINTMENT_TYPE) == () {
                    matches = false;
                }
            }

            // Filter by specialty
            if queryParams.hasKey("specialty") && matches {
                string[] specialtyValues = queryParams.get("specialty");
                if appointment.SPECIALTY is string && specialtyValues.indexOf(<string>appointment.SPECIALTY) == () {
                    matches = false;
                }
            }

            if matches {
                filtered.push(appointment);
            }
        }

        return filtered;
    }

    // Helper function to check if resource matches tag search criteria
    private isolated function matchesTags(json resourceJson, string[] searchTags) returns boolean|error {
        json|error metaTags = resourceJson.meta?.tag;
        
        if metaTags is error || metaTags is () {
            return false;
        }

        if metaTags is json[] {
            foreach json tag in metaTags {
                string? system = (check tag.system).toString();
                string? code = (check tag.code).toString();
                
                foreach string searchTag in searchTags {
                    // Support both "system|code" and just "code" formats
                    if searchTag.includes("|") {
                        string[] parts = re `\|`.split(searchTag);
                        if parts.length() == 2 && system == parts[0] && code == parts[1] {
                            return true;
                        }
                    } else {
                        if code == searchTag {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }

    // Helper function to check if resource matches profile search criteria
    private isolated function matchesProfiles(json resourceJson, string[] searchProfiles) returns boolean|error {
        json|error metaProfiles = resourceJson.meta?.profile;
        
        if metaProfiles is error || metaProfiles is () {
            return false;
        }

        if metaProfiles is json[] {
            foreach json profile in metaProfiles {
                string profileUrl = profile.toString();
                if searchProfiles.indexOf(profileUrl) != () {
                    return true;
                }
            }
        }

        return false;
    }

    // Helper function to check if resource matches security label search criteria
    private isolated function matchesSecurity(json resourceJson, string[] searchSecurity) returns boolean|error {
        json|error metaSecurity = resourceJson.meta?.security;
        
        if metaSecurity is error || metaSecurity is () {
            return false;
        }

        if metaSecurity is json[] {
            foreach json security in metaSecurity {
                string? system = (check security.system).toString();
                string? code = (check security.code).toString();
                
                foreach string searchSecurityLabel in searchSecurity {
                    // Support both "system|code" and just "code" formats
                    if searchSecurityLabel.includes("|") {
                        string[] parts = re `\|`.split(searchSecurityLabel);
                        if parts.length() == 2 && system == parts[0] && code == parts[1] {
                            return true;
                        }
                    } else {
                        if code == searchSecurityLabel {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }

    // Helper function to pad numbers with leading zero
    private isolated function padZero(int num) returns string {
        return num < 10 ? string `0${num}` : num.toString();
    }

    // Helper function to compare dates with FHIR prefix operators
    private isolated function compareDateWithPrefix(time:Civil resourceDate, string searchValue) returns boolean|error {
        // Extract prefix and date value
        string prefix = "eq"; // default is equals
        string dateValue = searchValue;
        
        if searchValue.startsWith("eq") {
            prefix = "eq";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("ne") {
            prefix = "ne";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("gt") {
            prefix = "gt";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("ge") {
            prefix = "ge";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("lt") {
            prefix = "lt";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("le") {
            prefix = "le";
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("sa") {
            prefix = "sa"; // starts after
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("eb") {
            prefix = "eb"; // ends before
            dateValue = searchValue.substring(2);
        } else if searchValue.startsWith("ap") {
            prefix = "ap"; // approximately
            dateValue = searchValue.substring(2);
        }
        
        // Convert resource date to comparable string
        decimal second = resourceDate.second ?: 0.0;
        string resourceDateStr = string `${resourceDate.year}-${self.padZero(resourceDate.month)}-${self.padZero(resourceDate.day)}T${self.padZero(resourceDate.hour)}:${self.padZero(resourceDate.minute)}:${self.padZero(<int>second)}`;
        
        // Normalize search date to same format for comparison
        string searchDateNormalized = dateValue.trim();
        
        // Perform comparison based on prefix
        match prefix {
            "eq" => {
                // Equals - check if resource date starts with search date (supports partial dates)
                return resourceDateStr.startsWith(searchDateNormalized);
            }
            "ne" => {
                // Not equals
                return !resourceDateStr.startsWith(searchDateNormalized);
            }
            "gt" => {
                // Greater than
                return resourceDateStr > searchDateNormalized;
            }
            "ge" => {
                // Greater than or equal
                return resourceDateStr >= searchDateNormalized;
            }
            "lt" => {
                // Less than
                return resourceDateStr < searchDateNormalized;
            }
            "le" => {
                // Less than or equal
                return resourceDateStr <= searchDateNormalized;
            }
            "sa" => {
                // Starts after (greater than)
                return resourceDateStr > searchDateNormalized;
            }
            "eb" => {
                // Ends before (less than)
                return resourceDateStr < searchDateNormalized;
            }
            "ap" => {
                // Approximately - for simplicity, treat as equals
                return resourceDateStr.startsWith(searchDateNormalized);
            }
            _ => {
                return false;
            }
        }
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
