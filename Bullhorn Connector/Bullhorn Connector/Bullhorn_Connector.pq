// This file contains your Data Connector logic
section Bullhorn_Connector;

[DataSource.Kind="Bullhorn_Connector", Publish="Bullhorn_Connector.Publish"]
shared Bullhorn_Connector.Feed = Value.ReplaceType(BHImpl, type function (url as Uri.Type) as any);

BHImpl = (url as text) =>
    let
        source = 
        Web.Contents(
            url,
            [ Headers = DefaultRequestHeaders ]
        ),
		json = Json.Document(source),
        fullResult = if (Record.HasFields(json, {"error", "error_description"})) then
            error Error.Record(json[error], json[error_description], json)
                else
            json
    in
        fullResult;

//Bullhorn OAuth 2 Values
client_id_init = ""; // Client ID
client_secret_init = ""; //Client Secret
username_init = ""; //API Account Username
password_init = ""; //API Account Password
redirect_uri_init = ""; //Redirect URI - Default is "http://www.bullhorn.com"
AuthorizeUrl_init = ""; //Authorise URL
TokenURL_init = ""; //Token URL
CallbackUri_init = ""; //Callback URI - Default is "https://www.bullhorn.com"
BHTokenURL_init = ""; //BH Token URL - this will be similar to "https://rest-apac.bullhornstaffing.com/rest-services/login?version=*"


// Data Source Kind description
Bullhorn_Connector = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

DefaultRequestHeaders =
    let
        storage = 
            [
                #"BhRestToken" = Extension.CurrentCredential()[access_token],
                #"Accept" = "application/json;odata.metadata=minimal",  // column name and values only
                #"OData-MaxVersion" = "4.0"                             // we only support v4
            ]
    in
        storage;

//Helper Functions for Login

StartLogin = (resourceUrl, state, display) =>
        let
            AuthorizeUrl = AuthorizeUrl_init & Uri.BuildQueryString([
                client_id = client_id_init,
                response_type = "code",
                action = "Login",
                username = username_init,
                password = password_init,
                state = state,
                redirect_uri = redirect_uri_init
                ])
        in
            [
                LoginUri = AuthorizeUrl,
                CallbackUri = CallbackUri_init,
                WindowHeight = 500,
                WindowWidth = 500,
                Context = null
            ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod("authorization_code","code",Parts[code]);

Refresh = (resourceUrl, refresh_token) => 
        TokenMethod(
            "refresh_token", 
            "refresh_token", 
            refresh_token
        );

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id_init,
            client_secret = client_secret_init,
            grant_type = grantType,
            redirect_uri = redirect_uri_init
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        authToken = Web.Contents(TokenURL_init, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400}
        ]),
        body = Json.Document(authToken),
        result = if (Record.HasFields(body, {"error", "error_description"})) then
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body,

        restQueryString = [

        ],
        restQuery = Record.AddField(restQueryString, "access_token", body[access_token]),

        restToken = Web.Contents(BHTokenURL_init, [
            Content = Text.ToBinary(Uri.BuildQueryString(restQuery)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400}
        ]),
        restBody = Json.Document(restToken),
        restResult = if (Record.HasFields(restBody, {"error", "error_description"})) then
                    error Error.Record(restBody[error], restBody[error_description], restBody)
                 else
                    restBody,
       accessToken = [],
       accessTokenAdd = Record.AddField(accessToken,"access_token",restBody[BhRestToken])

    in
        accessTokenAdd;

// Data Source UI publishing description
Bullhorn_Connector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Bullhorn_Connector.Icons,
    SourceTypeImage = Bullhorn_Connector.Icons
];

Bullhorn_Connector.Icons = [
    Icon16 = { Extension.Contents("Bullhorn_Connector16.png"), Extension.Contents("Bullhorn_Connector20.png"), Extension.Contents("Bullhorn_Connector24.png"), Extension.Contents("Bullhorn_Connector32.png") },
    Icon32 = { Extension.Contents("Bullhorn_Connector32.png"), Extension.Contents("Bullhorn_Connector40.png"), Extension.Contents("Bullhorn_Connector48.png"), Extension.Contents("Bullhorn_Connector64.png") }
];