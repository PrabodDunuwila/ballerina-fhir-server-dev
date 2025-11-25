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
            "Account" => {
                return self.saveAccountHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Patient" => {
                return self.savePatientHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Observation" => {
                return self.saveObservationHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Invoice" => {
                return self.saveInvoiceHistory(persistClient, resourceId, currentVersion, operation);
            }
            "DocumentManifest" => {
                return self.saveDocumentManifestHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Consent" => {
                return self.saveConsentHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Goal" => {
                return self.saveGoalHistory(persistClient, resourceId, currentVersion, operation);
            }
            "MedicinalProductPackaged" => {
                return self.saveMedicinalProductPackagedHistory(persistClient, resourceId, currentVersion, operation);
            }
            "MessageDefinition" => {
                return self.saveMessageDefinitionHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Endpoint" => {
                return self.saveEndpointHistory(persistClient, resourceId, currentVersion, operation);
            }
            "EnrollmentRequest" => {
                return self.saveEnrollmentRequestHistory(persistClient, resourceId, currentVersion, operation);
            }
            "EventDefinition" => {
                return self.saveEventDefinitionHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Practitioner" => {
                return self.savePractitionerHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Device" => {
                return self.saveDeviceHistory(persistClient, resourceId, currentVersion, operation);
            }
            "HealthcareService" => {
                return self.saveHealthcareServiceHistory(persistClient, resourceId, currentVersion, operation);
            }
            "PractitionerRole" => {
                return self.savePractitionerRoleHistory(persistClient, resourceId, currentVersion, operation);
            }
            "RelatedPerson" => {
                return self.saveRelatedPersonHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Location" => {
                return self.saveLocationHistory(persistClient, resourceId, currentVersion, operation);
            }
            "ServiceRequest" => {
                return self.saveServiceRequestHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Condition" => {
                return self.saveConditionHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Procedure" => {
                return self.saveProcedureHistory(persistClient, resourceId, currentVersion, operation);
            }
            "ImmunizationRecommendation" => {
                return self.saveImmunizationRecommendationHistory(persistClient, resourceId, currentVersion, operation);
            }
            "Slot" => {
                return self.saveSlotHistory(persistClient, resourceId, currentVersion, operation);
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

    // Save Account history
    private isolated function saveAccountHistory(db_store:Client persistClient, string resourceId,
                                                 record {|anydata...;|} currentVersion, string operation) returns error? {
        
        db_store:AccountTable account = check currentVersion.cloneWithType();
        
        db_store:AccountTableHistoryInsert historyRecord = {
            ACCOUNTTABLE_ID: account.ACCOUNTTABLE_ID,
            VERSION_ID: account.VERSION_ID,
            OPERATION: operation,
            PERIOD: account.PERIOD,
            STATUS: account.STATUS,
            IDENTIFIER: account.IDENTIFIER,
            TYPE: account.TYPE,
            NAME: account.NAME,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: account.RESOURCE_JSON
        };

        _ = check persistClient->/accounttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${account.VERSION_ID} of Account/${resourceId} to history`);
    }

    // Save Patient history
    private isolated function savePatientHistory(db_store:Client persistClient, string resourceId,
                                                 record {|anydata...;|} currentVersion, string operation) returns error? {
        
        db_store:PatientTable patient = check currentVersion.cloneWithType();
        
        db_store:PatientTableHistoryInsert historyRecord = {
            PATIENTTABLE_ID: patient.PATIENTTABLE_ID,
            VERSION_ID: patient.VERSION_ID,
            OPERATION: operation,
            BIRTHDATE: patient.BIRTHDATE,
            NAME: patient.NAME,
            FAMILY: patient.FAMILY,
            GIVEN: patient.GIVEN,
            GENDER: patient.GENDER,
            IDENTIFIER: patient.IDENTIFIER,
            ACTIVE: patient.ACTIVE,
            PHONE: patient.PHONE,
            EMAIL: patient.EMAIL,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: patient.RESOURCE_JSON
        };

        _ = check persistClient->/patienttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${patient.VERSION_ID} of Patient/${resourceId} to history`);
    }

    // Save Observation history
    private isolated function saveObservationHistory(db_store:Client persistClient, string resourceId,
                                                     record {|anydata...;|} currentVersion, string operation) returns error? {
        
        db_store:ObservationTable observation = check currentVersion.cloneWithType();
        
        db_store:ObservationTableHistoryInsert historyRecord = {
            OBSERVATIONTABLE_ID: observation.OBSERVATIONTABLE_ID,
            VERSION_ID: observation.VERSION_ID,
            OPERATION: operation,
            DATE: observation.DATE,
            CODE: observation.CODE,
            STATUS: observation.STATUS,
            CATEGORY: observation.CATEGORY,
            VALUE_QUANTITY: observation.VALUE_QUANTITY,
            IDENTIFIER: observation.IDENTIFIER,
            METHOD: observation.METHOD,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: observation.RESOURCE_JSON
        };

        _ = check persistClient->/observationtablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${observation.VERSION_ID} of Observation/${resourceId} to history`);
    }

    // Save Invoice history
    private isolated function saveInvoiceHistory(db_store:Client persistClient, string resourceId,
                                                 record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:InvoiceTable invoice = check currentVersion.cloneWithType();
        db_store:InvoiceTableHistoryInsert historyRecord = {
            INVOICETABLE_ID: invoice.INVOICETABLE_ID,
            VERSION_ID: invoice.VERSION_ID,
            OPERATION: operation,
            DATE: invoice.DATE,
            STATUS: invoice.STATUS,
            IDENTIFIER: invoice.IDENTIFIER,
            TYPE: invoice.TYPE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: invoice.RESOURCE_JSON
        };
        _ = check persistClient->/invoicetablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${invoice.VERSION_ID} of Invoice/${resourceId} to history`);
    }

    // Save DocumentManifest history
    private isolated function saveDocumentManifestHistory(db_store:Client persistClient, string resourceId,
                                                          record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:DocumentManifestTable manifest = check currentVersion.cloneWithType();
        db_store:DocumentManifestTableHistoryInsert historyRecord = {
            DOCUMENTMANIFESTTABLE_ID: manifest.DOCUMENTMANIFESTTABLE_ID,
            VERSION_ID: manifest.VERSION_ID,
            OPERATION: operation,
            CREATED: manifest.CREATED,
            STATUS: manifest.STATUS,
            IDENTIFIER: manifest.IDENTIFIER,
            TYPE: manifest.TYPE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: manifest.RESOURCE_JSON
        };
        _ = check persistClient->/documentmanifesttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${manifest.VERSION_ID} of DocumentManifest/${resourceId} to history`);
    }

    // Save Consent history
    private isolated function saveConsentHistory(db_store:Client persistClient, string resourceId,
                                                 record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:ConsentTable consent = check currentVersion.cloneWithType();
        db_store:ConsentTableHistoryInsert historyRecord = {
            CONSENTTABLE_ID: consent.CONSENTTABLE_ID,
            VERSION_ID: consent.VERSION_ID,
            OPERATION: operation,
            DATE: consent.DATE,
            STATUS: consent.STATUS,
            CATEGORY: consent.CATEGORY,
            IDENTIFIER: consent.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: consent.RESOURCE_JSON
        };
        _ = check persistClient->/consenttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${consent.VERSION_ID} of Consent/${resourceId} to history`);
    }

    // Save Goal history
    private isolated function saveGoalHistory(db_store:Client persistClient, string resourceId,
                                             record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:GoalTable goal = check currentVersion.cloneWithType();
        db_store:GoalTableHistoryInsert historyRecord = {
            GOALTABLE_ID: goal.GOALTABLE_ID,
            VERSION_ID: goal.VERSION_ID,
            OPERATION: operation,
            TARGET_DATE: goal.TARGET_DATE,
            CATEGORY: goal.CATEGORY,
            LIFECYCLE_STATUS: goal.LIFECYCLE_STATUS,
            IDENTIFIER: goal.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: goal.RESOURCE_JSON
        };
        _ = check persistClient->/goaltablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${goal.VERSION_ID} of Goal/${resourceId} to history`);
    }

    // Save MedicinalProductPackaged history
    private isolated function saveMedicinalProductPackagedHistory(db_store:Client persistClient, string resourceId,
                                                                   record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:MedicinalProductPackagedTable product = check currentVersion.cloneWithType();
        db_store:MedicinalProductPackagedTableHistoryInsert historyRecord = {
            MEDICINALPRODUCTPACKAGEDTABLE_ID: product.MEDICINALPRODUCTPACKAGEDTABLE_ID,
            VERSION_ID: product.VERSION_ID,
            OPERATION: operation,
            IDENTIFIER: product.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: product.RESOURCE_JSON
        };
        _ = check persistClient->/medicinalproductpackagedtablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${product.VERSION_ID} of MedicinalProductPackaged/${resourceId} to history`);
    }

    // Save MessageDefinition history
    private isolated function saveMessageDefinitionHistory(db_store:Client persistClient, string resourceId,
                                                           record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:MessageDefinitionTable msgDef = check currentVersion.cloneWithType();
        db_store:MessageDefinitionTableHistoryInsert historyRecord = {
            MESSAGEDEFINITIONTABLE_ID: msgDef.MESSAGEDEFINITIONTABLE_ID,
            VERSION_ID: msgDef.VERSION_ID,
            OPERATION: operation,
            DATE: msgDef.DATE,
            STATUS: msgDef.STATUS,
            CATEGORY: msgDef.CATEGORY,
            IDENTIFIER: msgDef.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: msgDef.RESOURCE_JSON
        };
        _ = check persistClient->/messagedefinitiontablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${msgDef.VERSION_ID} of MessageDefinition/${resourceId} to history`);
    }

    // Save Endpoint history
    private isolated function saveEndpointHistory(db_store:Client persistClient, string resourceId,
                                                  record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:EndpointTable endpoint = check currentVersion.cloneWithType();
        db_store:EndpointTableHistoryInsert historyRecord = {
            ENDPOINTTABLE_ID: endpoint.ENDPOINTTABLE_ID,
            VERSION_ID: endpoint.VERSION_ID,
            OPERATION: operation,
            STATUS: endpoint.STATUS,
            IDENTIFIER: endpoint.IDENTIFIER,
            NAME: endpoint.NAME,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: endpoint.RESOURCE_JSON
        };
        _ = check persistClient->/endpointtablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${endpoint.VERSION_ID} of Endpoint/${resourceId} to history`);
    }

    // Save EnrollmentRequest history
    private isolated function saveEnrollmentRequestHistory(db_store:Client persistClient, string resourceId,
                                                           record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:EnrollmentRequestTable enrollReq = check currentVersion.cloneWithType();
        db_store:EnrollmentRequestTableHistoryInsert historyRecord = {
            ENROLLMENTREQUESTTABLE_ID: enrollReq.ENROLLMENTREQUESTTABLE_ID,
            VERSION_ID: enrollReq.VERSION_ID,
            OPERATION: operation,
            STATUS: enrollReq.STATUS,
            IDENTIFIER: enrollReq.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: enrollReq.RESOURCE_JSON
        };
        _ = check persistClient->/enrollmentrequesttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${enrollReq.VERSION_ID} of EnrollmentRequest/${resourceId} to history`);
    }

    // Save EventDefinition history
    private isolated function saveEventDefinitionHistory(db_store:Client persistClient, string resourceId,
                                                         record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:EventDefinitionTable eventDef = check currentVersion.cloneWithType();
        db_store:EventDefinitionTableHistoryInsert historyRecord = {
            EVENTDEFINITIONTABLE_ID: eventDef.EVENTDEFINITIONTABLE_ID,
            VERSION_ID: eventDef.VERSION_ID,
            OPERATION: operation,
            DATE: eventDef.DATE,
            STATUS: eventDef.STATUS,
            IDENTIFIER: eventDef.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: eventDef.RESOURCE_JSON
        };
        _ = check persistClient->/eventdefinitiontablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${eventDef.VERSION_ID} of EventDefinition/${resourceId} to history`);
    }

    // Save Practitioner history
    private isolated function savePractitionerHistory(db_store:Client persistClient, string resourceId,
                                                      record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:PractitionerTable practitioner = check currentVersion.cloneWithType();
        db_store:PractitionerTableHistoryInsert historyRecord = {
            PRACTITIONERTABLE_ID: practitioner.PRACTITIONERTABLE_ID,
            VERSION_ID: practitioner.VERSION_ID,
            OPERATION: operation,
            NAME: practitioner.NAME,
            FAMILY: practitioner.FAMILY,
            GIVEN: practitioner.GIVEN,
            GENDER: practitioner.GENDER,
            IDENTIFIER: practitioner.IDENTIFIER,
            ACTIVE: practitioner.ACTIVE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: practitioner.RESOURCE_JSON
        };
        _ = check persistClient->/practitionertablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${practitioner.VERSION_ID} of Practitioner/${resourceId} to history`);
    }

    // Save Device history
    private isolated function saveDeviceHistory(db_store:Client persistClient, string resourceId,
                                                record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:DeviceTable device = check currentVersion.cloneWithType();
        db_store:DeviceTableHistoryInsert historyRecord = {
            DEVICETABLE_ID: device.DEVICETABLE_ID,
            VERSION_ID: device.VERSION_ID,
            OPERATION: operation,
            MANUFACTURER: device.MANUFACTURER,
            MODEL: device.MODEL,
            STATUS: device.STATUS,
            TYPE: device.TYPE,
            IDENTIFIER: device.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: device.RESOURCE_JSON
        };
        _ = check persistClient->/devicetablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${device.VERSION_ID} of Device/${resourceId} to history`);
    }

    // Save HealthcareService history
    private isolated function saveHealthcareServiceHistory(db_store:Client persistClient, string resourceId,
                                                           record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:HealthcareServiceTable healthcareService = check currentVersion.cloneWithType();
        db_store:HealthcareServiceTableHistoryInsert historyRecord = {
            HEALTHCARESERVICETABLE_ID: healthcareService.HEALTHCARESERVICETABLE_ID,
            VERSION_ID: healthcareService.VERSION_ID,
            OPERATION: operation,
            ACTIVE: healthcareService.ACTIVE,
            NAME: healthcareService.NAME,
            IDENTIFIER: healthcareService.IDENTIFIER,
            SERVICE_CATEGORY: healthcareService.SERVICE_CATEGORY,
            SERVICE_TYPE: healthcareService.SERVICE_TYPE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: healthcareService.RESOURCE_JSON
        };
        _ = check persistClient->/healthcareservicetablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${healthcareService.VERSION_ID} of HealthcareService/${resourceId} to history`);
    }

    // Save PractitionerRole history
    private isolated function savePractitionerRoleHistory(db_store:Client persistClient, string resourceId,
                                                          record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:PractitionerRoleTable role = check currentVersion.cloneWithType();
        db_store:PractitionerRoleTableHistoryInsert historyRecord = {
            PRACTITIONERROLETABLE_ID: role.PRACTITIONERROLETABLE_ID,
            VERSION_ID: role.VERSION_ID,
            OPERATION: operation,
            ROLE: role.ROLE,
            DATE: role.DATE,
            ACTIVE: role.ACTIVE,
            SPECIALTY: role.SPECIALTY,
            IDENTIFIER: role.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: role.RESOURCE_JSON
        };
        _ = check persistClient->/practitionerroletablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${role.VERSION_ID} of PractitionerRole/${resourceId} to history`);
    }

    // Save RelatedPerson history
    private isolated function saveRelatedPersonHistory(db_store:Client persistClient, string resourceId,
                                                       record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:RelatedPersonTable relatedPerson = check currentVersion.cloneWithType();
        db_store:RelatedPersonTableHistoryInsert historyRecord = {
            RELATEDPERSONTABLE_ID: relatedPerson.RELATEDPERSONTABLE_ID,
            VERSION_ID: relatedPerson.VERSION_ID,
            OPERATION: operation,
            BIRTHDATE: relatedPerson.BIRTHDATE,
            NAME: relatedPerson.NAME,
            GENDER: relatedPerson.GENDER,
            IDENTIFIER: relatedPerson.IDENTIFIER,
            ACTIVE: relatedPerson.ACTIVE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: relatedPerson.RESOURCE_JSON
        };
        _ = check persistClient->/relatedpersontablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${relatedPerson.VERSION_ID} of RelatedPerson/${resourceId} to history`);
    }

    // Save Location history
    private isolated function saveLocationHistory(db_store:Client persistClient, string resourceId,
                                                  record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:LocationTable location = check currentVersion.cloneWithType();
        db_store:LocationTableHistoryInsert historyRecord = {
            LOCATIONTABLE_ID: location.LOCATIONTABLE_ID,
            VERSION_ID: location.VERSION_ID,
            OPERATION: operation,
            NAME: location.NAME,
            STATUS: location.STATUS,
            TYPE: location.TYPE,
            IDENTIFIER: location.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: location.RESOURCE_JSON
        };
        _ = check persistClient->/locationtablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${location.VERSION_ID} of Location/${resourceId} to history`);
    }

    // Save ServiceRequest history
    private isolated function saveServiceRequestHistory(db_store:Client persistClient, string resourceId,
                                                        record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:ServiceRequestTable serviceRequest = check currentVersion.cloneWithType();
        db_store:ServiceRequestTableHistoryInsert historyRecord = {
            SERVICEREQUESTTABLE_ID: serviceRequest.SERVICEREQUESTTABLE_ID,
            VERSION_ID: serviceRequest.VERSION_ID,
            OPERATION: operation,
            STATUS: serviceRequest.STATUS,
            INTENT: serviceRequest.INTENT,
            CATEGORY: serviceRequest.CATEGORY,
            CODE: serviceRequest.CODE,
            IDENTIFIER: serviceRequest.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: serviceRequest.RESOURCE_JSON
        };
        _ = check persistClient->/servicerequesttablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${serviceRequest.VERSION_ID} of ServiceRequest/${resourceId} to history`);
    }

    // Save Condition history
    private isolated function saveConditionHistory(db_store:Client persistClient, string resourceId,
                                                   record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:ConditionTable condition = check currentVersion.cloneWithType();
        db_store:ConditionTableHistoryInsert historyRecord = {
            CONDITIONTABLE_ID: condition.CONDITIONTABLE_ID,
            VERSION_ID: condition.VERSION_ID,
            OPERATION: operation,
            CLINICAL_STATUS: condition.CLINICAL_STATUS,
            CATEGORY: condition.CATEGORY,
            CODE: condition.CODE,
            SEVERITY: condition.SEVERITY,
            IDENTIFIER: condition.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: condition.RESOURCE_JSON
        };
        _ = check persistClient->/conditiontablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${condition.VERSION_ID} of Condition/${resourceId} to history`);
    }

    // Save Procedure history
    private isolated function saveProcedureHistory(db_store:Client persistClient, string resourceId,
                                                   record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:ProcedureTable procedure = check currentVersion.cloneWithType();
        db_store:ProcedureTableHistoryInsert historyRecord = {
            PROCEDURETABLE_ID: procedure.PROCEDURETABLE_ID,
            VERSION_ID: procedure.VERSION_ID,
            OPERATION: operation,
            STATUS: procedure.STATUS,
            CATEGORY: procedure.CATEGORY,
            CODE: procedure.CODE,
            DATE: procedure.DATE,
            IDENTIFIER: procedure.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: procedure.RESOURCE_JSON
        };
        _ = check persistClient->/proceduretablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${procedure.VERSION_ID} of Procedure/${resourceId} to history`);
    }

    // Save ImmunizationRecommendation history
    private isolated function saveImmunizationRecommendationHistory(db_store:Client persistClient, string resourceId,
                                                                     record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:ImmunizationRecommendationTable immunization = check currentVersion.cloneWithType();
        db_store:ImmunizationRecommendationTableHistoryInsert historyRecord = {
            IMMUNIZATIONRECOMMENDATIONTABLE_ID: immunization.IMMUNIZATIONRECOMMENDATIONTABLE_ID,
            VERSION_ID: immunization.VERSION_ID,
            OPERATION: operation,
            DATE: immunization.DATE,
            STATUS: immunization.STATUS,
            IDENTIFIER: immunization.IDENTIFIER,
            TARGET_DISEASE: immunization.TARGET_DISEASE,
            VACCINE_TYPE: immunization.VACCINE_TYPE,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: immunization.RESOURCE_JSON
        };
        _ = check persistClient->/immunizationrecommendationtablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${immunization.VERSION_ID} of ImmunizationRecommendation/${resourceId} to history`);
    }

    // Save Slot history
    private isolated function saveSlotHistory(db_store:Client persistClient, string resourceId,
                                             record {|anydata...;|} currentVersion, string operation) returns error? {
        db_store:SlotTable slot = check currentVersion.cloneWithType();
        db_store:SlotTableHistoryInsert historyRecord = {
            SLOTTABLE_ID: slot.SLOTTABLE_ID,
            VERSION_ID: slot.VERSION_ID,
            OPERATION: operation,
            STATUS: slot.STATUS,
            START: slot.START,
            SERVICE_CATEGORY: slot.SERVICE_CATEGORY,
            SERVICE_TYPE: slot.SERVICE_TYPE,
            SPECIALTY: slot.SPECIALTY,
            IDENTIFIER: slot.IDENTIFIER,
            CREATED_AT: time:utcToCivil(time:utcNow()),
            RESOURCE_JSON: slot.RESOURCE_JSON
        };
        _ = check persistClient->/slottablehistories.post([historyRecord]);
        log:printInfo(string `Saved version ${slot.VERSION_ID} of Slot/${resourceId} to history`);
    }

    // Get current version number for a resource
    public isolated function getCurrentVersion(db_store:Client persistClient, string resourceType, string resourceId) returns int|error {
        match resourceType {
            "Appointment" => {
                db_store:AppointmentTable result = check persistClient->/appointmenttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Account" => {
                db_store:AccountTable result = check persistClient->/accounttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Patient" => {
                db_store:PatientTable result = check persistClient->/patienttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Observation" => {
                db_store:ObservationTable result = check persistClient->/observationtables/[resourceId]();
                return result.VERSION_ID;
            }
            "Invoice" => {
                db_store:InvoiceTable result = check persistClient->/invoicetables/[resourceId]();
                return result.VERSION_ID;
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTable result = check persistClient->/documentmanifesttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Consent" => {
                db_store:ConsentTable result = check persistClient->/consenttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Goal" => {
                db_store:GoalTable result = check persistClient->/goaltables/[resourceId]();
                return result.VERSION_ID;
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTable result = check persistClient->/medicinalproductpackagedtables/[resourceId]();
                return result.VERSION_ID;
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTable result = check persistClient->/messagedefinitiontables/[resourceId]();
                return result.VERSION_ID;
            }
            "Endpoint" => {
                db_store:EndpointTable result = check persistClient->/endpointtables/[resourceId]();
                return result.VERSION_ID;
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTable result = check persistClient->/enrollmentrequesttables/[resourceId]();
                return result.VERSION_ID;
            }
            "EventDefinition" => {
                db_store:EventDefinitionTable result = check persistClient->/eventdefinitiontables/[resourceId]();
                return result.VERSION_ID;
            }
            "Practitioner" => {
                db_store:PractitionerTable result = check persistClient->/practitionertables/[resourceId]();
                return result.VERSION_ID;
            }
            "Device" => {
                db_store:DeviceTable result = check persistClient->/devicetables/[resourceId]();
                return result.VERSION_ID;
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTable result = check persistClient->/healthcareservicetables/[resourceId]();
                return result.VERSION_ID;
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTable result = check persistClient->/practitionerroletables/[resourceId]();
                return result.VERSION_ID;
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTable result = check persistClient->/relatedpersontables/[resourceId]();
                return result.VERSION_ID;
            }
            "Location" => {
                db_store:LocationTable result = check persistClient->/locationtables/[resourceId]();
                return result.VERSION_ID;
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTable result = check persistClient->/servicerequesttables/[resourceId]();
                return result.VERSION_ID;
            }
            "Condition" => {
                db_store:ConditionTable result = check persistClient->/conditiontables/[resourceId]();
                return result.VERSION_ID;
            }
            "Procedure" => {
                db_store:ProcedureTable result = check persistClient->/proceduretables/[resourceId]();
                return result.VERSION_ID;
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTable result = check persistClient->/immunizationrecommendationtables/[resourceId]();
                return result.VERSION_ID;
            }
            "Slot" => {
                db_store:SlotTable result = check persistClient->/slottables/[resourceId]();
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
            "Account" => {
                return self.getAccountVersion(persistClient, resourceId, versionId);
            }
            "Patient" => {
                return self.getPatientVersion(persistClient, resourceId, versionId);
            }
            "Observation" => {
                return self.getObservationVersion(persistClient, resourceId, versionId);
            }
            "Invoice" => {
                return self.getInvoiceVersion(persistClient, resourceId, versionId);
            }
            "DocumentManifest" => {
                return self.getDocumentManifestVersion(persistClient, resourceId, versionId);
            }
            "Consent" => {
                return self.getConsentVersion(persistClient, resourceId, versionId);
            }
            "Goal" => {
                return self.getGoalVersion(persistClient, resourceId, versionId);
            }
            "MedicinalProductPackaged" => {
                return self.getMedicinalProductPackagedVersion(persistClient, resourceId, versionId);
            }
            "MessageDefinition" => {
                return self.getMessageDefinitionVersion(persistClient, resourceId, versionId);
            }
            "Endpoint" => {
                return self.getEndpointVersion(persistClient, resourceId, versionId);
            }
            "EnrollmentRequest" => {
                return self.getEnrollmentRequestVersion(persistClient, resourceId, versionId);
            }
            "EventDefinition" => {
                return self.getEventDefinitionVersion(persistClient, resourceId, versionId);
            }
            "Practitioner" => {
                return self.getPractitionerVersion(persistClient, resourceId, versionId);
            }
            "Device" => {
                return self.getDeviceVersion(persistClient, resourceId, versionId);
            }
            "HealthcareService" => {
                return self.getHealthcareServiceVersion(persistClient, resourceId, versionId);
            }
            "PractitionerRole" => {
                return self.getPractitionerRoleVersion(persistClient, resourceId, versionId);
            }
            "RelatedPerson" => {
                return self.getRelatedPersonVersion(persistClient, resourceId, versionId);
            }
            "Location" => {
                return self.getLocationVersion(persistClient, resourceId, versionId);
            }
            "ServiceRequest" => {
                return self.getServiceRequestVersion(persistClient, resourceId, versionId);
            }
            "Condition" => {
                return self.getConditionVersion(persistClient, resourceId, versionId);
            }
            "Procedure" => {
                return self.getProcedureVersion(persistClient, resourceId, versionId);
            }
            "ImmunizationRecommendation" => {
                return self.getImmunizationRecommendationVersion(persistClient, resourceId, versionId);
            }
            "Slot" => {
                return self.getSlotVersion(persistClient, resourceId, versionId);
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

    // Get specific Account version
    private isolated function getAccountVersion(db_store:Client persistClient, string resourceId, 
                                                int versionId) returns json|error {
        
        stream<db_store:AccountTableHistory, error?> historyStream = 
            persistClient->/accounttablehistories(targetType = db_store:AccountTableHistory);
        
        db_store:AccountTableHistory[] results = check from var item in historyStream 
            where item.ACCOUNTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Account/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Patient version
    private isolated function getPatientVersion(db_store:Client persistClient, string resourceId, 
                                                int versionId) returns json|error {
        
        stream<db_store:PatientTableHistory, error?> historyStream = 
            persistClient->/patienttablehistories(targetType = db_store:PatientTableHistory);
        
        db_store:PatientTableHistory[] results = check from var item in historyStream 
            where item.PATIENTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Patient/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Observation version
    private isolated function getObservationVersion(db_store:Client persistClient, string resourceId, 
                                                    int versionId) returns json|error {
        
        stream<db_store:ObservationTableHistory, error?> historyStream = 
            persistClient->/observationtablehistories(targetType = db_store:ObservationTableHistory);
        
        db_store:ObservationTableHistory[] results = check from var item in historyStream 
            where item.OBSERVATIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Observation/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Invoice version
    private isolated function getInvoiceVersion(db_store:Client persistClient, string resourceId, 
                                                int versionId) returns json|error {
        
        stream<db_store:InvoiceTableHistory, error?> historyStream = 
            persistClient->/invoicetablehistories(targetType = db_store:InvoiceTableHistory);
        
        db_store:InvoiceTableHistory[] results = check from var item in historyStream 
            where item.INVOICETABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Invoice/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific DocumentManifest version
    private isolated function getDocumentManifestVersion(db_store:Client persistClient, string resourceId, 
                                                         int versionId) returns json|error {
        
        stream<db_store:DocumentManifestTableHistory, error?> historyStream = 
            persistClient->/documentmanifesttablehistories(targetType = db_store:DocumentManifestTableHistory);
        
        db_store:DocumentManifestTableHistory[] results = check from var item in historyStream 
            where item.DOCUMENTMANIFESTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `DocumentManifest/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Consent version
    private isolated function getConsentVersion(db_store:Client persistClient, string resourceId, 
                                                int versionId) returns json|error {
        
        stream<db_store:ConsentTableHistory, error?> historyStream = 
            persistClient->/consenttablehistories(targetType = db_store:ConsentTableHistory);
        
        db_store:ConsentTableHistory[] results = check from var item in historyStream 
            where item.CONSENTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Consent/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Goal version
    private isolated function getGoalVersion(db_store:Client persistClient, string resourceId, 
                                             int versionId) returns json|error {
        
        stream<db_store:GoalTableHistory, error?> historyStream = 
            persistClient->/goaltablehistories(targetType = db_store:GoalTableHistory);
        
        db_store:GoalTableHistory[] results = check from var item in historyStream 
            where item.GOALTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Goal/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific MedicinalProductPackaged version
    private isolated function getMedicinalProductPackagedVersion(db_store:Client persistClient, string resourceId, 
                                                                 int versionId) returns json|error {
        
        stream<db_store:MedicinalProductPackagedTableHistory, error?> historyStream = 
            persistClient->/medicinalproductpackagedtablehistories(targetType = db_store:MedicinalProductPackagedTableHistory);
        
        db_store:MedicinalProductPackagedTableHistory[] results = check from var item in historyStream 
            where item.MEDICINALPRODUCTPACKAGEDTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `MedicinalProductPackaged/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific MessageDefinition version
    private isolated function getMessageDefinitionVersion(db_store:Client persistClient, string resourceId, 
                                                          int versionId) returns json|error {
        
        stream<db_store:MessageDefinitionTableHistory, error?> historyStream = 
            persistClient->/messagedefinitiontablehistories(targetType = db_store:MessageDefinitionTableHistory);
        
        db_store:MessageDefinitionTableHistory[] results = check from var item in historyStream 
            where item.MESSAGEDEFINITIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `MessageDefinition/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific Endpoint version
    private isolated function getEndpointVersion(db_store:Client persistClient, string resourceId, 
                                                 int versionId) returns json|error {
        
        stream<db_store:EndpointTableHistory, error?> historyStream = 
            persistClient->/endpointtablehistories(targetType = db_store:EndpointTableHistory);
        
        db_store:EndpointTableHistory[] results = check from var item in historyStream 
            where item.ENDPOINTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Endpoint/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific EnrollmentRequest version
    private isolated function getEnrollmentRequestVersion(db_store:Client persistClient, string resourceId, 
                                                          int versionId) returns json|error {
        
        stream<db_store:EnrollmentRequestTableHistory, error?> historyStream = 
            persistClient->/enrollmentrequesttablehistories(targetType = db_store:EnrollmentRequestTableHistory);
        
        db_store:EnrollmentRequestTableHistory[] results = check from var item in historyStream 
            where item.ENROLLMENTREQUESTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `EnrollmentRequest/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    // Get specific EventDefinition version
    private isolated function getEventDefinitionVersion(db_store:Client persistClient, string resourceId, 
                                                        int versionId) returns json|error {
        
        stream<db_store:EventDefinitionTableHistory, error?> historyStream = 
            persistClient->/eventdefinitiontablehistories(targetType = db_store:EventDefinitionTableHistory);
        
        db_store:EventDefinitionTableHistory[] results = check from var item in historyStream 
            where item.EVENTDEFINITIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `EventDefinition/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getPractitionerVersion(db_store:Client persistClient, string resourceId, 
                                                     int versionId) returns json|error {
        
        stream<db_store:PractitionerTableHistory, error?> historyStream = 
            persistClient->/practitionertablehistories(targetType = db_store:PractitionerTableHistory);
        
        db_store:PractitionerTableHistory[] results = check from var item in historyStream 
            where item.PRACTITIONERTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Practitioner/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getDeviceVersion(db_store:Client persistClient, string resourceId, 
                                               int versionId) returns json|error {
        
        stream<db_store:DeviceTableHistory, error?> historyStream = 
            persistClient->/devicetablehistories(targetType = db_store:DeviceTableHistory);
        
        db_store:DeviceTableHistory[] results = check from var item in historyStream 
            where item.DEVICETABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Device/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getHealthcareServiceVersion(db_store:Client persistClient, string resourceId, 
                                                          int versionId) returns json|error {
        
        stream<db_store:HealthcareServiceTableHistory, error?> historyStream = 
            persistClient->/healthcareservicetablehistories(targetType = db_store:HealthcareServiceTableHistory);
        
        db_store:HealthcareServiceTableHistory[] results = check from var item in historyStream 
            where item.HEALTHCARESERVICETABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `HealthcareService/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getPractitionerRoleVersion(db_store:Client persistClient, string resourceId, 
                                                         int versionId) returns json|error {
        
        stream<db_store:PractitionerRoleTableHistory, error?> historyStream = 
            persistClient->/practitionerroletablehistories(targetType = db_store:PractitionerRoleTableHistory);
        
        db_store:PractitionerRoleTableHistory[] results = check from var item in historyStream 
            where item.PRACTITIONERROLETABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `PractitionerRole/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getRelatedPersonVersion(db_store:Client persistClient, string resourceId, 
                                                      int versionId) returns json|error {
        
        stream<db_store:RelatedPersonTableHistory, error?> historyStream = 
            persistClient->/relatedpersontablehistories(targetType = db_store:RelatedPersonTableHistory);
        
        db_store:RelatedPersonTableHistory[] results = check from var item in historyStream 
            where item.RELATEDPERSONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `RelatedPerson/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getLocationVersion(db_store:Client persistClient, string resourceId, 
                                                 int versionId) returns json|error {
        
        stream<db_store:LocationTableHistory, error?> historyStream = 
            persistClient->/locationtablehistories(targetType = db_store:LocationTableHistory);
        
        db_store:LocationTableHistory[] results = check from var item in historyStream 
            where item.LOCATIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Location/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getServiceRequestVersion(db_store:Client persistClient, string resourceId, 
                                                       int versionId) returns json|error {
        
        stream<db_store:ServiceRequestTableHistory, error?> historyStream = 
            persistClient->/servicerequesttablehistories(targetType = db_store:ServiceRequestTableHistory);
        
        db_store:ServiceRequestTableHistory[] results = check from var item in historyStream 
            where item.SERVICEREQUESTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `ServiceRequest/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getConditionVersion(db_store:Client persistClient, string resourceId, 
                                                  int versionId) returns json|error {
        
        stream<db_store:ConditionTableHistory, error?> historyStream = 
            persistClient->/conditiontablehistories(targetType = db_store:ConditionTableHistory);
        
        db_store:ConditionTableHistory[] results = check from var item in historyStream 
            where item.CONDITIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Condition/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getProcedureVersion(db_store:Client persistClient, string resourceId, 
                                                  int versionId) returns json|error {
        
        stream<db_store:ProcedureTableHistory, error?> historyStream = 
            persistClient->/proceduretablehistories(targetType = db_store:ProcedureTableHistory);
        
        db_store:ProcedureTableHistory[] results = check from var item in historyStream 
            where item.PROCEDURETABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Procedure/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getImmunizationRecommendationVersion(db_store:Client persistClient, string resourceId, 
                                                                    int versionId) returns json|error {
        
        stream<db_store:ImmunizationRecommendationTableHistory, error?> historyStream = 
            persistClient->/immunizationrecommendationtablehistories(targetType = db_store:ImmunizationRecommendationTableHistory);
        
        db_store:ImmunizationRecommendationTableHistory[] results = check from var item in historyStream 
            where item.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `ImmunizationRecommendation/${resourceId}/_history/${versionId} not found`);
        }
        
        string jsonStr = check string:fromBytes(results[0].RESOURCE_JSON);
        json resourceJson = check jsonStr.fromJsonString();
        return resourceJson;
    }

    private isolated function getSlotVersion(db_store:Client persistClient, string resourceId, 
                                            int versionId) returns json|error {
        
        stream<db_store:SlotTableHistory, error?> historyStream = 
            persistClient->/slottablehistories(targetType = db_store:SlotTableHistory);
        
        db_store:SlotTableHistory[] results = check from var item in historyStream 
            where item.SLOTTABLE_ID == resourceId && item.VERSION_ID == versionId 
            select item;
        
        if results.length() == 0 {
            return error(string `Slot/${resourceId}/_history/${versionId} not found`);
        }
        
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
            "Account" => {
                return self.getAccountHistory(persistClient, resourceId);
            }
            "Patient" => {
                return self.getPatientHistory(persistClient, resourceId);
            }
            "Observation" => {
                return self.getObservationHistory(persistClient, resourceId);
            }
            "Invoice" => {
                return self.getInvoiceHistory(persistClient, resourceId);
            }
            "DocumentManifest" => {
                return self.getDocumentManifestHistory(persistClient, resourceId);
            }
            "Consent" => {
                return self.getConsentHistory(persistClient, resourceId);
            }
            "Goal" => {
                return self.getGoalHistory(persistClient, resourceId);
            }
            "MedicinalProductPackaged" => {
                return self.getMedicinalProductPackagedHistory(persistClient, resourceId);
            }
            "MessageDefinition" => {
                return self.getMessageDefinitionHistory(persistClient, resourceId);
            }
            "Endpoint" => {
                return self.getEndpointHistory(persistClient, resourceId);
            }
            "EnrollmentRequest" => {
                return self.getEnrollmentRequestHistory(persistClient, resourceId);
            }
            "EventDefinition" => {
                return self.getEventDefinitionHistory(persistClient, resourceId);
            }
            "Practitioner" => {
                return self.getPractitionerHistory(persistClient, resourceId);
            }
            "Device" => {
                return self.getDeviceHistory(persistClient, resourceId);
            }
            "HealthcareService" => {
                return self.getHealthcareServiceHistory(persistClient, resourceId);
            }
            "PractitionerRole" => {
                return self.getPractitionerRoleHistory(persistClient, resourceId);
            }
            "RelatedPerson" => {
                return self.getRelatedPersonHistory(persistClient, resourceId);
            }
            "Location" => {
                return self.getLocationHistory(persistClient, resourceId);
            }
            "ServiceRequest" => {
                return self.getServiceRequestHistory(persistClient, resourceId);
            }
            "Condition" => {
                return self.getConditionHistory(persistClient, resourceId);
            }
            "Procedure" => {
                return self.getProcedureHistory(persistClient, resourceId);
            }
            "ImmunizationRecommendation" => {
                return self.getImmunizationRecommendationHistory(persistClient, resourceId);
            }
            "Slot" => {
                return self.getSlotHistory(persistClient, resourceId);
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

    // Get all Account versions
    private isolated function getAccountHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:AccountTableHistory, error?> historyStream = 
            persistClient->/accounttablehistories(targetType = db_store:AccountTableHistory);
        
        db_store:AccountTableHistory[] results = check from var item in historyStream 
            where item.ACCOUNTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Invoice versions
    private isolated function getInvoiceHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:InvoiceTableHistory, error?> historyStream = 
            persistClient->/invoicetablehistories(targetType = db_store:InvoiceTableHistory);
        
        db_store:InvoiceTableHistory[] results = check from var item in historyStream 
            where item.INVOICETABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all DocumentManifest versions
    private isolated function getDocumentManifestHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:DocumentManifestTableHistory, error?> historyStream = 
            persistClient->/documentmanifesttablehistories(targetType = db_store:DocumentManifestTableHistory);
        
        db_store:DocumentManifestTableHistory[] results = check from var item in historyStream 
            where item.DOCUMENTMANIFESTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Consent versions
    private isolated function getConsentHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ConsentTableHistory, error?> historyStream = 
            persistClient->/consenttablehistories(targetType = db_store:ConsentTableHistory);
        
        db_store:ConsentTableHistory[] results = check from var item in historyStream 
            where item.CONSENTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Goal versions
    private isolated function getGoalHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:GoalTableHistory, error?> historyStream = 
            persistClient->/goaltablehistories(targetType = db_store:GoalTableHistory);
        
        db_store:GoalTableHistory[] results = check from var item in historyStream 
            where item.GOALTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all MedicinalProductPackaged versions
    private isolated function getMedicinalProductPackagedHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:MedicinalProductPackagedTableHistory, error?> historyStream = 
            persistClient->/medicinalproductpackagedtablehistories(targetType = db_store:MedicinalProductPackagedTableHistory);
        
        db_store:MedicinalProductPackagedTableHistory[] results = check from var item in historyStream 
            where item.MEDICINALPRODUCTPACKAGEDTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all MessageDefinition versions
    private isolated function getMessageDefinitionHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:MessageDefinitionTableHistory, error?> historyStream = 
            persistClient->/messagedefinitiontablehistories(targetType = db_store:MessageDefinitionTableHistory);
        
        db_store:MessageDefinitionTableHistory[] results = check from var item in historyStream 
            where item.MESSAGEDEFINITIONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Endpoint versions
    private isolated function getEndpointHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:EndpointTableHistory, error?> historyStream = 
            persistClient->/endpointtablehistories(targetType = db_store:EndpointTableHistory);
        
        db_store:EndpointTableHistory[] results = check from var item in historyStream 
            where item.ENDPOINTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all EnrollmentRequest versions
    private isolated function getEnrollmentRequestHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:EnrollmentRequestTableHistory, error?> historyStream = 
            persistClient->/enrollmentrequesttablehistories(targetType = db_store:EnrollmentRequestTableHistory);
        
        db_store:EnrollmentRequestTableHistory[] results = check from var item in historyStream 
            where item.ENROLLMENTREQUESTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all EventDefinition versions
    private isolated function getEventDefinitionHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:EventDefinitionTableHistory, error?> historyStream = 
            persistClient->/eventdefinitiontablehistories(targetType = db_store:EventDefinitionTableHistory);
        
        db_store:EventDefinitionTableHistory[] results = check from var item in historyStream 
            where item.EVENTDEFINITIONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getPractitionerHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:PractitionerTableHistory, error?> historyStream = 
            persistClient->/practitionertablehistories(targetType = db_store:PractitionerTableHistory);
        
        db_store:PractitionerTableHistory[] results = check from var item in historyStream 
            where item.PRACTITIONERTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getDeviceHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:DeviceTableHistory, error?> historyStream = 
            persistClient->/devicetablehistories(targetType = db_store:DeviceTableHistory);
        
        db_store:DeviceTableHistory[] results = check from var item in historyStream 
            where item.DEVICETABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getHealthcareServiceHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:HealthcareServiceTableHistory, error?> historyStream = 
            persistClient->/healthcareservicetablehistories(targetType = db_store:HealthcareServiceTableHistory);
        
        db_store:HealthcareServiceTableHistory[] results = check from var item in historyStream 
            where item.HEALTHCARESERVICETABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getPractitionerRoleHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:PractitionerRoleTableHistory, error?> historyStream = 
            persistClient->/practitionerroletablehistories(targetType = db_store:PractitionerRoleTableHistory);
        
        db_store:PractitionerRoleTableHistory[] results = check from var item in historyStream 
            where item.PRACTITIONERROLETABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getRelatedPersonHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:RelatedPersonTableHistory, error?> historyStream = 
            persistClient->/relatedpersontablehistories(targetType = db_store:RelatedPersonTableHistory);
        
        db_store:RelatedPersonTableHistory[] results = check from var item in historyStream 
            where item.RELATEDPERSONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getLocationHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:LocationTableHistory, error?> historyStream = 
            persistClient->/locationtablehistories(targetType = db_store:LocationTableHistory);
        
        db_store:LocationTableHistory[] results = check from var item in historyStream 
            where item.LOCATIONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getServiceRequestHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ServiceRequestTableHistory, error?> historyStream = 
            persistClient->/servicerequesttablehistories(targetType = db_store:ServiceRequestTableHistory);
        
        db_store:ServiceRequestTableHistory[] results = check from var item in historyStream 
            where item.SERVICEREQUESTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getConditionHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ConditionTableHistory, error?> historyStream = 
            persistClient->/conditiontablehistories(targetType = db_store:ConditionTableHistory);
        
        db_store:ConditionTableHistory[] results = check from var item in historyStream 
            where item.CONDITIONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getProcedureHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ProcedureTableHistory, error?> historyStream = 
            persistClient->/proceduretablehistories(targetType = db_store:ProcedureTableHistory);
        
        db_store:ProcedureTableHistory[] results = check from var item in historyStream 
            where item.PROCEDURETABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getImmunizationRecommendationHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ImmunizationRecommendationTableHistory, error?> historyStream = 
            persistClient->/immunizationrecommendationtablehistories(targetType = db_store:ImmunizationRecommendationTableHistory);
        
        db_store:ImmunizationRecommendationTableHistory[] results = check from var item in historyStream 
            where item.IMMUNIZATIONRECOMMENDATIONTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    private isolated function getSlotHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:SlotTableHistory, error?> historyStream = 
            persistClient->/slottablehistories(targetType = db_store:SlotTableHistory);
        
        db_store:SlotTableHistory[] results = check from var item in historyStream 
            where item.SLOTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Patient versions
    private isolated function getPatientHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:PatientTableHistory, error?> historyStream = 
            persistClient->/patienttablehistories(targetType = db_store:PatientTableHistory);
        
        db_store:PatientTableHistory[] results = check from var item in historyStream 
            where item.PATIENTTABLE_ID == resourceId 
            select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Observation versions
    private isolated function getObservationHistory(db_store:Client persistClient, string resourceId) returns json[]|error {
        
        stream<db_store:ObservationTableHistory, error?> historyStream = 
            persistClient->/observationtablehistories(targetType = db_store:ObservationTableHistory);
        
        db_store:ObservationTableHistory[] results = check from var item in historyStream 
            where item.OBSERVATIONTABLE_ID == resourceId 
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
            "Account" => {
                return self.getAllAccountHistory(persistClient);
            }
            "Patient" => {
                return self.getAllPatientHistory(persistClient);
            }
            "Observation" => {
                return self.getAllObservationHistory(persistClient);
            }
            "Invoice" => {
                return self.getAllInvoiceHistory(persistClient);
            }
            "DocumentManifest" => {
                return self.getAllDocumentManifestHistory(persistClient);
            }
            "Consent" => {
                return self.getAllConsentHistory(persistClient);
            }
            "Goal" => {
                return self.getAllGoalHistory(persistClient);
            }
            "MedicinalProductPackaged" => {
                return self.getAllMedicinalProductPackagedHistory(persistClient);
            }
            "MessageDefinition" => {
                return self.getAllMessageDefinitionHistory(persistClient);
            }
            "Endpoint" => {
                return self.getAllEndpointHistory(persistClient);
            }
            "EnrollmentRequest" => {
                return self.getAllEnrollmentRequestHistory(persistClient);
            }
            "EventDefinition" => {
                return self.getAllEventDefinitionHistory(persistClient);
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

    // Get all Invoice history (system-wide)
    private isolated function getAllInvoiceHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:InvoiceTableHistory, error?> historyStream = 
            persistClient->/invoicetablehistories(targetType = db_store:InvoiceTableHistory);
        
        db_store:InvoiceTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all DocumentManifest history (system-wide)
    private isolated function getAllDocumentManifestHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:DocumentManifestTableHistory, error?> historyStream = 
            persistClient->/documentmanifesttablehistories(targetType = db_store:DocumentManifestTableHistory);
        
        db_store:DocumentManifestTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Consent history (system-wide)
    private isolated function getAllConsentHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:ConsentTableHistory, error?> historyStream = 
            persistClient->/consenttablehistories(targetType = db_store:ConsentTableHistory);
        
        db_store:ConsentTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Goal history (system-wide)
    private isolated function getAllGoalHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:GoalTableHistory, error?> historyStream = 
            persistClient->/goaltablehistories(targetType = db_store:GoalTableHistory);
        
        db_store:GoalTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all MedicinalProductPackaged history (system-wide)
    private isolated function getAllMedicinalProductPackagedHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:MedicinalProductPackagedTableHistory, error?> historyStream = 
            persistClient->/medicinalproductpackagedtablehistories(targetType = db_store:MedicinalProductPackagedTableHistory);
        
        db_store:MedicinalProductPackagedTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all MessageDefinition history (system-wide)
    private isolated function getAllMessageDefinitionHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:MessageDefinitionTableHistory, error?> historyStream = 
            persistClient->/messagedefinitiontablehistories(targetType = db_store:MessageDefinitionTableHistory);
        
        db_store:MessageDefinitionTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Endpoint history (system-wide)
    private isolated function getAllEndpointHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:EndpointTableHistory, error?> historyStream = 
            persistClient->/endpointtablehistories(targetType = db_store:EndpointTableHistory);
        
        db_store:EndpointTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all EnrollmentRequest history (system-wide)
    private isolated function getAllEnrollmentRequestHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:EnrollmentRequestTableHistory, error?> historyStream = 
            persistClient->/enrollmentrequesttablehistories(targetType = db_store:EnrollmentRequestTableHistory);
        
        db_store:EnrollmentRequestTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all EventDefinition history (system-wide)
    private isolated function getAllEventDefinitionHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:EventDefinitionTableHistory, error?> historyStream = 
            persistClient->/eventdefinitiontablehistories(targetType = db_store:EventDefinitionTableHistory);
        
        db_store:EventDefinitionTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Account history (system-wide)
    private isolated function getAllAccountHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:AccountTableHistory, error?> historyStream = 
            persistClient->/accounttablehistories(targetType = db_store:AccountTableHistory);
        
        db_store:AccountTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Patient history (system-wide)
    private isolated function getAllPatientHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:PatientTableHistory, error?> historyStream = 
            persistClient->/patienttablehistories(targetType = db_store:PatientTableHistory);
        
        db_store:PatientTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }

    // Get all Observation history (system-wide)
    private isolated function getAllObservationHistory(db_store:Client persistClient) returns json[]|error {
        
        stream<db_store:ObservationTableHistory, error?> historyStream = 
            persistClient->/observationtablehistories(targetType = db_store:ObservationTableHistory);
        
        db_store:ObservationTableHistory[] results = check from var item in historyStream select item;
        
        json[] versions = [];
        foreach var historyRecord in results {
            string jsonStr = check string:fromBytes(historyRecord.RESOURCE_JSON);
            json resourceJson = check jsonStr.fromJsonString();
            versions.push(resourceJson);
        }
        
        return versions;
    }
}
