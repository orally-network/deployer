#! /bin/bash

set -e

case $1 in
  ic)
    NETWORK="--network ic"
    ;;
  local)
    NETWORK=''
    ;;
  *)
    echo "Please specify network."
    exit 0
    ;;
esac

# clean enviroment
dfx stop && dfx start --clean --background

# deploy the siwe_signer canister
cd pythia
dfx deploy siwe_signer_mock $NETWORK
SIWE_SIGNER_CANISTER_ID=$(dfx canister id siwe_signer_mock $NETWORK)
cd -

# deploy the treasurer canister
cd treasurer
read 
ENCODED_INIT_CONFIG=$(didc encode "(record {token_addr=\"338662C6e113aD9CfA4E2e755931643D8Cf1884B\"; chain_rpc=\"https://rpc.sepolia.org\"; siwe_signer_canister=principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; key_name=\"dfx_test_key\"; chain_id=11155111:nat; treasurer=\"E86C4A45C1Da21f8838a1ea26Fc852BD66489ce9\"})")
dfx deploy treasurer --argument "$ENCODED_INIT_CONFIG" --argument-type raw $NETWORK
dfx canister call treasurer init_controllers --async $NETWORK
TREASURER_CANISTER_ID=$(dfx canister id treasurer $NETWORK)
cd -

# deploy the exchange_rate_canister
cd sybil
dfx deploy exchange_rate_canister
ECHANGE_RATE_CANISTER_ID=$(dfx canister id exchange_rate_canister $NETWORK)
cd -

# deploy the sybil canister
cd sybil
dfx canister create sybil $NETWORK
dfx build sybil $NETWORK
gzip -f -1 ./.dfx/local/canisters/sybil/sybil.wasm
dfx canister install --wasm ./.dfx/local/canisters/sybil/sybil.wasm.gz $NETWORK sybil
dfx canister call sybil set_expiration_time '(3600:nat)' --async $NETWORK
dfx canister call sybil set_siwe_signer_canister "(\"${SIWE_SIGNER_CANISTER_ID}\")" --async $NETWORK
dfx canister call sybil set_exchange_rate_canister "(\"${ECHANGE_RATE_CANISTER_ID}\")" --async $NETWORK
dfx canister call sybil set_treasurer_canister "(\"${TREASURER_CANISTER_ID}\")" --async $NETWORK
dfx canister call sybil set_key_name '("dfx_test_key")' --async $NETWORK
dfx canister call sybil set_cost_per_execution '(1)' --async $NETWORK
SYBIL_CANISTER_ID=$(dfx canister id sybil $NETWORK)
cd -

# deploy the pythia canister
cd pythia
dfx canister create pythia $NETWORK
dfx build pythia $NETWORK
gzip -f -1 ./.dfx/local/canisters/pythia/pythia.wasm
dfx canister install --wasm ./.dfx/local/canisters/pythia/pythia.wasm.gz --argument "(0:nat, \"dfx_test_key\", principal \"${SIWE_SIGNER_CANISTER_ID}\", principal \"${SYBIL_CANISTER_ID}\")" $NETWORK pythia
cd -