import ballerina_fhir_server.db_store;

import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/persist;

// Validate if a referenced resource exists in the database
public isolated function validateReferenceExists(db_store:Client persistClient, string resourceType, string resourceId) returns boolean|error {
    match resourceType {
        "Appointment" => {
            stream<db_store:AppointmentTable, persist:Error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);
            
            db_store:AppointmentTable[] results = check from var appointment in appointmentStream
                where appointment.APPOINTMENTTABLE_ID == resourceId
                select appointment;
            
            return results.length() > 0;
        }
        "Patient" => {
            stream<db_store:PatientTable, persist:Error?> patientStream = persistClient->/patienttables(targetType = db_store:PatientTable);
            
            db_store:PatientTable[] results = check from var patient in patientStream
                where patient.PATIENTTABLE_ID == resourceId
                select patient;
            
            return results.length() > 0;
        }
        "Practitioner" => {
            stream<db_store:PractitionerTable, persist:Error?> practitionerStream = persistClient->/practitionertables(targetType = db_store:PractitionerTable);
            
            db_store:PractitionerTable[] results = check from var practitioner in practitionerStream
                where practitioner.PRACTITIONERTABLE_ID == resourceId
                select practitioner;
            
            return results.length() > 0;
        }
        "Device" => {
            stream<db_store:DeviceTable, persist:Error?> deviceStream = persistClient->/devicetables(targetType = db_store:DeviceTable);
            
            db_store:DeviceTable[] results = check from var device in deviceStream
                where device.DEVICETABLE_ID == resourceId
                select device;
            
            return results.length() > 0;
        }
        "HealthcareService" => {
            stream<db_store:HealthcareServiceTable, persist:Error?> healthcareServiceStream = persistClient->/healthcareservicetables(targetType = db_store:HealthcareServiceTable);
            
            db_store:HealthcareServiceTable[] results = check from var healthcareService in healthcareServiceStream
                where healthcareService.HEALTHCARESERVICETABLE_ID == resourceId
                select healthcareService;
            
            return results.length() > 0;
        }
        "PractitionerRole" => {
            stream<db_store:PractitionerRoleTable, persist:Error?> practitionerRoleStream = persistClient->/practitionerroletables(targetType = db_store:PractitionerRoleTable);
            
            db_store:PractitionerRoleTable[] results = check from var practitionerRole in practitionerRoleStream
                where practitionerRole.PRACTITIONERROLETABLE_ID == resourceId
                select practitionerRole;
            
            return results.length() > 0;
        }
        "RelatedPerson" => {
            stream<db_store:RelatedPersonTable, persist:Error?> relatedPersonStream = persistClient->/relatedpersontables(targetType = db_store:RelatedPersonTable);
            
            db_store:RelatedPersonTable[] results = check from var relatedPerson in relatedPersonStream
                where relatedPerson.RELATEDPERSONTABLE_ID == resourceId
                select relatedPerson;
            
            return results.length() > 0;
        }
        "Location" => {
            stream<db_store:LocationTable, persist:Error?> locationStream = persistClient->/locationtables(targetType = db_store:LocationTable);
            
            db_store:LocationTable[] results = check from var location in locationStream
                where location.LOCATIONTABLE_ID == resourceId
                select location;
            
            return results.length() > 0;
        }
        "ServiceRequest" => {
            stream<db_store:ServiceRequestTable, persist:Error?> serviceRequestStream = persistClient->/servicerequesttables(targetType = db_store:ServiceRequestTable);
            
            db_store:ServiceRequestTable[] results = check from var serviceRequest in serviceRequestStream
                where serviceRequest.SERVICEREQUESTTABLE_ID == resourceId
                select serviceRequest;
            
            return results.length() > 0;
        }
        "Condition" => {
            stream<db_store:ConditionTable, persist:Error?> conditionStream = persistClient->/conditiontables(targetType = db_store:ConditionTable);
            
            db_store:ConditionTable[] results = check from var condition in conditionStream
                where condition.CONDITIONTABLE_ID == resourceId
                select condition;
            
            return results.length() > 0;
        }
        "Observation" => {
            stream<db_store:ObservationTable, persist:Error?> observationStream = persistClient->/observationtables(targetType = db_store:ObservationTable);
            
            db_store:ObservationTable[] results = check from var observation in observationStream
                where observation.OBSERVATIONTABLE_ID == resourceId
                select observation;
            
            return results.length() > 0;
        }
        "Procedure" => {
            stream<db_store:ProcedureTable, persist:Error?> procedureStream = persistClient->/proceduretables(targetType = db_store:ProcedureTable);
            
            db_store:ProcedureTable[] results = check from var procedure in procedureStream
                where procedure.PROCEDURETABLE_ID == resourceId
                select procedure;
            
            return results.length() > 0;
        }
        "ImmunizationRecommendation" => {
            stream<db_store:ImmunizationRecommendationTable, persist:Error?> immunizationRecommendationStream = persistClient->/immunizationrecommendationtables(targetType = db_store:ImmunizationRecommendationTable);
            
            db_store:ImmunizationRecommendationTable[] results = check from var immunizationRecommendation in immunizationRecommendationStream
                where immunizationRecommendation.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId
                select immunizationRecommendation;
            
            return results.length() > 0;
        }
        "Slot" => {
            stream<db_store:SlotTable, persist:Error?> slotStream = persistClient->/slottables(targetType = db_store:SlotTable);
            
            db_store:SlotTable[] results = check from var slot in slotStream
                where slot.SLOTTABLE_ID == resourceId
                select slot;
            
            return results.length() > 0;
        }
        "Account" => {
            stream<db_store:AccountTable, persist:Error?> accountStream = persistClient->/accounttables(targetType = db_store:AccountTable);
            
            db_store:AccountTable[] results = check from var account in accountStream
                where account.ACCOUNTTABLE_ID == resourceId
                select account;
            
            return results.length() > 0;
        }
        "Invoice" => {
            stream<db_store:InvoiceTable, persist:Error?> invoiceStream = persistClient->/invoicetables(targetType = db_store:InvoiceTable);
            
            db_store:InvoiceTable[] results = check from var invoice in invoiceStream
                where invoice.INVOICETABLE_ID == resourceId
                select invoice;
            
            return results.length() > 0;
        }
        "DocumentManifest" => {
            stream<db_store:DocumentManifestTable, persist:Error?> documentManifestStream = persistClient->/documentmanifesttables(targetType = db_store:DocumentManifestTable);
            
            db_store:DocumentManifestTable[] results = check from var documentManifest in documentManifestStream
                where documentManifest.DOCUMENTMANIFESTTABLE_ID == resourceId
                select documentManifest;
            
            return results.length() > 0;
        }
        "Consent" => {
            stream<db_store:ConsentTable, persist:Error?> consentStream = persistClient->/consenttables(targetType = db_store:ConsentTable);
            
            db_store:ConsentTable[] results = check from var consent in consentStream
                where consent.CONSENTTABLE_ID == resourceId
                select consent;
            
            return results.length() > 0;
        }
        "Goal" => {
            stream<db_store:GoalTable, persist:Error?> goalStream = persistClient->/goaltables(targetType = db_store:GoalTable);
            
            db_store:GoalTable[] results = check from var goal in goalStream
                where goal.GOALTABLE_ID == resourceId
                select goal;
            
            return results.length() > 0;
        }
        "MedicinalProductPackaged" => {
            stream<db_store:MedicinalProductPackagedTable, persist:Error?> medicinalProductPackagedStream = persistClient->/medicinalproductpackagedtables(targetType = db_store:MedicinalProductPackagedTable);
            
            db_store:MedicinalProductPackagedTable[] results = check from var medicinalProductPackaged in medicinalProductPackagedStream
                where medicinalProductPackaged.MEDICINALPRODUCTPACKAGEDTABLE_ID == resourceId
                select medicinalProductPackaged;
            
            return results.length() > 0;
        }
        "MessageDefinition" => {
            stream<db_store:MessageDefinitionTable, persist:Error?> messageDefinitionStream = persistClient->/messagedefinitiontables(targetType = db_store:MessageDefinitionTable);
            
            db_store:MessageDefinitionTable[] results = check from var messageDefinition in messageDefinitionStream
                where messageDefinition.MESSAGEDEFINITIONTABLE_ID == resourceId
                select messageDefinition;
            
            return results.length() > 0;
        }
        "Endpoint" => {
            stream<db_store:EndpointTable, persist:Error?> endpointStream = persistClient->/endpointtables(targetType = db_store:EndpointTable);
            
            db_store:EndpointTable[] results = check from var endpoint in endpointStream
                where endpoint.ENDPOINTTABLE_ID == resourceId
                select endpoint;
            
            return results.length() > 0;
        }
        "EnrollmentRequest" => {
            stream<db_store:EnrollmentRequestTable, persist:Error?> enrollmentRequestStream = persistClient->/enrollmentrequesttables(targetType = db_store:EnrollmentRequestTable);
            
            db_store:EnrollmentRequestTable[] results = check from var enrollmentRequest in enrollmentRequestStream
                where enrollmentRequest.ENROLLMENTREQUESTTABLE_ID == resourceId
                select enrollmentRequest;
            
            return results.length() > 0;
        }
        "EventDefinition" => {
            stream<db_store:EventDefinitionTable, persist:Error?> eventDefinitionStream = persistClient->/eventdefinitiontables(targetType = db_store:EventDefinitionTable);
            
            db_store:EventDefinitionTable[] results = check from var eventDefinition in eventDefinitionStream
                where eventDefinition.EVENTDEFINITIONTABLE_ID == resourceId
                select eventDefinition;
            
            return results.length() > 0;
        }
        _ => {
            // For unsupported resource types, log warning and allow (don't break existing functionality)
            log:printWarn(string `Reference validation not implemented for resource type: ${resourceType}`);
            return true;
        }
    }
}

