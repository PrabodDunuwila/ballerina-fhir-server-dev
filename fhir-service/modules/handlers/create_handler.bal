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
            "ActivityDefinition" => {
                db_store:ActivityDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/activitydefinitiontables.post([insert]);
                return recordIds[0];
            }
            "AdverseEvent" => {
                db_store:AdverseEventTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/adverseeventtables.post([insert]);
                return recordIds[0];
            }
            "AllergyIntolerance" => {
                db_store:AllergyIntoleranceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/allergyintolerancetables.post([insert]);
                return recordIds[0];
            }
            "Appointment" => {
                db_store:AppointmentTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/appointmenttables.post([insert]);
                return recordIds[0];
            }
            "AppointmentResponse" => {
                db_store:AppointmentResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/appointmentresponsetables.post([insert]);
                return recordIds[0];
            }
            "AuditEvent" => {
                db_store:AuditEventTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/auditeventtables.post([insert]);
                return recordIds[0];
            }
            "Basic" => {
                db_store:BasicTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/basictables.post([insert]);
                return recordIds[0];
            }
            "BodyStructure" => {
                db_store:BodyStructureTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/bodystructuretables.post([insert]);
                return recordIds[0];
            }
            "Bundle" => {
                db_store:BundleTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/bundletables.post([insert]);
                return recordIds[0];
            }
            "CapabilityStatement" => {
                db_store:CapabilityStatementTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/capabilitystatementtables.post([insert]);
                return recordIds[0];
            }
            "CarePlan" => {
                db_store:CarePlanTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/careplantables.post([insert]);
                return recordIds[0];
            }
            "CareTeam" => {
                db_store:CareTeamTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/careteamtables.post([insert]);
                return recordIds[0];
            }
            "ChargeItem" => {
                db_store:ChargeItemTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/chargeitemtables.post([insert]);
                return recordIds[0];
            }
            "ChargeItemDefinition" => {
                db_store:ChargeItemDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/chargeitemdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Claim" => {
                db_store:ClaimTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/claimtables.post([insert]);
                return recordIds[0];
            }
            "ClaimResponse" => {
                db_store:ClaimResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/claimresponsetables.post([insert]);
                return recordIds[0];
            }
            "ClinicalImpression" => {
                db_store:ClinicalImpressionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/clinicalimpressiontables.post([insert]);
                return recordIds[0];
            }
            "CodeSystem" => {
                db_store:CodeSystemTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/codesystemtables.post([insert]);
                return recordIds[0];
            }
            "Communication" => {
                db_store:CommunicationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/communicationtables.post([insert]);
                return recordIds[0];
            }
            "CommunicationRequest" => {
                db_store:CommunicationRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/communicationrequesttables.post([insert]);
                return recordIds[0];
            }
            "CompartmentDefinition" => {
                db_store:CompartmentDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/compartmentdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Composition" => {
                db_store:CompositionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/compositiontables.post([insert]);
                return recordIds[0];
            }
            "ConceptMap" => {
                db_store:ConceptMapTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/conceptmaptables.post([insert]);
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
            "Contract" => {
                db_store:ContractTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/contracttables.post([insert]);
                return recordIds[0];
            }
            "Coverage" => {
                db_store:CoverageTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/coveragetables.post([insert]);
                return recordIds[0];
            }
            "CoverageEligibilityRequest" => {
                db_store:CoverageEligibilityRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/coverageeligibilityrequesttables.post([insert]);
                return recordIds[0];
            }
            "CoverageEligibilityResponse" => {
                db_store:CoverageEligibilityResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/coverageeligibilityresponsetables.post([insert]);
                return recordIds[0];
            }
            "DetectedIssue" => {
                db_store:DetectedIssueTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/detectedissuetables.post([insert]);
                return recordIds[0];
            }
            "Device" => {
                db_store:DeviceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicetables.post([insert]);
                return recordIds[0];
            }
            "DeviceDefinition" => {
                db_store:DeviceDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicedefinitiontables.post([insert]);
                return recordIds[0];
            }
            "DeviceMetric" => {
                db_store:DeviceMetricTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicemetrictables.post([insert]);
                return recordIds[0];
            }
            "DeviceRequest" => {
                db_store:DeviceRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/devicerequesttables.post([insert]);
                return recordIds[0];
            }
            "DeviceUseStatement" => {
                db_store:DeviceUseStatementTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/deviceusestatementtables.post([insert]);
                return recordIds[0];
            }
            "DiagnosticReport" => {
                db_store:DiagnosticReportTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/diagnosticreporttables.post([insert]);
                return recordIds[0];
            }
            "DocumentManifest" => {
                db_store:DocumentManifestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/documentmanifesttables.post([insert]);
                return recordIds[0];
            }
            "DocumentReference" => {
                db_store:DocumentReferenceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/documentreferencetables.post([insert]);
                return recordIds[0];
            }
            "EffectEvidenceSynthesis" => {
                db_store:EffectEvidenceSynthesisTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/effectevidencesynthesistables.post([insert]);
                return recordIds[0];
            }
            "Encounter" => {
                db_store:EncounterTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/encountertables.post([insert]);
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
            "EnrollmentResponse" => {
                db_store:EnrollmentResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/enrollmentresponsetables.post([insert]);
                return recordIds[0];
            }
            "EpisodeOfCare" => {
                db_store:EpisodeOfCareTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/episodeofcaretables.post([insert]);
                return recordIds[0];
            }
            "EventDefinition" => {
                db_store:EventDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/eventdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Evidence" => {
                db_store:EvidenceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/evidencetables.post([insert]);
                return recordIds[0];
            }
            "EvidenceVariable" => {
                db_store:EvidenceVariableTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/evidencevariabletables.post([insert]);
                return recordIds[0];
            }
            "ExampleScenario" => {
                db_store:ExampleScenarioTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/examplescenariotables.post([insert]);
                return recordIds[0];
            }
            "ExplanationOfBenefit" => {
                db_store:ExplanationOfBenefitTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/explanationofbenefittables.post([insert]);
                return recordIds[0];
            }
            "FamilyMemberHistory" => {
                db_store:FamilyMemberHistoryTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/familymemberhistorytables.post([insert]);
                return recordIds[0];
            }
            "Flag" => {
                db_store:FlagTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/flagtables.post([insert]);
                return recordIds[0];
            }
            "Goal" => {
                db_store:GoalTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/goaltables.post([insert]);
                return recordIds[0];
            }
            "GraphDefinition" => {
                db_store:GraphDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/graphdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Group" => {
                db_store:GroupTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/grouptables.post([insert]);
                return recordIds[0];
            }
            "GuidanceResponse" => {
                db_store:GuidanceResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/guidanceresponsetables.post([insert]);
                return recordIds[0];
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/healthcareservicetables.post([insert]);
                return recordIds[0];
            }
            "ImagingStudy" => {
                db_store:ImagingStudyTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/imagingstudytables.post([insert]);
                return recordIds[0];
            }
            "Immunization" => {
                db_store:ImmunizationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/immunizationtables.post([insert]);
                return recordIds[0];
            }
            "ImmunizationEvaluation" => {
                db_store:ImmunizationEvaluationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/immunizationevaluationtables.post([insert]);
                return recordIds[0];
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/immunizationrecommendationtables.post([insert]);
                return recordIds[0];
            }
            "ImplementationGuide" => {
                db_store:ImplementationGuideTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/implementationguidetables.post([insert]);
                return recordIds[0];
            }
            "InsurancePlan" => {
                db_store:InsurancePlanTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/insuranceplantables.post([insert]);
                return recordIds[0];
            }
            "Invoice" => {
                db_store:InvoiceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/invoicetables.post([insert]);
                return recordIds[0];
            }
            "Library" => {
                db_store:LibraryTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/librarytables.post([insert]);
                return recordIds[0];
            }
            "Linkage" => {
                db_store:LinkageTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/linkagetables.post([insert]);
                return recordIds[0];
            }
            "List" => {
                db_store:ListTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/listtables.post([insert]);
                return recordIds[0];
            }
            "Location" => {
                db_store:LocationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/locationtables.post([insert]);
                return recordIds[0];
            }
            "Measure" => {
                db_store:MeasureTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/measuretables.post([insert]);
                return recordIds[0];
            }
            "MeasureReport" => {
                db_store:MeasureReportTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/measurereporttables.post([insert]);
                return recordIds[0];
            }
            "Media" => {
                db_store:MediaTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/mediatables.post([insert]);
                return recordIds[0];
            }
            "Medication" => {
                db_store:MedicationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationtables.post([insert]);
                return recordIds[0];
            }
            "MedicationAdministration" => {
                db_store:MedicationAdministrationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationadministrationtables.post([insert]);
                return recordIds[0];
            }
            "MedicationDispense" => {
                db_store:MedicationDispenseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationdispensetables.post([insert]);
                return recordIds[0];
            }
            "MedicationKnowledge" => {
                db_store:MedicationKnowledgeTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationknowledgetables.post([insert]);
                return recordIds[0];
            }
            "MedicationRequest" => {
                db_store:MedicationRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationrequesttables.post([insert]);
                return recordIds[0];
            }
            "MedicationStatement" => {
                db_store:MedicationStatementTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicationstatementtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProduct" => {
                db_store:MedicinalProductTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproducttables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductAuthorization" => {
                db_store:MedicinalProductAuthorizationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductauthorizationtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductContraindication" => {
                db_store:MedicinalProductContraindicationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductcontraindicationtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductIndication" => {
                db_store:MedicinalProductIndicationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductindicationtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductInteraction" => {
                db_store:MedicinalProductInteractionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductinteractiontables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductpackagedtables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductPharmaceutical" => {
                db_store:MedicinalProductPharmaceuticalTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductpharmaceuticaltables.post([insert]);
                return recordIds[0];
            }
            "MedicinalProductUndesirableEffect" => {
                db_store:MedicinalProductUndesirableEffectTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/medicinalproductundesirableeffecttables.post([insert]);
                return recordIds[0];
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/messagedefinitiontables.post([insert]);
                return recordIds[0];
            }
            "MessageHeader" => {
                db_store:MessageHeaderTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/messageheadertables.post([insert]);
                return recordIds[0];
            }
            "MolecularSequence" => {
                db_store:MolecularSequenceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/molecularsequencetables.post([insert]);
                return recordIds[0];
            }
            "NamingSystem" => {
                db_store:NamingSystemTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/namingsystemtables.post([insert]);
                return recordIds[0];
            }
            "NutritionOrder" => {
                db_store:NutritionOrderTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/nutritionordertables.post([insert]);
                return recordIds[0];
            }
            "Observation" => {
                db_store:ObservationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/observationtables.post([insert]);
                return recordIds[0];
            }
            "OperationDefinition" => {
                db_store:OperationDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/operationdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "Organization" => {
                db_store:OrganizationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/organizationtables.post([insert]);
                return recordIds[0];
            }
            "OrganizationAffiliation" => {
                db_store:OrganizationAffiliationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/organizationaffiliationtables.post([insert]);
                return recordIds[0];
            }
            "Patient" => {
                db_store:PatientTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/patienttables.post([insert]);
                return recordIds[0];
            }
            "PaymentNotice" => {
                db_store:PaymentNoticeTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/paymentnoticetables.post([insert]);
                return recordIds[0];
            }
            "PaymentReconciliation" => {
                db_store:PaymentReconciliationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/paymentreconciliationtables.post([insert]);
                return recordIds[0];
            }
            "Person" => {
                db_store:PersonTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/persontables.post([insert]);
                return recordIds[0];
            }
            "PlanDefinition" => {
                db_store:PlanDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/plandefinitiontables.post([insert]);
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
            "Provenance" => {
                db_store:ProvenanceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/provenancetables.post([insert]);
                return recordIds[0];
            }
            "Questionnaire" => {
                db_store:QuestionnaireTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/questionnairetables.post([insert]);
                return recordIds[0];
            }
            "QuestionnaireResponse" => {
                db_store:QuestionnaireResponseTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/questionnaireresponsetables.post([insert]);
                return recordIds[0];
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/relatedpersontables.post([insert]);
                return recordIds[0];
            }
            "RequestGroup" => {
                db_store:RequestGroupTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/requestgrouptables.post([insert]);
                return recordIds[0];
            }
            "ResearchDefinition" => {
                db_store:ResearchDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/researchdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "ResearchElementDefinition" => {
                db_store:ResearchElementDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/researchelementdefinitiontables.post([insert]);
                return recordIds[0];
            }
            "ResearchStudy" => {
                db_store:ResearchStudyTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/researchstudytables.post([insert]);
                return recordIds[0];
            }
            "ResearchSubject" => {
                db_store:ResearchSubjectTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/researchsubjecttables.post([insert]);
                return recordIds[0];
            }
            "RiskAssessment" => {
                db_store:RiskAssessmentTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/riskassessmenttables.post([insert]);
                return recordIds[0];
            }
            "RiskEvidenceSynthesis" => {
                db_store:RiskEvidenceSynthesisTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/riskevidencesynthesistables.post([insert]);
                return recordIds[0];
            }
            "Schedule" => {
                db_store:ScheduleTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/scheduletables.post([insert]);
                return recordIds[0];
            }
            "SearchParameter" => {
                db_store:SearchParameterTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/searchparametertables.post([insert]);
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
            "Specimen" => {
                db_store:SpecimenTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/specimentables.post([insert]);
                return recordIds[0];
            }
            "SpecimenDefinition" => {
                db_store:SpecimenDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/specimendefinitiontables.post([insert]);
                return recordIds[0];
            }
            "StructureDefinition" => {
                db_store:StructureDefinitionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/structuredefinitiontables.post([insert]);
                return recordIds[0];
            }
            "StructureMap" => {
                db_store:StructureMapTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/structuremaptables.post([insert]);
                return recordIds[0];
            }
            "Subscription" => {
                db_store:SubscriptionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/subscriptiontables.post([insert]);
                return recordIds[0];
            }
            "Substance" => {
                db_store:SubstanceTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/substancetables.post([insert]);
                return recordIds[0];
            }
            "SubstanceSpecification" => {
                db_store:SubstanceSpecificationTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/substancespecificationtables.post([insert]);
                return recordIds[0];
            }
            "SupplyDelivery" => {
                db_store:SupplyDeliveryTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/supplydeliverytables.post([insert]);
                return recordIds[0];
            }
            "SupplyRequest" => {
                db_store:SupplyRequestTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/supplyrequesttables.post([insert]);
                return recordIds[0];
            }
            "Task" => {
                db_store:TaskTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/tasktables.post([insert]);
                return recordIds[0];
            }
            "TerminologyCapabilities" => {
                db_store:TerminologyCapabilitiesTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/terminologycapabilitiestables.post([insert]);
                return recordIds[0];
            }
            "TestReport" => {
                db_store:TestReportTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/testreporttables.post([insert]);
                return recordIds[0];
            }
            "TestScript" => {
                db_store:TestScriptTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/testscripttables.post([insert]);
                return recordIds[0];
            }
            "ValueSet" => {
                db_store:ValueSetTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/valuesettables.post([insert]);
                return recordIds[0];
            }
            "VerificationResult" => {
                db_store:VerificationResultTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/verificationresulttables.post([insert]);
                return recordIds[0];
            }
            "VisionPrescription" => {
                db_store:VisionPrescriptionTableInsert insert = check insertModel.cloneWithType();
                string[] recordIds = check persistClient->/visionprescriptiontables.post([insert]);
                return recordIds[0];
            }
            _ => {
                return error(string `Unsupported resource type for saving: ${resourceType}`);
            }
        }
    }
}
