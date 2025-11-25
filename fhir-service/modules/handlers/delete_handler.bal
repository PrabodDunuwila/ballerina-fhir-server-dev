import ballerina_fhir_server.db_store;
import ballerina_fhir_server.utils;

import ballerina/log;

public class DeleteHandler {
    private utils:TransactionHandler transactionHandler;
    private HistoryHandler historyHandler;

    public isolated function init() {
        self.transactionHandler = new utils:TransactionHandler();
        self.historyHandler = new HistoryHandler();
    }

    // Main function to delete resource with full transaction support
    public isolated function deleteResourceWithTransaction(db_store:Client persistClient, string resourceType, string resourceId) returns boolean|error {

        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Check if resource exists
            log:printInfo(string `Checking if ${resourceType}/${resourceId} exists`);
            boolean exists = check self.checkResourceExists(persistClient, resourceType, resourceId);

            if !exists {
                return error(string `${resourceType}/${resourceId} not found`);
            }

            // Backup before delete
            log:printInfo(string `Backing up ${resourceType}/${resourceId} before deletion`);
            record {|anydata...;|}? backup = check self.backupResource(persistClient, resourceType, resourceId);
            'transaction.backupResource = backup;
            'transaction.backupReferences = check self.backupReferences(persistClient, resourceType, resourceId);

            // Save to history before deletion
            if backup is record {|anydata...;|} {
                log:printInfo(string `Saving current version of ${resourceType}/${resourceId} to history before deletion`);
                error? historyResult = self.historyHandler.saveToHistory(persistClient, resourceType, resourceId, backup, "DELETE");
                if historyResult is error {
                    log:printError(string `Failed to save history: ${historyResult.message()}`);
                    error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(
                        persistClient, 'transaction, resourceType
                    );
                    if (rollbackResult is error) {
                        log:printError(rollbackResult.toString());
                    }
                    return historyResult;
                }
            }

            // Find references
            log:printInfo(string `Finding references for ${resourceType}/${resourceId}`);
            int[] referenceIds = check self.findSourceReferences(persistClient, resourceType, resourceId);

            // Delete references
            error? refResult = self.deleteReferences(persistClient, referenceIds, 'transaction);

            if refResult is error {
                error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Delete main resource
            log:printInfo(string `Deleting main ${resourceType}/${resourceId} record`);
            error? deleteResult = utils:deleteResource(persistClient, resourceType, resourceId);

            if deleteResult is error {
                error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteResult;
            }

            // Commit Transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully deleted ${resourceType}/${resourceId}`);
            return true;

        } on fail error e {
            error? rollbackResult = self.transactionHandler.rollbackDeleteTransaction(persistClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(rollbackResult.toString());
            }
            return e;
        }
    }

    // Check if resource exists
    private isolated function checkResourceExists(db_store:Client persistClient, string resourceType, string resourceId) returns boolean|error {

        match resourceType {
            "Account" => {
                stream<db_store:AccountTable, error?> accountStream = persistClient->/accounttables(targetType = db_store:AccountTable);
                db_store:AccountTable[] accounts = check from var account in accountStream where account.ACCOUNTTABLE_ID == resourceId select account;
                return accounts.length() > 0;
            }
            "Appointment" => {
                stream<db_store:AppointmentTable, error?> appointmentStream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);
                db_store:AppointmentTable[] appointments = check from var appointment in appointmentStream where appointment.APPOINTMENTTABLE_ID == resourceId select appointment;
                return appointments.length() > 0;
            }
            "Practitioner" => {
                stream<db_store:PractitionerTable, error?> practitionerStream = persistClient->/practitionertables(targetType = db_store:PractitionerTable);
                db_store:PractitionerTable[] results = check from var item in practitionerStream where item.PRACTITIONERTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Device" => {
                stream<db_store:DeviceTable, error?> deviceStream = persistClient->/devicetables(targetType = db_store:DeviceTable);
                db_store:DeviceTable[] results = check from var item in deviceStream where item.DEVICETABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "HealthcareService" => {
                stream<db_store:HealthcareServiceTable, error?> healthcareServiceStream = persistClient->/healthcareservicetables(targetType = db_store:HealthcareServiceTable);
                db_store:HealthcareServiceTable[] results = check from var item in healthcareServiceStream where item.HEALTHCARESERVICETABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "PractitionerRole" => {
                stream<db_store:PractitionerRoleTable, error?> practitionerRoleStream = persistClient->/practitionerroletables(targetType = db_store:PractitionerRoleTable);
                db_store:PractitionerRoleTable[] results = check from var item in practitionerRoleStream where item.PRACTITIONERROLETABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "RelatedPerson" => {
                stream<db_store:RelatedPersonTable, error?> relatedPersonStream = persistClient->/relatedpersontables(targetType = db_store:RelatedPersonTable);
                db_store:RelatedPersonTable[] results = check from var item in relatedPersonStream where item.RELATEDPERSONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Location" => {
                stream<db_store:LocationTable, error?> locationStream = persistClient->/locationtables(targetType = db_store:LocationTable);
                db_store:LocationTable[] results = check from var item in locationStream where item.LOCATIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "ServiceRequest" => {
                stream<db_store:ServiceRequestTable, error?> serviceRequestStream = persistClient->/servicerequesttables(targetType = db_store:ServiceRequestTable);
                db_store:ServiceRequestTable[] results = check from var item in serviceRequestStream where item.SERVICEREQUESTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Condition" => {
                stream<db_store:ConditionTable, error?> conditionStream = persistClient->/conditiontables(targetType = db_store:ConditionTable);
                db_store:ConditionTable[] results = check from var item in conditionStream where item.CONDITIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Observation" => {
                stream<db_store:ObservationTable, error?> observationStream = persistClient->/observationtables(targetType = db_store:ObservationTable);
                db_store:ObservationTable[] results = check from var item in observationStream where item.OBSERVATIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Patient" => {
                stream<db_store:PatientTable, error?> patientStream = persistClient->/patienttables(targetType = db_store:PatientTable);
                db_store:PatientTable[] results = check from var item in patientStream where item.PATIENTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Procedure" => {
                stream<db_store:ProcedureTable, error?> procedureStream = persistClient->/proceduretables(targetType = db_store:ProcedureTable);
                db_store:ProcedureTable[] results = check from var item in procedureStream where item.PROCEDURETABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "ImmunizationRecommendation" => {
                stream<db_store:ImmunizationRecommendationTable, error?> immunizationStream = persistClient->/immunizationrecommendationtables(targetType = db_store:ImmunizationRecommendationTable);
                db_store:ImmunizationRecommendationTable[] results = check from var item in immunizationStream where item.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Invoice" => {
                stream<db_store:InvoiceTable, error?> invoiceStream = persistClient->/invoicetables(targetType = db_store:InvoiceTable);
                db_store:InvoiceTable[] results = check from var item in invoiceStream where item.INVOICETABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "EventDefinition" => {
                stream<db_store:EventDefinitionTable, error?> eventDefinitionStream = persistClient->/eventdefinitiontables(targetType = db_store:EventDefinitionTable);
                db_store:EventDefinitionTable[] results = check from var item in eventDefinitionStream where item.EVENTDEFINITIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "DocumentManifest" => {
                stream<db_store:DocumentManifestTable, error?> documentManifestStream = persistClient->/documentmanifesttables(targetType = db_store:DocumentManifestTable);
                db_store:DocumentManifestTable[] results = check from var item in documentManifestStream where item.DOCUMENTMANIFESTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "MessageDefinition" => {
                stream<db_store:MessageDefinitionTable, error?> messageDefinitionStream = persistClient->/messagedefinitiontables(targetType = db_store:MessageDefinitionTable);
                db_store:MessageDefinitionTable[] results = check from var item in messageDefinitionStream where item.MESSAGEDEFINITIONTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Goal" => {
                stream<db_store:GoalTable, error?> goalStream = persistClient->/goaltables(targetType = db_store:GoalTable);
                db_store:GoalTable[] results = check from var item in goalStream where item.GOALTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "MedicinalProductPackaged" => {
                stream<db_store:MedicinalProductPackagedTable, error?> medicinalProductPackagedStream = persistClient->/medicinalproductpackagedtables(targetType = db_store:MedicinalProductPackagedTable);
                db_store:MedicinalProductPackagedTable[] results = check from var item in medicinalProductPackagedStream where item.MEDICINALPRODUCTPACKAGEDTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Endpoint" => {
                stream<db_store:EndpointTable, error?> endpointStream = persistClient->/endpointtables(targetType = db_store:EndpointTable);
                db_store:EndpointTable[] results = check from var item in endpointStream where item.ENDPOINTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "EnrollmentRequest" => {
                stream<db_store:EnrollmentRequestTable, error?> enrollmentRequestStream = persistClient->/enrollmentrequesttables(targetType = db_store:EnrollmentRequestTable);
                db_store:EnrollmentRequestTable[] results = check from var item in enrollmentRequestStream where item.ENROLLMENTREQUESTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Consent" => {
                stream<db_store:ConsentTable, error?> consentStream = persistClient->/consenttables(targetType = db_store:ConsentTable);
                db_store:ConsentTable[] results = check from var item in consentStream where item.CONSENTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            "Slot" => {
                stream<db_store:SlotTable, error?> slotStream = persistClient->/slottables(targetType = db_store:SlotTable);
                db_store:SlotTable[] results = check from var item in slotStream where item.SLOTTABLE_ID == resourceId select item;
                return results.length() > 0;
            }
            _ => {
                return error(string `Resource type ${resourceType} is not supported for delete operations`);
            }
        }
    }

    // Find all references where this resource is the SOURCE
    private isolated function findSourceReferences(db_store:Client persistClient, string resourceType, string resourceId) returns int[]|error {

        stream<db_store:REFERENCES, error?> referenceStream = persistClient->/references(targetType = db_store:REFERENCES);

        db_store:REFERENCES[] references = check from var ref in referenceStream
            where ref.SOURCE_RESOURCE_TYPE == resourceType && ref.SOURCE_RESOURCE_ID == resourceId
            select ref;

        // Extract reference IDs
        int[] referenceIds = [];
        foreach var ref in references {
            referenceIds.push(ref.ID);
        }

        return referenceIds;
    }

    // Delete all references and track for rollback
    private isolated function deleteReferences(db_store:Client persistClient, int[] referenceIds, utils:TransactionContext 'transaction) returns error? {

        if referenceIds.length() == 0 {
            log:printDebug("No references to delete");
            return;
        }

        foreach int refId in referenceIds {
            _ = check persistClient->/references/[refId].delete();

            // Track deleted reference for potential rollback
            'transaction.deletedReferenceIds.push(refId);
            log:printInfo(string `Deleted reference: ${refId}`);
        }
    }

    // Add backup methods to DeleteHandler
    private isolated function backupResource(db_store:Client persistClient, string resourceType, string resourceId) returns record {|anydata...;|}|error {
        match resourceType {
            "Account" => {
                stream<db_store:AccountTable, error?> 'stream = persistClient->/accounttables(targetType = db_store:AccountTable);
                db_store:AccountTable[] results = check from var item in 'stream where item.ACCOUNTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Appointment" => {
                stream<db_store:AppointmentTable, error?> 'stream = persistClient->/appointmenttables(targetType = db_store:AppointmentTable);
                db_store:AppointmentTable[] results = check from var item in 'stream where item.APPOINTMENTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Practitioner" => {
                stream<db_store:PractitionerTable, error?> 'stream = persistClient->/practitionertables(targetType = db_store:PractitionerTable);
                db_store:PractitionerTable[] results = check from var item in 'stream where item.PRACTITIONERTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Device" => {
                stream<db_store:DeviceTable, error?> 'stream = persistClient->/devicetables(targetType = db_store:DeviceTable);
                db_store:DeviceTable[] results = check from var item in 'stream where item.DEVICETABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "HealthcareService" => {
                stream<db_store:HealthcareServiceTable, error?> 'stream = persistClient->/healthcareservicetables(targetType = db_store:HealthcareServiceTable);
                db_store:HealthcareServiceTable[] results = check from var item in 'stream where item.HEALTHCARESERVICETABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "PractitionerRole" => {
                stream<db_store:PractitionerRoleTable, error?> 'stream = persistClient->/practitionerroletables(targetType = db_store:PractitionerRoleTable);
                db_store:PractitionerRoleTable[] results = check from var item in 'stream where item.PRACTITIONERROLETABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "RelatedPerson" => {
                stream<db_store:RelatedPersonTable, error?> 'stream = persistClient->/relatedpersontables(targetType = db_store:RelatedPersonTable);
                db_store:RelatedPersonTable[] results = check from var item in 'stream where item.RELATEDPERSONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Location" => {
                stream<db_store:LocationTable, error?> 'stream = persistClient->/locationtables(targetType = db_store:LocationTable);
                db_store:LocationTable[] results = check from var item in 'stream where item.LOCATIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "ServiceRequest" => {
                stream<db_store:ServiceRequestTable, error?> 'stream = persistClient->/servicerequesttables(targetType = db_store:ServiceRequestTable);
                db_store:ServiceRequestTable[] results = check from var item in 'stream where item.SERVICEREQUESTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Condition" => {
                stream<db_store:ConditionTable, error?> 'stream = persistClient->/conditiontables(targetType = db_store:ConditionTable);
                db_store:ConditionTable[] results = check from var item in 'stream where item.CONDITIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Observation" => {
                stream<db_store:ObservationTable, error?> 'stream = persistClient->/observationtables(targetType = db_store:ObservationTable);
                db_store:ObservationTable[] results = check from var item in 'stream where item.OBSERVATIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Patient" => {
                stream<db_store:PatientTable, error?> 'stream = persistClient->/patienttables(targetType = db_store:PatientTable);
                db_store:PatientTable[] results = check from var item in 'stream where item.PATIENTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Procedure" => {
                stream<db_store:ProcedureTable, error?> 'stream = persistClient->/proceduretables(targetType = db_store:ProcedureTable);
                db_store:ProcedureTable[] results = check from var item in 'stream where item.PROCEDURETABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "ImmunizationRecommendation" => {
                stream<db_store:ImmunizationRecommendationTable, error?> 'stream = persistClient->/immunizationrecommendationtables(targetType = db_store:ImmunizationRecommendationTable);
                db_store:ImmunizationRecommendationTable[] results = check from var item in 'stream where item.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Invoice" => {
                stream<db_store:InvoiceTable, error?> 'stream = persistClient->/invoicetables(targetType = db_store:InvoiceTable);
                db_store:InvoiceTable[] results = check from var item in 'stream where item.INVOICETABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "EventDefinition" => {
                stream<db_store:EventDefinitionTable, error?> 'stream = persistClient->/eventdefinitiontables(targetType = db_store:EventDefinitionTable);
                db_store:EventDefinitionTable[] results = check from var item in 'stream where item.EVENTDEFINITIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "DocumentManifest" => {
                stream<db_store:DocumentManifestTable, error?> 'stream = persistClient->/documentmanifesttables(targetType = db_store:DocumentManifestTable);
                db_store:DocumentManifestTable[] results = check from var item in 'stream where item.DOCUMENTMANIFESTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "MessageDefinition" => {
                stream<db_store:MessageDefinitionTable, error?> 'stream = persistClient->/messagedefinitiontables(targetType = db_store:MessageDefinitionTable);
                db_store:MessageDefinitionTable[] results = check from var item in 'stream where item.MESSAGEDEFINITIONTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Goal" => {
                stream<db_store:GoalTable, error?> 'stream = persistClient->/goaltables(targetType = db_store:GoalTable);
                db_store:GoalTable[] results = check from var item in 'stream where item.GOALTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "MedicinalProductPackaged" => {
                stream<db_store:MedicinalProductPackagedTable, error?> 'stream = persistClient->/medicinalproductpackagedtables(targetType = db_store:MedicinalProductPackagedTable);
                db_store:MedicinalProductPackagedTable[] results = check from var item in 'stream where item.MEDICINALPRODUCTPACKAGEDTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Endpoint" => {
                stream<db_store:EndpointTable, error?> 'stream = persistClient->/endpointtables(targetType = db_store:EndpointTable);
                db_store:EndpointTable[] results = check from var item in 'stream where item.ENDPOINTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "EnrollmentRequest" => {
                stream<db_store:EnrollmentRequestTable, error?> 'stream = persistClient->/enrollmentrequesttables(targetType = db_store:EnrollmentRequestTable);
                db_store:EnrollmentRequestTable[] results = check from var item in 'stream where item.ENROLLMENTREQUESTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Consent" => {
                stream<db_store:ConsentTable, error?> 'stream = persistClient->/consenttables(targetType = db_store:ConsentTable);
                db_store:ConsentTable[] results = check from var item in 'stream where item.CONSENTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            "Slot" => {
                stream<db_store:SlotTable, error?> 'stream = persistClient->/slottables(targetType = db_store:SlotTable);
                db_store:SlotTable[] results = check from var item in 'stream where item.SLOTTABLE_ID == resourceId select item;
                return results.length() > 0 ? results[0] : error("Resource not found");
            }
            _ => {
                return error(string `Resource type ${resourceType} is not supported for backup operations`);
            }
        }
    }

    private isolated function backupReferences(db_store:Client persistClient, string resourceType, string resourceId) returns db_store:REFERENCES[]|error {

        stream<db_store:REFERENCES, error?> 'stream = persistClient->/references(targetType = db_store:REFERENCES);

        db_store:REFERENCES[] references = check from var ref in 'stream
            where ref.SOURCE_RESOURCE_TYPE == resourceType && ref.SOURCE_RESOURCE_ID == resourceId
            select ref;

        return references;
    }
}
