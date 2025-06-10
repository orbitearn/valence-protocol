// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {Forwarder} from "../src/libraries/Forwarder.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {console} from "forge-std/src/console.sol";

contract ForwarderScript is Script {
    // Sepolia Testnet Addresses
    // USDC on Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // WETH on Sepolia
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    // Native ETH represented as address(0)
    address constant NATIVE_ETH = address(0);

    address owner;
    address processor;
    Forwarder public forwarder;
    BaseAccount inputAccount;
    BaseAccount outputAccount;

    function run() external {
        // Get private keys from environment variables
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 processorPrivateKey = vm.envUint("PROCESSOR_PRIVATE_KEY");

        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        console.log("Deploying Forwarder...");
        console.log("Owner:", owner);
        console.log("Processor:", processor);

        vm.startBroadcast(ownerPrivateKey);

        // Deploy BaseAccount contracts for input and output
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));

        console.log("Input Account deployed at:", address(inputAccount));
        console.log("Output Account deployed at:", address(outputAccount));

        // Create forwarding configurations
        Forwarder.ForwardingConfig[] memory forwardingConfigs = new Forwarder.ForwardingConfig[](3);

        // Forward native ETH with max 0.1 ETH per execution
        forwardingConfigs[0] = Forwarder.ForwardingConfig({tokenAddress: NATIVE_ETH, maxAmount: 0.1 ether});

        // Forward USDC with max 1000 USDC per execution (assuming 6 decimals)
        forwardingConfigs[1] = Forwarder.ForwardingConfig({tokenAddress: USDC_SEPOLIA, maxAmount: 1000 * 10 ** 6});

        // Forward WETH with max 0.5 WETH per execution
        forwardingConfigs[2] = Forwarder.ForwardingConfig({tokenAddress: WETH_SEPOLIA, maxAmount: 0.5 ether});

        // Create main configuration
        Forwarder.ForwarderConfig memory config = Forwarder.ForwarderConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            forwardingConfigs: forwardingConfigs,
            intervalType: Forwarder.IntervalType.TIME,
            minInterval: 3600 // 1 hour minimum interval
        });

        bytes memory configBytes = abi.encode(config);

        // Deploy Forwarder
        forwarder = new Forwarder(owner, processor, configBytes);

        console.log("Forwarder deployed at:", address(forwarder));

        // Approve the library from input account
        inputAccount.approveLibrary(address(forwarder));

        console.log("Library approved for input account");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia Testnet");
        console.log("Forwarder:", address(forwarder));
        console.log("Input Account:", address(inputAccount));
        console.log("Output Account:", address(outputAccount));
        console.log("Interval Type: TIME (1 hour)");
        console.log("Forwarding Configs:");
        console.log("  - Native ETH: max 0.1 ETH");
        console.log("  - USDC:", USDC_SEPOLIA, "max 1000 USDC");
        console.log("  - WETH:", WETH_SEPOLIA, "max 0.5 WETH");
        console.log("Owner:", owner);
        console.log("Processor:", processor);
    }

    function deployWithBlockInterval() external {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 processorPrivateKey = vm.envUint("PROCESSOR_PRIVATE_KEY");

        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        vm.startBroadcast(ownerPrivateKey);

        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));

        // Simple configuration with just native ETH forwarding
        Forwarder.ForwardingConfig[] memory forwardingConfigs = new Forwarder.ForwardingConfig[](1);
        forwardingConfigs[0] = Forwarder.ForwardingConfig({tokenAddress: NATIVE_ETH, maxAmount: 0.01 ether});

        Forwarder.ForwarderConfig memory config = Forwarder.ForwarderConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            forwardingConfigs: forwardingConfigs,
            intervalType: Forwarder.IntervalType.BLOCKS,
            minInterval: 100 // 100 blocks minimum interval (~20 minutes on Ethereum)
        });

        bytes memory configBytes = abi.encode(config);
        forwarder = new Forwarder(owner, processor, configBytes);

        inputAccount.approveLibrary(address(forwarder));

        vm.stopBroadcast();

        console.log("Forwarder (block-based) deployed at:", address(forwarder));
    }
}
