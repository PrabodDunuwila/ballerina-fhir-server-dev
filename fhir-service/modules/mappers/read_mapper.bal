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
            "Account" => {
                json|error accountJson = (check self.readAccount(persistClient, resourceId)).toJson();
                return accountJson;
            }
            "Appointment" => {
                json|error appointmentJson = (check self.readAppointment(persistClient, resourceId)).toJson();
                return appointmentJson;
            }
            "Patient" => {
                json|error patientJson = (check self.readPatient(persistClient, resourceId)).toJson();
                return patientJson;
            }
            "Practitioner" => {
                json|error practitionerJson = (check self.readPractitioner(persistClient, resourceId)).toJson();
                return practitionerJson;
            }
            "Device" => {
                json|error deviceJson = (check self.readDevice(persistClient, resourceId)).toJson();
                return deviceJson;
            }
            "HealthcareService" => {
                json|error healthcareServiceJson = (check self.readHealthcareService(persistClient, resourceId)).toJson();
                return healthcareServiceJson;
            }
            "PractitionerRole" => {
                json|error practitionerRoleJson = (check self.readPractitionerRole(persistClient, resourceId)).toJson();
                return practitionerRoleJson;
            }
            "RelatedPerson" => {
                json|error relatedPersonJson = (check self.readRelatedPerson(persistClient, resourceId)).toJson();
                return relatedPersonJson;
            }
            "Location" => {
                json|error locationJson = (check self.readLocation(persistClient, resourceId)).toJson();
                return locationJson;
            }
            "ServiceRequest" => {
                json|error serviceRequestJson = (check self.readServiceRequest(persistClient, resourceId)).toJson();
                return serviceRequestJson;
            }
            "Condition" => {
                json|error conditionJson = (check self.readCondition(persistClient, resourceId)).toJson();
                return conditionJson;
            }
            "Observation" => {
                json|error observationJson = (check self.readObservation(persistClient, resourceId)).toJson();
                return observationJson;
            }
            "Procedure" => {
                json|error procedureJson = (check self.readProcedure(persistClient, resourceId)).toJson();
                return procedureJson;
            }
            "ImmunizationRecommendation" => {
                json|error immunizationRecommendationJson = (check self.readImmunizationRecommendation(persistClient, resourceId)).toJson();
                return immunizationRecommendationJson;
            }
            "Slot" => {
                json|error slotJson = (check self.readSlot(persistClient, resourceId)).toJson();
                return slotJson;
            }
            _ => {
                // Generic handler for all other resources
                return self.readGenericResource(persistClient, resourceType, resourceId);
            }
        }
    }


    // Search resources with filters
    public isolated function searchResources(db_store:Client persistClient, string resourceType, map<string[]> queryParams) returns json|error {
        match resourceType {
            "Account" => {
                return self.searchAccounts(persistClient, queryParams);
            }
            "Appointment" => {
                return self.searchAppointments(persistClient, queryParams);
            }
            "Patient" => {
                return self.searchPatients(persistClient, queryParams);
            }
            "Practitioner" => {
                return self.searchPractitioners(persistClient, queryParams);
            }
            "Device" => {
                return self.searchDevices(persistClient, queryParams);
            }
            "HealthcareService" => {
                return self.searchHealthcareServices(persistClient, queryParams);
            }
            "PractitionerRole" => {
                return self.searchPractitionerRoles(persistClient, queryParams);
            }
            "RelatedPerson" => {
                return self.searchRelatedPersons(persistClient, queryParams);
            }
            "Location" => {
                return self.searchLocations(persistClient, queryParams);
            }
            "ServiceRequest" => {
                return self.searchServiceRequests(persistClient, queryParams);
            }
            "Condition" => {
                return self.searchConditions(persistClient, queryParams);
            }
            "Observation" => {
                return self.searchObservations(persistClient, queryParams);
            }
            "Procedure" => {
                return self.searchProcedures(persistClient, queryParams);
            }
            "ImmunizationRecommendation" => {
                return self.searchImmunizationRecommendations(persistClient, queryParams);
            }
            "Slot" => {
                return self.searchSlots(persistClient, queryParams);
            }
            _ => {
                // Generic handler for all other resources
                return self.searchGenericResources(persistClient, resourceType, queryParams);
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

    // Read a single Account resource
    private isolated function readAccount(db_store:Client persistClient, string resourceId) returns json|error {
        db_store:AccountTable account = check persistClient->/accounttables/[resourceId]();
        json|error resourceJson = check self.mapFromAccountTable(account);
        return resourceJson;
    }

    // Search Accounts with query parameters
    private isolated function searchAccounts(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        // Check if any reference parameters are present
        string[] referenceParams = ["patient", "subject", "owner"];
        string[]? matchingResourceIds = ();
        boolean hasReferenceParams = false;
        
        foreach string refParam in referenceParams {
            if queryParams.hasKey(refParam) {
                hasReferenceParams = true;
                // Get resource IDs from REFERENCES table
                string[]? refIds = check self.getResourceIdsByReference(persistClient, "Account", refParam, queryParams.get(refParam));
                
                if refIds is string[] {
                    if matchingResourceIds is () {
                        matchingResourceIds = refIds;
                    } else {
                        // Intersect with existing IDs (AND logic)
                        string[] intersected = self.intersectStringArrays(matchingResourceIds, refIds);
                        // If intersection results in empty array, no accounts match all criteria
                        if intersected.length() == 0 {
                            json bundle = {
                                "resourceType": "Bundle",
                                "type": "searchset",
                                "total": 0,
                                "entry": []
                            };
                            return bundle;
                        }
                        matchingResourceIds = intersected;
                    }
                } else {
                    // If any reference parameter has no matches, return empty result
                    json bundle = {
                        "resourceType": "Bundle",
                        "type": "searchset",
                        "total": 0,
                        "entry": []
                    };
                    return bundle;
                }
            }
        }
        
        // If reference parameters were provided but no matches found, return empty result
        if hasReferenceParams && matchingResourceIds is () {
            json bundle = {
                "resourceType": "Bundle",
                "type": "searchset",
                "total": 0,
                "entry": []
            };
            return bundle;
        }

        stream<db_store:AccountTable, persist:Error?> accountStream = persistClient->/accounttables();

        db_store:AccountTable[] allAccounts = check from var account in accountStream
            select account;

        // Apply filters manually
        db_store:AccountTable[] filteredAccounts = [];
        
        foreach var account in allAccounts {
            boolean matches = true;
            
            // If reference parameters were used, check if this account ID is in the matching list
            if matchingResourceIds is string[] {
                matches = self.arrayContains(matchingResourceIds, account.ACCOUNTTABLE_ID);
            }
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && account.ACCOUNTTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && account.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // name filter
            if matches && queryParams.hasKey("name") {
                string[] names = queryParams.get("name");
                if names.length() > 0 && account.NAME != names[0] {
                    matches = false;
                }
            }
            
            // type filter
            if matches && queryParams.hasKey("type") {
                string[] types = queryParams.get("type");
                if types.length() > 0 && account.TYPE != types[0] {
                    matches = false;
                }
            }
            
            // identifier filter
            if matches && queryParams.hasKey("identifier") {
                string[] identifiers = queryParams.get("identifier");
                if identifiers.length() > 0 && account.IDENTIFIER != identifiers[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredAccounts.push(account);
            }
        }

        // Convert filtered results to FHIR Bundle
        json bundle = check self.createAccountSearchBundle(filteredAccounts, queryParams);

        return bundle;
    }

    // Search Appointments with query parameters
    private isolated function searchAppointments(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        // Check if any reference parameters are present
        string[] referenceParams = ["actor", "patient", "practitioner", "location", "slot", "based-on", "supporting-info"];
        string[]? matchingResourceIds = ();
        boolean hasReferenceParams = false;
        
        foreach string refParam in referenceParams {
            if queryParams.hasKey(refParam) {
                hasReferenceParams = true;
                // Get resource IDs from REFERENCES table
                string[]? refIds = check self.getResourceIdsByReference(persistClient, "Appointment", refParam, queryParams.get(refParam));
                
                if refIds is string[] {
                    if matchingResourceIds is () {
                        matchingResourceIds = refIds;
                    } else {
                        // Intersect with existing IDs (AND logic)
                        string[] intersected = self.intersectStringArrays(matchingResourceIds, refIds);
                        // If intersection results in empty array, no appointments match all criteria
                        if intersected.length() == 0 {
                            json bundle = {
                                "resourceType": "Bundle",
                                "type": "searchset",
                                "total": 0,
                                "entry": []
                            };
                            return bundle;
                        }
                        matchingResourceIds = intersected;
                    }
                } else {
                    // If any reference parameter has no matches, return empty result
                    json bundle = {
                        "resourceType": "Bundle",
                        "type": "searchset",
                        "total": 0,
                        "entry": []
                    };
                    return bundle;
                }
            }
        }
        
        // If reference parameters were provided but no matches found, return empty result
        if hasReferenceParams && matchingResourceIds is () {
            json bundle = {
                "resourceType": "Bundle",
                "type": "searchset",
                "total": 0,
                "entry": []
            };
            return bundle;
        }
        
        // Create a copy of queryParams without reference parameters for WHERE clause
        map<string[]> nonRefQueryParams = {};
        foreach var [key, values] in queryParams.entries() {
            if !self.arrayContains(referenceParams, key) {
                nonRefQueryParams[key] = values;
            }
        }
        
        // Build SQL WHERE clause from non-reference query parameters
        sql:ParameterizedQuery whereClause = self.buildWhereClause(nonRefQueryParams);
        
        stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(
            targetType = db_store:AppointmentTable,
            whereClause = whereClause
        );

        // Convert stream to array
        db_store:AppointmentTable[] allAppointments = check from var appointment in appointmentStream
            select appointment;

        // Filter by reference parameters if matches were found
        db_store:AppointmentTable[] filteredAppointments = allAppointments;
        if matchingResourceIds is string[] {
            filteredAppointments = [];
            foreach var appointment in allAppointments {
                if self.arrayContains(matchingResourceIds, appointment.APPOINTMENTTABLE_ID) {
                    filteredAppointments.push(appointment);
                }
            }
        }

        // Convert filtered results to FHIR Bundle
        json bundle = check self.createSearchBundle(filteredAppointments, queryParams);

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

        // _lastUpdated filter - FHIR standard parameter
        if queryParams.hasKey("_lastUpdated") {
            string[] lastUpdatedValues = queryParams.get("_lastUpdated");
            if lastUpdatedValues.length() > 0 {
                string lastUpdatedValue = lastUpdatedValues[0];
                // Parse date prefix if present
                string prefix = "eq";
                string actualDateTime = lastUpdatedValue;
                if lastUpdatedValue.length() > 2 {
                    string possiblePrefix = lastUpdatedValue.substring(0, 2);
                    if possiblePrefix == "eq" || possiblePrefix == "ne" || possiblePrefix == "gt" || 
                        possiblePrefix == "ge" || possiblePrefix == "lt" || possiblePrefix == "le" {
                        prefix = possiblePrefix;
                        actualDateTime = lastUpdatedValue.substring(2);
                    }
                }

                sql:ParameterizedQuery lastUpdatedCondition;
                match prefix {
                    "eq" => {
                        lastUpdatedCondition = `LAST_UPDATED = ${actualDateTime}`;
                    }
                    "ne" => {
                        lastUpdatedCondition = `LAST_UPDATED != ${actualDateTime}`;
                    }
                    "gt" => {
                        lastUpdatedCondition = `LAST_UPDATED > ${actualDateTime}`;
                    }
                    "ge" => {
                        lastUpdatedCondition = `LAST_UPDATED >= ${actualDateTime}`;
                    }
                    "lt" => {
                        lastUpdatedCondition = `LAST_UPDATED < ${actualDateTime}`;
                    }
                    "le" => {
                        lastUpdatedCondition = `LAST_UPDATED <= ${actualDateTime}`;
                    }
                    _ => {
                        lastUpdatedCondition = `LAST_UPDATED = ${actualDateTime}`;
                    }
                }
                conditions.push(lastUpdatedCondition);
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

    // Read a single Patient resource
    private isolated function readPatient(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:PatientTable, persist:Error?> patientStream = persistClient->/patienttables(targetType = db_store:PatientTable);

        db_store:PatientTable[] results = check from var patient in patientStream
            where patient.PATIENTTABLE_ID == resourceId
            select patient;

        if results.length() == 0 {
            return error(string `Patient/${resourceId} not found`);
        }

        db_store:PatientTable patient = results[0];
        json|error resourceJson = check self.mapFromPatientTable(patient);

        return resourceJson;
    }

    // Search Patients with query parameters
    private isolated function searchPatients(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:PatientTable, persist:Error?> patientStream = persistClient->/patienttables(targetType = db_store:PatientTable);

        // Convert stream to array
        db_store:PatientTable[] allPatients = check from var patient in patientStream
            select patient;

        // Filter based on query parameters
        db_store:PatientTable[] filteredPatients = [];
        
        foreach var patient in allPatients {
            boolean matches = true;
            
            // _id filter
            if queryParams.hasKey("_id") {
                string[] idValues = queryParams.get("_id");
                if idValues.length() > 0 && patient.PATIENTTABLE_ID != idValues[0] {
                    matches = false;
                }
            }
            
            // family filter
            if matches && queryParams.hasKey("family") {
                string[] familyValues = queryParams.get("family");
                if familyValues.length() > 0 && patient.FAMILY != familyValues[0] {
                    matches = false;
                }
            }
            
            // given filter
            if matches && queryParams.hasKey("given") {
                string[] givenValues = queryParams.get("given");
                if givenValues.length() > 0 && patient.GIVEN != givenValues[0] {
                    matches = false;
                }
            }
            
            // gender filter
            if matches && queryParams.hasKey("gender") {
                string[] genderValues = queryParams.get("gender");
                if genderValues.length() > 0 && patient.GENDER != genderValues[0] {
                    matches = false;
                }
            }
            
            // birthdate filter
            if matches && queryParams.hasKey("birthdate") {
                string[] birthdateValues = queryParams.get("birthdate");
                if birthdateValues.length() > 0 && patient.BIRTHDATE.toString() != birthdateValues[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredPatients.push(patient);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var patient in filteredPatients {
            json|error resourceJson = check self.mapFromPatientTable(patient);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Patient/${patient.PATIENTTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredPatients.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single Practitioner resource
    private isolated function readPractitioner(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:PractitionerTable, persist:Error?> practitionerStream = persistClient->/practitionertables(targetType = db_store:PractitionerTable);

        db_store:PractitionerTable[] results = check from var practitioner in practitionerStream
            where practitioner.PRACTITIONERTABLE_ID == resourceId
            select practitioner;

        if results.length() == 0 {
            return error(string `Practitioner/${resourceId} not found`);
        }

        db_store:PractitionerTable practitioner = results[0];
        json|error resourceJson = check self.mapFromPractitionerTable(practitioner);

        return resourceJson;
    }

    // Search Practitioners with query parameters
    private isolated function searchPractitioners(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:PractitionerTable, persist:Error?> practitionerStream = persistClient->/practitionertables(targetType = db_store:PractitionerTable);

        // Convert stream to array
        db_store:PractitionerTable[] allPractitioners = check from var practitioner in practitionerStream
            select practitioner;

        // Filter based on query parameters
        db_store:PractitionerTable[] filteredPractitioners = [];
        
        foreach var practitioner in allPractitioners {
            boolean matches = true;
            
            // _id filter
            if queryParams.hasKey("_id") {
                string[] idValues = queryParams.get("_id");
                if idValues.length() > 0 && practitioner.PRACTITIONERTABLE_ID != idValues[0] {
                    matches = false;
                }
            }
            
            // family filter
            if matches && queryParams.hasKey("family") {
                string[] familyValues = queryParams.get("family");
                if familyValues.length() > 0 && practitioner.FAMILY != familyValues[0] {
                    matches = false;
                }
            }
            
            // given filter
            if matches && queryParams.hasKey("given") {
                string[] givenValues = queryParams.get("given");
                if givenValues.length() > 0 && practitioner.GIVEN != givenValues[0] {
                    matches = false;
                }
            }
            
            // gender filter
            if matches && queryParams.hasKey("gender") {
                string[] genderValues = queryParams.get("gender");
                if genderValues.length() > 0 && practitioner.GENDER != genderValues[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredPractitioners.push(practitioner);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var practitioner in filteredPractitioners {
            json|error resourceJson = check self.mapFromPractitionerTable(practitioner);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Practitioner/${practitioner.PRACTITIONERTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredPractitioners.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single Device by ID
    private isolated function readDevice(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:DeviceTable, persist:Error?> deviceStream = persistClient->/devicetables();

        db_store:DeviceTable[] results = check from var device in deviceStream
            where device.DEVICETABLE_ID == resourceId
            select device;

        if results.length() == 0 {
            return error(string `Device/${resourceId} not found`);
        }

        return check self.mapFromDeviceTable(results[0]);
    }

    // Search Devices with optional filters
    private isolated function searchDevices(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:DeviceTable, persist:Error?> deviceStream = persistClient->/devicetables();

        db_store:DeviceTable[] allDevices = check from var device in deviceStream
            select device;

        // Apply filters manually
        db_store:DeviceTable[] filteredDevices = [];
        
        foreach var device in allDevices {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && device.DEVICETABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && device.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // manufacturer filter
            if matches && queryParams.hasKey("manufacturer") {
                string[] manufacturers = queryParams.get("manufacturer");
                if manufacturers.length() > 0 && device.MANUFACTURER != manufacturers[0] {
                    matches = false;
                }
            }
            
            // model filter
            if matches && queryParams.hasKey("model") {
                string[] models = queryParams.get("model");
                if models.length() > 0 && device.MODEL != models[0] {
                    matches = false;
                }
            }
            
            // device-name filter
            if matches && queryParams.hasKey("device-name") {
                string[] names = queryParams.get("device-name");
                if names.length() > 0 && device.DEVICE_NAME != names[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredDevices.push(device);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var device in filteredDevices {
            json|error resourceJson = check self.mapFromDeviceTable(device);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Device/${device.DEVICETABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredDevices.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single HealthcareService by ID
    private isolated function readHealthcareService(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:HealthcareServiceTable, persist:Error?> healthcareServiceStream = persistClient->/healthcareservicetables();

        db_store:HealthcareServiceTable[] results = check from var healthcareService in healthcareServiceStream
            where healthcareService.HEALTHCARESERVICETABLE_ID == resourceId
            select healthcareService;

        if results.length() == 0 {
            return error(string `HealthcareService/${resourceId} not found`);
        }

        return check self.mapFromHealthcareServiceTable(results[0]);
    }

    // Search HealthcareServices with optional filters
    private isolated function searchHealthcareServices(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:HealthcareServiceTable, persist:Error?> healthcareServiceStream = persistClient->/healthcareservicetables();

        db_store:HealthcareServiceTable[] allHealthcareServices = check from var healthcareService in healthcareServiceStream
            select healthcareService;

        // Apply filters manually
        db_store:HealthcareServiceTable[] filteredHealthcareServices = [];
        
        foreach var healthcareService in allHealthcareServices {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && healthcareService.HEALTHCARESERVICETABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // name filter
            if matches && queryParams.hasKey("name") {
                string[] names = queryParams.get("name");
                if names.length() > 0 && healthcareService.NAME != names[0] {
                    matches = false;
                }
            }
            
            // active filter
            if matches && queryParams.hasKey("active") {
                string[] actives = queryParams.get("active");
                if actives.length() > 0 && healthcareService.ACTIVE != actives[0] {
                    matches = false;
                }
            }
            
            // service-category filter
            if matches && queryParams.hasKey("service-category") {
                string[] categories = queryParams.get("service-category");
                if categories.length() > 0 && healthcareService.SERVICE_CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // service-type filter
            if matches && queryParams.hasKey("service-type") {
                string[] types = queryParams.get("service-type");
                if types.length() > 0 && healthcareService.SERVICE_TYPE != types[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredHealthcareServices.push(healthcareService);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var healthcareService in filteredHealthcareServices {
            json|error resourceJson = check self.mapFromHealthcareServiceTable(healthcareService);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/HealthcareService/${healthcareService.HEALTHCARESERVICETABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredHealthcareServices.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single PractitionerRole by ID
    private isolated function readPractitionerRole(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:PractitionerRoleTable, persist:Error?> practitionerRoleStream = persistClient->/practitionerroletables();

        db_store:PractitionerRoleTable[] results = check from var practitionerRole in practitionerRoleStream
            where practitionerRole.PRACTITIONERROLETABLE_ID == resourceId
            select practitionerRole;

        if results.length() == 0 {
            return error(string `PractitionerRole/${resourceId} not found`);
        }

        return check self.mapFromPractitionerRoleTable(results[0]);
    }

    // Search PractitionerRoles with optional filters
    private isolated function searchPractitionerRoles(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:PractitionerRoleTable, persist:Error?> practitionerRoleStream = persistClient->/practitionerroletables();

        db_store:PractitionerRoleTable[] allPractitionerRoles = check from var practitionerRole in practitionerRoleStream
            select practitionerRole;

        // Apply filters manually
        db_store:PractitionerRoleTable[] filteredPractitionerRoles = [];
        
        foreach var practitionerRole in allPractitionerRoles {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && practitionerRole.PRACTITIONERROLETABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // active filter
            if matches && queryParams.hasKey("active") {
                string[] actives = queryParams.get("active");
                if actives.length() > 0 && practitionerRole.ACTIVE != actives[0] {
                    matches = false;
                }
            }
            
            // role filter
            if matches && queryParams.hasKey("role") {
                string[] roles = queryParams.get("role");
                if roles.length() > 0 && practitionerRole.ROLE != roles[0] {
                    matches = false;
                }
            }
            
            // specialty filter
            if matches && queryParams.hasKey("specialty") {
                string[] specialties = queryParams.get("specialty");
                if specialties.length() > 0 && practitionerRole.SPECIALTY != specialties[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredPractitionerRoles.push(practitionerRole);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var practitionerRole in filteredPractitionerRoles {
            json|error resourceJson = check self.mapFromPractitionerRoleTable(practitionerRole);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/PractitionerRole/${practitionerRole.PRACTITIONERROLETABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredPractitionerRoles.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single RelatedPerson by ID
    private isolated function readRelatedPerson(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:RelatedPersonTable, persist:Error?> relatedPersonStream = persistClient->/relatedpersontables();

        db_store:RelatedPersonTable[] results = check from var relatedPerson in relatedPersonStream
            where relatedPerson.RELATEDPERSONTABLE_ID == resourceId
            select relatedPerson;

        if results.length() == 0 {
            return error(string `RelatedPerson/${resourceId} not found`);
        }

        return check self.mapFromRelatedPersonTable(results[0]);
    }

    // Search RelatedPersons with optional filters
    private isolated function searchRelatedPersons(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:RelatedPersonTable, persist:Error?> relatedPersonStream = persistClient->/relatedpersontables();

        db_store:RelatedPersonTable[] allRelatedPersons = check from var relatedPerson in relatedPersonStream
            select relatedPerson;

        // Apply filters manually
        db_store:RelatedPersonTable[] filteredRelatedPersons = [];
        
        foreach var relatedPerson in allRelatedPersons {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && relatedPerson.RELATEDPERSONTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // name filter
            if matches && queryParams.hasKey("name") {
                string[] names = queryParams.get("name");
                if names.length() > 0 && relatedPerson.NAME != names[0] {
                    matches = false;
                }
            }
            
            // gender filter
            if matches && queryParams.hasKey("gender") {
                string[] genders = queryParams.get("gender");
                if genders.length() > 0 && relatedPerson.GENDER != genders[0] {
                    matches = false;
                }
            }
            
            // active filter
            if matches && queryParams.hasKey("active") {
                string[] actives = queryParams.get("active");
                if actives.length() > 0 && relatedPerson.ACTIVE != actives[0] {
                    matches = false;
                }
            }
            
            // birthdate filter
            if matches && queryParams.hasKey("birthdate") {
                string[] birthdates = queryParams.get("birthdate");
                if birthdates.length() > 0 && relatedPerson.BIRTHDATE.toString() != birthdates[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredRelatedPersons.push(relatedPerson);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var relatedPerson in filteredRelatedPersons {
            json|error resourceJson = check self.mapFromRelatedPersonTable(relatedPerson);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/RelatedPerson/${relatedPerson.RELATEDPERSONTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredRelatedPersons.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single Location by ID
    private isolated function readLocation(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:LocationTable, persist:Error?> locationStream = persistClient->/locationtables();

        db_store:LocationTable[] results = check from var location in locationStream
            where location.LOCATIONTABLE_ID == resourceId
            select location;

        if results.length() == 0 {
            return error(string `Location/${resourceId} not found`);
        }

        return check self.mapFromLocationTable(results[0]);
    }

    // Search Locations with optional filters
    private isolated function searchLocations(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:LocationTable, persist:Error?> locationStream = persistClient->/locationtables();

        db_store:LocationTable[] allLocations = check from var location in locationStream
            select location;

        // Apply filters manually
        db_store:LocationTable[] filteredLocations = [];
        
        foreach var location in allLocations {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && location.LOCATIONTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // name filter
            if matches && queryParams.hasKey("name") {
                string[] names = queryParams.get("name");
                if names.length() > 0 && location.NAME != names[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && location.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // address-city filter
            if matches && queryParams.hasKey("address-city") {
                string[] cities = queryParams.get("address-city");
                if cities.length() > 0 && location.ADDRESS_CITY != cities[0] {
                    matches = false;
                }
            }
            
            // address-state filter
            if matches && queryParams.hasKey("address-state") {
                string[] states = queryParams.get("address-state");
                if states.length() > 0 && location.ADDRESS_STATE != states[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredLocations.push(location);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var location in filteredLocations {
            json|error resourceJson = check self.mapFromLocationTable(location);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Location/${location.LOCATIONTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredLocations.length(),
            "entry": entries
        };

        return bundle;
    }

    // Read a single ServiceRequest by ID
    private isolated function readServiceRequest(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:ServiceRequestTable, persist:Error?> serviceRequestStream = persistClient->/servicerequesttables();

        db_store:ServiceRequestTable[] results = check from var serviceRequest in serviceRequestStream
            where serviceRequest.SERVICEREQUESTTABLE_ID == resourceId
            select serviceRequest;

        if results.length() == 0 {
            return error(string `ServiceRequest/${resourceId} not found`);
        }

        return check self.mapFromServiceRequestTable(results[0]);
    }

    // Search ServiceRequests with optional filters
    private isolated function searchServiceRequests(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:ServiceRequestTable, persist:Error?> serviceRequestStream = persistClient->/servicerequesttables();

        db_store:ServiceRequestTable[] allServiceRequests = check from var serviceRequest in serviceRequestStream
            select serviceRequest;

        // Apply filters manually
        db_store:ServiceRequestTable[] filteredServiceRequests = [];
        
        foreach var serviceRequest in allServiceRequests {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && serviceRequest.SERVICEREQUESTTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && serviceRequest.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // intent filter
            if matches && queryParams.hasKey("intent") {
                string[] intents = queryParams.get("intent");
                if intents.length() > 0 && serviceRequest.INTENT != intents[0] {
                    matches = false;
                }
            }
            
            // category filter
            if matches && queryParams.hasKey("category") {
                string[] categories = queryParams.get("category");
                if categories.length() > 0 && serviceRequest.CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // priority filter
            if matches && queryParams.hasKey("priority") {
                string[] priorities = queryParams.get("priority");
                if priorities.length() > 0 && serviceRequest.PRIORITY != priorities[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredServiceRequests.push(serviceRequest);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var serviceRequest in filteredServiceRequests {
            json|error resourceJson = check self.mapFromServiceRequestTable(serviceRequest);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/ServiceRequest/${serviceRequest.SERVICEREQUESTTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredServiceRequests.length(),
            "entry": entries
        };

        return bundle;
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

    // Convert AccountTable record to JSON
    private isolated function convertAccountToJson(db_store:AccountTable account) returns json|error {
        byte[] resourceJsonBytes = account.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = check resourceJsonString.fromJsonString();

        return resourceJson;
    }

    // Convert AppointmentTable record to JSON
    private isolated function convertAppointmentToJson(db_store:AppointmentTable appointment) returns json|error {
        byte[] resourceJsonBytes = appointment.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = check resourceJsonString.fromJsonString();

        return resourceJson;
    }

    // Create FHIR Bundle for Account search results
    private isolated function createAccountSearchBundle(db_store:AccountTable[] accounts, map<string[]> queryParams) returns json|error {
        json[] entries = [];

        foreach db_store:AccountTable account in accounts {
            json resourceJson = check self.convertAccountToJson(account);

            json entry = {
                "fullUrl": string `https://example.com/fhir/Account/${account.ACCOUNTTABLE_ID}`,
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

        return bundle;
    }

    // Create FHIR Bundle for Appointment search results
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
    // Map from AccountTable to Account JSON
    public isolated function mapFromAccountTable(db_store:AccountTable accountTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = accountTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    public isolated function mapFromAppointmentTable(db_store:AppointmentTable appointmentTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = appointmentTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        // Convert JSON to international401:Appointment record
        // international401:Appointment appointment = check fhirParser:parse(resourceJson, international401:Appointment).ensureType();

        return resourceJson;
    }

    // Map from PatientTable to Patient JSON
    public isolated function mapFromPatientTable(db_store:PatientTable patientTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = patientTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from PractitionerTable to Practitioner JSON
    public isolated function mapFromPractitionerTable(db_store:PractitionerTable practitionerTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = practitionerTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from DeviceTable to Device JSON
    public isolated function mapFromDeviceTable(db_store:DeviceTable deviceTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = deviceTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from HealthcareServiceTable to HealthcareService JSON
    public isolated function mapFromHealthcareServiceTable(db_store:HealthcareServiceTable healthcareServiceTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = healthcareServiceTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from PractitionerRoleTable to PractitionerRole JSON
    public isolated function mapFromPractitionerRoleTable(db_store:PractitionerRoleTable practitionerRoleTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = practitionerRoleTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from RelatedPersonTable to RelatedPerson JSON
    public isolated function mapFromRelatedPersonTable(db_store:RelatedPersonTable relatedPersonTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = relatedPersonTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from LocationTable to Location JSON
    public isolated function mapFromLocationTable(db_store:LocationTable locationTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = locationTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Map from ServiceRequestTable to ServiceRequest JSON
    public isolated function mapFromServiceRequestTable(db_store:ServiceRequestTable serviceRequestTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = serviceRequestTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Read a single Condition by ID
    private isolated function readCondition(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:ConditionTable, persist:Error?> conditionStream = persistClient->/conditiontables();

        db_store:ConditionTable[] results = check from var condition in conditionStream
            where condition.CONDITIONTABLE_ID == resourceId
            select condition;

        if results.length() == 0 {
            return error(string `Condition/${resourceId} not found`);
        }

        return check self.mapFromConditionTable(results[0]);
    }

    // Search Conditions with optional filters
    private isolated function searchConditions(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:ConditionTable, persist:Error?> conditionStream = persistClient->/conditiontables();

        db_store:ConditionTable[] allConditions = check from var condition in conditionStream
            select condition;

        // Apply filters manually
        db_store:ConditionTable[] filteredConditions = [];
        
        foreach var condition in allConditions {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && condition.CONDITIONTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // clinical-status filter
            if matches && queryParams.hasKey("clinical-status") {
                string[] statuses = queryParams.get("clinical-status");
                if statuses.length() > 0 && condition.CLINICAL_STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // verification-status filter
            if matches && queryParams.hasKey("verification-status") {
                string[] verStatuses = queryParams.get("verification-status");
                if verStatuses.length() > 0 && condition.VERIFICATION_STATUS != verStatuses[0] {
                    matches = false;
                }
            }
            
            // category filter
            if matches && queryParams.hasKey("category") {
                string[] categories = queryParams.get("category");
                if categories.length() > 0 && condition.CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // severity filter
            if matches && queryParams.hasKey("severity") {
                string[] severities = queryParams.get("severity");
                if severities.length() > 0 && condition.SEVERITY != severities[0] {
                    matches = false;
                }
            }
            
            // code filter
            if matches && queryParams.hasKey("code") {
                string[] codes = queryParams.get("code");
                if codes.length() > 0 && condition.CODE != codes[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredConditions.push(condition);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var condition in filteredConditions {
            json|error resourceJson = check self.mapFromConditionTable(condition);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Condition/${condition.CONDITIONTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredConditions.length(),
            "entry": entries
        };

        return bundle;
    }

    // Map from ConditionTable to Condition JSON
    public isolated function mapFromConditionTable(db_store:ConditionTable conditionTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = conditionTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Read a single Observation by ID
    private isolated function readObservation(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:ObservationTable, persist:Error?> observationStream = persistClient->/observationtables();

        db_store:ObservationTable[] results = check from var observation in observationStream
            where observation.OBSERVATIONTABLE_ID == resourceId
            select observation;

        if results.length() == 0 {
            return error(string `Observation/${resourceId} not found`);
        }

        return check self.mapFromObservationTable(results[0]);
    }

    // Search Observations with optional filters
    private isolated function searchObservations(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:ObservationTable, persist:Error?> observationStream = persistClient->/observationtables();

        db_store:ObservationTable[] allObservations = check from var observation in observationStream
            select observation;

        // Apply filters manually
        db_store:ObservationTable[] filteredObservations = [];
        
        foreach var observation in allObservations {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && observation.OBSERVATIONTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && observation.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // category filter
            if matches && queryParams.hasKey("category") {
                string[] categories = queryParams.get("category");
                if categories.length() > 0 && observation.CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // code filter
            if matches && queryParams.hasKey("code") {
                string[] codes = queryParams.get("code");
                if codes.length() > 0 && observation.CODE != codes[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredObservations.push(observation);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var observation in filteredObservations {
            json|error resourceJson = check self.mapFromObservationTable(observation);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Observation/${observation.OBSERVATIONTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredObservations.length(),
            "entry": entries
        };

        return bundle;
    }

    // Map from ObservationTable to Observation JSON
    public isolated function mapFromObservationTable(db_store:ObservationTable observationTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = observationTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Read a single Procedure by ID
    private isolated function readProcedure(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:ProcedureTable, persist:Error?> procedureStream = persistClient->/proceduretables();

        db_store:ProcedureTable[] results = check from var procedure in procedureStream
            where procedure.PROCEDURETABLE_ID == resourceId
            select procedure;

        if results.length() == 0 {
            return error(string `Procedure/${resourceId} not found`);
        }

        return check self.mapFromProcedureTable(results[0]);
    }

    // Search Procedures with optional filters
    private isolated function searchProcedures(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:ProcedureTable, persist:Error?> procedureStream = persistClient->/proceduretables();

        db_store:ProcedureTable[] allProcedures = check from var procedure in procedureStream
            select procedure;

        // Apply filters manually
        db_store:ProcedureTable[] filteredProcedures = [];
        
        foreach var procedure in allProcedures {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && procedure.PROCEDURETABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && procedure.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // category filter
            if matches && queryParams.hasKey("category") {
                string[] categories = queryParams.get("category");
                if categories.length() > 0 && procedure.CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // code filter
            if matches && queryParams.hasKey("code") {
                string[] codes = queryParams.get("code");
                if codes.length() > 0 && procedure.CODE != codes[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredProcedures.push(procedure);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var procedure in filteredProcedures {
            json|error resourceJson = check self.mapFromProcedureTable(procedure);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Procedure/${procedure.PROCEDURETABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredProcedures.length(),
            "entry": entries
        };

        return bundle;
    }

    // Map from ProcedureTable to Procedure JSON
    public isolated function mapFromProcedureTable(db_store:ProcedureTable procedureTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = procedureTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Read a single ImmunizationRecommendation by ID
    private isolated function readImmunizationRecommendation(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:ImmunizationRecommendationTable, persist:Error?> immunizationRecommendationStream = persistClient->/immunizationrecommendationtables();

        db_store:ImmunizationRecommendationTable[] results = check from var immunizationRecommendation in immunizationRecommendationStream
            where immunizationRecommendation.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId
            select immunizationRecommendation;

        if results.length() == 0 {
            return error(string `ImmunizationRecommendation/${resourceId} not found`);
        }

        return check self.mapFromImmunizationRecommendationTable(results[0]);
    }

    // Search ImmunizationRecommendations with optional filters
    private isolated function searchImmunizationRecommendations(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:ImmunizationRecommendationTable, persist:Error?> immunizationRecommendationStream = persistClient->/immunizationrecommendationtables();

        db_store:ImmunizationRecommendationTable[] allImmunizationRecommendations = check from var immunizationRecommendation in immunizationRecommendationStream
            select immunizationRecommendation;

        // Apply filters manually
        db_store:ImmunizationRecommendationTable[] filteredImmunizationRecommendations = [];
        
        foreach var immunizationRecommendation in allImmunizationRecommendations {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && immunizationRecommendation.IMMUNIZATIONRECOMMENDATIONTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && immunizationRecommendation.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // target-disease filter
            if matches && queryParams.hasKey("target-disease") {
                string[] diseases = queryParams.get("target-disease");
                if diseases.length() > 0 && immunizationRecommendation.TARGET_DISEASE != diseases[0] {
                    matches = false;
                }
            }
            
            // vaccine-type filter
            if matches && queryParams.hasKey("vaccine-type") {
                string[] vaccineTypes = queryParams.get("vaccine-type");
                if vaccineTypes.length() > 0 && immunizationRecommendation.VACCINE_TYPE != vaccineTypes[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredImmunizationRecommendations.push(immunizationRecommendation);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var immunizationRecommendation in filteredImmunizationRecommendations {
            json|error resourceJson = check self.mapFromImmunizationRecommendationTable(immunizationRecommendation);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/ImmunizationRecommendation/${immunizationRecommendation.IMMUNIZATIONRECOMMENDATIONTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredImmunizationRecommendations.length(),
            "entry": entries
        };

        return bundle;
    }

    // Map from ImmunizationRecommendationTable to ImmunizationRecommendation JSON
    public isolated function mapFromImmunizationRecommendationTable(db_store:ImmunizationRecommendationTable immunizationRecommendationTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = immunizationRecommendationTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Read a single Slot by ID
    private isolated function readSlot(db_store:Client persistClient, string resourceId) returns json|error {
        stream<db_store:SlotTable, persist:Error?> slotStream = persistClient->/slottables();

        db_store:SlotTable[] results = check from var slot in slotStream
            where slot.SLOTTABLE_ID == resourceId
            select slot;

        if results.length() == 0 {
            return error(string `Slot/${resourceId} not found`);
        }

        return check self.mapFromSlotTable(results[0]);
    }

    // Search Slots with optional filters
    private isolated function searchSlots(db_store:Client persistClient, map<string[]> queryParams) returns json|error {
        stream<db_store:SlotTable, persist:Error?> slotStream = persistClient->/slottables();

        db_store:SlotTable[] allSlots = check from var slot in slotStream
            select slot;

        // Apply filters manually
        db_store:SlotTable[] filteredSlots = [];
        
        foreach var slot in allSlots {
            boolean matches = true;
            
            // _id filter
            if matches && queryParams.hasKey("_id") {
                string[] ids = queryParams.get("_id");
                if ids.length() > 0 && slot.SLOTTABLE_ID != ids[0] {
                    matches = false;
                }
            }
            
            // status filter
            if matches && queryParams.hasKey("status") {
                string[] statuses = queryParams.get("status");
                if statuses.length() > 0 && slot.STATUS != statuses[0] {
                    matches = false;
                }
            }
            
            // service-category filter
            if matches && queryParams.hasKey("service-category") {
                string[] categories = queryParams.get("service-category");
                if categories.length() > 0 && slot.SERVICE_CATEGORY != categories[0] {
                    matches = false;
                }
            }
            
            // service-type filter
            if matches && queryParams.hasKey("service-type") {
                string[] serviceTypes = queryParams.get("service-type");
                if serviceTypes.length() > 0 && slot.SERVICE_TYPE != serviceTypes[0] {
                    matches = false;
                }
            }
            
            // specialty filter
            if matches && queryParams.hasKey("specialty") {
                string[] specialties = queryParams.get("specialty");
                if specialties.length() > 0 && slot.SPECIALTY != specialties[0] {
                    matches = false;
                }
            }
            
            if matches {
                filteredSlots.push(slot);
            }
        }

        // Convert filtered results to FHIR Bundle
        json[] entries = [];
        foreach var slot in filteredSlots {
            json|error resourceJson = check self.mapFromSlotTable(slot);
            if resourceJson is json {
                entries.push({
                    "fullUrl": string `https://example.com/fhir/Slot/${slot.SLOTTABLE_ID}`,
                    "resource": resourceJson
                });
            }
        }

        json bundle = {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": filteredSlots.length(),
            "entry": entries
        };

        return bundle;
    }

    // Map from SlotTable to Slot JSON
    public isolated function mapFromSlotTable(db_store:SlotTable slotTable) returns json|error {
        // Extract the RESOURCE_JSON bytes and convert to JSON
        byte[] resourceJsonBytes = slotTable.RESOURCE_JSON;
        string resourceJsonString = check string:fromBytes(resourceJsonBytes);
        json resourceJson = resourceJsonString.toJson();

        return resourceJson;
    }

    // Helper function to get resource IDs by reference parameter
    private isolated function getResourceIdsByReference(db_store:Client persistClient, string sourceResourceType, string searchParamName, string[] referenceValues) returns string[]?|error {
        string[] matchingIds = [];
        
        foreach string refValue in referenceValues {
            // Parse reference value - can be in formats:
            // 1. [id] - just the ID
            // 2. [type]/[id] - type and ID
            // 3. [url] - absolute URL
            
            string? targetType = ();
            string? targetId = ();
            
            // Check if it contains a slash (ResourceType/ID format)
            int? slashIndex = refValue.indexOf("/");
            if slashIndex is int {
                targetType = refValue.substring(0, slashIndex);
                targetId = refValue.substring(slashIndex + 1);
            } else {
                // Just an ID - we'll match any target type
                targetId = refValue;
            }
            
            // Query REFERENCES table
            stream<db_store:REFERENCES, persist:Error?> referencesStream = persistClient->/references(targetType = db_store:REFERENCES);
            
            db_store:REFERENCES[] matchingRefs = [];
            if targetType is string && targetId is string {
                // Match both target type and ID
                matchingRefs = check from var ref in referencesStream
                    where ref.SOURCE_RESOURCE_TYPE == sourceResourceType &&
                          ref.TARGET_RESOURCE_TYPE == targetType &&
                          ref.TARGET_RESOURCE_ID == targetId
                    select ref;
            } else if targetId is string {
                // Match only target ID (any type)
                matchingRefs = check from var ref in referencesStream
                    where ref.SOURCE_RESOURCE_TYPE == sourceResourceType &&
                          ref.TARGET_RESOURCE_ID == targetId
                    select ref;
            }
            
            // Collect unique source resource IDs
            foreach var ref in matchingRefs {
                if !self.arrayContains(matchingIds, ref.SOURCE_RESOURCE_ID) {
                    matchingIds.push(ref.SOURCE_RESOURCE_ID);
                }
            }
        }
        
        return matchingIds.length() > 0 ? matchingIds : ();
    }

    // Helper function to check if array contains a value
    private isolated function arrayContains(string[] arr, string value) returns boolean {
        foreach string item in arr {
            if item == value {
                return true;
            }
        }
        return false;
    }

    // Helper function to intersect two string arrays (returns common elements)
    private isolated function intersectStringArrays(string[] arr1, string[] arr2) returns string[] {
        string[] result = [];
        foreach string item in arr1 {
            if self.arrayContains(arr2, item) && !self.arrayContains(result, item) {
                result.push(item);
            }
        }
        return result;
    }

    // Generic resource reader for all unsupported resources
    private isolated function readGenericResource(db_store:Client persistClient, string resourceType, string resourceId) returns json|error {
        // Construct table name
        string tableName = resourceType.toUpperAscii() + "Table";
        string idColumn = resourceType.toUpperAscii() + "TABLE_ID";
        
        // Build and execute SQL query
        sql:ParameterizedQuery query = `SELECT RESOURCE_JSON FROM ${tableName} WHERE ${idColumn} = ${resourceId}`;
        
        stream<record {| byte[] RESOURCE_JSON; |}, persist:Error?> resultStream = persistClient->queryNativeSQL(query);
        
        record {| byte[] RESOURCE_JSON; |}[] results = check from var row in resultStream select row;
        
        if results.length() == 0 {
            return error(string `${resourceType}/${resourceId} not found`);
        }
        
        // Convert bytes to JSON
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        
        return resourceJson;
    }

    // Generic resource searcher for all unsupported resources  
    private isolated function searchGenericResources(db_store:Client persistClient, string resourceType, map<string[]> queryParams) returns json|error {
        string tableName = resourceType.toUpperAscii() + "Table";
        
        // Build and execute SQL query
        sql:ParameterizedQuery query = `SELECT RESOURCE_JSON FROM ${tableName}`;
        
        stream<record {| byte[] RESOURCE_JSON; |}, persist:Error?> resultStream = persistClient->queryNativeSQL(query);
        
        record {| byte[] RESOURCE_JSON; |}[] results = check from var row in resultStream select row;
        
        // Convert results to FHIR Bundle
        json[] entries = [];
        foreach var row in results {
            string jsonStr = check string:fromBytes(row.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            
            string resourceIdStr = "";
            json|error idValue = resourceJson.id;
            if idValue is string {
                resourceIdStr = idValue;
            } else if idValue is json {
                resourceIdStr = idValue.toString();
            }
            
            json entry = {
                "fullUrl": string `${resourceType}/${resourceIdStr}`,
                "resource": resourceJson
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
}


