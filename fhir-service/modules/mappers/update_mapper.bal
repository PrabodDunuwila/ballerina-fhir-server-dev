import ballerina_fhir_server.db_store;

import ballerina/io;
import ballerina/time;

public class UpdateMapper {
    private json[] references;

    public isolated function init() {
        self.references = [];
    }

    // This function will map values to persist update models
    public isolated function mapToUpdateModel(db_store:Client persistClient, string resourceType, json resourceJson, int newVersion = 2) returns record {|anydata...;|}|error? {
        FHIRMapper fhirMapper = new FHIRMapper();
        map<json> extractedValues = check fhirMapper.extractSearchParameters(persistClient, resourceType, resourceJson);
        self.references = fhirMapper.getReferences();

        match resourceType {
            "Account" => {
                time:Date? periodValue = ();
                if extractedValues.hasKey("period") {
                    json periodJson = extractedValues.get("period");
                    // Check if period is a JSON object with start/end dates
                    if periodJson is map<json> && periodJson.hasKey("start") {
                        string startDateStr = periodJson.get("start").toString();
                        if startDateStr.trim().length() > 0 {
                            periodValue = check parseDateString(startDateStr);
                        }
                    } else if periodJson is string {
                        // Handle simple string date format
                        string periodStr = periodJson;
                        if periodStr.trim().length() > 0 {
                            periodValue = check parseDateString(periodStr);
                        }
                    }
                }
                
                db_store:AccountTableUpdate accountUpdate = {
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    PERIOD: periodValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    VERSION_ID: 2,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return accountUpdate;
            }
            "Appointment" => {
                io:println(extractedValues);

                db_store:AppointmentTableUpdate appointmentUpdate = {
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    PART_STATUS: extractedValues.hasKey("part-status") ? extractedValues.get("part-status").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    APPOINTMENT_TYPE: extractedValues.hasKey("appointment-type") ? extractedValues.get("appointment-type").toString() : "",
                    REASON_CODE: extractedValues.hasKey("reason-code") ? extractedValues.get("reason-code").toString() : "",
                    SPECIALTY: extractedValues.hasKey("speciality") ? extractedValues.get("speciality").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    VERSION_ID: newVersion,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return appointmentUpdate;
            }
            _ => {
                // Generic handler for all other resources
                return self.createGenericUpdateModel(resourceType, resourceJson, extractedValues, newVersion);
            }
        }
    }

    // Generic update model creator for all resources
    private isolated function createGenericUpdateModel(string resourceType, json resourceJson, map<json> extractedValues, int newVersion) returns record {|anydata...;|}|error {
        
        // Create base record with required fields
        map<anydata> updateModel = {};
        
        // Add all extracted search parameter values
        foreach var [key, value] in extractedValues.entries() {
            string columnName = key.toUpperAscii();
            // Replace hyphens with underscores
            string[] parts = re `-`.split(columnName);
            columnName = string:'join("_", ...parts);
            
            // Handle different value types
            if value is string {
                updateModel[columnName] = value;
            } else if value is json {
                updateModel[columnName] = value.toString();
            }
        }
        
        // Add standard fields (required for all tables)
        updateModel["VERSION_ID"] = newVersion;
        updateModel["UPDATED_AT"] = time:utcToCivil(time:utcNow());
        updateModel["LAST_UPDATED"] = time:utcToCivil(time:utcNow());
        updateModel["RESOURCE_JSON"] = resourceJson.toString().toBytes();
        
        return updateModel;
    }

    public isolated function getReferences() returns json[] {
        return self.references;
    }
}
