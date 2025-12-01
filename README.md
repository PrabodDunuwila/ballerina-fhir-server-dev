# FHIR R4 Server - Ballerina Implementation

A RESTful FHIR R4 server implementation built with Ballerina, supporting CRUD operations, resource references, and version history for all FHIR R4 resources.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Running the Server](#running-the-server)
- [FHIR Resource Operations](#fhir-resource-operations)
- [Reference Management](#reference-management)
- [Examples](#examples)
  - [Creating a Practitioner](#1-creating-a-practitioner)
  - [Creating a Patient](#2-creating-a-patient)
  - [Creating an Appointment](#3-creating-an-appointment)
- [API Reference](#api-reference)
- [Error Handling](#error-handling)

## Overview

This FHIR R4 server implements the HL7 FHIR (Fast Healthcare Interoperability Resources) specification version R4. It provides a complete REST API for managing healthcare resources with support for referential integrity, transaction management, and resource versioning.

## Features

- ✅ Full FHIR R4 resource support (145+ resource types)
- ✅ RESTful CRUD operations (Create, Read, Update, Delete)
- ✅ Resource reference validation and management
- ✅ Version history tracking (`_history` endpoint)
- ✅ Transaction management with automatic rollback

## Prerequisites

- Ballerina Swan Lake 2201.12.3 or higher
- H2 Database (or any JDBC-compatible database)
- Java 17 or higher

## Configuration

Configure the database connection in `Config.toml`:

```toml
[ballerina_fhir_server.handlers]
dbUrl = "jdbc:h2:~./fhir-data-db"
dbUser = "sa"
dbPassword = ""
```

## Running the Server

1. Navigate to the fhir-service directory:
```bash
cd fhir-service
```

2. Build the project:
```bash
bal build
```

3. Run the server:
```bash
bal run
```

The server will start on `http://localhost:9090/fhir/r4`.

## FHIR Resource Operations

### Supported Operations

| Operation | HTTP Method | Endpoint Pattern | Description |
|-----------|-------------|------------------|-------------|
| **Create** | POST | `/{resourceType}` | Create a new resource |
| **Read** | GET | `/{resourceType}/{id}` | Retrieve a resource by ID |
| **Update** | PUT | `/{resourceType}/{id}` | Update an existing resource |
| **Delete** | DELETE | `/{resourceType}/{id}` | Delete a resource |
| **History (Instance)** | GET | `/{resourceType}/{id}/_history` | Get version history for a resource |
| **History (Type)** | GET | `/fhir/r4/{resourceType}/_history` | Get history for all resources of a type |

## Reference Management

### Understanding FHIR References

FHIR resources often reference other resources. For example:
- A **Patient** may reference a **Practitioner** as their general practitioner
- An **Appointment** references both **Patient** and **Practitioner** as participants

**Important**: Referenced resources **must exist** before creating resources that reference them. The server validates all references and will reject requests if referenced resources don't exist.

### Reference Format

References follow the pattern: `{ResourceType}/{id}`

```json
{
  "reference": "Patient/patient-123",
  "display": "John Doe"
}
```

## Examples

### 1. Creating a Practitioner

Practitioners are healthcare providers (doctors, nurses, etc.). They are typically created first as they are referenced by other resources.

**Request:**
```bash
POST http://localhost:9090/fhir/r4/Practitioner
Content-Type: application/json
```

**Request Body:**
```json
{
  "resourceType": "Practitioner",
  "id": "practitioner-001",
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Smith",
      "given": ["Dr.", "John"],
      "prefix": ["Dr."]
    }
  ],
  "telecom": [
    {
      "system": "phone",
      "value": "+1-555-123-4567",
      "use": "work"
    },
    {
      "system": "email",
      "value": "dr.smith@healthcare.org",
      "use": "work"
    }
  ],
  "address": [
    {
      "use": "work",
      "type": "both",
      "line": ["123 Medical Center Drive"],
      "city": "Boston",
      "state": "MA",
      "postalCode": "02101",
      "country": "USA"
    }
  ],
  "gender": "male",
  "qualification": [
    {
      "identifier": [
        {
          "system": "http://example.org/medical-licenses",
          "value": "MD-12345"
        }
      ],
      "code": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0360",
            "code": "MD",
            "display": "Doctor of Medicine"
          }
        ]
      },
      "period": {
        "start": "2010-06-15"
      },
      "issuer": {
        "display": "State Medical Board"
      }
    }
  ]
}
```

**Response:**
```
HTTP/1.1 201 Created
Location: http://localhost:9090/fhir/r4/Practitioner/practitioner-001
```

```json
{
  "resourceType": "Practitioner",
  "id": "practitioner-001",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2024-12-01T10:30:00.000Z"
  },
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Smith",
      "given": ["Dr.", "John"],
      "prefix": ["Dr."]
    }
  ]
  // ... rest of the resource
}
```

### 2. Creating a Patient

Patients can reference their general practitioner. The practitioner must exist before creating the patient.

**Prerequisites:**
- Practitioner with ID `practitioner-001` must exist (created in step 1)

**Request:**
```bash
POST http://localhost:9090/fhir/r4/Patient
Content-Type: application/json
```

**Request Body:**
```json
{
  "resourceType": "Patient",
  "id": "patient-001",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2025-11-24T10:00:00Z"
  },
  "text": {
    "status": "generated",
    "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\">John Doe</div>"
  },
  "identifier": [
    {
      "use": "official",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "MR",
            "display": "Medical Record Number"
          }
        ]
      },
      "system": "http://hospital.example.org/patients",
      "value": "MRN123456"
    },
    {
      "use": "secondary",
      "type": {
        "coding": [
          {
            "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
            "code": "SS",
            "display": "Social Security Number"
          }
        ]
      },
      "system": "http://hl7.org/fhir/sid/us-ssn",
      "value": "123-45-6789"
    }
  ],
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Doe",
      "given": ["John", "Michael"],
      "prefix": ["Mr."],
      "suffix": ["Jr."]
    },
    {
      "use": "nickname",
      "given": ["Johnny"]
    }
  ],
  "telecom": [
    {
      "system": "phone",
      "value": "+1-555-123-4567",
      "use": "home",
      "rank": 1
    },
    {
      "system": "phone",
      "value": "+1-555-987-6543",
      "use": "mobile",
      "rank": 2
    },
    {
      "system": "email",
      "value": "john.doe@example.com",
      "use": "home"
    }
  ],
  "gender": "male",
  "birthDate": "1985-06-15",
  "deceasedBoolean": false,
  "address": [
    {
      "use": "home",
      "type": "physical",
      "line": ["123 Main Street", "Apartment 4B"],
      "city": "Springfield",
      "state": "IL",
      "postalCode": "62701",
      "country": "USA",
      "period": {
        "start": "2020-01-01"
      }
    }
  ],
  "maritalStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
        "code": "M",
        "display": "Married"
      }
    ]
  },
  "multipleBirthBoolean": false,
  "contact": [
    {
      "relationship": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/v2-0131",
              "code": "C",
              "display": "Emergency Contact"
            }
          ]
        }
      ],
      "name": {
        "family": "Doe",
        "given": ["Jane"]
      },
      "telecom": [
        {
          "system": "phone",
          "value": "+1-555-111-2222",
          "use": "mobile"
        }
      ],
      "address": {
        "use": "home",
        "line": ["123 Main Street", "Apartment 4B"],
        "city": "Springfield",
        "state": "IL",
        "postalCode": "62701",
        "country": "USA"
      },
      "gender": "female"
    }
  ],
  "communication": [
    {
      "language": {
        "coding": [
          {
            "system": "urn:ietf:bcp:47",
            "code": "en-US",
            "display": "English (United States)"
          }
        ],
        "text": "English"
      },
      "preferred": true
    }
  ],
  "generalPractitioner": [
    {
      "reference": "Practitioner/practitioner-001",
      "display": "Dr. Sarah Smith"
    }
  ]
}
```

**Response:**
```
HTTP/1.1 201 Created
Location: http://localhost:9090/fhir/r4/Patient/patient-001
```

```json
{
  "resourceType": "Patient",
  "id": "patient-001",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2024-12-01T10:35:00.000Z"
  },
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Doe",
      "given": ["Jane", "Marie"]
    }
  ],
  "generalPractitioner": [
    {
      "reference": "Practitioner/practitioner-001",
      "display": "Dr. John Smith"
    }
  ]
  // ... rest of the resource
}
```

**What Happens Behind the Scenes:**
1. Server validates that `Practitioner/practitioner-001` exists
2. Creates the Patient resource
3. Stores the reference in the REFERENCES table for tracking
4. Returns the created resource with metadata

### 3. Creating an Appointment

Appointments require both Patient and Practitioner to exist as they reference both participants.

**Prerequisites:**
- Practitioner with ID `practitioner-001` must exist (created in step 1)
- Patient with ID `patient-001` must exist (created in step 2)

**Request:**
```bash
POST http://localhost:9090/fhir/r4/Appointment
Content-Type: application/json
```

**Request Body:**
```json
{
  "resourceType": "Appointment",
  "id": "appointment01",
  "status": "booked",
  "serviceCategory": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/service-category",
          "code": "17",
          "display": "General Practice"
        }
      ]
    }
  ],
  "serviceType": [
    {
      "coding": [
        {
          "system": "http://terminology.hl7.org/CodeSystem/service-type",
          "code": "124",
          "display": "General Practice"
        }
      ]
    }
  ],
  "specialty": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "394814009",
          "display": "General practice"
        }
      ]
    }
  ],
  "appointmentType": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/v2-0276",
        "code": "ROUTINE",
        "display": "Routine appointment"
      }
    ]
  },
  "reasonCode": [
    {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "386661006",
          "display": "Fever"
        }
      ],
      "text": "Patient complaining of fever"
    }
  ],
  "priority": 5,
  "description": "Routine check-up for patient with fever symptoms",
  "start": "2025-11-25T10:00:00Z",
  "end": "2025-11-25T10:30:00Z",
  "created": "2025-11-24T14:00:00Z",
  "comment": "Patient prefers morning appointments",
  "participant": [
    {
      "actor": {
        "reference": "Patient/patient-001",
        "display": "John Doe"
      },
      "required": "required",
      "status": "accepted"
    },
    {
      "type": [
        {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
              "code": "PPRF",
              "display": "primary performer"
            }
          ]
        }
      ],
      "actor": {
        "reference": "Practitioner/practitioner-001",
        "display": "Dr. Jane Smith"
      },
      "required": "required",
      "status": "accepted"
    }
  ]
}
```

**Response:**
```
HTTP/1.1 201 Created
Location: http://localhost:9090/fhir/r4/Appointment/appointment-001
```

```json
{
    "resourceType": "Appointment",
    "id": "appointment-001",
    "status": "booked",
    "serviceCategory": [
        {
            "coding": [
                {
                    "system": "http://terminology.hl7.org/CodeSystem/service-category",
                    "code": "17",
                    "display": "General Practice"
                }
            ]
        }
    ],
  // ... rest of the resource
}
```

**What Happens Behind the Scenes:**
1. Server validates that `Patient/patient-001` exists
2. Server validates that `Practitioner/practitioner-001` exists
3. Creates the Appointment resource
4. Stores both references in the REFERENCES table
5. Returns the created resource with metadata

### Reference Validation Error Example

If you try to create an Appointment without the required resources:

**Request:**
```json
{
  "resourceType": "Appointment",
  "participant": [
    {
      "actor": {
        "reference": "Patient/non-existent-patient"
      }
    }
  ]
}
```

**Response:**
```
HTTP/1.1 400 Bad Request
Content-Type: application/json
```

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "not-found",
      "diagnostics": "Referenced resource does not exist: Patient/non-existent-patient"
    }
  ]
}
```

## API Reference

### Read a Resource

**Request:**
```bash
GET http://localhost:9090/fhir/r4/Patient/patient-001
```

**Response:**
```json
{
  "resourceType": "Patient",
  "id": "patient-001",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2024-12-01T10:35:00.000Z"
  }
  // ... resource content
}
```

### Update a Resource

**Request:**
```bash
PUT http://localhost:9090/fhir/r4/Patient/patient-001
Content-Type: application/json
```

**Request Body:**
```json
{
  "resourceType": "Patient",
  "id": "patient-001",
  "active": true,
  "name": [
    {
      "use": "official",
      "family": "Doe-Johnson",
      "given": ["Jane", "Marie"]
    }
  ]
  // ... updated content
}
```

**Response:**
```
HTTP/1.1 200 OK
```

```json
{
  "resourceType": "Patient",
  "id": "patient-001",
  "meta": {
    "versionId": "2",
    "lastUpdated": "2024-12-01T11:00:00.000Z"
  }
  // ... updated resource
}
```

### Delete a Resource

**Request:**
```bash
DELETE http://localhost:9090/fhir/r4/Patient/patient-001
```

**Response:**
```
HTTP/1.1 204 No Content
```

### Get Resource History

**Instance History:**
```bash
GET http://localhost:9090/fhir/r4/Patient/patient-001/_history
```

**Response:**
```json
{
  "resourceType": "Bundle",
  "type": "history",
  "total": 2,
  "entry": [
    {
      "resource": {
        "resourceType": "Patient",
        "id": "patient-001",
        "meta": {
          "versionId": "2",
          "lastUpdated": "2024-12-01T11:00:00.000Z"
        }
        // ... version 2 content
      }
    },
    {
      "resource": {
        "resourceType": "Patient",
        "id": "patient-001",
        "meta": {
          "versionId": "1",
          "lastUpdated": "2024-12-01T10:35:00.000Z"
        }
        // ... version 1 content
      }
    }
  ]
}
```

## Error Handling

### Common Error Responses

| Status Code | Description | Example Scenario |
|-------------|-------------|------------------|
| 400 Bad Request | Invalid resource format or missing required fields | Malformed JSON |
| 404 Not Found | Resource does not exist | GET /fhir/r4/Patient/non-existent |
| 409 Conflict | Resource already exists | POST with existing ID |
| 500 Internal Server Error | Server error | Database connection failure |

## Database Schema

The server uses the following core tables:

- **Resource Tables**: One table per FHIR resource type (e.g., `PATIENT`, `PRACTITIONER`, `APPOINTMENT`)
- **REFERENCES Table**: Tracks all resource references for validation and cascade operations
- **History Tables**: Store version history for each resource

## FHIR Specification

This implementation follows the HL7 FHIR R4 specification:
- [FHIR R4 Specification](http://hl7.org/fhir/R4/)
- [FHIR RESTful API](http://hl7.org/fhir/R4/http.html)
- [Resource References](http://hl7.org/fhir/R4/references.html)
