// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title DeployAll Script
 * @notice Comprehensive deployment script for all Valence Protocol contracts
 * @dev Before running this script, make sure to set up your environment variables.
 *      See DEPLOYMENT_SETUP.md for detailed instructions.
 *
 * Required Environment Variables:
 * - OWNER_PRIVATE_KEY: Private key for contract owner
 * - PROCESSOR_PRIVATE_KEY: Private key for processor account
 *
 * Usage:
 *   forge script script/DeployAll.script.sol --fork-url sepolia --broadcast
 */
import {Script} from "forge-std/src/Script.sol";
import {CCTPTransfer} from "../src/libraries/CCTPTransfer.sol";
import {CompoundV3PositionManager} from "../src/libraries/CompoundV3PositionManager.sol";
import {AavePositionManager} from "../src/libraries/AavePositionManager.sol";
import {PancakeSwapV3PositionManager} from "../src/libraries/PancakeSwapV3PositionManager.sol";
import {Forwarder} from "../src/libraries/Forwarder.sol";
import {Splitter} from "../src/libraries/Splitter.sol";
import {ValenceVault} from "../src/vaults/ValenceVault.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {Account} from "../src/accounts/Account.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {ITokenMessenger} from "../src/libraries/interfaces/cctp/ITokenMessenger.sol";
import {CometMainInterface} from "../src/libraries/interfaces/compoundV3/CometMainInterface.sol";
import {IPool} from "aave-v3-origin/interfaces/IPool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console} from "forge-std/src/console.sol";
import {Authorization} from "../src/authorization/Authorization.sol";
import {LiteProcessor} from "../src/processor/LiteProcessor.sol";

