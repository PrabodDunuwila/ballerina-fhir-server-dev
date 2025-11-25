import ballerina_fhir_server.db_store;
import ballerina/log;
import ballerina/time;

// Handler for managing resource version history
public class HistoryHandler {

    public isolated function init() {
    }

    // Save current version to history before update/delete
    public isolated function saveToHistory(db_store:Client persistClient, string resourceType, string resourceId, 
                                          record {|anydata...;|} currentVersion, string operation) returns error? {
        match resourceType {
            "Appointment" => {
                return self.saveAppointmentHistory(persistClient, resourceId, currentVersion, operation);
            }
            _ => {
                log:printWarn(string `History tracking not implemented for ${resourceType}`);
                return;
            }
        }
    }

    // Save Appointment history
    private isolated function saveAppointmentHistory(db_store:Client persistClient, string resourceId,
                                                     record {|anydata...;|} currentVersion, string operation) returns error? {
        
        db_store:AppointmentTable appointment = check currentVersion.cloneWithType();
        
        db_store:AppointmentTableHistoryInsert historyRecord = {
            APPOINTMENTTABLE_ID: appointment.APPOINTMENTTABLE_ID,
            VERSION_ID: appointment.VERSION_ID,
            OPERATION: operation,
            DATE: appointment.DATE,
            SERVICE_CATEGORY: appointment.SERVICE_CATEGORY,
            PART_STATUS: appointment.PART_STATUS,
            STATUS: appointment.STATUS,
            APPOINTMENT_TYPE: appointment.APPOINTMENT_TYPE,
            REASON_CODE: appointment.REASON_CODE,
            SPECIALTY: appointment.SPECIALTY,
            IDENTIFIER: appointment.IDENTIFIER,
            SERVICE_TYPE: appointment.SERVICE_TYPE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: appointment.RESOURCE_JSON
        };

        _ = check persistClient->/appointmenttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${appointment.VERSION_ID} of Appointment/${resourceId} to history`);
    }

    // Get current version number for a resource
    public isolated function getCurrentVersion(db_store:Client persistClient, string resourceType, string resourceId) returns int|error {
        match resourceType {
            "Appointment" => {
                db_store:AppointmentTable result = check persistClient->/appointmenttables/[resourceId]();
                return result.VERSION_ID;
            }
            _ => {
                return error(string `Version tracking not implemented for ${resourceType}`);
            }
        }
    }

    // Retrieve specific version from history
    public isolated function getResourceVersion(db_store:Client persistClient, string resourceType, 
                                               string resourceId, int versionId) returns json|error {
        match resourceType {
            "Appointment" => {
                return self.getAppointmentVersion(persistClient, resourceId, versionId);
            }
            _ => {
                return error(string `History retrieval not implemented for ${resourceType}`);
            }
        }
    }

    // Get specific Appointment version
    private isolated function getAppointmentVersion(db_store:Client persistClient, string resourceId, 
                                                    int versionId) returns json|error {
        
        stream<db_store:AppointmentTableHistory, error?> historyStream = 
            persistClient->/appointmenttablehistories(targetType = db_store:AppointmentTableHistory);
        
        db_store:AppointmentTableHistory[] results = check from var item in historyStream 
            where item.APPOINTMENTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Appointment/${resourceId}/_history/${versionId} not found`);
        }
        
        // Convert RESOURCE_JSON to json
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        
        return resourceJson;
    }

    // Get all versions for a resource
    public isolated function getResourceHistory(db_store:Client persistClient, string resourceType, 
                                                string resourceId) returns json[]|error {
        match resourceType {
            "Appointment" => {
                return self.getAppointmentHistory(persistClient, resourceId);
            }
            _ => {
                return error(string `History retrieval not implemented for ${resourceType}`);
            }
        }
    }

    // Get all Appointment versions
    private isolated function getAppointmentHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:AppointmentTableHistory, error?> historyStream = 
            persistClient->/appointmenttablehistories(targetType = db_store:AppointmentTableHistory);
        
        db_store:AppointmentTableHistory[] results = check from var item in historyStream 
            where item.APPOINTMENTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all history for resource type (system-wide)
    public isolated function getAllHistory(db_store:Client persistClient, string resourceType) returns json[]|error {
        match resourceType {
            "Appointment" => {
                return self.getAllAppointmentHistory(persistClient);
            }
            _ => {
                return error(string `History retrieval not implemented for ${resourceType}`);
            }
        }
    }

    // Get all Appointment history (system-wide)
    private isolated function getAllAppointmentHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:AppointmentTableHistory, error?> historyStream = 
            persistClient->/appointmenttablehistories(targetType = db_store:AppointmentTableHistory);
        
        db_store:AppointmentTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }
}