// Validate all references before saving
public isolated function validateReferences(db_store:Client persistClient, json[] references) returns error? {
    if references.length() == 0 {
        log:printInfo("No references to validate");
        return;
    }

    log:printInfo(string `Validating ${references.length()} reference(s)`);

    foreach json referenceEntry in references {
        if referenceEntry is map<json> {
            foreach var [_, paramValue] in referenceEntry.entries() {
                // Handle array of references
                if paramValue is json[] {
                    foreach json ref in paramValue {
                        error? result = validateSingleReference(persistClient, ref);
                        if result is error {
                            return result;
                        }
                    }
                } else {
                    // Single reference
                    error? result = validateSingleReference(persistClient, paramValue);
                    if result is error {
                        return result;
                    }
                }
            }
        }
    }
    
    log:printInfo("All references validated successfully");
}

// Validate a single reference object
isolated function validateSingleReference(db_store:Client persistClient, json fhirReference) returns error? {
    if !(fhirReference is map<json>) {
        return;
    }

    map<json> refMap = <map<json>>fhirReference;
    json refString = refMap["reference"];
    
    if !(refString is string) || refString == "" {
        return;
    }

    // Parse reference string
    string[] refParts = regex:split(<string>refString, "/");
    if refParts.length() != 2 {
        return error(string `Invalid reference format: ${refString}. Expected format: ResourceType/id`);
    }

    string targetResourceType = refParts[0];
    string targetResourceId = refParts[1];

    // Check if resource exists
    boolean exists = check validateReferenceExists(persistClient, targetResourceType, targetResourceId);
    if !exists {
        return error(string `Referenced resource does not exist: ${targetResourceType}/${targetResourceId}`);
    }
    
    log:printInfo(string `✓ Valid reference: ${targetResourceType}/${targetResourceId}`);
}

