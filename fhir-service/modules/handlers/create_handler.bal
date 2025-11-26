import ballerina_fhir_server.db_store;
import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;
import ballerina_fhir_server.utils as mapperUtils;

import ballerina/log;
import ballerinax/java.jdbc;

public class CreateHandler {
    private mappers:CreateMapper? createMapper = ();
    private utils:TransactionHandler transactionHandler;
    private final jdbc:Client? jdbcClient;

    public isolated function init(jdbc:Client? jdbcClient = ()) {
        self.jdbcClient = jdbcClient;
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Main function to save resource
    public isolated function saveResourceWithTransaction(db_store:Client persistClient, string resourceType, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();

        do {
            // Create mapper with jdbcClient if available
            jdbc:Client? jdbcConn = self.jdbcClient;
            mappers:CreateMapper mapper = jdbcConn is jdbc:Client 
                ? new mappers:CreateMapper(jdbcConn) 
                : new mappers:CreateMapper();
            
            // Map resource to insert model
            log:printInfo(string `Mapping ${resourceType} to insert model`);
            record {|anydata...;|}|error? insertModel = mapper.mapToInsertModel(
                persistClient, resourceType, resourceJson
            );

            if insertModel is () {
                return error(string `Failed to create insert model for ${resourceType}`);
            }

            if insertModel is error {
                return insertModel;
            }

            // Get extracted references after mapping
            json[] references = mapper.getReferences();

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

    // Generic insert method - uses Ballerina persist with match statement
    private isolated function saveMainResource(db_store:Client persistClient, string resourceType, record {|anydata...;|} insertModel) returns string|error {
        
        // Get primary key column and extract resource ID
        string primaryKeyColumn = mapperUtils:getPrimaryKeyColumn(resourceType);
        anydata resourceIdValue = insertModel[primaryKeyColumn];
        if !(resourceIdValue is string) {
            return error(string `Primary key value must be a string for ${resourceType}`);
        }
        string resourceId = <string>resourceIdValue;

        // Use persist client with match statement for each resource type
        match resourceType {
            "Appointment" => {
                db_store:AppointmentTableInsert appointmentInsert = check insertModel.cloneWithType();
                _ = check persistClient->/appointmenttables.post([appointmentInsert]);
            }
            "Patient" => {
                db_store:PatientTableInsert patientInsert = check insertModel.cloneWithType();
                _ = check persistClient->/patienttables.post([patientInsert]);
            }
            "Practitioner" => {
                db_store:PractitionerTableInsert practitionerInsert = check insertModel.cloneWithType();
                _ = check persistClient->/practitionertables.post([practitionerInsert]);
            }
            "Organization" => {
                db_store:OrganizationTableInsert organizationInsert = check insertModel.cloneWithType();
                _ = check persistClient->/organizationtables.post([organizationInsert]);
            }
            "Observation" => {
                db_store:ObservationTableInsert observationInsert = check insertModel.cloneWithType();
                _ = check persistClient->/observationtables.post([observationInsert]);
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }

        log:printInfo(string `Successfully inserted ${resourceType} with ID: ${resourceId}`);
        return resourceId;
    }
}
