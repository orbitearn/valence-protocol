// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {Splitter} from "../src/libraries/Splitter.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {console} from "forge-std/src/console.sol";

contract SplitterScript is Script {
    // Sepolia Testnet Addresses
    // USDC on Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // WETH on Sepolia
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    // Native ETH represented as address(0)
    address constant NATIVE_ETH = address(0);

    address owner;
    address processor;
    Splitter public splitter;
    BaseAccount inputAccount;
    BaseAccount outputAccount1;
    BaseAccount outputAccount2;
    BaseAccount outputAccount3;

    function run() external {
        // Get private keys from environment variables
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 processorPrivateKey = vm.envUint("PROCESSOR_PRIVATE_KEY");
        
        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        console.log("Deploying Splitter...");
        console.log("Owner:", owner);
        console.log("Processor:", processor);

        vm.startBroadcast(ownerPrivateKey);

        // Deploy BaseAccount contracts
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount1 = new BaseAccount(owner, new address[](0));
        outputAccount2 = new BaseAccount(owner, new address[](0));
        outputAccount3 = new BaseAccount(owner, new address[](0));

        console.log("Input Account deployed at:", address(inputAccount));
        console.log("Output Account 1 deployed at:", address(outputAccount1));
        console.log("Output Account 2 deployed at:", address(outputAccount2));
        console.log("Output Account 3 deployed at:", address(outputAccount3));

        // Create split configurations
        Splitter.SplitConfig[] memory splits = new Splitter.SplitConfig[](6);
        
        // Native ETH splits (Fixed Ratio)
        // 50% to output account 1
        splits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(500000000000000000) // 0.5 * 10^18
        });

        // 30% to output account 2
        splits[1] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(300000000000000000) // 0.3 * 10^18
        });

        // 20% to output account 3
        splits[2] = Splitter.SplitConfig({
            outputAccount: outputAccount3,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(200000000000000000) // 0.2 * 10^18
        });

        // USDC splits (Fixed Amount)
        // 1000 USDC to output account 1
        splits[3] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: USDC_SEPOLIA,
            splitType: Splitter.SplitType.FixedAmount,
            splitData: abi.encode(1000 * 10**6) // 1000 USDC
        });

        // 500 USDC to output account 2
        splits[4] = Splitter.SplitConfig({
            outputAccount: outputAccount2,
            token: USDC_SEPOLIA,
            splitType: Splitter.SplitType.FixedAmount,
            splitData: abi.encode(500 * 10**6) // 500 USDC
        });

        // WETH splits (Fixed Ratio)
        // 100% to output account 1 (for demonstration)
        splits[5] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: WETH_SEPOLIA,
            splitType: Splitter.SplitType.FixedRatio,
            splitData: abi.encode(1000000000000000000) // 1.0 * 10^18 (100%)
        });

        // Create main configuration
        Splitter.SplitterConfig memory config = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: splits
        });

        bytes memory configBytes = abi.encode(config);
        
        // Deploy Splitter
        splitter = new Splitter(owner, processor, configBytes);
        
        console.log("Splitter deployed at:", address(splitter));

        // Approve the library from input account
        inputAccount.approveLibrary(address(splitter));

        console.log("Library approved for input account");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia Testnet");
        console.log("Splitter:", address(splitter));
        console.log("Input Account:", address(inputAccount));
        console.log("Output Account 1:", address(outputAccount1));
        console.log("Output Account 2:", address(outputAccount2));
        console.log("Output Account 3:", address(outputAccount3));
        console.log("");
        console.log("Split Configuration:");
        console.log("ETH Splits (Ratio-based):");
        console.log("  - 50% to Account 1");
        console.log("  - 30% to Account 2");
        console.log("  - 20% to Account 3");
        console.log("USDC Splits (Fixed Amount):");
        console.log("  - 1000 USDC to Account 1");
        console.log("  - 500 USDC to Account 2");
        console.log("WETH Splits (Ratio-based):");
        console.log("  - 100% to Account 1");
        console.log("");
        console.log("Owner:", owner);
        console.log("Processor:", processor);
    }



    // Alternative configuration with dynamic ratio (requires oracle)
    function deployWithDynamicRatio() external {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 processorPrivateKey = vm.envUint("PROCESSOR_PRIVATE_KEY");
        
        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        vm.startBroadcast(ownerPrivateKey);

        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount1 = new BaseAccount(owner, new address[](0));

        // Simple configuration with fixed amount only
        Splitter.SplitConfig[] memory splits = new Splitter.SplitConfig[](1);
        splits[0] = Splitter.SplitConfig({
            outputAccount: outputAccount1,
            token: NATIVE_ETH,
            splitType: Splitter.SplitType.FixedAmount,
            splitData: abi.encode(0.01 ether)
        });

        Splitter.SplitterConfig memory config = Splitter.SplitterConfig({
            inputAccount: inputAccount,
            splits: splits
        });

        bytes memory configBytes = abi.encode(config);
        splitter = new Splitter(owner, processor, configBytes);
        
        inputAccount.approveLibrary(address(splitter));

        vm.stopBroadcast();

        console.log("Simple Splitter deployed at:", address(splitter));
    }
} 