// Delete main resource
public isolated function deleteResource(db_store:Client persistClient, string resourceType, string resourceId) returns error? {
    match resourceType {
        "Account" => { _ = check persistClient->/accounttables/[resourceId].delete(); }
        "Appointment" => { _ = check persistClient->/appointmenttables/[resourceId].delete(); }
        "Patient" => { _ = check persistClient->/patienttables/[resourceId].delete(); }
        "Practitioner" => { _ = check persistClient->/practitionertables/[resourceId].delete(); }
        "Device" => { _ = check persistClient->/devicetables/[resourceId].delete(); }
        "HealthcareService" => { _ = check persistClient->/healthcareservicetables/[resourceId].delete(); }
        "PractitionerRole" => { _ = check persistClient->/practitionerroletables/[resourceId].delete(); }
        "RelatedPerson" => { _ = check persistClient->/relatedpersontables/[resourceId].delete(); }
        "Location" => { _ = check persistClient->/locationtables/[resourceId].delete(); }
        "ServiceRequest" => { _ = check persistClient->/servicerequesttables/[resourceId].delete(); }
        "Condition" => { _ = check persistClient->/conditiontables/[resourceId].delete(); }
        "Observation" => { _ = check persistClient->/observationtables/[resourceId].delete(); }
        "Procedure" => { _ = check persistClient->/proceduretables/[resourceId].delete(); }
        "ImmunizationRecommendation" => { _ = check persistClient->/immunizationrecommendationtables/[resourceId].delete(); }
        "Slot" => { _ = check persistClient->/slottables/[resourceId].delete(); }
        "Invoice" => { _ = check persistClient->/invoicetables/[resourceId].delete(); }
        "DocumentManifest" => { _ = check persistClient->/documentmanifesttables/[resourceId].delete(); }
        "Consent" => { _ = check persistClient->/consenttables/[resourceId].delete(); }
        "Goal" => { _ = check persistClient->/goaltables/[resourceId].delete(); }
        "MedicinalProductPackaged" => { _ = check persistClient->/medicinalproductpackagedtables/[resourceId].delete(); }
        "MessageDefinition" => { _ = check persistClient->/messagedefinitiontables/[resourceId].delete(); }
        "Endpoint" => { _ = check persistClient->/endpointtables/[resourceId].delete(); }
        "EnrollmentRequest" => { _ = check persistClient->/enrollmentrequesttables/[resourceId].delete(); }
        "EventDefinition" => { _ = check persistClient->/eventdefinitiontables/[resourceId].delete(); }
        _ => { return error(string `Unsupported resource type for deletion: ${resourceType}`); }
    }
}

