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
                
                db_store:AccountTableInsert accountInsert = {
                    ACCOUNTTABLE_ID: check resourceJson.id,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : "",
                    PERIOD: periodValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : "",
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : "",
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : "",
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return accountInsert;
            }
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
            "Invoice" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:InvoiceTableInsert invoiceInsert = {
                    INVOICETABLE_ID: check resourceJson.id,
                    DATE: dateValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    TOTALNET: extractedValues.hasKey("totalnet") ? extractedValues.get("totalnet").toString() : (),
                    PARTICIPANT_ROLE: extractedValues.hasKey("participant-role") ? extractedValues.get("participant-role").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : (),
                    TOTALGROSS: extractedValues.hasKey("totalgross") ? extractedValues.get("totalgross").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return invoiceInsert;
            }
            "DocumentManifest" => {
                time:Date? createdValue = ();
                if extractedValues.hasKey("created") {
                    string createdStr = extractedValues.get("created").toString();
                    if createdStr.trim().length() > 0 {
                        createdValue = check parseDateString(createdStr);
                    }
                }
                
                db_store:DocumentManifestTableInsert documentManifestInsert = {
                    DOCUMENTMANIFESTTABLE_ID: check resourceJson.id,
                    CREATED: createdValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    RELATED_ID: extractedValues.hasKey("related-id") ? extractedValues.get("related-id").toString() : (),
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    SOURCE: extractedValues.hasKey("source") ? extractedValues.get("source").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    TYPE: extractedValues.hasKey("type") ? extractedValues.get("type").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return documentManifestInsert;
            }
            "Consent" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                time:Date? periodValue = ();
                if extractedValues.hasKey("period") {
                    string periodStr = extractedValues.get("period").toString();
                    if periodStr.trim().length() > 0 {
                        periodValue = check parseDateString(periodStr);
                    }
                }
                
                db_store:ConsentTableInsert consentInsert = {
                    CONSENTTABLE_ID: check resourceJson.id,
                    DATE: dateValue,
                    SECURITY_LABEL: extractedValues.hasKey("security-label") ? extractedValues.get("security-label").toString() : (),
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    ACTION: extractedValues.hasKey("action") ? extractedValues.get("action").toString() : (),
                    SCOPE: extractedValues.hasKey("scope") ? extractedValues.get("scope").toString() : (),
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : (),
                    PERIOD: periodValue,
                    PURPOSE: extractedValues.hasKey("purpose") ? extractedValues.get("purpose").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return consentInsert;
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
                
                db_store:GoalTableInsert goalInsert = {
                    GOALTABLE_ID: check resourceJson.id,
                    TARGET_DATE: targetDateValue,
                    ACHIEVEMENT_STATUS: extractedValues.hasKey("achievement-status") ? extractedValues.get("achievement-status").toString() : (),
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : (),
                    LIFECYCLE_STATUS: extractedValues.hasKey("lifecycle-status") ? extractedValues.get("lifecycle-status").toString() : (),
                    START_DATE: startDateValue,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return goalInsert;
            }
            "MedicinalProductPackaged" => {
                db_store:MedicinalProductPackagedTableInsert medicinalProductPackagedInsert = {
                    MEDICINALPRODUCTPACKAGEDTABLE_ID: check resourceJson.id,
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return medicinalProductPackagedInsert;
            }
            "MessageDefinition" => {
                time:Date? dateValue = ();
                if extractedValues.hasKey("date") {
                    string dateStr = extractedValues.get("date").toString();
                    if dateStr.trim().length() > 0 {
                        dateValue = check parseDateString(dateStr);
                    }
                }
                
                db_store:MessageDefinitionTableInsert messageDefinitionInsert = {
                    MESSAGEDEFINITIONTABLE_ID: check resourceJson.id,
                    PUBLISHER: extractedValues.hasKey("publisher") ? extractedValues.get("publisher").toString() : (),
                    JURISDICTION: extractedValues.hasKey("jurisdiction") ? extractedValues.get("jurisdiction").toString() : (),
                    FOCUS: extractedValues.hasKey("focus") ? extractedValues.get("focus").toString() : (),
                    CONTEXT: extractedValues.hasKey("context") ? extractedValues.get("context").toString() : (),
                    URL: extractedValues.hasKey("url") ? extractedValues.get("url").toString() : (),
                    EVENT: extractedValues.hasKey("event") ? extractedValues.get("event").toString() : (),
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    DATE: dateValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    CATEGORY: extractedValues.hasKey("category") ? extractedValues.get("category").toString() : (),
                    VERSION: extractedValues.hasKey("version") ? extractedValues.get("version").toString() : (),
                    TITLE: extractedValues.hasKey("title") ? extractedValues.get("title").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    CONTEXT_QUANTITY: extractedValues.hasKey("context-quantity") ? extractedValues.get("context-quantity").toString() : (),
                    CONTEXT_TYPE: extractedValues.hasKey("context-type") ? extractedValues.get("context-type").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return messageDefinitionInsert;
            }
            "Endpoint" => {
                db_store:EndpointTableInsert endpointInsert = {
                    ENDPOINTTABLE_ID: check resourceJson.id,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    CONNECTION_TYPE: extractedValues.hasKey("connection-type") ? extractedValues.get("connection-type").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    PAYLOAD_TYPE: extractedValues.hasKey("payload-type") ? extractedValues.get("payload-type").toString() : (),
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return endpointInsert;
            }
            "EnrollmentRequest" => {
                db_store:EnrollmentRequestTableInsert enrollmentRequestInsert = {
                    ENROLLMENTREQUESTTABLE_ID: check resourceJson.id,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return enrollmentRequestInsert;
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
                
                db_store:EventDefinitionTableInsert eventDefinitionInsert = {
                    EVENTDEFINITIONTABLE_ID: check resourceJson.id,
                    PUBLISHER: extractedValues.hasKey("publisher") ? extractedValues.get("publisher").toString() : (),
                    JURISDICTION: extractedValues.hasKey("jurisdiction") ? extractedValues.get("jurisdiction").toString() : (),
                    EFFECTIVE: effectiveValue,
                    TOPIC: extractedValues.hasKey("topic") ? extractedValues.get("topic").toString() : (),
                    CONTEXT: extractedValues.hasKey("context") ? extractedValues.get("context").toString() : (),
                    URL: extractedValues.hasKey("url") ? extractedValues.get("url").toString() : (),
                    NAME: extractedValues.hasKey("name") ? extractedValues.get("name").toString() : (),
                    DATE: dateValue,
                    STATUS: extractedValues.hasKey("status") ? extractedValues.get("status").toString() : (),
                    DESCRIPTION: extractedValues.hasKey("description") ? extractedValues.get("description").toString() : (),
                    VERSION: extractedValues.hasKey("version") ? extractedValues.get("version").toString() : (),
                    TITLE: extractedValues.hasKey("title") ? extractedValues.get("title").toString() : (),
                    IDENTIFIER: extractedValues.hasKey("identifier") ? extractedValues.get("identifier").toString() : (),
                    CONTEXT_QUANTITY: extractedValues.hasKey("context-quantity") ? extractedValues.get("context-quantity").toString() : (),
                    CONTEXT_TYPE: extractedValues.hasKey("context-type") ? extractedValues.get("context-type").toString() : (),
                    VERSION_ID: 1,
                    CREATED_AT: time:utcToCivil(time:utcNow()),
                    UPDATED_AT: time:utcToCivil(time:utcNow()),
                    LAST_UPDATED: time:utcToCivil(time:utcNow()),
                    RESOURCE_JSON: resourceJson.toJsonString().toBytes()
                };

                return eventDefinitionInsert;
            }
            _ => {
                return error(string `Resource type ${resourceType} is not supported for create operation`);
            }
        }
    }

    public isolated function getReferences() returns json[] {
        return self.references;
    }
}
