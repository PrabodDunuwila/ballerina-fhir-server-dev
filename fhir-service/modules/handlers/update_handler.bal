import ballerina_fhir_server.db_store;
import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;

import ballerina/log;
import ballerina/persist;

public class UpdateHandler {
    private mappers:UpdateMapper updateMapper;
    private utils:TransactionHandler transactionHandler;

    public isolated function init() {
        self.updateMapper = new mappers:UpdateMapper();
        self.transactionHandler = new utils:TransactionHandler();
    }

    // Main function for PUT (full update)
    public isolated function updateResourceWithTransaction(db_store:Client persistClient, string resourceType, string resourceId, json resourceJson) returns string|error {

        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Check if resource exists
            log:printInfo(string `Checking if ${resourceType}/${resourceId} exists`);
            boolean exists = check self.checkResourceExists(persistClient, resourceType, resourceId);

            if !exists {
                return error(string `${resourceType}/${resourceId} not found`);
            }

            // Backup existing resource (for rollback)
            log:printInfo(string `Backing up existing ${resourceType}/${resourceId}`);
            record {|anydata...;|}? backup = check self.backupResource(persistClient, resourceType, resourceId);
            'transaction.backupResource = backup;

            // Delete old references (they will be recreated)
            log:printInfo(string `Deleting old references for ${resourceType}/${resourceId}`);
            int[] oldReferenceIds = check self.findSourceReferences(persistClient, resourceType, resourceId);
            error? deleteRefsResult = utils:deleteReferences(persistClient, oldReferenceIds, 'transaction);

            if deleteRefsResult is error {
                log:printError(string `Failed to delete old references: ${deleteRefsResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteRefsResult;
            }

            // Map updated resource to update model
            log:printInfo(string `Mapping updated ${resourceType} to model`);
            record {|anydata...;|}|error? updateModel = self.updateMapper.mapToUpdateModel(persistClient, resourceType, resourceJson);

            if updateModel is () || updateModel is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateModel is error ? updateModel : error("Failed to create update model");
            }

            // Get extracted references after mapping
            json[] references = self.updateMapper.getReferences();

            // Validate all references BEFORE updating main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}/${resourceId}`);
            error? validationResult = utils:validateReferences(persistClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return validationResult;
            }

            // Update main resource
            log:printInfo(string `Updating main ${resourceType}/${resourceId} record`);
            error? updateResult = self.updateMainResource(persistClient, resourceType, resourceId, updateModel);

            if updateResult is error {
                log:printError(string `Main resource update failed: ${updateResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateResult;
            }

            // Save new references
            log:printInfo(string `Saving new references for ${resourceType}/${resourceId}`);
            error? refResult = utils:saveReferences(persistClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                log:printError(string `Reference save failed: ${refResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully updated ${resourceType}/${resourceId}`);
            return resourceId;

        } on fail error e {
            log:printError(string `Update transaction failed for ${resourceType}/${resourceId}: ${e.message()}`);
            error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                persistClient, 'transaction, resourceType
            );
            if (rollbackResult is error) {
                log:printError(rollbackResult.toString());
            }
            return e;
        }
    }

    // Main function for PATCH (partial update) with transaction support
    public isolated function patchResourceWithTransaction(db_store:Client persistClient, string resourceType, string resourceId, json patchJson) returns json|error {
        // Begin transaction
        utils:TransactionContext 'transaction = self.transactionHandler.beginTransaction();
        'transaction.mainResourceId = resourceId;

        do {
            // Check if resource exists and get current data
            log:printInfo(string `Fetching existing ${resourceType}/${resourceId}`);
            json existingResource = check self.getResourceAsJson(persistClient, resourceType, resourceId);

            // Backup for rollback
            log:printInfo(string `Backing up existing resource`);
            record {|anydata...;|}? backup = check self.backupResource(persistClient, resourceType, resourceId);
            'transaction.backupResource = backup;

            // Apply patch to existing resource
            log:printInfo(string `Applying patch to ${resourceType}/${resourceId}`);
            json mergedResource = check self.applyPatch(existingResource, patchJson);

            // Delete old references
            log:printInfo(string `Deleting old references`);
            int[] oldReferenceIds = check self.findSourceReferences(persistClient, resourceType, resourceId);
            error? deleteRefsResult = utils:deleteReferences(persistClient, oldReferenceIds, 'transaction);

            if deleteRefsResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return deleteRefsResult;
            }

            // Map merged resource to update model
            log:printInfo(string `Mapping patched resource to model`);
            record {|anydata...;|}|error? updateModel = self.updateMapper.mapToUpdateModel(persistClient, resourceType, mergedResource);

            if updateModel is () || updateModel is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateModel is error ? updateModel : error("Failed to create update model");
            }

            // Get extracted references after mapping
            json[] references = self.updateMapper.getReferences();

            // Validate all references BEFORE updating main resource
            log:printInfo(string `Validating ${references.length()} reference(s) for ${resourceType}/${resourceId}`);
            error? validationResult = utils:validateReferences(persistClient, references);
            if validationResult is error {
                log:printError(string `Reference validation failed: ${validationResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return validationResult;
            }

            // Update main resource
            log:printInfo(string `Updating main resource`);
            error? updateResult = self.updateMainResource(persistClient, resourceType, resourceId, updateModel);

            if updateResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return updateResult;
            }

            // Save new references
            log:printInfo(string `Saving new references`);
            error? refResult = utils:saveReferences(persistClient, references, resourceType, resourceId, 'transaction);

            if refResult is error {
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType);
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return refResult;
            }

            // Commit transaction
            self.transactionHandler.commitTransaction('transaction, resourceType, resourceId);

            log:printInfo(string `Successfully patched ${resourceType}/${resourceId}`);
            return mergedResource;

        } on fail error e {
            log:printError(string `Patch transaction failed: ${e.message()}`);
            error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                persistClient, 'transaction, resourceType
            );
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
                db_store:AccountTable|persist:Error result = persistClient->/accounttables/[resourceId]();
                return !(result is persist:Error);
            }
            "Appointment" => {
                db_store:AppointmentTable|persist:Error result = persistClient->/appointmenttables/[resourceId]();
                return !(result is persist:Error);
            }
            "Invoice" => {
                db_store:InvoiceTable|persist:Error result = persistClient->/invoicetables/[resourceId]();
                return !(result is persist:Error);
            }
            "EventDefinition" => {
                db_store:EventDefinitionTable|persist:Error result = persistClient->/eventdefinitiontables/[resourceId]();
                return !(result is persist:Error);
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTable|persist:Error result = persistClient->/documentmanifesttables/[resourceId]();
                return !(result is persist:Error);
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTable|persist:Error result = persistClient->/messagedefinitiontables/[resourceId]();
                return !(result is persist:Error);
            }
            "Goal" => {
                db_store:GoalTable|persist:Error result = persistClient->/goaltables/[resourceId]();
                return !(result is persist:Error);
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTable|persist:Error result = persistClient->/medicinalproductpackagedtables/[resourceId]();
                return !(result is persist:Error);
            }
            "Endpoint" => {
                db_store:EndpointTable|persist:Error result = persistClient->/endpointtables/[resourceId]();
                return !(result is persist:Error);
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTable|persist:Error result = persistClient->/enrollmentrequesttables/[resourceId]();
                return !(result is persist:Error);
            }
            "Consent" => {
                db_store:ConsentTable|persist:Error result = persistClient->/consenttables/[resourceId]();
                return !(result is persist:Error);
            }
            _ => {
                // Generic fallback - assumes resource exists if no specific handler
                // This will be caught during actual operations if resource doesn't exist
                return true;
            }
        }
    }

    // Backup resource for rollback
    private isolated function backupResource(db_store:Client persistClient,
            string resourceType,
            string resourceId) returns record {|anydata...;|}|error {
        
        match resourceType {
            "Account" => {
                db_store:AccountTable result = check persistClient->/accounttables/[resourceId]();
                return result;
            }
            "Appointment" => {
                db_store:AppointmentTable result = check persistClient->/appointmenttables/[resourceId]();
                return result;
            }
            "Invoice" => {
                db_store:InvoiceTable result = check persistClient->/invoicetables/[resourceId]();
                return result;
            }
            "EventDefinition" => {
                db_store:EventDefinitionTable result = check persistClient->/eventdefinitiontables/[resourceId]();
                return result;
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTable result = check persistClient->/documentmanifesttables/[resourceId]();
                return result;
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTable result = check persistClient->/messagedefinitiontables/[resourceId]();
                return result;
            }
            "Goal" => {
                db_store:GoalTable result = check persistClient->/goaltables/[resourceId]();
                return result;
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTable result = check persistClient->/medicinalproductpackagedtables/[resourceId]();
                return result;
            }
            "Endpoint" => {
                db_store:EndpointTable result = check persistClient->/endpointtables/[resourceId]();
                return result;
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTable result = check persistClient->/enrollmentrequesttables/[resourceId]();
                return result;
            }
            "Consent" => {
                db_store:ConsentTable result = check persistClient->/consenttables/[resourceId]();
                return result;
            }
            _ => {
                return error(string `Unsupported resource type for backup: ${resourceType}`);
            }
        }
    }

    // Get resource as JSON (for PATCH operations)
    private isolated function getResourceAsJson(db_store:Client persistClient, string resourceType, string resourceId) returns json|error {

        record {|anydata...;|} backup = check self.backupResource(persistClient, resourceType, resourceId);

        // Extract RESOURCE_JSON field
        byte[]? resourceBlob = ();

        match resourceType {
            "Account" => {
                db_store:AccountTable account = check backup.cloneWithType();
                resourceBlob = account.RESOURCE_JSON;
            }
            "Appointment" => {
                db_store:AppointmentTable appointment = check backup.cloneWithType();
                resourceBlob = appointment.RESOURCE_JSON;
            }
            "Invoice" => {
                db_store:InvoiceTable invoice = check backup.cloneWithType();
                resourceBlob = invoice.RESOURCE_JSON;
            }
            "EventDefinition" => {
                db_store:EventDefinitionTable eventDefinition = check backup.cloneWithType();
                resourceBlob = eventDefinition.RESOURCE_JSON;
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTable documentManifest = check backup.cloneWithType();
                resourceBlob = documentManifest.RESOURCE_JSON;
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTable messageDefinition = check backup.cloneWithType();
                resourceBlob = messageDefinition.RESOURCE_JSON;
            }
            "Goal" => {
                db_store:GoalTable goal = check backup.cloneWithType();
                resourceBlob = goal.RESOURCE_JSON;
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTable medicinalProductPackaged = check backup.cloneWithType();
                resourceBlob = medicinalProductPackaged.RESOURCE_JSON;
            }
            "Endpoint" => {
                db_store:EndpointTable endpoint = check backup.cloneWithType();
                resourceBlob = endpoint.RESOURCE_JSON;
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTable enrollmentRequest = check backup.cloneWithType();
                resourceBlob = enrollmentRequest.RESOURCE_JSON;
            }
            "Consent" => {
                db_store:ConsentTable consent = check backup.cloneWithType();
                resourceBlob = consent.RESOURCE_JSON;
            }
            _ => {
                // Try to extract RESOURCE_JSON generically
                anydata resourceJsonField = backup["RESOURCE_JSON"];
                if resourceJsonField is byte[] {
                    resourceBlob = resourceJsonField;
                }
            }
        }

        if resourceBlob is byte[] {
            string jsonString = check string:fromBytes(resourceBlob);
            json resourceJson = check jsonString.fromJsonString();
            return resourceJson;
        }

        return error("Could not extract resource JSON");
    }

    // Apply JSON patch
    private isolated function applyPatch(json existing, json patch) returns json|error {
         if !(existing is map<json>) {
            return error(string `Existing resource is not a JSON object: ${existing.toString()}`);
        }
        
        if !(patch is map<json>) {
            return error(string `Patch is not a JSON object: ${patch.toString()}`);
        }

        map<json> existingMap = <map<json>>existing;
        map<json> patchMap = <map<json>>patch;

        // Create a new map to hold merged values
        map<json> mergedMap = existingMap.clone();

        // Patch values override existing values
        foreach var [key, value] in patchMap.entries() {
            mergedMap[key] = value;
        }

        return mergedMap;
    }

    // Find source references
    private isolated function findSourceReferences(db_store:Client persistClient, string resourceType, string resourceId) returns int[]|error {

        stream<db_store:REFERENCES, error?> 'stream = persistClient->/references(targetType = db_store:REFERENCES);

        db_store:REFERENCES[] references = check from var ref in 'stream
            where ref.SOURCE_RESOURCE_TYPE == resourceType && ref.SOURCE_RESOURCE_ID == resourceId
            select ref;

        int[] referenceIds = [];
        foreach var ref in references {
            referenceIds.push(ref.ID);
        }

        return referenceIds;
    }

    private isolated function updateMainResource(db_store:Client persistClient, string resourceType, string resourceId, record {|anydata...;|} updateModel) returns error? {

        match resourceType {
            "Account" => {
                db_store:AccountTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/accounttables/[resourceId].put(updateRecord);
            }
            "Appointment" => {
                db_store:AppointmentTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/appointmenttables/[resourceId].put(updateRecord);
            }
            "Invoice" => {
                db_store:InvoiceTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/invoicetables/[resourceId].put(updateRecord);
            }
            "EventDefinition" => {
                db_store:EventDefinitionTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/eventdefinitiontables/[resourceId].put(updateRecord);
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/documentmanifesttables/[resourceId].put(updateRecord);
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/messagedefinitiontables/[resourceId].put(updateRecord);
            }
            "Goal" => {
                db_store:GoalTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/goaltables/[resourceId].put(updateRecord);
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/medicinalproductpackagedtables/[resourceId].put(updateRecord);
            }
            "Endpoint" => {
                db_store:EndpointTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/endpointtables/[resourceId].put(updateRecord);
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/enrollmentrequesttables/[resourceId].put(updateRecord);
            }
            "Consent" => {
                db_store:ConsentTableUpdate updateRecord = check updateModel.cloneWithType();
                _ = check persistClient->/consenttables/[resourceId].put(updateRecord);
            }
            _ => {
                return error(string `Unsupported resource type: ${resourceType}`);
            }
        }
    }
}