// Delete references
public isolated function deleteReferences(db_store:Client persistClient, int[] referenceIds, TransactionContext 'transaction) returns error? {

    foreach int refId in referenceIds {
        _ = check persistClient->/references/[refId].delete();
        'transaction.deletedReferenceIds.push(refId);
    }
}

public isolated function saveReferences(db_store:Client persistClient, json[] references, string sourceResType, string sourceResId, TransactionContext 'transaction) returns error? {
    if references.length() == 0 {
        log:printInfo("No references to save");
        return;
    }

    log:printInfo(string `Saving ${references.length()} reference(s) for ${sourceResType}/${sourceResId}`);

    foreach json referenceEntry in references {

        // referenceEntry is a map with param name as key
        if referenceEntry is map<json> {
            foreach var [paramName, paramValue] in referenceEntry.entries() {

                // Handle array of references
                if paramValue is json[] {
                    foreach json singleRef in paramValue {
                        error? result = saveSingleReference(persistClient, sourceResType, sourceResId, paramName, singleRef, 'transaction);
                        if result is error {
                            return result;
                        }
                    }
                }
                // Handle single reference
                else {
                    error? result = saveSingleReference(persistClient, sourceResType, sourceResId, paramName, paramValue, 'transaction);
                    if result is error {
                        return result;
                    }
                }
            }
        }
    }

    log:printInfo(string `Successfully saved all references for ${sourceResType}/${sourceResId}`);
}

public isolated function saveSingleReference(db_store:Client persistClient, string sourceResType, string sourceResId, string sourceExpression, json fhirReference, TransactionContext 'transaction) returns error? {

    // Extract reference details
    if !(fhirReference is map<json>) {
        log:printDebug(string `Skipping non-object reference: ${fhirReference.toString()}`);
        return;
    }

    map<json> refMap = <map<json>>fhirReference;

    // Get reference string (e.g., "Patient/123")
    json refString = refMap["reference"];
    if !(refString is string) || refString == "" {
        log:printDebug("Empty or invalid reference, skipping");
        return;
    }

    // Parse reference string
    string[] refParts = regex:split(<string>refString, "/");
    if refParts.length() != 2 {
        return error(string `Invalid reference format: ${refString}. Expected format: ResourceType/id`);
    }

    string targetResourceType = refParts[0];
    string targetResourceId = refParts[1];

    // Get display value (optional)
    json displayJson = refMap["display"];
    string displayValue = displayJson is string ? displayJson : "";

    // Create reference insert record
    db_store:REFERENCESInsert referencesInsert = {
        SOURCE_RESOURCE_TYPE: sourceResType,
        SOURCE_RESOURCE_ID: sourceResId,
        SOURCE_EXPRESSION: sourceExpression,
        TARGET_RESOURCE_TYPE: targetResourceType,
        TARGET_RESOURCE_ID: targetResourceId,
        DISPLAY_VALUE: displayValue,
        CREATED_AT: time:utcToCivil(time:utcNow()),
        UPDATED_AT: time:utcToCivil(time:utcNow()),
        LAST_UPDATED: time:utcToCivil(time:utcNow())
    };

    // Save to database
    int[] recordIds = check persistClient->/references.post([referencesInsert]);
    int savedRefId = recordIds[0];

    // Track in transaction context for rollback
    'transaction.savedReferenceIds.push(savedRefId);

    log:printInfo(string `Saved reference [${savedRefId}]: ${sourceResType}/${sourceResId} --(${sourceExpression})--> ${targetResourceType}/${targetResourceId}`);
}
