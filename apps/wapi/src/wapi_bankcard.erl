-module(wapi_bankcard).

-include_lib("dmsl/include/dmsl_domain_thrift.hrl").
-include_lib("binbase_proto/include/binbase_binbase_thrift.hrl").

-export([lookup_bank_info/2]).

-type bank_info() :: #{
    payment_system := dmsl_domain_thrift:'BankCardPaymentSystem'(),
    bank_name      := binary(),
    issuer_country := dmsl_domain_thrift:'Residence'() | undefined,
    metadata       := map()
}.

-type lookup_error() ::
    notfound |
    {invalid,
        payment_system |
        issuer_country
    }.

-spec lookup_bank_info(_PAN :: binary(), woody_context:ctx()) ->
    {ok, bank_info()} | {error, lookup_error()}.

lookup_bank_info(PAN, WoodyCtx) ->
    RequestVersion = {'last', #binbase_Last{}},
    case wapi_woody_client:call_service(binbase, 'Lookup', [PAN, RequestVersion], WoodyCtx) of
        {ok, BinData} ->
            decode_bank_info(BinData);
        {exception, #binbase_BinNotFound{}} ->
            {error, notfound}
    end.

decode_bank_info(#binbase_ResponseData{bin_data = BinData, version = Version}) ->
    try
        {ok, #{
            payment_system => decode_payment_system(BinData#binbase_BinData.payment_system),
            bank_name      => BinData#binbase_BinData.bank_name,
            issuer_country => decode_issuer_country(BinData#binbase_BinData.iso_country_code),
            metadata       => #{
                <<"version">> => Version
            }
        }}
    catch
        {invalid, What} ->
            {error, {invalid, What}}
    end.

-define(invalid(What), erlang:throw({invalid, What})).

%% Payment system mapping
%%
%% List of known payment systems as of https://github.com/rbkmoney/binbase-data/commit/dcfabb1e.
%% Please keep in sorted order.
-spec decode_payment_system(binary()) ->
    dmsl_domain_thrift:'BankCardPaymentSystem'().

decode_payment_system(<<"AMERICAN EXPRESS">>)           -> amex;
decode_payment_system(<<"AMERICAN EXPRESS COMPANY">>)   -> amex;
decode_payment_system(<<"ATM CARD">>)                   -> ?invalid(payment_system);
decode_payment_system(<<"ATOS PRIVATE LABEL">>)         -> ?invalid(payment_system);
decode_payment_system(<<"AURA">>)                       -> ?invalid(payment_system);
decode_payment_system(<<"BANKCARD(INACTIVE)">>)         -> ?invalid(payment_system);
decode_payment_system(<<"BP FUEL CARD">>)               -> ?invalid(payment_system);
decode_payment_system(<<"CABAL">>)                      -> ?invalid(payment_system);
decode_payment_system(<<"CARNET">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"CHINA UNION PAY">>)            -> unionpay;
decode_payment_system(<<"CHJONES FUEL CARD">>)          -> ?invalid(payment_system);
decode_payment_system(<<"CIRRUS">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"COMPROCARD">>)                 -> ?invalid(payment_system);
decode_payment_system(<<"DANKORT">>)                    -> dankort;
decode_payment_system(<<"DFS/DCI">>)                    -> ?invalid(payment_system);
decode_payment_system(<<"DINACARD">>)                   -> ?invalid(payment_system);
decode_payment_system(<<"DINERS CLUB INTERNATIONAL">>)  -> dinersclub;
decode_payment_system(<<"DISCOVER">>)                   -> discover;
decode_payment_system(<<"DUET">>)                       -> ?invalid(payment_system);
decode_payment_system(<<"EBT">>)                        -> ?invalid(payment_system);
decode_payment_system(<<"EFTPOS">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"ELO">>)                        -> ?invalid(payment_system);
decode_payment_system(<<"ELO/DISCOVER">>)               -> ?invalid(payment_system);
decode_payment_system(<<"EUROSHELL FUEL CARD">>)        -> ?invalid(payment_system);
decode_payment_system(<<"FUEL CARD">>)                  -> ?invalid(payment_system);
decode_payment_system(<<"GE CAPITAL">>)                 -> ?invalid(payment_system);
decode_payment_system(<<"GLOBAL BC">>)                  -> ?invalid(payment_system);
decode_payment_system(<<"HIPERCARD">>)                  -> ?invalid(payment_system);
decode_payment_system(<<"HRG STORE CARD">>)             -> ?invalid(payment_system);
decode_payment_system(<<"JCB">>)                        -> jcb;
decode_payment_system(<<"LOCAL BRAND">>)                -> ?invalid(payment_system);
decode_payment_system(<<"LOCAL CARD">>)                 -> ?invalid(payment_system);
decode_payment_system(<<"LOYALTY CARD">>)               -> ?invalid(payment_system);
decode_payment_system(<<"LUKOIL FUEL CARD">>)           -> ?invalid(payment_system);
decode_payment_system(<<"MAESTRO">>)                    -> maestro;
decode_payment_system(<<"MASTERCARD">>)                 -> mastercard;
decode_payment_system(<<"NEWDAY">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"NSPK MIR">>)                   -> nspkmir;
decode_payment_system(<<"OUROCARD">>)                   -> ?invalid(payment_system);
decode_payment_system(<<"PAYPAL">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"PHH FUEL CARD">>)              -> ?invalid(payment_system);
decode_payment_system(<<"PRIVATE LABEL">>)              -> ?invalid(payment_system);
decode_payment_system(<<"PRIVATE LABEL CARD">>)         -> ?invalid(payment_system);
decode_payment_system(<<"PROSTIR">>)                    -> ?invalid(payment_system);
decode_payment_system(<<"RBS GIFT CARD">>)              -> ?invalid(payment_system);
decode_payment_system(<<"RED FUEL CARD">>)              -> ?invalid(payment_system);
decode_payment_system(<<"RED LIQUID FUEL CARD">>)       -> ?invalid(payment_system);
decode_payment_system(<<"RUPAY">>)                      -> ?invalid(payment_system);
decode_payment_system(<<"SBERCARD">>)                   -> ?invalid(payment_system);
decode_payment_system(<<"SODEXO">>)                     -> ?invalid(payment_system);
decode_payment_system(<<"STAR REWARDS">>)               -> ?invalid(payment_system);
decode_payment_system(<<"TROY">>)                       -> ?invalid(payment_system);
decode_payment_system(<<"UATP">>)                       -> ?invalid(payment_system);
decode_payment_system(<<"UK FUEL CARD">>)               -> ?invalid(payment_system);
decode_payment_system(<<"UNIONPAY">>)                   -> unionpay;
decode_payment_system(<<"VISA">>)                       -> visa;
decode_payment_system(<<"VISA/DANKORT">>)               -> visa; % supposedly 🤔
decode_payment_system(<<"VPAY">>)                       -> ?invalid(payment_system);
decode_payment_system(PaymentSystem) ->
    _ = logger:warning("unknown payment system encountered: ~s", [PaymentSystem]),
    ?invalid(payment_system).

%% Residence mapping
%%
-spec decode_issuer_country(binary() | undefined) ->
    dmsl_domain_thrift:'Residence'() | undefined.

decode_issuer_country(Residence) when is_binary(Residence) ->
    try
        {enum, Variants} = dmsl_domain_thrift:enum_info('Residence'),
        Variant = erlang:list_to_existing_atom(string:to_lower(erlang:binary_to_list(Residence))),
        element(1, lists:keyfind(Variant, 1, Variants))
    catch
        error:badarg ->
            _ = logger:warning("unknown residence encountered: ~s", [Residence]),
            ?invalid(issuer_country)
    end;
decode_issuer_country(undefined) ->
    undefined.
