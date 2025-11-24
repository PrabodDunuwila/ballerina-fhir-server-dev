import ballerina_fhir_server.db_store;
import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;

import ballerina/log;

public class CreateHandler {
    private mappers:CreateMapper createMapper = new mappers:CreateMapper();
    private utils:TransactionHandler transactionHandler;

    public isolated function init() {
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Main function to save resource
    public isolated function saveResourceWithTransaction(db_store:Client persistClient, string resourceType, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();

        do {
            // Map resource to insert model
            log:printInfo(string `Mapping ${resourceType} to insert model`);
            record {|anydata...;|}|error? insertModel = self.createMapper.mapToInsertModel(
                persistClient, resourceType, resourceJson
            );

            if insertModel is () {
                return error(string `Failed to create insert model for ${resourceType}`);
            }

            if insertModel is error {
                return insertModel;
            }

            // Get extracted references after mapping
            json[] references = self.createMapper.getReferences();

            // Validate all references BEFORE saving main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}`);
            error? validationResult = utils:validateReferences(persistClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                return validationResult;
            }

            // Save main resource
            log:printInfo(string `Saving main ${resourceType} record`);
            string resourceId = check self.saveMainResource(persistClient, resourceType, insertModel);
            'transaction.mainResourceId = resourceId;

            log:printInfo(string `Saved ${resourceType} with ID: ${resourceId}`);

            // Save all references
            log:printInfo(string `Saving references for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(persistClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                // Rollback on reference save failure
                log:printError(string `Reference save failed: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackCreateTransaction(persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(`Rollback Status: ${rollbackResult.toString()}`);
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully saved ${resourceType}/${resourceId} with all references`);
            return resourceId;

        } on fail error e {
            // Rollback on any failure
            log:printError(string `Transaction failed for ${resourceType}: ${e.message()}`);
            error? rollbackResult = check self.transactionHandler.rollbackCreateTransaction(persistClient, 'transaction, resourceType);
            if (rollbackResult is error) {
                log:printError(`Rollback Status: ${rollbackResult.toString()}`);
            }
            return e;
        }
    }

    private isolated function saveMainResource(db_store:Client persistClient, string resourceType, record {|anydata...;|} insertModel) returns string|error {

        match resourceType {
            "Appointment" => {
                db_store:AppointmentTableInsert appointmentInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/appointmenttables.post([appointmentInsert]);
                return recordIds[0];
            }
            "Patient" => {
                db_store:PatientTableInsert patientInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/patienttables.post([patientInsert]);
                return recordIds[0];
            }
            "Practitioner" => {
                db_store:PractitionerTableInsert practitionerInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/practitionertables.post([practitionerInsert]);
                return recordIds[0];
            }
            "Device" => {
                db_store:DeviceTableInsert deviceInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicetables.post([deviceInsert]);
                return recordIds[0];
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTableInsert healthcareServiceInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/healthcareservicetables.post([healthcareServiceInsert]);
                return recordIds[0];
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTableInsert practitionerRoleInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/practitionerroletables.post([practitionerRoleInsert]);
                return recordIds[0];
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTableInsert relatedPersonInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/relatedpersontables.post([relatedPersonInsert]);
                return recordIds[0];
            }
            "Location" => {
                db_store:LocationTableInsert locationInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/locationtables.post([locationInsert]);
                return recordIds[0];
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTableInsert serviceRequestInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/servicerequesttables.post([serviceRequestInsert]);
                return recordIds[0];
            }
            "Condition" => {
                db_store:ConditionTableInsert conditionInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/conditiontables.post([conditionInsert]);
                return recordIds[0];
            }
            "Observation" => {
                db_store:ObservationTableInsert observationInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/observationtables.post([observationInsert]);
                return recordIds[0];
            }
            "Procedure" => {
                db_store:ProcedureTableInsert procedureInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/proceduretables.post([procedureInsert]);
                return recordIds[0];
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTableInsert immunizationRecommendationInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/immunizationrecommendationtables.post([immunizationRecommendationInsert]);
                return recordIds[0];
            }
            "Slot" => {
                db_store:SlotTableInsert slotInsert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/slottables.post([slotInsert]);
                return recordIds[0];
            }
            _ => {
                return error(string `Unsupported resource type for saving: ${resourceType}`);
            }
        }
    }
}