contract DeployAllScript is Script {
    // Ethereum Sepolia Testnet Addresses
    address USDC = vm.envAddress("USDC");
    address WETH = vm.envAddress("WETH");
    address DAI = vm.envAddress("DAI");
    address COMPOUND_V3_USDC_MARKET = vm.envAddress("COMPOUND_V3_USDC_MARKET");
    address CCTP_TOKEN_MESSENGER = vm.envAddress("CCTP_TOKEN_MESSENGER");
    address AAVE_POOL = vm.envAddress("AAVE_POOL");
    address constant REWARDS_SEPOLIA = 0x8bF5b658bdF0388E8b482ED51B14aef58f90abfD;

    // Native ETH
    address constant NATIVE_ETH = address(0);

    // Deployed contract instances
    CCTPTransfer public cctpTransfer;
    CompoundV3PositionManager public positionManager;
    CompoundV3PositionManager public positionManagerArbitrum; // Arbitrum deployment
    AavePositionManager public aavePositionManager;
    PancakeSwapV3PositionManager public pancakePositionManager; // Arbitrum only
    Forwarder public forwarder;
    Splitter public splitter;
    Splitter public splitterArbitrum; // Arbitrum deployment
    ValenceVault public valenceVault;

    // Ethereum Sepolia Accounts
    BaseAccount public inputAccount1;
    BaseAccount public inputAccount2;
    BaseAccount public inputAccount3; // For Splitter
    BaseAccount public aaveInputAccount; // For Aave
    BaseAccount public aaveOutputAccount; // For Aave
    BaseAccount public vaultDepositAccount; // For Vault
    BaseAccount public vaultWithdrawAccount; // For Vault
    BaseAccount public outputAccount1;
    BaseAccount public outputAccount2;
    BaseAccount public outputAccount3; // For Splitter
    BaseAccount public outputAccount4; // For Splitter
    BaseAccount public cctpAccount;

    // // Arbitrum Sepolia Accounts
    // BaseAccount public arbitrumInputAccount1; // For Compound on Arbitrum
    // BaseAccount public arbitrumOutputAccount1; // For Compound on Arbitrum
    // BaseAccount public arbitrumInputAccount2; // For Splitter on Arbitrum
    // BaseAccount public arbitrumOutputAccount2; // For Splitter on Arbitrum
    // BaseAccount public arbitrumOutputAccount3; // For Splitter on Arbitrum
    // BaseAccount public pancakeInputAccount; // For PancakeSwap
    // BaseAccount public pancakeOutputAccount; // For PancakeSwap

    address owner;
    LiteProcessor processor;

    function run() external {
        // Get private keys from environment variables with helpful error messages
        uint256 ownerPrivateKey;

        try vm.envUint("OWNER_PRIVATE_KEY") returns (uint256 key) {
            ownerPrivateKey = key;
        } catch {
            console.log("ERROR: OWNER_PRIVATE_KEY environment variable not set!");
            console.log("Please set it in your .env file or export it:");
            console.log("export OWNER_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef");
            revert("Missing OWNER_PRIVATE_KEY environment variable");
        }

        owner = vm.addr(ownerPrivateKey);

        console.log("=== COMPREHENSIVE DEPLOYMENT SCRIPT ===");
        console.log("Network: Sepolia Testnet");
        console.log("Owner:", owner);
        console.log("Processor:", address(processor));
        console.log("");
        console.log("Environment Variables Used:");
        console.log("  OWNER_PRIVATE_KEY: ****");
        console.log("  PROCESSOR_PRIVATE_KEY: ****");
        console.log("");

        vm.startBroadcast(ownerPrivateKey);

        // Deploy all required accounts
        _deployAccounts();

        // Deploy all contracts
        _deployAuthorizationAndProcessor();
        _deployCCTPTransfer();
        _deployCompoundV3PositionManager();
        _deployAavePositionManager();
        _deployForwarder();
        _deploySplitter();
        _deployValenceVault();

        vm.stopBroadcast();

        _printDeploymentSummary();
    }

    function _deployAuthorizationAndProcessor() internal {
        console.log("Deploying Authorization and Processor...");

        // Deploy Authorization contract
        address[] memory authorizedAddresses = new address[](1);
        authorizedAddresses[0] = owner; // Owner is the only authorized address for now

        Authorization authorization = new Authorization(
            owner,
            owner,
            address(0), // Placeholder for mailbox, set to zero for now
            true // Enable authorization
        );

        console.log("  Authorization deployed at:", address(authorization));

        // Deploy Processor contract
        processor = new LiteProcessor(
            "", // Placeholder for mailbox, set to zero for now
            address(0), // Placeholder for mailbox, set to zero for now
            1, // Origin domain ID, can be set as needed
            authorizedAddresses
        );

        console.log("  Processor deployed at:", address(processor));
        console.log("");
    }

    function _deployAccounts() internal {
        console.log("1. Deploying Accounts...");

        // Deploy BaseAccount contracts
        inputAccount1 = new BaseAccount(owner, new address[](0));
        inputAccount2 = new BaseAccount(owner, new address[](0));
        inputAccount3 = new BaseAccount(owner, new address[](0));
        aaveInputAccount = new BaseAccount(owner, new address[](0));
        aaveOutputAccount = new BaseAccount(owner, new address[](0));
        vaultDepositAccount = new BaseAccount(owner, new address[](0));
        vaultWithdrawAccount = new BaseAccount(owner, new address[](0));
        outputAccount1 = new BaseAccount(owner, new address[](0));
        outputAccount2 = new BaseAccount(owner, new address[](0));
        outputAccount3 = new BaseAccount(owner, new address[](0));
        outputAccount4 = new BaseAccount(owner, new address[](0));

        // Deploy Account contract for CCTP
        cctpAccount = new BaseAccount(owner, new address[](0));

        console.log("  Input Account 1:", address(inputAccount1));
        console.log("  Input Account 2:", address(inputAccount2));
        console.log("  Input Account 3:", address(inputAccount3));
        console.log("  Aave Input Account:", address(aaveInputAccount));
        console.log("  Aave Output Account:", address(aaveOutputAccount));
        console.log("  Vault Deposit Account:", address(vaultDepositAccount));
        console.log("  Vault Withdraw Account:", address(vaultWithdrawAccount));
        console.log("  Output Account 1:", address(outputAccount1));
        console.log("  Output Account 2:", address(outputAccount2));
        console.log("  Output Account 3:", address(outputAccount3));
        console.log("  Output Account 4:", address(outputAccount4));
        console.log("  CCTP Account:", address(cctpAccount));
        console.log("");
    }

    function _deployCCTPTransfer() internal {
        console.log("2. Deploying CCTPTransfer...");

        // Create CCTP configuration
        CCTPTransfer.CCTPTransferConfig memory cctpConfig = CCTPTransfer.CCTPTransferConfig({
            amount: 100 * 10 ** 6, // 100 USDC
            mintRecipient: bytes32(uint256(uint160(owner))), // Convert owner address to bytes32
            inputAccount: cctpAccount,
            destinationDomain: 5, // Polygon domain (adjust as needed)
            cctpTokenMessenger: ITokenMessenger(CCTP_TOKEN_MESSENGER),
            transferToken: USDC
        });

        bytes memory cctpConfigBytes = abi.encode(cctpConfig);
        cctpTransfer = new CCTPTransfer(owner, address(processor), cctpConfigBytes);

        // Approve library
        cctpAccount.approveLibrary(address(cctpTransfer));

        console.log("  CCTPTransfer deployed at:", address(cctpTransfer));
        console.log("  Configured for 100 USDC transfers to domain 5");
        console.log("");
    }

    function _deployCompoundV3PositionManager() internal {
        console.log("3. Deploying CompoundV3PositionManager...");

        // Verify market configuration
        address marketBaseToken = CometMainInterface(COMPOUND_V3_USDC_MARKET).baseToken();
        require(marketBaseToken == USDC, "Market base token mismatch");

        // Create Compound configuration
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory compoundConfig = CompoundV3PositionManager
            .CompoundV3PositionManagerConfig({
            inputAccount: inputAccount1,
            outputAccount: outputAccount1,
            baseAsset: USDC,
            marketProxyAddress: COMPOUND_V3_USDC_MARKET,
            rewards: REWARDS_SEPOLIA
        });

        bytes memory compoundConfigBytes = abi.encode(compoundConfig);
        positionManager = new CompoundV3PositionManager(owner, address(processor), compoundConfigBytes);

        // Approve library
        inputAccount1.approveLibrary(address(positionManager));
        outputAccount1.approveLibrary(address(positionManager));

        console.log("  CompoundV3PositionManager deployed at:", address(positionManager));
        console.log("  Configured for USDC lending on Compound V3");
        console.log("");
    }

    function _deployAavePositionManager() internal {
        console.log("4. Deploying AavePositionManager...");

        // Create Aave configuration
        AavePositionManager.AavePositionManagerConfig memory aaveConfig = AavePositionManager.AavePositionManagerConfig({
            poolAddress: IPool(AAVE_POOL),
            inputAccount: aaveInputAccount,
            outputAccount: aaveOutputAccount,
            supplyAsset: USDC,
            borrowAsset: DAI,
            referralCode: 0
        });

        bytes memory aaveConfigBytes = abi.encode(aaveConfig);
        aavePositionManager = new AavePositionManager(owner, address(processor), aaveConfigBytes);

        // Approve library
        aaveInputAccount.approveLibrary(address(aavePositionManager));
        aaveOutputAccount.approveLibrary(address(aavePositionManager));

        console.log("  AavePositionManager deployed at:", address(aavePositionManager));
        console.log("  Configured for USDC supply and DAI borrow on Aave V3 Sepolia");
        console.log("");
    }

    function _deployForwarder() internal {
        console.log("5. Deploying Forwarder...");

        // Create forwarding configurations
        Forwarder.ForwardingConfig[] memory forwardingConfigs = new Forwarder.ForwardingConfig[](3);

        forwardingConfigs[0] = Forwarder.ForwardingConfig({
            tokenAddress: NATIVE_ETH,
            maxAmount: 0.01 ether // Small amount for testing
        });

        forwardingConfigs[1] = Forwarder.ForwardingConfig({
            tokenAddress: USDC,
            maxAmount: 100 * 10 ** 6 // 100 USDC
        });

        forwardingConfigs[2] = Forwarder.ForwardingConfig({
            tokenAddress: WETH,
            maxAmount: 0.01 ether // 0.01 WETH
        });

        // Create main forwarder configuration
        Forwarder.ForwarderConfig memory forwarderConfig = Forwarder.ForwarderConfig({
            inputAccount: inputAccount2,
            outputAccount: outputAccount2,
            forwardingConfigs: forwardingConfigs,
            intervalType: Forwarder.IntervalType.TIME,
            minInterval: 300 // 5 minutes for testing
        });

        bytes memory forwarderConfigBytes = abi.encode(forwarderConfig);
        forwarder = new Forwarder(owner, address(processor), forwarderConfigBytes);

        // Approve library
        inputAccount2.approveLibrary(address(forwarder));

        console.log("  Forwarder deployed at:", address(forwarder));
        console.log("  Configured for multi-token forwarding with 5min intervals");
        console.log("");
    }

    function _deploySplitter() internal {
        console.log("6. Deploying Splitter...");

        // Create split configurations
        Splitter.SplitConfig[] memory splits = new Splitter.SplitConfig[](5);

        // Native ETH splits (Fixed Ratio) - Total must equal 100%
        // 40% to output account 1
        splits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(400000000000000000) // 0.4 * 10^18
        });

        // 35% to output account 3
        splits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount3,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(350000000000000000) // 0.35 * 10^18
        });

        // 25% to output account 4
        splits[2] = Splitter.SplitConfig({
            outputAccount: outputAccount4,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(250000000000000000) // 0.25 * 10^18
        });

        // USDC splits (Fixed Amount)
        // 500 USDC to output account 1
        splits[3] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: USDC,
            splitType: Splitter.SplitType.FixedAmount,
            splitData: abi.encode(500 * 10 ** 6) // 500 USDC
        });

        // WETH splits (Fixed Ratio)
        // 100% to output account 3
        splits[4] = Splitter.SplitConfig({
            outputAccount: outputAccount3,
            token: WETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(1000000000000000000) // 1.0 * 10^18 (100%)
        });

        // Create main splitter configuration
        Splitter.SplitterConfig memory splitterConfig =
            Splitter.SplitterConfig({inputAccount: inputAccount3, splits: splits});

        bytes memory splitterConfigBytes = abi.encode(splitterConfig);
        splitter = new Splitter(owner, address(processor), splitterConfigBytes);

        // Approve library
        inputAccount3.approveLibrary(address(splitter));

        console.log("  Splitter deployed at:", address(splitter));
        console.log("  Configured for multi-token splitting");
        console.log("");
    }

    function _deployValenceVault() internal {
        console.log("7. Deploying ValenceVault...");

        // Create vault configuration
        ValenceVault.FeeConfig memory feeConfig = ValenceVault.FeeConfig({
            depositFeeBps: 50, // 0.5% deposit fee
            platformFeeBps: 200, // 2% annual platform fee
            performanceFeeBps: 1000, // 10% performance fee
            solverCompletionFee: 0.001 ether // 0.001 ETH solver fee
        });

        ValenceVault.FeeDistributionConfig memory feeDistribution = ValenceVault.FeeDistributionConfig({
            strategistAccount: owner, // Strategist receives fees
            platformAccount: address(processor), // Platform receives fees
            strategistRatioBps: 5000 // 50% to strategist, 50% to platform
        });

        ValenceVault.VaultConfig memory vaultConfig = ValenceVault.VaultConfig({
            depositAccount: vaultDepositAccount,
            withdrawAccount: vaultWithdrawAccount,
            strategist: owner,
            fees: feeConfig,
            feeDistribution: feeDistribution,
            depositCap: 1000000 * 10 ** 6, // 1M USDC cap
            withdrawLockupPeriod: 7 days, // 7 day withdraw lockup
            maxWithdrawFeeBps: 500 // Max 5% withdraw fee
        });

        bytes memory vaultConfigBytes = abi.encode(vaultConfig);

        // Deploy vault using proxy pattern (proper way for upgradeable contracts)
        ValenceVault implementation = new ValenceVault();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(
            ValenceVault.initialize,
            (
                owner,
                vaultConfigBytes,
                USDC,
                "Valence USDC Vault",
                "vUSDC",
                1e18 // 1:1 starting rate
            )
        );

        // Deploy proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        valenceVault = ValenceVault(address(proxy));

        console.log("  ValenceVault Implementation:", address(implementation));
        console.log("  ValenceVault Proxy:", address(valenceVault));
        console.log("  Configured for USDC with 1M cap and 7-day lockup");
        console.log("");
    }

    function _printDeploymentSummary() internal view {
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia Testnet");
        console.log("");
        console.log("ACCOUNTS:");
        console.log("  Input Account 1 (Compound):", address(inputAccount1));
        console.log("  Output Account 1 (Compound):", address(outputAccount1));
        console.log("  Input Account 2 (Forwarder):", address(inputAccount2));
        console.log("  Output Account 2 (Forwarder):", address(outputAccount2));
        console.log("  Input Account 3 (Splitter):", address(inputAccount3));
        console.log("  Aave Input Account:", address(aaveInputAccount));
        console.log("  Aave Output Account:", address(aaveOutputAccount));
        console.log("  Vault Deposit Account:", address(vaultDepositAccount));
        console.log("  Vault Withdraw Account:", address(vaultWithdrawAccount));
        console.log("  Output Account 3 (Splitter):", address(outputAccount3));
        console.log("  Output Account 4 (Splitter):", address(outputAccount4));
        console.log("  CCTP Account:", address(cctpAccount));
        console.log("");
        console.log("CONTRACTS:");
        console.log("  CCTPTransfer:", address(cctpTransfer));
        console.log("  CompoundV3PositionManager:", address(positionManager));
        console.log("  AavePositionManager:", address(aavePositionManager));
        console.log("  Forwarder:", address(forwarder));
        console.log("  Splitter:", address(splitter));
        console.log("  ValenceVault:", address(valenceVault));
        console.log("");
        console.log("TOKEN ADDRESSES:");
        console.log("  USDC:", USDC);
        console.log("  WETH:", WETH);
        console.log("  DAI:", DAI);
        console.log("  Compound Market:", COMPOUND_V3_USDC_MARKET);
        console.log("  Aave Pool:", AAVE_POOL);
        console.log("  CCTP Messenger:", CCTP_TOKEN_MESSENGER);
        console.log("");
        console.log("ROLES:");
        console.log("  Owner:", owner);
        console.log("  Processor:", address(processor));
        console.log("");
        console.log("All contracts deployed and configured successfully!");
    }

    // Helper functions for environment variables
    function _getOwnerPrivateKey() internal view returns (uint256) {
        try vm.envUint("OWNER_PRIVATE_KEY") returns (uint256 key) {
            return key;
        } catch {
            revert("OWNER_PRIVATE_KEY environment variable not set. Please export it or add to .env file.");
        }
    }
}
