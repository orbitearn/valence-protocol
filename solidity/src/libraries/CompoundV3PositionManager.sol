// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {BaseAccount} from "../accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {CometMainInterface} from "./interfaces/compoundV3/CometMainInterface.sol";

/**
 * @title CompoundV3PositionManager
 * @dev Contract for managing Compound V3 lending positions through supply, withdraw operations.
 * It leverages Account contracts to interact with the Compound V3 protocol, enabling automated position management.
 */
contract CompoundV3PositionManager is Library {
    /**
     * @title CompoundV3PositionManagerConfig
     * @notice Configuration struct for CompoundV3 lending operations
     * @dev Used to define parameters for interacting with CompoundV3 protocol
     * @param inputAccount The Base Account from which transactions will be initiated
     * @param outputAccount The Base Account that will receive withdrawals. 
     * @param baseAsset Address of the base token of the CompoundV3 market
     * @param marketProxyAddress Address of the CompoundV3 market proxy
     */
    struct CompoundV3PositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address baseAsset;
        address marketProxyAddress;

    }

    /// @notice Holds the current configuration for the CompoundV3PositionManager.
    CompoundV3PositionManagerConfig public config;

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the CompoundV3PositionManager.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @notice Validates the provided configuration parameters
     * @dev Checks for validity of input account, output account, base asset, and market proxy address
     * @param _config The encoded configuration bytes to validate
     * @return CompoundV3PositionManagerConfig A validated configuration struct
     */
    function validateConfig(bytes memory _config) internal view returns (CompoundV3PositionManagerConfig memory) {
        // Decode the configuration bytes into the CompoundV3PositionManagerConfig struct.
        CompoundV3PositionManagerConfig memory decodedConfig = abi.decode(_config, (CompoundV3PositionManagerConfig));

        // Ensure the Compound pool address is valid (non-zero).
        if (decodedConfig.marketProxyAddress == address(0)) {
            revert("Market proxy address can't be zero address");
        }

        // Ensure the input account address is valid (non-zero).
        if (decodedConfig.inputAccount == BaseAccount(payable(address(0)))) {
            revert("Input account can't be zero address");
        }

        // Ensure the output account address is valid (non-zero).
        if (decodedConfig.outputAccount == BaseAccount(payable(address(0)))) {
            revert("Output account can't be zero address");
        }

        if (decodedConfig.baseAsset != CometMainInterface(decodedConfig.marketProxyAddress).baseToken()) {
            revert("Market base asset and given base asset are not same");
        }

        return decodedConfig;
    }

    // /**
    //  * @notice Supplies tokens to the Aave protocol
    //  * @dev Only the designated processor can execute this function.
    //  * First approves the Aave pool to spend tokens, then supplies them to the protocol.
    //  * The input account will receive the corresponding aTokens.
    //  * If amount is 0, the entire balance of the supply asset in the input account will be used.
    //  * @param amount The amount of tokens to supply, or 0 to use entire balance
    //  */
    // function supply(uint256 amount) external onlyProcessor {
    //     // Get the current configuration.
    //     AavePositionManagerConfig memory storedConfig = config;

    //     // Get the current balance of the supply asset in the input account
    //     uint256 balance = IERC20(storedConfig.supplyAsset).balanceOf(address(storedConfig.inputAccount));

    //     // Check if balance is zero
    //     if (balance == 0) {
    //         revert("No supply asset balance available");
    //     }

    //     // If amount is 0, use the entire balance
    //     uint256 amountToSupply = amount == 0 ? balance : amount;

    //     // Check if there's enough balance for the requested amount
    //     if (balance < amountToSupply) {
    //         revert("Insufficient supply asset balance");
    //     }

    //     // Encode the approval call for the Aave pool.
    //     bytes memory encodedApproveCall =
    //         abi.encodeCall(IERC20.approve, (address(storedConfig.poolAddress), amountToSupply));

    //     // Execute the approval from the input account
    //     storedConfig.inputAccount.execute(storedConfig.supplyAsset, 0, encodedApproveCall);

    //     // Supply the specified asset to the Aave protocol.
    //     bytes memory encodedSupplyCall = abi.encodeCall(
    //         IPool.supply,
    //         (storedConfig.supplyAsset, amountToSupply, address(storedConfig.inputAccount), storedConfig.referralCode)
    //     );

    //     // Execute the supply from the input account
    //     storedConfig.inputAccount.execute(address(storedConfig.poolAddress), 0, encodedSupplyCall);
    // }

    // /**
    //  * @notice Withdraws previously supplied tokens from Aave
    //  * @dev Only the designated processor can execute this function.
    //  * Withdraws assets from Aave and sends them to the output account.
    //  * This reduces the available collateral for any outstanding loans.
    //  * @param amount The amount of tokens to withdraw, passing 0 will withdraw the entire balance
    //  */
    // function withdraw(uint256 amount) external onlyProcessor {
    //     // Get the current configuration.
    //     AavePositionManagerConfig memory storedConfig = config;

    //     // If amount is 0, use uint256.max to withdraw as much as possible
    //     if (amount == 0) {
    //         amount = type(uint256).max;
    //     }

    //     // Withdraw the specified asset from the Aave protocol.
    //     bytes memory encodedWithdrawCall =
    //         abi.encodeCall(IPool.withdraw, (storedConfig.supplyAsset, amount, address(storedConfig.outputAccount)));

    //     // Execute the withdraw from the input account
    //     storedConfig.inputAccount.execute(address(storedConfig.poolAddress), 0, encodedWithdrawCall);
    // }


    /**
     * @dev Internal initialization function called during construction
     * @param _config New configuration
     */
    function _initConfig(bytes memory _config) internal override {
        config = validateConfig(_config);
    }

    /**
     * @dev Updates the CompoundV3PositionManager configuration.
     * Only the contract owner is authorized to call this function.
     * @param _config New encoded configuration parameters.
     */
    function updateConfig(bytes memory _config) public override onlyOwner {
        // Validate and update the configuration.
        config = validateConfig(_config);
    }
}
