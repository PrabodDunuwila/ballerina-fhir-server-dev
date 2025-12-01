// Custom type definitions to replace persist-generated types

public type SearchParamExpression record {|
    string SEARCH_PARAM_NAME;
    string SEARCH_PARAM_TYPE;
    string RESOURCE_NAME;
    string EXPRESSION;
|};

public type Reference record {|
    int ID;
    string SOURCE_RESOURCE_TYPE;
    string SOURCE_RESOURCE_ID;
    string SOURCE_EXPRESSION;
    string TARGET_RESOURCE_TYPE;
    string TARGET_RESOURCE_ID;
    string DISPLAY_VALUE;
    anydata CREATED_AT;
    anydata UPDATED_AT;
    anydata LAST_UPDATED;
|};
