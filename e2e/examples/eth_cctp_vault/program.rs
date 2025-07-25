use std::collections::BTreeMap;
use std::error::Error;
use std::path::Path;
use std::time::Duration;

use cosmwasm_std::{Binary, Uint128};
use localic_std::modules::cosmwasm::contract_instantiate;
use localic_utils::utils::test_context::TestContext;
use localic_utils::{
    DEFAULT_KEY, NEUTRON_CHAIN_ADMIN_ADDR, NEUTRON_CHAIN_DENOM, NEUTRON_CHAIN_NAME,
};
use log::info;

use valence_e2e::utils::astroport::{setup_astroport_lper_lib, setup_astroport_lwer_lib};
use valence_e2e::utils::base_account::{approve_library, create_base_accounts};

use valence_e2e::utils::manager::{
    ASTROPORT_LPER_NAME, ASTROPORT_WITHDRAWER_NAME, BASE_ACCOUNT_NAME, FORWARDER_NAME,
    ICA_CCTP_TRANSFER_NAME, ICA_IBC_TRANSFER_NAME, INTERCHAIN_ACCOUNT_NAME,
    NEUTRON_IBC_TRANSFER_NAME,
};
use valence_e2e::utils::vault::{setup_liquidation_fwd_lib, setup_neutron_ibc_transfer_lib};
use valence_e2e::utils::{LOCAL_CODE_ID_CACHE_PATH_NEUTRON, NOBLE_CHAIN_NAME, UUSDC_DENOM};
use valence_ica_ibc_transfer::msg::RemoteChainInfo;
use valence_library_utils::liquidity_utils::AssetData;
use valence_library_utils::LibraryAccountType;

use crate::neutron::ica::{instantiate_interchain_account_contract, register_interchain_account};
use crate::strategist::strategy_config;
use crate::VAULT_NEUTRON_CACHE_PATH;

pub fn setup_neutron_accounts(
    test_ctx: &mut TestContext,
) -> Result<strategy_config::neutron::NeutronAccounts, Box<dyn Error>> {
    let base_account_code_id = test_ctx
        .get_contract()
        .contract(BASE_ACCOUNT_NAME)
        .get_cw()
        .code_id
        .unwrap();

    let neutron_base_accounts = create_base_accounts(
        test_ctx,
        DEFAULT_KEY,
        NEUTRON_CHAIN_NAME,
        base_account_code_id,
        NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        vec![],
        4,
        None,
    );

    let noble_inbound_interchain_account_addr = instantiate_interchain_account_contract(test_ctx)?;
    let noble_outbound_interchain_account_addr = instantiate_interchain_account_contract(test_ctx)?;

    let inbound_noble_ica_addr =
        register_interchain_account(test_ctx, &noble_inbound_interchain_account_addr)?;
    let outbound_noble_ica_addr =
        register_interchain_account(test_ctx, &noble_outbound_interchain_account_addr)?;

    let neutron_accounts = strategy_config::neutron::NeutronAccounts {
        noble_inbound_ica: strategy_config::neutron::IcaAccount {
            library_account: noble_inbound_interchain_account_addr,
            remote_addr: inbound_noble_ica_addr,
        },
        noble_outbound_ica: strategy_config::neutron::IcaAccount {
            library_account: noble_outbound_interchain_account_addr,
            remote_addr: outbound_noble_ica_addr,
        },
        deposit: neutron_base_accounts[0].to_string(),
        position: neutron_base_accounts[1].to_string(),
        withdraw: neutron_base_accounts[2].to_string(),
        liquidation: neutron_base_accounts[3].to_string(),
    };

    Ok(neutron_accounts)
}

pub fn upload_neutron_contracts(test_ctx: &mut TestContext) -> Result<(), Box<dyn Error>> {
    // copy over relevant contracts from artifacts/ to local path
    let local_contracts_path = Path::new(VAULT_NEUTRON_CACHE_PATH);
    if !local_contracts_path.exists() {
        std::fs::create_dir(local_contracts_path)?;
    }

    for contract in [
        INTERCHAIN_ACCOUNT_NAME,
        ASTROPORT_LPER_NAME,
        ASTROPORT_WITHDRAWER_NAME,
        NEUTRON_IBC_TRANSFER_NAME,
        FORWARDER_NAME,
        ICA_CCTP_TRANSFER_NAME,
        ICA_IBC_TRANSFER_NAME,
        BASE_ACCOUNT_NAME,
    ] {
        let contract_name = format!("{contract}.wasm");
        let contract_path = Path::new(&contract_name);
        let src = Path::new("artifacts/").join(contract_path);
        let dest = local_contracts_path.join(contract_path);
        std::fs::copy(src, dest)?;
    }

    let mut uploader = test_ctx.build_tx_upload_contracts();
    uploader
        .with_chain_name(NEUTRON_CHAIN_NAME)
        .send_with_local_cache(
            "e2e/examples/eth_cctp_vault/neutron_contracts/",
            LOCAL_CODE_ID_CACHE_PATH_NEUTRON,
        )?;

    Ok(())
}

