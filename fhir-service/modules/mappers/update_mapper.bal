import ballerina_fhir_server.db_store;

import ballerina/io;
import ballerina/time;

public class UpdateMapper {
    private json[] references;

    public isolated function init() {
        self.references = [];
    }

    // This function will map values to persist update models
    public isolated function mapToUpdateModel(db_store:Client persistClient, string resourceType, json resourceJson, int newVersion = 2) returns record {|anydata...;|}|error? {
        FHIRMapper fhirMapper = new FHIRMapper();
        map<json> extractedValues = check fhirMapper.extractSearchParameters(persistClient, resourceType, resourceJson);
        self.references = fhirMapper.getReferences();

        match resourceType {
            "Account" => {
                time:Date? periodValue = ();
                if extractedValues.hasKey("period") {
                    json periodJson = extractedValues.get("period");
                    // Check if period is a JSON object with start/end dates
                    if periodJson is map<json> && periodJson.hasKey("start") {
                        string startDateStr = periodJson.get("start").toString();
                        if startDateStr.trim().length() > 0 {
                            periodValue = check parseDateString(startDateStr);
                        }
                    } else if periodJson is string {
                        // Handle simple string date format
                        string periodStr = periodJson;
                        if periodStr.trim().length() > 0 {
                            periodValue = check parseDateString(periodStr);
                        }
                    }
                }
                
                db_store:AccountTableUpdate accountUpdate = {
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    PERIOD: periodValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    VERSION_ID: 2,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return accountUpdate;
            }
            "Appointment" => {
                io:println(extractedValues);

                db_store:AppointmentTableUpdate appointmentUpdate = {
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    PART_STATUS: extractedValues.hasKey("part-status") ? extractedValues.get("part-status").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    APPOINTMENT_TYPE: extractedValues.hasKey("appointment-type") ? extractedValues.get("appointment-type").toString() : "",
                    REASON_CODE: extractedValues.hasKey("reason-code") ? extractedValues.get("reason-code").toString() : "",
                    SPECIALTY: extractedValues.hasKey("speciality") ? extractedValues.get("speciality").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return appointmentUpdate;
            }
            "Patient" => {
                db_store:PatientTableUpdate patientUpdate = {
                    LANGUAGE: extractedValues.hasKey("language") ? extractedValues.get("language").toString() : "",
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    DECEASED: extractedValues.hasKey("deceased") ? extractedValues.get("deceased").toString() : "",
                    BIRTHDATE: extractedValues.hasKey("birthdate") ? check parseDateString(extractedValues.get("birthdate").toString()) : (),
                    ADDRESS_CITY: extractedValues.hasKey("address-city") ? extractedValues.get("address-city").toString() : "",
                    EMAIL: extractedValues.hasKey("email") ? extractedValues.get("email").toString() : "",
                    ADDRESS_STATE: extractedValues.hasKey("address-state") ? extractedValues.get("address-state").toString() : "",
                    TELECOM: extractedValues.hasKey("telecom") ? extractedValues.get("telecom").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    FAMILY: extractedValues.hasKey("family") ? extractedValues.get("family").toString() : "",
                    ADDRESS_USE: extractedValues.hasKey("address-use") ? extractedValues.get("address-use").toString() : "",
                    GIVEN: extractedValues.hasKey("given") ? extractedValues.get("given").toString() : "",
                    ADDRESS: extractedValues.hasKey("address") ? extractedValues.get("address").toString() : "",
                    GENDER: extractedValues.hasKey("gender") ? extractedValues.get("gender").toString() : "",
                    PHONETIC: extractedValues.hasKey("phonetic") ? extractedValues.get("phonetic").toString() : "",
                    DEATH_DATE: extractedValues.hasKey("death-date") ? check parseDateString(extractedValues.get("death-date").toString()) : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return patientUpdate;
            }
            "Practitioner" => {
                db_store:PractitionerTableUpdate practitionerUpdate = {
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    ADDRESS_CITY: extractedValues.hasKey("address-city") ? extractedValues.get("address-city").toString() : "",
                    EMAIL: extractedValues.hasKey("email") ? extractedValues.get("email").toString() : "",
                    ADDRESS_STATE: extractedValues.hasKey("address-state") ? extractedValues.get("address-state").toString() : "",
                    TELECOM: extractedValues.hasKey("telecom") ? extractedValues.get("telecom").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    FAMILY: extractedValues.hasKey("family") ? extractedValues.get("family").toString() : "",
                    ADDRESS_USE: extractedValues.hasKey("address-use") ? extractedValues.get("address-use").toString() : "",
                    GIVEN: extractedValues.hasKey("given") ? extractedValues.get("given").toString() : "",
                    ADDRESS: extractedValues.hasKey("address") ? extractedValues.get("address").toString() : "",
                    GENDER: extractedValues.hasKey("gender") ? extractedValues.get("gender").toString() : "",
                    PHONETIC: extractedValues.hasKey("phonetic") ? extractedValues.get("phonetic").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    COMMUNICATION: extractedValues.hasKey("communication") ? extractedValues.get("communication").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return practitionerUpdate;
            }
            "Device" => {
                db_store:DeviceTableUpdate deviceUpdate = {
                    MANUFACTURER: extractedValues.hasKey("manufacturer") ? extractedValues.get("manufacturer").toString() : "",
                    MODEL: extractedValues.hasKey("model") ? extractedValues.get("model").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    UDI_CARRIER: extractedValues.hasKey("udi-carrier") ? extractedValues.get("udi-carrier").toString() : "",
                    UDI_DI: extractedValues.hasKey("udi-di") ? extractedValues.get("udi-di").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return deviceUpdate;
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTableUpdate healthcareServiceUpdate = {
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return healthcareServiceUpdate;
            }
            "PractitionerRole" => {
                db_store:PractitionerRoleTableUpdate practitionerRoleUpdate = {
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    EMAIL: extractedValues.hasKey("email") ? extractedValues.get("email").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    ROLE: extractedValues.hasKey("role") ? extractedValues.get("role").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    TELECOM: extractedValues.hasKey("telecom") ? extractedValues.get("telecom").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return practitionerRoleUpdate;
            }
            "RelatedPerson" => {
                db_store:RelatedPersonTableUpdate relatedPersonUpdate = {
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    BIRTHDATE: extractedValues.hasKey("birthdate") ? check parseDateString(extractedValues.get("birthdate").toString()) : (),
                    ADDRESS_CITY: extractedValues.hasKey("address-city") ? extractedValues.get("address-city").toString() : "",
                    EMAIL: extractedValues.hasKey("email") ? extractedValues.get("email").toString() : "",
                    ADDRESS_STATE: extractedValues.hasKey("address-state") ? extractedValues.get("address-state").toString() : "",
                    TELECOM: extractedValues.hasKey("telecom") ? extractedValues.get("telecom").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    ADDRESS_USE: extractedValues.hasKey("address-use") ? extractedValues.get("address-use").toString() : "",
                    ADDRESS: extractedValues.hasKey("address") ? extractedValues.get("address").toString() : "",
                    GENDER: extractedValues.hasKey("gender") ? extractedValues.get("gender").toString() : "",
                    PHONETIC: extractedValues.hasKey("phonetic") ? extractedValues.get("phonetic").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    RELATIONSHIP: extractedValues.hasKey("relationship") ? extractedValues.get("relationship").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return relatedPersonUpdate;
            }
            "Location" => {
                db_store:LocationTableUpdate locationUpdate = {
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    ADDRESS_CITY: extractedValues.hasKey("address-city") ? extractedValues.get("address-city").toString() : "",
                    ADDRESS_STATE: extractedValues.hasKey("address-state") ? extractedValues.get("address-state").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    ADDRESS_USE: extractedValues.hasKey("address-use") ? extractedValues.get("address-use").toString() : "",
                    ADDRESS: extractedValues.hasKey("address") ? extractedValues.get("address").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    OPERATIONAL_STATUS: extractedValues.hasKey("operational-status") ? extractedValues.get("operational-status").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return locationUpdate;
            }
            "ServiceRequest" => {
                db_store:ServiceRequestTableUpdate serviceRequestUpdate = {
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    INTENT: extractedValues.hasKey("intent") ? extractedValues.get("intent").toString() : "",
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    PRIORITY: extractedValues.hasKey("priority") ? extractedValues.get("priority").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    AUTHORED: extractedValues.hasKey("authored") ? check time:civilFromString(extractedValues.get("authored").toString()) : (),
                    BODY_SITE: extractedValues.hasKey("body-site") ? extractedValues.get("body-site").toString() : "",
                    INSTANTIATES_URI: extractedValues.hasKey("instantiates-uri") ? extractedValues.get("instantiates-uri").toString() : "",
                    OCCURRENCE: extractedValues.hasKey("occurrence") ? check time:civilFromString(extractedValues.get("occurrence").toString()) : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    REQUISITION: extractedValues.hasKey("requisition") ? extractedValues.get("requisition").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return serviceRequestUpdate;
            }
            "Condition" => {
                db_store:ConditionTableUpdate conditionUpdate = {
                    ABATEMENT_AGE: extractedValues.hasKey("abatement-age") ? extractedValues.get("abatement-age").toString() : "",
                    ABATEMENT_DATE: extractedValues.hasKey("abatement-date") ? check parseDateString(extractedValues.get("abatement-date").toString()) : (),
                    ABATEMENT_STRING: extractedValues.hasKey("abatement-string") ? extractedValues.get("abatement-string").toString() : "",
                    BODY_SITE: extractedValues.hasKey("body-site") ? extractedValues.get("body-site").toString() : "",
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    CLINICAL_STATUS: extractedValues.hasKey("clinical-status") ? extractedValues.get("clinical-status").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    EVIDENCE: extractedValues.hasKey("evidence") ? extractedValues.get("evidence").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    ONSET_AGE: extractedValues.hasKey("onset-age") ? extractedValues.get("onset-age").toString() : "",
                    ONSET_DATE: extractedValues.hasKey("onset-date") ? check parseDateString(extractedValues.get("onset-date").toString()) : (),
                    ONSET_INFO: extractedValues.hasKey("onset-info") ? extractedValues.get("onset-info").toString() : "",
                    RECORDED_DATE: extractedValues.hasKey("recorded-date") ? check parseDateString(extractedValues.get("recorded-date").toString()) : (),
                    SEVERITY: extractedValues.hasKey("severity") ? extractedValues.get("severity").toString() : "",
                    STAGE: extractedValues.hasKey("stage") ? extractedValues.get("stage").toString() : "",
                    VERIFICATION_STATUS: extractedValues.hasKey("verification-status") ? extractedValues.get("verification-status").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return conditionUpdate;
            }
            "Observation" => {
                db_store:ObservationTableUpdate observationUpdate = {
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    COMBO_CODE: extractedValues.hasKey("combo-code") ? extractedValues.get("combo-code").toString() : "",
                    COMBO_DATA_ABSENT_REASON: extractedValues.hasKey("combo-data-absent-reason") ? extractedValues.get("combo-data-absent-reason").toString() : "",
                    COMBO_VALUE_CONCEPT: extractedValues.hasKey("combo-value-concept") ? extractedValues.get("combo-value-concept").toString() : "",
                    COMBO_VALUE_QUANTITY: extractedValues.hasKey("combo-value-quantity") ? extractedValues.get("combo-value-quantity").toString() : "",
                    COMPONENT_CODE: extractedValues.hasKey("component-code") ? extractedValues.get("component-code").toString() : "",
                    COMPONENT_DATA_ABSENT_REASON: extractedValues.hasKey("component-data-absent-reason") ? extractedValues.get("component-data-absent-reason").toString() : "",
                    COMPONENT_VALUE_CONCEPT: extractedValues.hasKey("component-value-concept") ? extractedValues.get("component-value-concept").toString() : "",
                    COMPONENT_VALUE_QUANTITY: extractedValues.hasKey("component-value-quantity") ? extractedValues.get("component-value-quantity").toString() : "",
                    DATA_ABSENT_REASON: extractedValues.hasKey("data-absent-reason") ? extractedValues.get("data-absent-reason").toString() : "",
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    METHOD: extractedValues.hasKey("method") ? extractedValues.get("method").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    VALUE_CONCEPT: extractedValues.hasKey("value-concept") ? extractedValues.get("value-concept").toString() : "",
                    VALUE_DATE: extractedValues.hasKey("value-date") ? check parseDateString(extractedValues.get("value-date").toString()) : (),
                    VALUE_QUANTITY: extractedValues.hasKey("value-quantity") ? extractedValues.get("value-quantity").toString() : "",
                    VALUE_STRING: extractedValues.hasKey("value-string") ? extractedValues.get("value-string").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return observationUpdate;
            }
            "Procedure" => {
                db_store:ProcedureTableUpdate procedureUpdate = {
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    INSTANTIATES_URI: extractedValues.hasKey("instantiates-uri") ? extractedValues.get("instantiates-uri").toString() : "",
                    REASON_CODE: extractedValues.hasKey("reason-code") ? extractedValues.get("reason-code").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return procedureUpdate;
            }
            "ImmunizationRecommendation" => {
                db_store:ImmunizationRecommendationTableUpdate immunizationUpdate = {
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    TARGET_DISEASE: extractedValues.hasKey("target-disease") ? extractedValues.get("target-disease").toString() : "",
                    VACCINE_TYPE: extractedValues.hasKey("vaccine-type") ? extractedValues.get("vaccine-type").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return immunizationUpdate;
            }
            "Slot" => {
                db_store:SlotTableUpdate slotUpdate = {
                    APPOINTMENT_TYPE: extractedValues.hasKey("appointment-type") ? extractedValues.get("appointment-type").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    START: extractedValues.hasKey("start") ? check time:civilFromString(extractedValues.get("start").toString()) : (),
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return slotUpdate;
            }
            "Invoice" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:InvoiceTableUpdate invoiceUpdate = {
                    DATE: dateValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    TOTALNET: extractedValues.hasKey("totalnet") ? extractedValues.get("totalnet").toString() : (),
                    PARTICIPANT_ROLE: extractedValues.hasKey("participant-role") ? extractedValues.get("participant-role").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : (),
                    TOTALGROSS: extractedValues.hasKey("totalgross") ? extractedValues.get("totalgross").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return invoiceUpdate;
            }
            "DocumentManifest" => {
                time:Date? createdValue = ();
                if extractedValues.hasKey("created") {
                    string createdStr = extractedValues.get("created").toString();
                    if createdStr.trim().length() > 0 {
                        createdValue = check parseDateString(createdStr);
                    }
                }
                
                db_store:DocumentManifestTableUpdate documentManifestUpdate = {
                    CREATED: createdValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : (),
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    SOURCE: extractedValues.hasKey("source") ? extractedValues.get("source").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return documentManifestUpdate;
            }
            "Consent" => {
                time:Date? periodValue = ();
                if extractedValues.hasKey("period") {
                    json periodJson = extractedValues.get("period");
                    if periodJson is map<json> && periodJson.hasKey("start") {
                        string startDateStr = periodJson.get("start").toString();
                        if startDateStr.trim().length() > 0 {
                            periodValue = check parseDateString(startDateStr);
                        }
                    } else if periodJson is string {
                        string periodStr = periodJson;
                        if periodStr.trim().length() > 0 {
                            periodValue = check parseDateString(periodStr);
                        }
                    }
                }
                
                db_store:ConsentTableUpdate consentUpdate = {
                    PERIOD: periodValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return consentUpdate;
            }
            "Goal" => {
                time:Date? startDateValue = ();
                if extractedValues.hasKey("start-date") {
                    string startDateStr = extractedValues.get("start-date").toString();
                    if startDateStr.trim().length() > 0 {
                        startDateValue = check parseDateString(startDateStr);
                    }
                }
                
                time:Date? targetDateValue = ();
                if extractedValues.hasKey("target-date") {
                    string targetDateStr = extractedValues.get("target-date").toString();
                    if targetDateStr.trim().length() > 0 {
                        targetDateValue = check parseDateString(targetDateStr);
                    }
                }
                
                db_store:GoalTableUpdate goalUpdate = {
                    TARGET_DATE: targetDateValue,
                    ACHIEVEMENT_STATUS: extractedValues.hasKey("achievement-status") ? extractedValues.get("achievement-status").toString() : (),
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : (),
                    LIFECYCLE_STATUS: extractedValues.hasKey("lifecycle-status") ? extractedValues.get("lifecycle-status").toString() : (),
                    START_DATE: startDateValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return goalUpdate;
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTableUpdate medicinalProductUpdate = {
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return medicinalProductUpdate;
            }
            "MessageDefinition" => {
                db_store:MessageDefinitionTableUpdate messageDefinitionUpdate = {
                    PUBLISHER: extractedValues.hasKey("publisher") ? extractedValues.get("publisher").toString() : (),
                    JURISDICTION: extractedValues.hasKey("jurisdiction") ? extractedValues.get("jurisdiction").toString() : (),
                    CONTEXT: extractedValues.hasKey("context") ? extractedValues.get("context").toString() : (),
                    URL: extractedValues.hasKey("url") ? extractedValues.get("url").toString() : (),
                    EVENT: extractedValues.hasKey("event") ? extractedValues.get("event").toString() : (),
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    VERSION: extractedValues.hasKey("version") ? extractedValues.get("version").toString() : (),
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    CONTEXT_QUANTITY: extractedValues.hasKey("context-quantity") ? extractedValues.get("context-quantity").toString() : (),
                    CONTEXT_TYPE: extractedValues.hasKey("context-type") ? extractedValues.get("context-type").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return messageDefinitionUpdate;
            }
            "Endpoint" => {
                db_store:EndpointTableUpdate endpointUpdate = {
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return endpointUpdate;
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTableUpdate enrollmentRequestUpdate = {
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return enrollmentRequestUpdate;
            }
            "EventDefinition" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                time:Date? effectiveValue = ();
                if extractedValues.hasKey("effective") {
                    string effectiveStr = extractedValues.get("effective").toString();
                    if effectiveStr.trim().length() > 0 {
                        effectiveValue = check parseDateString(effectiveStr);
                    }
                }
                
                db_store:EventDefinitionTableUpdate eventDefinitionUpdate = {
                    PUBLISHER: extractedValues.hasKey("publisher") ? extractedValues.get("publisher").toString() : (),
                    JURISDICTION: extractedValues.hasKey("jurisdiction") ? extractedValues.get("jurisdiction").toString() : (),
                    EFFECTIVE: effectiveValue,
                    TOPIC: extractedValues.hasKey("topic") ? extractedValues.get("topic").toString() : (),
                    CONTEXT: extractedValues.hasKey("context") ? extractedValues.get("context").toString() : (),
                    URL: extractedValues.hasKey("url") ? extractedValues.get("url").toString() : (),
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    DATE: dateValue,
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    VERSION: extractedValues.hasKey("version") ? extractedValues.get("version").toString() : (),
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    CONTEXT_QUANTITY: extractedValues.hasKey("context-quantity") ? extractedValues.get("context-quantity").toString() : (),
                    CONTEXT_TYPE: extractedValues.hasKey("context-type") ? extractedValues.get("context-type").toString() : (),
                    VERSION_ID: newVersion,
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toString().toBytes()
                };

                return eventDefinitionUpdate;
            }
            _ => {
                return error(string `Resource type ${resourceType} is not supported for update operations`);
            }
        }
    }

    public isolated function getReferences() returns json[] {
        return self.references;
    }
}
