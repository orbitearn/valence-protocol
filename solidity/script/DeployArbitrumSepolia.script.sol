// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title DeployArbitrumSepolia Script
 * @notice Deployment script for Arbitrum Sepolia network
 * @dev Before running this script, make sure to set up your environment variables.
 *      See DEPLOYMENT_SETUP.md for detailed instructions.
 *
 * Required Environment Variables:
 * - OWNER_PRIVATE_KEY: Private key for contract owner
 * - PROCESSOR_PRIVATE_KEY: Private key for processor account
 *
 * Usage:
 *   forge script script/DeployArbitrumSepolia.script.sol --fork-url arbitrum-sepolia --broadcast
 */
import {Script} from "forge-std/src/Script.sol";
import {CompoundV3PositionManager} from "../src/libraries/CompoundV3PositionManager.sol";
import {PancakeSwapV3PositionManager} from "../src/libraries/PancakeSwapV3PositionManager.sol";
import {Splitter} from "../src/libraries/Splitter.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {CometMainInterface} from "../src/libraries/interfaces/compoundV3/CometMainInterface.sol";
import {console} from "forge-std/src/console.sol";

contract DeployArbitrumSepoliaScript is Script {
    // Arbitrum Sepolia Testnet Addresses (Please verify these addresses)
    address constant USDC_ARBITRUM_SEPOLIA = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant WETH_ARBITRUM_SEPOLIA = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

    // Note: These are placeholder addresses - please update with actual Arbitrum Sepolia addresses
    address constant COMPOUND_V3_USDC_MARKET_ARBITRUM_SEPOLIA = 0x0000000000000000000000000000000000000001;
    address constant PANCAKESWAP_POSITION_MANAGER_ARBITRUM_SEPOLIA = 0x0000000000000000000000000000000000000002;
    address constant PANCAKESWAP_MASTER_CHEF_V3_ARBITRUM_SEPOLIA = 0x0000000000000000000000000000000000000003;
    uint24 constant PANCAKESWAP_POOL_FEE = 2500; // 0.25%

    // Native ETH
    address constant NATIVE_ETH = address(0);

    // Deployed contract instances
    CompoundV3PositionManager public positionManager;
    PancakeSwapV3PositionManager public pancakePositionManager;
    Splitter public splitter;

    // Accounts
    BaseAccount public compoundInputAccount;
    BaseAccount public compoundOutputAccount;
    BaseAccount public pancakeInputAccount;
    BaseAccount public pancakeOutputAccount;
    BaseAccount public splitterInputAccount;
    BaseAccount public splitterOutputAccount1;
    BaseAccount public splitterOutputAccount2;

    address owner;
    address processor;

    function run() external {
        // Get private keys from environment variables with helpful error messages
        uint256 ownerPrivateKey;
        uint256 processorPrivateKey;

        try vm.envUint("OWNER_PRIVATE_KEY") returns (uint256 key) {
            ownerPrivateKey = key;
        } catch {
            console.log("ERROR: OWNER_PRIVATE_KEY environment variable not set!");
            console.log("Please set it in your .env file or export it:");
            console.log("export OWNER_PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef");
            revert("Missing OWNER_PRIVATE_KEY environment variable");
        }

        try vm.envUint("PROCESSOR_PRIVATE_KEY") returns (uint256 key) {
            processorPrivateKey = key;
        } catch {
            console.log("ERROR: PROCESSOR_PRIVATE_KEY environment variable not set!");
            console.log("Please set it in your .env file or export it:");
            console.log(
                "export PROCESSOR_PRIVATE_KEY=0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
            );
            revert("Missing PROCESSOR_PRIVATE_KEY environment variable");
        }

        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        console.log("=== ARBITRUM SEPOLIA DEPLOYMENT SCRIPT ===");
        console.log("Network: Arbitrum Sepolia Testnet");
        console.log("Chain ID: 421614");
        console.log("Owner:", owner);
        console.log("Processor:", processor);
        console.log("");
        console.log("Environment Variables Used:");
        console.log("  OWNER_PRIVATE_KEY: ****");
        console.log("  PROCESSOR_PRIVATE_KEY: ****");
        console.log("");

        vm.startBroadcast(ownerPrivateKey);

        // Deploy all required accounts
        _deployAccounts();

        // Deploy all contracts
        _deployCompoundV3PositionManager();
        _deploySplitter();
        _deployPancakeSwapV3PositionManager();

        vm.stopBroadcast();

        _printDeploymentSummary();
    }

    function _deployAccounts() internal {
        console.log("1. Deploying Accounts...");

        // Deploy BaseAccount contracts
        compoundInputAccount = new BaseAccount(owner, new address[](0));
        compoundOutputAccount = new BaseAccount(owner, new address[](0));
        pancakeInputAccount = new BaseAccount(owner, new address[](0));
        pancakeOutputAccount = new BaseAccount(owner, new address[](0));
        splitterInputAccount = new BaseAccount(owner, new address[](0));
        splitterOutputAccount1 = new BaseAccount(owner, new address[](0));
        splitterOutputAccount2 = new BaseAccount(owner, new address[](0));

        console.log("  Compound Input Account:", address(compoundInputAccount));
        console.log("  Compound Output Account:", address(compoundOutputAccount));
        console.log("  PancakeSwap Input Account:", address(pancakeInputAccount));
        console.log("  PancakeSwap Output Account:", address(pancakeOutputAccount));
        console.log("  Splitter Input Account:", address(splitterInputAccount));
        console.log("  Splitter Output Account 1:", address(splitterOutputAccount1));
        console.log("  Splitter Output Account 2:", address(splitterOutputAccount2));
        console.log("");
    }

    function _deployCompoundV3PositionManager() internal {
        console.log("2. Deploying CompoundV3PositionManager on Arbitrum...");

        // Note: Skip verification since this is a placeholder address
        console.log("  Warning: Using placeholder Compound market address - please verify before production use");

        // Create Compound configuration
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory compoundConfig = CompoundV3PositionManager
            .CompoundV3PositionManagerConfig({
            inputAccount: compoundInputAccount,
            outputAccount: compoundOutputAccount,
            baseAsset: USDC_ARBITRUM_SEPOLIA,
            marketProxyAddress: COMPOUND_V3_USDC_MARKET_ARBITRUM_SEPOLIA
        });

        bytes memory compoundConfigBytes = abi.encode(compoundConfig);
        positionManager = new CompoundV3PositionManager(owner, processor, compoundConfigBytes);

        // Approve library
        compoundInputAccount.approveLibrary(address(positionManager));
        compoundOutputAccount.approveLibrary(address(positionManager));

        console.log("  CompoundV3PositionManager deployed at:", address(positionManager));
        console.log("  Configured for USDC lending on Compound V3 Arbitrum");
        console.log("");
    }

    function _deploySplitter() internal {
        console.log("3. Deploying Splitter on Arbitrum...");

        // Create split configurations for Arbitrum tokens
        Splitter.SplitConfig[] memory splits = new Splitter.SplitConfig[](3);

        // Native ETH splits (Fixed Ratio) - 60% to account 1, 40% to account 2
        splits[0] = Splitter.SplitConfig({
            outputAccount: splitterOutputAccount1,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(600000000000000000) // 0.6 * 10^18 (60%)
        });

        splits[1] = Splitter.SplitConfig({
            outputAccount: splitterOutputAccount2,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(400000000000000000) // 0.4 * 10^18 (40%)
        });

        // USDC splits (Fixed Amount) - 1000 USDC to account 1
        splits[2] = Splitter.SplitConfig({
            outputAccount: splitterOutputAccount1,
            token: USDC_ARBITRUM_SEPOLIA,
            splitType: Splitter.SplitType.FixedAmount,
            splitData: abi.encode(1000 * 10 ** 6) // 1000 USDC
        });

        // Create main splitter configuration
        Splitter.SplitterConfig memory splitterConfig =
            Splitter.SplitterConfig({inputAccount: splitterInputAccount, splits: splits});

        bytes memory splitterConfigBytes = abi.encode(splitterConfig);
        splitter = new Splitter(owner, processor, splitterConfigBytes);

        // Approve library
        splitterInputAccount.approveLibrary(address(splitter));

        console.log("  Splitter deployed at:", address(splitter));
        console.log("  Configured for Arbitrum token splitting");
        console.log("");
    }

    function _deployPancakeSwapV3PositionManager() internal {
        console.log("4. Deploying PancakeSwapV3PositionManager on Arbitrum...");

        console.log("  Warning: Using placeholder PancakeSwap addresses - please verify before production use");

        // Create PancakeSwap configuration
        PancakeSwapV3PositionManager.PancakeSwapV3PositionManagerConfig memory pancakeConfig =
        PancakeSwapV3PositionManager.PancakeSwapV3PositionManagerConfig({
            inputAccount: pancakeInputAccount,
            outputAccount: pancakeOutputAccount,
            positionManager: PANCAKESWAP_POSITION_MANAGER_ARBITRUM_SEPOLIA,
            masterChef: PANCAKESWAP_MASTER_CHEF_V3_ARBITRUM_SEPOLIA,
            token0: WETH_ARBITRUM_SEPOLIA, // Assuming WETH is token0
            token1: USDC_ARBITRUM_SEPOLIA, // USDC is token1
            poolFee: PANCAKESWAP_POOL_FEE,
            slippageBps: 500, // 5% slippage
            timeout: 300 // 5 minutes
        });

        bytes memory pancakeConfigBytes = abi.encode(pancakeConfig);
        pancakePositionManager = new PancakeSwapV3PositionManager(owner, processor, pancakeConfigBytes);

        // Approve library
        pancakeInputAccount.approveLibrary(address(pancakePositionManager));
        pancakeOutputAccount.approveLibrary(address(pancakePositionManager));

        console.log("  PancakeSwapV3PositionManager deployed at:", address(pancakePositionManager));
        console.log("  Configured for WETH/USDC pool on PancakeSwap V3 Arbitrum");
        console.log("");
    }

    function _printDeploymentSummary() internal view {
        console.log("=== ARBITRUM SEPOLIA DEPLOYMENT SUMMARY ===");
        console.log("Network: Arbitrum Sepolia Testnet");
        console.log("Chain ID: 421614");
        console.log("");
        console.log("ACCOUNTS:");
        console.log("  Compound Input Account:", address(compoundInputAccount));
        console.log("  Compound Output Account:", address(compoundOutputAccount));
        console.log("  PancakeSwap Input Account:", address(pancakeInputAccount));
        console.log("  PancakeSwap Output Account:", address(pancakeOutputAccount));
        console.log("  Splitter Input Account:", address(splitterInputAccount));
        console.log("  Splitter Output Account 1:", address(splitterOutputAccount1));
        console.log("  Splitter Output Account 2:", address(splitterOutputAccount2));
        console.log("");
        console.log("CONTRACTS:");
        console.log("  CompoundV3PositionManager:", address(positionManager));
        console.log("  PancakeSwapV3PositionManager:", address(pancakePositionManager));
        console.log("  Splitter:", address(splitter));
        console.log("");
        console.log("TOKEN ADDRESSES:");
        console.log("  USDC (Arbitrum):", USDC_ARBITRUM_SEPOLIA);
        console.log("  WETH (Arbitrum):", WETH_ARBITRUM_SEPOLIA);
        console.log("  Compound Market (Placeholder):", COMPOUND_V3_USDC_MARKET_ARBITRUM_SEPOLIA);
        console.log("  PancakeSwap Position Manager (Placeholder):", PANCAKESWAP_POSITION_MANAGER_ARBITRUM_SEPOLIA);
        console.log("  PancakeSwap MasterChef V3 (Placeholder):", PANCAKESWAP_MASTER_CHEF_V3_ARBITRUM_SEPOLIA);
        console.log("");
        console.log("IMPORTANT NOTES:");
        console.log("  - Compound and PancakeSwap addresses are placeholders");
        console.log("  - Please verify and update addresses before production deployment");
        console.log("  - Make sure to fund accounts with appropriate tokens for testing");
        console.log("");
        console.log("ROLES:");
        console.log("  Owner:", owner);
        console.log("  Processor:", processor);
        console.log("");
        console.log("All contracts deployed successfully on Arbitrum Sepolia!");
    }

    // Helper functions for environment variables
    function _getOwnerPrivateKey() internal view returns (uint256) {
        try vm.envUint("OWNER_PRIVATE_KEY") returns (uint256 key) {
            return key;
        } catch {
            revert("OWNER_PRIVATE_KEY environment variable not set. Please export it or add to .env file.");
        }
    }

    function _getProcessorPrivateKey() internal view returns (uint256) {
        try vm.envUint("PROCESSOR_PRIVATE_KEY") returns (uint256 key) {
            return key;
        } catch {
            revert("PROCESSOR_PRIVATE_KEY environment variable not set. Please export it or add to .env file.");
        }
    }
}
