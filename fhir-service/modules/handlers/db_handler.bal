import ballerina_fhir_server.utils;

import ballerina/io;
import ballerina/sql;
import ballerinax/java.jdbc;

// Database configuration
configurable string dbUrl = ?;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable boolean clearDataOnStartup = false;

public class DBHandler {
    private final string filePath = "./scripts/schema.sql";
    private final jdbc:Client|sql:Error jdbcClient = new (dbUrl, dbUser, dbPassword);

    private sql:ParameterizedQuery[] dropQueries;
    private sql:ParameterizedQuery[] createQueries;

    public function init() {
        self.dropQueries = [];
        self.createQueries = [];
    }

    public function initializeJdbcClient() returns jdbc:Client|sql:Error {
        return self.jdbcClient;
    }

    private function isDBExsists(jdbc:Client jdbcClient) returns boolean|error {
        sql:ParameterizedQuery query = `SELECT COUNT(TABLE_CATALOG) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='PUBLIC'`;
        int count = check jdbcClient->queryRow(query);
        if (count > 0) {
            return true;
        }
        return false;
    }

    public function initDatabase(jdbc:Client jdbcClient) returns boolean|error? {
        boolean|error dbExists = self.isDBExsists(jdbcClient);
        
        if (dbExists is error) {
            return false;
        } else if (dbExists == true) {
            // Database exists - check if we should clear it
            if (clearDataOnStartup) {
                io:println("Clearing existing database data as clearDataOnStartup is enabled...");
                // Continue to drop and recreate tables
            } else {
                io:println("Database already exists. Skipping initialization to preserve existing data.");
                return true;
            }
        }
        
        // Initialize or reinitialize database
        sql:ExecutionResult dropQueryResult = {affectedRowCount: 0, lastInsertId: 0};
        sql:ExecutionResult createQueryResult = {affectedRowCount: 0, lastInsertId: 0};

        error? isError = self.retreiveQueriesFromSchema();

        if (isError is error) {
            io:println("An error occured when reading the db schema: " + isError.message());
            return false;
        } else {
            foreach sql:ParameterizedQuery dropQuery in self.dropQueries {
                sql:ParameterizedQuery query1 = dropQuery;
                dropQueryResult = check jdbcClient->execute(query1);
            }

            foreach sql:ParameterizedQuery createQuery in self.createQueries {
                sql:ParameterizedQuery query2 = createQuery;
                createQueryResult = check jdbcClient->execute(query2);
            }
        }

        io:println("Drop Query Result: " + dropQueryResult.toString());
        io:println("Create Query Result: " + createQueryResult.toString());

        // MIGHT BE OBSOLETE: Check whether if necessary
        error? isSearchParamsPopulated = self.populateSearchParamExpressionTable();
        if (isSearchParamsPopulated is error) {
            io:print("An error occured while populating the SEARCH_PARAM_EXPRESSION_TABLE: " + isSearchParamsPopulated.message());
            return false;
        } else {
            io:println("SEARCH_PARAM_EXPRESSION TABLE populated successfully!");
            return true;
        }
    }

    private function convertToParameterizedQuery(readonly & string[] strQuery) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery parameterizedQuery = ``;
        parameterizedQuery.strings = strQuery;
        return parameterizedQuery;
    }

    private function retreiveQueriesFromSchema() returns error? {
        string[] readLines = check io:fileReadLines(self.filePath);

        boolean inCreateQuery = false;
        string currentCreateQuery = "";

        foreach string line in readLines {
            string trimmed = string:trim(line);

            if trimmed == "" {
                continue;
            }

            // Handle DROP queries
            if trimmed.startsWith("DROP") && trimmed.endsWith(";") {
                readonly & string[] tempArr = [trimmed];
                self.dropQueries.push(self.convertToParameterizedQuery(tempArr));
                continue;
            }

            // Handle CREATE queries
            if trimmed.startsWith("CREATE") {
                inCreateQuery = true;
                currentCreateQuery = trimmed;

                // If CREATE ends immediately with `;`
                if trimmed.endsWith(";") {
                    readonly & string[] tempArr = [currentCreateQuery];
                    self.createQueries.push(self.convertToParameterizedQuery(tempArr));
                    inCreateQuery = false;
                    currentCreateQuery = "";
                }
                continue;
            }

            if inCreateQuery {
                currentCreateQuery = currentCreateQuery + " " + trimmed;

                if trimmed.endsWith(";") {
                    readonly & string[] tempArr = [currentCreateQuery];
                    self.createQueries.push(self.convertToParameterizedQuery(tempArr));
                    inCreateQuery = false;
                    currentCreateQuery = "";
                }
            }
        }
    }

    private function populateSearchParamExpressionTable() returns error? {
        final string dataFilePath = "./assets/r4-searchParam-Expression.csv";
        final string[] readLines = check io:fileReadLines(dataFilePath);
        final string:RegExp regex = re `,`;
        int i = 0;
        int totRecords = 0;

        jdbc:Client jdbcConn = check self.jdbcClient;

        foreach string line in readLines {
            i += 1;

            // Exclude Header
            if (i == 1) {
                continue;
            }

            string[] data = regex.split(line);

            if (data.length() == 4) {
                string searchParamName = data[0];
                string 'resource = data[1];
                string searchParamType = data[2];
                string expression = data[3];

                string sqlQuery = string `INSERT INTO "SEARCH_PARAM_RES_EXPRESSIONS" (SEARCH_PARAM_NAME, SEARCH_PARAM_TYPE, RESOURCE_NAME, EXPRESSION) VALUES ('${searchParamName}', '${searchParamType}', '${'resource}', '${expression}')`;
                sql:ParameterizedQuery query = new utils:RawSQLQuery(sqlQuery);

                sql:ExecutionResult result = check jdbcConn->execute(query);
                if result.lastInsertId is int {
                    totRecords = <int>result.lastInsertId;
                }
            }
        }
        io:println("Total Records Inserted: " + totRecords.toString());
    }
}