#[allow(clippy::too_many_arguments)]
pub fn setup_neutron_libraries(
    test_ctx: &mut TestContext,
    neutron_program_accounts: &strategy_config::neutron::NeutronAccounts,
    pool: &str,
    authorizations: &str,
    processor: &str,
    amount: u128,
    usdc_on_neutron: &str,
    eth_withdraw_acc: String,
    lp_token_denom: &str,
) -> Result<strategy_config::neutron::NeutronLibraries, Box<dyn Error>> {
    let astro_cl_pool_asset_data = AssetData {
        asset1: NEUTRON_CHAIN_DENOM.to_string(),
        asset2: usdc_on_neutron.to_string(),
    };

    // library to enter into the position from the deposit account
    // and route the issued shares into the into the position account
    let astro_lper_lib = setup_astroport_lper_lib(
        test_ctx,
        neutron_program_accounts.deposit.to_string(),
        neutron_program_accounts.position.to_string(),
        astro_cl_pool_asset_data.clone(),
        pool.to_string(),
        processor.to_string(),
        authorizations.to_string(),
    )?;

    // library to forward the required amount of shares, from the position account
    // to the liquidation account, needed to fulfill the withdraw obligations
    let forwarder_lib = setup_liquidation_fwd_lib(
        test_ctx,
        neutron_program_accounts.position.to_string(),
        neutron_program_accounts.liquidation.to_string(),
        lp_token_denom,
    )?;

    // library to withdraw the position held by the position account
    // and route the underlying funds into the withdraw account
    let astro_lwer_lib = setup_astroport_lwer_lib(
        test_ctx,
        neutron_program_accounts.liquidation.to_string(),
        neutron_program_accounts.withdraw.to_string(),
        astro_cl_pool_asset_data.clone(),
        pool.to_string(),
        processor.to_string(),
    )?;

    // library to move USDC from a program-owned ICA on noble
    // into the deposit account on neutron
    let ica_ibc_transfer_lib = setup_ica_ibc_transfer_lib(
        test_ctx,
        &neutron_program_accounts.noble_inbound_ica.library_account,
        &neutron_program_accounts.deposit,
        amount,
    )?;

    // library to move USDC from a program-owned ICA on noble
    // into the withdraw account on ethereum
    let cctp_forwarder_lib_addr = setup_cctp_forwarder_lib(
        test_ctx,
        neutron_program_accounts
            .noble_outbound_ica
            .library_account
            .to_string(),
        eth_withdraw_acc,
        processor.to_string(),
        authorizations.to_string(),
        amount,
    )?;

    // library to move USDC from the withdraw account on neutron
    // into a program-owned ICA on noble
    let neutron_ibc_transfer_lib = setup_neutron_ibc_transfer_lib(
        test_ctx,
        neutron_program_accounts.withdraw.to_string(),
        neutron_program_accounts
            .noble_outbound_ica
            .remote_addr
            .to_string(),
        usdc_on_neutron,
        authorizations.to_string(),
        processor.to_string(),
        NOBLE_CHAIN_NAME,
        None,
    )?;

    info!("approving strategist on liquidation account...");
    approve_library(
        test_ctx,
        NEUTRON_CHAIN_NAME,
        DEFAULT_KEY,
        &neutron_program_accounts.liquidation.to_string(),
        NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        None,
    );

    let libraries = strategy_config::neutron::NeutronLibraries {
        astroport_lper: astro_lper_lib,
        astroport_lwer: astro_lwer_lib,
        noble_inbound_transfer: ica_ibc_transfer_lib,
        noble_cctp_transfer: cctp_forwarder_lib_addr,
        neutron_ibc_transfer: neutron_ibc_transfer_lib,
        liquidation_forwarder: forwarder_lib,
        authorizations: authorizations.to_string(),
        processor: processor.to_string(),
    };

    Ok(libraries)
}

