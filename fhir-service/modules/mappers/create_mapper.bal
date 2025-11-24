import ballerina_fhir_server.db_store;

import ballerina/io;
import ballerina/time;

// Helper function to parse date string in YYYY-MM-DD format to time:Date
isolated function parseDateString(string dateStr) returns time:Date|error {
    // Handle empty or whitespace-only strings
    if dateStr.trim().length() == 0 {
        return error("Date string is empty");
    }
    
    // Parse date string "YYYY-MM-DD" into components
    string[] parts = re `-`.split(dateStr);
    if parts.length() != 3 {
        return error(string `Invalid date format: ${dateStr}. Expected YYYY-MM-DD`);
    }
    
    // Validate each part is not empty
    if parts[0].trim().length() == 0 || parts[1].trim().length() == 0 || parts[2].trim().length() == 0 {
        return error(string `Invalid date format: ${dateStr}. One or more components are empty`);
    }
    
    int year = check int:fromString(parts[0]);
    int month = check int:fromString(parts[1]);
    int day = check int:fromString(parts[2]);
    
    time:Date date = {year: year, month: month, day: day};
    return date;
}

public class CreateMapper {
    private json[] references;

    public isolated function init() {
        self.references = [];
    }

    // This function will map values to persist insert models
    public isolated function mapToInsertModel(db_store:Client persistClient, string resourceType, json resourceJson) returns record {|anydata...;|}|error? {
        FHIRMapper fhirMapper = new FHIRMapper();
        map<json> extractedValues = check fhirMapper.extractSearchParameters(persistClient, resourceType, resourceJson);
        self.references = fhirMapper.getReferences();

        match resourceType {
            "Appointment" => {
                io:println(extractedValues);

                db_store:AppointmentTableInsert appointmentInsert = {
                    APPOINTMENTTABLE_ID: check resourceJson.id,
                    DATE: extractedValues.hasKey("date") ? check time:civilFromString(extractedValues.get("date").toString()) : (),
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    PART_STATUS: extractedValues.hasKey("part-status") ? extractedValues.get("part-status").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    APPOINTMENT_TYPE: extractedValues.hasKey("appointment-type") ? extractedValues.get("appointment-type").toString() : "",
                    REASON_CODE: extractedValues.hasKey("reason-code") ? extractedValues.get("reason-code").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return appointmentInsert;
            }
            "Patient" => {
                io:println(extractedValues);

                db_store:PatientTableInsert patientInsert = {
                    PATIENTTABLE_ID: check resourceJson.id,
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
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return patientInsert;
            }
            "Practitioner" => {
                db_store:PractitionerTableInsert practitionerInsert = {
                    PRACTITIONERTABLE_ID: check resourceJson.id,
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
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return practitionerInsert;
            }
            "Device" => {
                db_store:DeviceTableInsert deviceInsert = {
                    DEVICETABLE_ID: check resourceJson.id,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    UDI_DI: extractedValues.hasKey("udi-di") ? extractedValues.get("udi-di").toString() : "",
                    UDI_CARRIER: extractedValues.hasKey("udi-carrier") ? extractedValues.get("udi-carrier").toString() : "",
                    DEVICE_NAME: extractedValues.hasKey("device-name") ? extractedValues.get("device-name").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    MODEL: extractedValues.hasKey("model") ? extractedValues.get("model").toString() : "",
                    MANUFACTURER: extractedValues.hasKey("manufacturer") ? extractedValues.get("manufacturer").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    URL: extractedValues.hasKey("url") ? extractedValues.get("url").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return deviceInsert;
            }
            "HealthcareService" => {
                db_store:HealthcareServiceTableInsert healthcareServiceInsert = {
                    HEALTHCARESERVICETABLE_ID: check resourceJson.id,
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    CHARACTERISTIC: extractedValues.hasKey("characteristic") ? extractedValues.get("characteristic").toString() : "",
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    PROGRAM: extractedValues.hasKey("program") ? extractedValues.get("program").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return healthcareServiceInsert;
            }
            "PractitionerRole" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    // Only parse if the date string is not empty
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:PractitionerRoleTableInsert practitionerRoleInsert = {
                    PRACTITIONERROLETABLE_ID: check resourceJson.id,
                    ROLE: extractedValues.hasKey("role") ? extractedValues.get("role").toString() : "",
                    DATE: dateValue,
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    EMAIL: extractedValues.hasKey("email") ? extractedValues.get("email").toString() : "",
                    TELECOM: extractedValues.hasKey("telecom") ? extractedValues.get("telecom").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return practitionerRoleInsert;
            }
            "RelatedPerson" => {
                time:Date? birthdateValue = ();
                if extractedValues.hasKey("birthdate") {
                    string birthdateStr = extractedValues.get("birthdate").toString();
                    if birthdateStr.trim().length() > 0 {
                        birthdateValue = check parseDateString(birthdateStr);
                    }
                }
                
                db_store:RelatedPersonTableInsert relatedPersonInsert = {
                    RELATEDPERSONTABLE_ID: check resourceJson.id,
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    ACTIVE: extractedValues.hasKey("active") ? extractedValues.get("active").toString() : "",
                    PHONE: extractedValues.hasKey("phone") ? extractedValues.get("phone").toString() : "",
                    BIRTHDATE: birthdateValue,
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
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return relatedPersonInsert;
            }
            "Location" => {
                db_store:LocationTableInsert locationInsert = {
                    LOCATIONTABLE_ID: check resourceJson.id,
                    ADDRESS_COUNTRY: extractedValues.hasKey("address-country") ? extractedValues.get("address-country").toString() : "",
                    ADDRESS_POSTALCODE: extractedValues.hasKey("address-postalcode") ? extractedValues.get("address-postalcode").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    ADDRESS_USE: extractedValues.hasKey("address-use") ? extractedValues.get("address-use").toString() : "",
                    ADDRESS: extractedValues.hasKey("address") ? extractedValues.get("address").toString() : "",
                    OPERATIONAL_STATUS: extractedValues.hasKey("operational-status") ? extractedValues.get("operational-status").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    ADDRESS_CITY: extractedValues.hasKey("address-city") ? extractedValues.get("address-city").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    ADDRESS_STATE: extractedValues.hasKey("address-state") ? extractedValues.get("address-state").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return locationInsert;
            }
            "ServiceRequest" => {
                time:Date? occurrenceValue = ();
                if extractedValues.hasKey("occurrence") {
                    string occurrenceStr = extractedValues.get("occurrence").toString();
                    if occurrenceStr.trim().length() > 0 {
                        occurrenceValue = check parseDateString(occurrenceStr);
                    }
                }
                
                time:Date? authoredValue = ();
                if extractedValues.hasKey("authored") {
                    string authoredStr = extractedValues.get("authored").toString();
                    if authoredStr.trim().length() > 0 {
                        authoredValue = check parseDateString(authoredStr);
                    }
                }
                
                db_store:ServiceRequestTableInsert serviceRequestInsert = {
                    SERVICEREQUESTTABLE_ID: check resourceJson.id,
                    REQUISITION: extractedValues.hasKey("requisition") ? extractedValues.get("requisition").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    OCCURRENCE: occurrenceValue,
                    INSTANTIATES_URI: extractedValues.hasKey("instantiates-uri") ? extractedValues.get("instantiates-uri").toString() : "",
                    PERFORMER_TYPE: extractedValues.hasKey("performer-type") ? extractedValues.get("performer-type").toString() : "",
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    INTENT: extractedValues.hasKey("intent") ? extractedValues.get("intent").toString() : "",
                    AUTHORED: authoredValue,
                    PRIORITY: extractedValues.hasKey("priority") ? extractedValues.get("priority").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    BODY_SITE: extractedValues.hasKey("body-site") ? extractedValues.get("body-site").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return serviceRequestInsert;
            }
            "Condition" => {
                time:Date? onsetDateValue = ();
                if extractedValues.hasKey("onset-date") {
                    string onsetDateStr = extractedValues.get("onset-date").toString();
                    if onsetDateStr.trim().length() > 0 {
                        onsetDateValue = check parseDateString(onsetDateStr);
                    }
                }
                
                time:Date? recordedDateValue = ();
                if extractedValues.hasKey("recorded-date") {
                    string recordedDateStr = extractedValues.get("recorded-date").toString();
                    if recordedDateStr.trim().length() > 0 {
                        recordedDateValue = check parseDateString(recordedDateStr);
                    }
                }
                
                time:Date? abatementDateValue = ();
                if extractedValues.hasKey("abatement-date") {
                    string abatementDateStr = extractedValues.get("abatement-date").toString();
                    if abatementDateStr.trim().length() > 0 {
                        abatementDateValue = check parseDateString(abatementDateStr);
                    }
                }
                
                db_store:ConditionTableInsert conditionInsert = {
                    CONDITIONTABLE_ID: check resourceJson.id,
                    CLINICAL_STATUS: extractedValues.hasKey("clinical-status") ? extractedValues.get("clinical-status").toString() : "",
                    STAGE: extractedValues.hasKey("stage") ? extractedValues.get("stage").toString() : "",
                    ONSET_AGE: extractedValues.hasKey("onset-age") ? extractedValues.get("onset-age").toString() : "",
                    ONSET_INFO: extractedValues.hasKey("onset-info") ? extractedValues.get("onset-info").toString() : "",
                    EVIDENCE: extractedValues.hasKey("evidence") ? extractedValues.get("evidence").toString() : "",
                    ONSET_DATE: onsetDateValue,
                    BODY_SITE: extractedValues.hasKey("body-site") ? extractedValues.get("body-site").toString() : "",
                    VERIFICATION_STATUS: extractedValues.hasKey("verification-status") ? extractedValues.get("verification-status").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    ABATEMENT_AGE: extractedValues.hasKey("abatement-age") ? extractedValues.get("abatement-age").toString() : "",
                    ABATEMENT_STRING: extractedValues.hasKey("abatement-string") ? extractedValues.get("abatement-string").toString() : "",
                    RECORDED_DATE: recordedDateValue,
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    ABATEMENT_DATE: abatementDateValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SEVERITY: extractedValues.hasKey("severity") ? extractedValues.get("severity").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return conditionInsert;
            }
            "Observation" => {
                time:Date? valueDateValue = ();
                if extractedValues.hasKey("value-date") {
                    string valueDateStr = extractedValues.get("value-date").toString();
                    if valueDateStr.trim().length() > 0 {
                        valueDateValue = check parseDateString(valueDateStr);
                    }
                }
                
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:ObservationTableInsert observationInsert = {
                    OBSERVATIONTABLE_ID: check resourceJson.id,
                    COMPONENT_CODE: extractedValues.hasKey("component-code") ? extractedValues.get("component-code").toString() : "",
                    VALUE_QUANTITY: extractedValues.hasKey("value-quantity") ? extractedValues.get("value-quantity").toString() : "",
                    COMBO_CODE: extractedValues.hasKey("combo-code") ? extractedValues.get("combo-code").toString() : "",
                    VALUE_DATE: valueDateValue,
                    DATE: dateValue,
                    VALUE_STRING: extractedValues.hasKey("value-string") ? extractedValues.get("value-string").toString() : "",
                    COMBO_DATA_ABSENT_REASON: extractedValues.hasKey("combo-data-absent-reason") ? extractedValues.get("combo-data-absent-reason").toString() : "",
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    COMBO_VALUE_QUANTITY: extractedValues.hasKey("combo-value-quantity") ? extractedValues.get("combo-value-quantity").toString() : "",
                    VALUE_CONCEPT: extractedValues.hasKey("value-concept") ? extractedValues.get("value-concept").toString() : "",
                    METHOD: extractedValues.hasKey("method") ? extractedValues.get("method").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    COMPONENT_DATA_ABSENT_REASON: extractedValues.hasKey("component-data-absent-reason") ? extractedValues.get("component-data-absent-reason").toString() : "",
                    DATA_ABSENT_REASON: extractedValues.hasKey("data-absent-reason") ? extractedValues.get("data-absent-reason").toString() : "",
                    COMPONENT_VALUE_QUANTITY: extractedValues.hasKey("component-value-quantity") ? extractedValues.get("component-value-quantity").toString() : "",
                    COMPONENT_VALUE_CONCEPT: extractedValues.hasKey("component-value-concept") ? extractedValues.get("component-value-concept").toString() : "",
                    COMBO_VALUE_CONCEPT: extractedValues.hasKey("combo-value-concept") ? extractedValues.get("combo-value-concept").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return observationInsert;
            }
            "Procedure" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:ProcedureTableInsert procedureInsert = {
                    PROCEDURETABLE_ID: check resourceJson.id,
                    DATE: dateValue,
                    CODE: extractedValues.hasKey("code") ? extractedValues.get("code").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    INSTANTIATES_URI: extractedValues.hasKey("instantiates-uri") ? extractedValues.get("instantiates-uri").toString() : "",
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : "",
                    REASON_CODE: extractedValues.hasKey("reason-code") ? extractedValues.get("reason-code").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return procedureInsert;
            }
            "ImmunizationRecommendation" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:ImmunizationRecommendationTableInsert immunizationRecommendationInsert = {
                    IMMUNIZATIONRECOMMENDATIONTABLE_ID: check resourceJson.id,
                    DATE: dateValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    TARGET_DISEASE: extractedValues.hasKey("target-disease") ? extractedValues.get("target-disease").toString() : "",
                    VACCINE_TYPE: extractedValues.hasKey("vaccine-type") ? extractedValues.get("vaccine-type").toString() : "",
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return immunizationRecommendationInsert;
            }
            "Slot" => {
                time:Date? startValue = ();
                if extractedValues.hasKey("start") {
                    string startStr = extractedValues.get("start").toString();
                    if startStr.trim().length() > 0 {
                        startValue = check parseDateString(startStr);
                    }
                }
                
                db_store:SlotTableInsert slotInsert = {
                    SLOTTABLE_ID: check resourceJson.id,
                    SERVICE_CATEGORY: extractedValues.hasKey("service-category") ? extractedValues.get("service-category").toString() : "",
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    APPOINTMENT_TYPE: extractedValues.hasKey("appointment-type") ? extractedValues.get("appointment-type").toString() : "",
                    SPECIALTY: extractedValues.hasKey("specialty") ? extractedValues.get("specialty").toString() : "",
                    START: startValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    SERVICE_TYPE: extractedValues.hasKey("service-type") ? extractedValues.get("service-type").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return slotInsert;
            }
            _ => {
                // Generic handler for all other resources
                return self.createGenericInsertModel(resourceType, resourceJson, extractedValues);
            }
        }
    }

    // Generic insert model creator for all resources
    private isolated function createGenericInsertModel(string resourceType, json resourceJson, map<json> extractedValues) returns record {|anydata...;|}|error {
        
        // Create base record with required fields
        map<anydata> insertModel = {};
        
        // Add ID field (required for all resources)
        string idFieldName = resourceType.toUpperAscii() + "TABLE_ID";
        insertModel[idFieldName] = check resourceJson.id;
        
        // Add all extracted search parameter values
        foreach var [key, value] in extractedValues.entries() {
            string columnName = key.toUpperAscii();
            // Replace hyphens with underscores
            string[] parts = re `-`.split(columnName);
            columnName = string:'join("_", ...parts);
            
            // Handle different value types
            if value is string {
                insertModel[columnName] = value;
            } else if value is json {
                insertModel[columnName] = value.toString();
            }
        }
        
        // Add standard fields (required for all tables)
        insertModel["VERSION_ID"] = 1;
        insertModel["CREATED_AT"] = time:utcToCivil(time:utcNow());
        insertModel["UPDATED_AT"] = time:utcToCivil(time:utcNow());
        insertModel["LAST_UPDATED"] = time:utcToCivil(time:utcNow());
        insertModel["RESOURCE_JSON"] = resourceJson.toJsonString().toBytes();
        
        return insertModel;
    }

    public isolated function getReferences() returns json[] {
        return self.references;
    }
}
