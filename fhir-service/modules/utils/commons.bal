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
        "ActivityDefinition" => { _ = check persistClient->/activitydefinitiontables/[resourceId].delete(); }
        "AdverseEvent" => { _ = check persistClient->/adverseeventtables/[resourceId].delete(); }
        "AllergyIntolerance" => { _ = check persistClient->/allergyintolerancetables/[resourceId].delete(); }
        "Appointment" => { _ = check persistClient->/appointmenttables/[resourceId].delete(); }
        "AppointmentResponse" => { _ = check persistClient->/appointmentresponsetables/[resourceId].delete(); }
        "AuditEvent" => { _ = check persistClient->/auditeventtables/[resourceId].delete(); }
        "Basic" => { _ = check persistClient->/basictables/[resourceId].delete(); }
        "BodyStructure" => { _ = check persistClient->/bodystructuretables/[resourceId].delete(); }
        "Bundle" => { _ = check persistClient->/bundletables/[resourceId].delete(); }
        "CapabilityStatement" => { _ = check persistClient->/capabilitystatementtables/[resourceId].delete(); }
        "CarePlan" => { _ = check persistClient->/careplantables/[resourceId].delete(); }
        "CareTeam" => { _ = check persistClient->/careteamtables/[resourceId].delete(); }
        "ChargeItem" => { _ = check persistClient->/chargeitemtables/[resourceId].delete(); }
        "ChargeItemDefinition" => { _ = check persistClient->/chargeitemdefinitiontables/[resourceId].delete(); }
        "Claim" => { _ = check persistClient->/claimtables/[resourceId].delete(); }
        "ClaimResponse" => { _ = check persistClient->/claimresponsetables/[resourceId].delete(); }
        "ClinicalImpression" => { _ = check persistClient->/clinicalimpressiontables/[resourceId].delete(); }
        "CodeSystem" => { _ = check persistClient->/codesystemtables/[resourceId].delete(); }
        "Communication" => { _ = check persistClient->/communicationtables/[resourceId].delete(); }
        "CommunicationRequest" => { _ = check persistClient->/communicationrequesttables/[resourceId].delete(); }
        "CompartmentDefinition" => { _ = check persistClient->/compartmentdefinitiontables/[resourceId].delete(); }
        "Composition" => { _ = check persistClient->/compositiontables/[resourceId].delete(); }
        "ConceptMap" => { _ = check persistClient->/conceptmaptables/[resourceId].delete(); }
        "Condition" => { _ = check persistClient->/conditiontables/[resourceId].delete(); }
        "Consent" => { _ = check persistClient->/consenttables/[resourceId].delete(); }
        "Contract" => { _ = check persistClient->/contracttables/[resourceId].delete(); }
        "Coverage" => { _ = check persistClient->/coveragetables/[resourceId].delete(); }
        "CoverageEligibilityRequest" => { _ = check persistClient->/coverageeligibilityrequesttables/[resourceId].delete(); }
        "CoverageEligibilityResponse" => { _ = check persistClient->/coverageeligibilityresponsetables/[resourceId].delete(); }
        "DetectedIssue" => { _ = check persistClient->/detectedissuetables/[resourceId].delete(); }
        "Device" => { _ = check persistClient->/devicetables/[resourceId].delete(); }
        "DeviceDefinition" => { _ = check persistClient->/devicedefinitiontables/[resourceId].delete(); }
        "DeviceMetric" => { _ = check persistClient->/devicemetrictables/[resourceId].delete(); }
        "DeviceRequest" => { _ = check persistClient->/devicerequesttables/[resourceId].delete(); }
        "DeviceUseStatement" => { _ = check persistClient->/deviceusestatementtables/[resourceId].delete(); }
        "DiagnosticReport" => { _ = check persistClient->/diagnosticreporttables/[resourceId].delete(); }
        "DocumentManifest" => { _ = check persistClient->/documentmanifesttables/[resourceId].delete(); }
        "DocumentReference" => { _ = check persistClient->/documentreferencetables/[resourceId].delete(); }
        "EffectEvidenceSynthesis" => { _ = check persistClient->/effectevidencesynthesistables/[resourceId].delete(); }
        "Encounter" => { _ = check persistClient->/encountertables/[resourceId].delete(); }
        "Endpoint" => { _ = check persistClient->/endpointtables/[resourceId].delete(); }
        "EnrollmentRequest" => { _ = check persistClient->/enrollmentrequesttables/[resourceId].delete(); }
        "EnrollmentResponse" => { _ = check persistClient->/enrollmentresponsetables/[resourceId].delete(); }
        "EpisodeOfCare" => { _ = check persistClient->/episodeofcaretables/[resourceId].delete(); }
        "EventDefinition" => { _ = check persistClient->/eventdefinitiontables/[resourceId].delete(); }
        "Evidence" => { _ = check persistClient->/evidencetables/[resourceId].delete(); }
        "EvidenceVariable" => { _ = check persistClient->/evidencevariabletables/[resourceId].delete(); }
        "ExampleScenario" => { _ = check persistClient->/examplescenariotables/[resourceId].delete(); }
        "ExplanationOfBenefit" => { _ = check persistClient->/explanationofbenefittables/[resourceId].delete(); }
        "FamilyMemberHistory" => { _ = check persistClient->/familymemberhistorytables/[resourceId].delete(); }
        "Flag" => { _ = check persistClient->/flagtables/[resourceId].delete(); }
        "Goal" => { _ = check persistClient->/goaltables/[resourceId].delete(); }
        "GraphDefinition" => { _ = check persistClient->/graphdefinitiontables/[resourceId].delete(); }
        "Group" => { _ = check persistClient->/grouptables/[resourceId].delete(); }
        "GuidanceResponse" => { _ = check persistClient->/guidanceresponsetables/[resourceId].delete(); }
        "HealthcareService" => { _ = check persistClient->/healthcareservicetables/[resourceId].delete(); }
        "ImagingStudy" => { _ = check persistClient->/imagingstudytables/[resourceId].delete(); }
        "Immunization" => { _ = check persistClient->/immunizationtables/[resourceId].delete(); }
        "ImmunizationEvaluation" => { _ = check persistClient->/immunizationevaluationtables/[resourceId].delete(); }
        "ImmunizationRecommendation" => { _ = check persistClient->/immunizationrecommendationtables/[resourceId].delete(); }
        "ImplementationGuide" => { _ = check persistClient->/implementationguidetables/[resourceId].delete(); }
        "InsurancePlan" => { _ = check persistClient->/insuranceplantables/[resourceId].delete(); }
        "Invoice" => { _ = check persistClient->/invoicetables/[resourceId].delete(); }
        "Library" => { _ = check persistClient->/librarytables/[resourceId].delete(); }
        "Linkage" => { _ = check persistClient->/linkagetables/[resourceId].delete(); }
        "List" => { _ = check persistClient->/listtables/[resourceId].delete(); }
        "Location" => { _ = check persistClient->/locationtables/[resourceId].delete(); }
        "Measure" => { _ = check persistClient->/measuretables/[resourceId].delete(); }
        "MeasureReport" => { _ = check persistClient->/measurereporttables/[resourceId].delete(); }
        "Media" => { _ = check persistClient->/mediatables/[resourceId].delete(); }
        "Medication" => { _ = check persistClient->/medicationtables/[resourceId].delete(); }
        "MedicationAdministration" => { _ = check persistClient->/medicationadministrationtables/[resourceId].delete(); }
        "MedicationDispense" => { _ = check persistClient->/medicationdispensetables/[resourceId].delete(); }
        "MedicationKnowledge" => { _ = check persistClient->/medicationknowledgetables/[resourceId].delete(); }
        "MedicationRequest" => { _ = check persistClient->/medicationrequesttables/[resourceId].delete(); }
        "MedicationStatement" => { _ = check persistClient->/medicationstatementtables/[resourceId].delete(); }
        "MedicinalProduct" => { _ = check persistClient->/medicinalproducttables/[resourceId].delete(); }
        "MedicinalProductAuthorization" => { _ = check persistClient->/medicinalproductauthorizationtables/[resourceId].delete(); }
        "MedicinalProductContraindication" => { _ = check persistClient->/medicinalproductcontraindicationtables/[resourceId].delete(); }
        "MedicinalProductIndication" => { _ = check persistClient->/medicinalproductindicationtables/[resourceId].delete(); }
        "MedicinalProductInteraction" => { _ = check persistClient->/medicinalproductinteractiontables/[resourceId].delete(); }
        "MedicinalProductPackaged" => { _ = check persistClient->/medicinalproductpackagedtables/[resourceId].delete(); }
        "MedicinalProductPharmaceutical" => { _ = check persistClient->/medicinalproductpharmaceuticaltables/[resourceId].delete(); }
        "MedicinalProductUndesirableEffect" => { _ = check persistClient->/medicinalproductundesirableeffecttables/[resourceId].delete(); }
        "MessageDefinition" => { _ = check persistClient->/messagedefinitiontables/[resourceId].delete(); }
        "MessageHeader" => { _ = check persistClient->/messageheadertables/[resourceId].delete(); }
        "MolecularSequence" => { _ = check persistClient->/molecularsequencetables/[resourceId].delete(); }
        "NamingSystem" => { _ = check persistClient->/namingsystemtables/[resourceId].delete(); }
        "NutritionOrder" => { _ = check persistClient->/nutritionordertables/[resourceId].delete(); }
        "Observation" => { _ = check persistClient->/observationtables/[resourceId].delete(); }
        "OperationDefinition" => { _ = check persistClient->/operationdefinitiontables/[resourceId].delete(); }
        "Organization" => { _ = check persistClient->/organizationtables/[resourceId].delete(); }
        "OrganizationAffiliation" => { _ = check persistClient->/organizationaffiliationtables/[resourceId].delete(); }
        "Patient" => { _ = check persistClient->/patienttables/[resourceId].delete(); }
        "PaymentNotice" => { _ = check persistClient->/paymentnoticetables/[resourceId].delete(); }
        "PaymentReconciliation" => { _ = check persistClient->/paymentreconciliationtables/[resourceId].delete(); }
        "Person" => { _ = check persistClient->/persontables/[resourceId].delete(); }
        "PlanDefinition" => { _ = check persistClient->/plandefinitiontables/[resourceId].delete(); }
        "Practitioner" => { _ = check persistClient->/practitionertables/[resourceId].delete(); }
        "PractitionerRole" => { _ = check persistClient->/practitionerroletables/[resourceId].delete(); }
        "Procedure" => { _ = check persistClient->/proceduretables/[resourceId].delete(); }
        "Provenance" => { _ = check persistClient->/provenancetables/[resourceId].delete(); }
        "Questionnaire" => { _ = check persistClient->/questionnairetables/[resourceId].delete(); }
        "QuestionnaireResponse" => { _ = check persistClient->/questionnaireresponsetables/[resourceId].delete(); }
        "RelatedPerson" => { _ = check persistClient->/relatedpersontables/[resourceId].delete(); }
        "RequestGroup" => { _ = check persistClient->/requestgrouptables/[resourceId].delete(); }
        "ResearchDefinition" => { _ = check persistClient->/researchdefinitiontables/[resourceId].delete(); }
        "ResearchElementDefinition" => { _ = check persistClient->/researchelementdefinitiontables/[resourceId].delete(); }
        "ResearchStudy" => { _ = check persistClient->/researchstudytables/[resourceId].delete(); }
        "ResearchSubject" => { _ = check persistClient->/researchsubjecttables/[resourceId].delete(); }
        "RiskAssessment" => { _ = check persistClient->/riskassessmenttables/[resourceId].delete(); }
        "RiskEvidenceSynthesis" => { _ = check persistClient->/riskevidencesynthesistables/[resourceId].delete(); }
        "Schedule" => { _ = check persistClient->/scheduletables/[resourceId].delete(); }
        "SearchParameter" => { _ = check persistClient->/searchparametertables/[resourceId].delete(); }
        "ServiceRequest" => { _ = check persistClient->/servicerequesttables/[resourceId].delete(); }
        "Slot" => { _ = check persistClient->/slottables/[resourceId].delete(); }
        "Specimen" => { _ = check persistClient->/specimentables/[resourceId].delete(); }
        "SpecimenDefinition" => { _ = check persistClient->/specimendefinitiontables/[resourceId].delete(); }
        "StructureDefinition" => { _ = check persistClient->/structuredefinitiontables/[resourceId].delete(); }
        "StructureMap" => { _ = check persistClient->/structuremaptables/[resourceId].delete(); }
        "Subscription" => { _ = check persistClient->/subscriptiontables/[resourceId].delete(); }
        "Substance" => { _ = check persistClient->/substancetables/[resourceId].delete(); }
        "SubstanceSpecification" => { _ = check persistClient->/substancespecificationtables/[resourceId].delete(); }
        "SupplyDelivery" => { _ = check persistClient->/supplydeliverytables/[resourceId].delete(); }
        "SupplyRequest" => { _ = check persistClient->/supplyrequesttables/[resourceId].delete(); }
        "Task" => { _ = check persistClient->/tasktables/[resourceId].delete(); }
        "TerminologyCapabilities" => { _ = check persistClient->/terminologycapabilitiestables/[resourceId].delete(); }
        "TestReport" => { _ = check persistClient->/testreporttables/[resourceId].delete(); }
        "TestScript" => { _ = check persistClient->/testscripttables/[resourceId].delete(); }
        "ValueSet" => { _ = check persistClient->/valuesettables/[resourceId].delete(); }
        "VerificationResult" => { _ = check persistClient->/verificationresulttables/[resourceId].delete(); }
        "VisionPrescription" => { _ = check persistClient->/visionprescriptiontables/[resourceId].delete(); }
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