pub fn setup_cctp_forwarder_lib(
    test_ctx: &mut TestContext,
    input_account: String,
    mut output_addr: String,
    _processor: String,
    _authorizations: String,
    amount: u128,
) -> Result<String, Box<dyn Error>> {
    let ica_cctp_transfer_code_id = test_ctx
        .get_contract()
        .contract(ICA_CCTP_TRANSFER_NAME)
        .get_cw()
        .code_id
        .unwrap();

    let trimmed_addr = output_addr.split_off(2);
    let mut mint_recipient = vec![0u8; 32];

    let addr_bytes = hex::decode(trimmed_addr).unwrap();
    mint_recipient[(32 - addr_bytes.len())..].copy_from_slice(&addr_bytes);

    let cctp_transfer_config = valence_ica_cctp_transfer::msg::LibraryConfig {
        input_addr: LibraryAccountType::Addr(input_account.to_string()),
        amount: (amount / 2).into(),
        denom: UUSDC_DENOM.to_string(),
        destination_domain_id: 0,
        mint_recipient: Binary::from(mint_recipient),
    };

    let ica_cctp_transfer_instantiate_msg = valence_library_utils::msg::InstantiateMsg::<
        valence_ica_cctp_transfer::msg::LibraryConfig,
    > {
        // TODO: uncomment to not bypass authorizations/processor logic
        // owner: authorizations.to_string(),
        // processor: processor.to_string(),
        owner: NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        processor: NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        config: cctp_transfer_config,
    };

    let cctp_transfer_lib = contract_instantiate(
        test_ctx
            .get_request_builder()
            .get_request_builder(NEUTRON_CHAIN_NAME),
        DEFAULT_KEY,
        ica_cctp_transfer_code_id,
        &serde_json::to_string(&ica_cctp_transfer_instantiate_msg)?,
        "cctp_transfer",
        None,
        "",
    )?;
    info!("cctp transfer lib: {}", cctp_transfer_lib.address);

    info!("approving cctp transfer library on account...");
    approve_library(
        test_ctx,
        NEUTRON_CHAIN_NAME,
        DEFAULT_KEY,
        &input_account,
        cctp_transfer_lib.address.to_string(),
        None,
    );

    Ok(cctp_transfer_lib.address)
}

pub fn setup_ica_ibc_transfer_lib(
    test_ctx: &mut TestContext,
    interchain_account_addr: &str,
    neutron_deposit_acc: &str,
    amount_to_transfer: u128,
) -> Result<String, Box<dyn Error>> {
    let ica_ibc_transfer_lib_code = *test_ctx
        .get_chain(NEUTRON_CHAIN_NAME)
        .contract_codes
        .get(ICA_IBC_TRANSFER_NAME)
        .unwrap();

    info!("ica ibc transfer lib code: {ica_ibc_transfer_lib_code}");

    info!("Instantiating the ICA IBC transfer contract...");
    let ica_ibc_transfer_instantiate_msg = valence_library_utils::msg::InstantiateMsg::<
        valence_ica_ibc_transfer::msg::LibraryConfig,
    > {
        owner: NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        processor: NEUTRON_CHAIN_ADMIN_ADDR.to_string(),
        config: valence_ica_ibc_transfer::msg::LibraryConfig {
            input_addr: LibraryAccountType::Addr(interchain_account_addr.to_string()),
            amount: Uint128::new(amount_to_transfer),
            denom: UUSDC_DENOM.to_string(),
            receiver: neutron_deposit_acc.to_string(),
            memo: "".to_string(),
            remote_chain_info: RemoteChainInfo {
                channel_id: test_ctx
                    .get_transfer_channels()
                    .src(NOBLE_CHAIN_NAME)
                    .dest(NEUTRON_CHAIN_NAME)
                    .get(),
                ibc_transfer_timeout: None,
            },
            denom_to_pfm_map: BTreeMap::default(),
            eureka_config: None,
        },
    };

    let ica_ibc_transfer = contract_instantiate(
        test_ctx
            .get_request_builder()
            .get_request_builder(NEUTRON_CHAIN_NAME),
        DEFAULT_KEY,
        ica_ibc_transfer_lib_code,
        &serde_json::to_string(&ica_ibc_transfer_instantiate_msg)?,
        "valence_ica_ibc_transfer",
        None,
        "",
    )?;
    info!(
        "ICA IBC transfer contract instantiated. Address: {}",
        ica_ibc_transfer.address
    );

    info!("Approving the ICA IBC transfer library...");
    approve_library(
        test_ctx,
        NEUTRON_CHAIN_NAME,
        DEFAULT_KEY,
        interchain_account_addr,
        ica_ibc_transfer.address.to_string(),
        None,
    );

    std::thread::sleep(Duration::from_secs(2));

    Ok(ica_ibc_transfer.address)
}
