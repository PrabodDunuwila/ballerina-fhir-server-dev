import ballerina_fhir_server.db_store;
import ballerina_fhir_server.mappers;
import ballerina_fhir_server.utils;

import ballerina/log;
import ballerina/persist;

public class UpdateHandler {
    private mappers:UpdateMapper updateMapper;
    private utils:TransactionHandler transactionHandler;
    private HistoryHandler historyHandler;

    public isolated function init() {
        self.updateMapper = new mappers:UpdateMapper();
        self.transactionHandler = new utils:TransactionHandler();
        self.historyHandler = new HistoryHandler();
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
            record {|anydata...;|} backup = check self.backupResource(persistClient, resourceType, resourceId);
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

            // Save current version to history before updating
            log:printInfo(string `Saving current version of ${resourceType}/${resourceId} to history`);
            error? historyResult = self.historyHandler.saveToHistory(persistClient, resourceType, resourceId, backup, "UPDATE");
            if historyResult is error {
                log:printError(string `Failed to save history: ${historyResult.message()}`);
                error? rollbackResult = self.transactionHandler.rollbackUpdateTransaction(
                    persistClient, 'transaction, resourceType
                );
                if (rollbackResult is error) {
                    log:printError(rollbackResult.toString());
                }
                return historyResult;
            }

            // Get current VERSION_ID and increment it
            int currentVersion = check self.getCurrentVersionFromBackup(backup, resourceType);
            int newVersion = currentVersion + 1;

            // Map updated resource to update model
            log:printInfo(string `Mapping updated ${resourceType} to model (version ${newVersion})`);
            record {|anydata...;|}|error? updateModel = self.updateMapper.mapToUpdateModel(persistClient, resourceType, resourceJson, newVersion);

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
            "Condition" => {
                db_store:ConditionTable|persist:Error result = persistClient->/conditiontables/[resourceId]();
                return !(result is persist:Error);
            }
            "Device" => {
                db_store:DeviceTable|persist:Error result = persistClient->/devicetables/[resourceId]();
                return !(result is persist:Error);
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTable|persist:Error result = persistClient->/healthcareservicetables/[resourceId]();
                return !(result is persist:Error);
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTable|persist:Error result = persistClient->/immunizationrecommendationtables/[resourceId]();
                return !(result is persist:Error);
            }
            "Location" => {
                db_store:LocationTable|persist:Error result = persistClient->/locationtables/[resourceId]();
                return !(result is persist:Error);
            }
            "Observation" => {
                db_store:ObservationTable|persist:Error result = persistClient->/observationtables/[resourceId]();
                return !(result is persist:Error);
            }
            "Patient" => {
                db_store:PatientTable|persist:Error result = persistClient->/patienttables/[resourceId]();
                return !(result is persist:Error);
            }
            "Practitioner" => {
                db_store:PractitionerTable|persist:Error result = persistClient->/practitionertables/[resourceId]();
                return !(result is persist:Error);
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTable|persist:Error result = persistClient->/practitionerroletables/[resourceId]();
                return !(result is persist:Error);
            }
            "Procedure" => {
                db_store:ProcedureTable|persist:Error result = persistClient->/proceduretables/[resourceId]();
                return !(result is persist:Error);
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTable|persist:Error result = persistClient->/relatedpersontables/[resourceId]();
                return !(result is persist:Error);
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTable|persist:Error result = persistClient->/servicerequesttables/[resourceId]();
                return !(result is persist:Error);
            }
            "Slot" => {
                db_store:SlotTable|persist:Error result = persistClient->/slottables/[resourceId]();
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
            "Condition" => {
                db_store:ConditionTable result = check persistClient->/conditiontables/[resourceId]();
                return result;
            }
            "Device" => {
                db_store:DeviceTable result = check persistClient->/devicetables/[resourceId]();
                return result;
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTable result = check persistClient->/healthcareservicetables/[resourceId]();
                return result;
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTable result = check persistClient->/immunizationrecommendationtables/[resourceId]();
                return result;
            }
            "Location" => {
                db_store:LocationTable result = check persistClient->/locationtables/[resourceId]();
                return result;
            }
            "Observation" => {
                db_store:ObservationTable result = check persistClient->/observationtables/[resourceId]();
                return result;
            }
            "Patient" => {
                db_store:PatientTable result = check persistClient->/patienttables/[resourceId]();
                return result;
            }
            "Practitioner" => {
                db_store:PractitionerTable result = check persistClient->/practitionertables/[resourceId]();
                return result;
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTable result = check persistClient->/practitionerroletables/[resourceId]();
                return result;
            }
            "Procedure" => {
                db_store:ProcedureTable result = check persistClient->/proceduretables/[resourceId]();
                return result;
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTable result = check persistClient->/relatedpersontables/[resourceId]();
                return result;
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTable result = check persistClient->/servicerequesttables/[resourceId]();
                return result;
            }
            "Slot" => {
                db_store:SlotTable result = check persistClient->/slottables/[resourceId]();
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
            "Condition" => {
                db_store:ConditionTable condition = check backup.cloneWithType();
                resourceBlob = condition.RESOURCE_JSON;
            }
            "Device" => {
                db_store:DeviceTable device = check backup.cloneWithType();
                resourceBlob = device.RESOURCE_JSON;
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTable healthcareService = check backup.cloneWithType();
                resourceBlob = healthcareService.RESOURCE_JSON;
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTable immunizationRecommendation = check backup.cloneWithType();
                resourceBlob = immunizationRecommendation.RESOURCE_JSON;
            }
            "Location" => {
                db_store:LocationTable location = check backup.cloneWithType();
                resourceBlob = location.RESOURCE_JSON;
            }
            "Observation" => {
                db_store:ObservationTable observation = check backup.cloneWithType();
                resourceBlob = observation.RESOURCE_JSON;
            }
            "Patient" => {
                db_store:PatientTable patient = check backup.cloneWithType();
                resourceBlob = patient.RESOURCE_JSON;
            }
            "Practitioner" => {
                db_store:PractitionerTable practitioner = check backup.cloneWithType();
                resourceBlob = practitioner.RESOURCE_JSON;
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTable practitionerRole = check backup.cloneWithType();
                resourceBlob = practitionerRole.RESOURCE_JSON;
            }
            "Procedure" => {
                db_store:ProcedureTable procedure = check backup.cloneWithType();
                resourceBlob = procedure.RESOURCE_JSON;
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTable relatedPerson = check backup.cloneWithType();
                resourceBlob = relatedPerson.RESOURCE_JSON;
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTable serviceRequest = check backup.cloneWithType();
                resourceBlob = serviceRequest.RESOURCE_JSON;
            }
            "Slot" => {
                db_store:SlotTable slot = check backup.cloneWithType();
                resourceBlob = slot.RESOURCE_JSON;
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

    // Extract current VERSION_ID from backup
    private isolated function getCurrentVersionFromBackup(record {|anydata...;|} backup, string resourceType) returns int|error {
        match resourceType {
            "Appointment" => {
                db_store:AppointmentTable appointment = check backup.cloneWithType();
                return appointment.VERSION_ID;
            }
            "Account" => {
                db_store:AccountTable account = check backup.cloneWithType();
                return account.VERSION_ID;
            }
            _ => {
                // Try generic extraction
                anydata versionField = backup["VERSION_ID"];
                if versionField is int {
                    return versionField;
                }
                return error(string `Could not extract VERSION_ID for ${resourceType}`);
            }
        }
    }
}
