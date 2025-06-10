// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {Authorization} from "../src/authorization/Authorization.sol";
import {LiteProcessor} from "../src/processor/LiteProcessor.sol";
import {BaseAccount} from "../src/accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {console} from "forge-std/src/console.sol";

contract AuthorizationScript is Script {
    // Sepolia Testnet Addresses
    // USDC on Sepolia
    address constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // WETH on Sepolia
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    // Native ETH represented as address(0)
    address constant NATIVE_ETH = address(0);

    address owner;
    LiteProcessor processor;
    Authorization public authorization;
    BaseAccount inputAccount;
    BaseAccount outputAccount1;
    BaseAccount outputAccount2;
    BaseAccount outputAccount3;

    function run() external {
        // Get private keys from environment variables
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");

        owner = vm.addr(ownerPrivateKey);
        // processor = vm.addr(processorPrivateKey);

        console.log("Deploying Authorization...");
        console.log("Owner:", owner);

        vm.startBroadcast(ownerPrivateKey);

        // deploy authorization
        authorization = new Authorization(owner, owner, address(0), true);

        console.log("Authorization:", address(authorization));

        address[] memory authorizedAddresses = new address[](2);
        authorizedAddresses[0] = owner;
        authorizedAddresses[1] = address(authorization);

        processor = new LiteProcessor(
            "", // Placeholder for mailbox, set to zero for now
            address(0), // Placeholder for mailbox, set to zero for now
            1, // Origin domain ID, can be set as needed
            authorizedAddresses
        );

        console.log("Processor:", address(processor));

        authorization.updateProcessor(address(processor));
    }
}

// bytes memory bytecode = abi.encodePacked(
//     type(Authorization).creationCode,
//     abi.encode(owner, owner, address(0), true)
// );
// address auth = vm.computeCreate2Address(salt, keccak256(bytecode));
