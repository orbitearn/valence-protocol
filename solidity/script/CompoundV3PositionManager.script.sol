// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {CompoundV3PositionManager} from "../src/libraries/CompoundV3PositionManager.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {CometMainInterface} from "../src/libraries/interfaces/compoundV3/CometMainInterface.sol";
import {console} from "forge-std/src/console.sol";

contract CompoundV3PositionManagerScript is Script {
    // Sepolia Testnet Addresses
    // Compound V3 USDC Market on Sepolia
    address constant COMPOUND_V3_USDC_MARKET = 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e;
    // USDC on Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    // For mainnet
    // address constant COMPOUND_V3_USDC_MARKET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    // address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address owner;
    address processor;
    CompoundV3PositionManager public positionManager;
    BaseAccount inputAccount;
    BaseAccount outputAccount;

    function run() external {
        // Get private keys from environment variables
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 processorPrivateKey = vm.envUint("PROCESSOR_PRIVATE_KEY");

        owner = vm.addr(ownerPrivateKey);
        processor = vm.addr(processorPrivateKey);

        console.log("Deploying CompoundV3PositionManager...");
        console.log("Owner:", owner);
        console.log("Processor:", processor);

        vm.startBroadcast(ownerPrivateKey);

        // Deploy BaseAccount contracts for input and output
        inputAccount = new BaseAccount(owner, new address[](0));
        outputAccount = new BaseAccount(owner, new address[](0));

        console.log("Input Account deployed at:", address(inputAccount));
        console.log("Output Account deployed at:", address(outputAccount));

        // Verify the market base token matches our expected token
        address marketBaseToken = CometMainInterface(COMPOUND_V3_USDC_MARKET).baseToken();
        console.log("Market base token:", marketBaseToken);
        console.log("Expected USDC address:", USDC_SEPOLIA);
        require(marketBaseToken == USDC_SEPOLIA, "Base token mismatch");

        // Create configuration
        CompoundV3PositionManager.CompoundV3PositionManagerConfig memory config = CompoundV3PositionManager
            .CompoundV3PositionManagerConfig({
            inputAccount: inputAccount,
            outputAccount: outputAccount,
            baseAsset: USDC_SEPOLIA,
            marketProxyAddress: COMPOUND_V3_USDC_MARKET
        });

        bytes memory configBytes = abi.encode(config);

        // Deploy CompoundV3PositionManager
        positionManager = new CompoundV3PositionManager(owner, processor, configBytes);

        console.log("CompoundV3PositionManager deployed at:", address(positionManager));

        // Approve the library from both accounts
        inputAccount.approveLibrary(address(positionManager));
        outputAccount.approveLibrary(address(positionManager));

        console.log("Library approved for both accounts");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia Testnet");
        console.log("CompoundV3PositionManager:", address(positionManager));
        console.log("Input Account:", address(inputAccount));
        console.log("Output Account:", address(outputAccount));
        console.log("Base Asset (USDC):", USDC_SEPOLIA);
        console.log("Compound Market:", COMPOUND_V3_USDC_MARKET);
        console.log("Owner:", owner);
        console.log("Processor:", processor);
    }
}
