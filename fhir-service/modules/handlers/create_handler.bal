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
            "Account" => {
                db_store:AccountTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/accounttables.post([insert]);
                return recordIds[0];
            }
            "Appointment" => {
                db_store:AppointmentTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/appointmenttables.post([insert]);
                return recordIds[0];
            }
            "Condition" => {
                db_store:ConditionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/conditiontables.post([insert]);
                return recordIds[0];
            }
            "Consent" => {
                db_store:ConsentTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/consenttables.post([insert]);
                return recordIds[0];
            }
            "Device" => {
                db_store:DeviceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicetables.post([insert]);
                return recordIds[0];
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/documentmanifesttables.post([insert]);
                return recordIds[0];
            }
            "Endpoint" => {
                db_store:EndpointTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/endpointtables.post([insert]);
                return recordIds[0];
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/enrollmentrequesttables.post([insert]);
                return recordIds[0];
            }
            "EventDefinition" => {
                db_store:EventDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/eventdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Goal" => {
                db_store:GoalTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/goaltables.post([insert]);
                return recordIds[0];
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/healthcareservicetables.post([insert]);
                return recordIds[0];
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/immunizationrecommendationtables.post([insert]);
                return recordIds[0];
            }
            "Invoice" => {
                db_store:InvoiceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/invoicetables.post([insert]);
                return recordIds[0];
            }
            "Location" => {
                db_store:LocationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/locationtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductpackagedtables.post([insert]);
                return recordIds[0];
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/messagedefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Observation" => {
                db_store:ObservationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/observationtables.post([insert]);
                return recordIds[0];
            }
            "Patient" => {
                db_store:PatientTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/patienttables.post([insert]);
                return recordIds[0];
            }
            "Practitioner" => {
                db_store:PractitionerTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/practitionertables.post([insert]);
                return recordIds[0];
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/practitionerroletables.post([insert]);
                return recordIds[0];
            }
            "Procedure" => {
                db_store:ProcedureTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/proceduretables.post([insert]);
                return recordIds[0];
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/relatedpersontables.post([insert]);
                return recordIds[0];
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/servicerequesttables.post([insert]);
                return recordIds[0];
            }
            "Slot" => {
                db_store:SlotTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/slottables.post([insert]);
                return recordIds[0];
            }
            _ => {
                return error(string `Unsupported resource type for saving: ${resourceType}`);
            }
        }
    }
}
