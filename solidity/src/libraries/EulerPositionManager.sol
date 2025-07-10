// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {BaseAccount} from "../accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IEulerMarkets} from "./interfaces/euler/IEulerMarkets.sol";

/**
 * @title EulerPositionManager
 * @dev Contract for managing Euler Finance lending positions through supply, borrow, withdraw, and repay operations.
 * It leverages Account contracts to interact with the Euler Finance protocol, enabling automated position management.
 */
contract EulerPositionManager is Library {
    /**
     * @title EulerPositionManagerConfig
     * @notice Configuration struct for Euler Finance lending operations
     * @dev Used to define parameters for interacting with Euler Finance protocol
     * @param inputAccount The Base Account from which transactions will be initiated
     * @param outputAccount The Base Account that will receive withdrawals
     * @param marketsAddress Address of the Euler Markets contract
     * @param subAccountId The sub-account ID to use (0 for primary account)
     */
    struct EulerPositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address marketsAddress;
        uint256 subAccountId;
    }

    /// @notice Holds the current configuration for the EulerPositionManager.
    EulerPositionManagerConfig public config;

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the EulerPositionManager.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @notice Validates the provided configuration parameters
     * @dev Checks for validity of input account, output account, and markets address
     * @param _config The encoded configuration bytes to validate
     * @return EulerPositionManagerConfig A validated configuration struct
     */
    function validateConfig(bytes memory _config) internal view returns (EulerPositionManagerConfig memory) {
        // Decode the configuration bytes into the EulerPositionManagerConfig struct.
        EulerPositionManagerConfig memory decodedConfig = abi.decode(_config, (EulerPositionManagerConfig));

        // Ensure the markets address is valid (non-zero).
        if (decodedConfig.marketsAddress == address(0)) {
            revert("Markets address can't be zero address");
        }

        // Ensure the input account address is valid (non-zero).
        if (decodedConfig.inputAccount == BaseAccount(payable(address(0)))) {
            revert("Input account can't be zero address");
        }

        // Ensure the output account address is valid (non-zero).
        if (decodedConfig.outputAccount == BaseAccount(payable(address(0)))) {
            revert("Output account can't be zero address");
        }

        return decodedConfig;
    }

    /**
     * @notice Supplies an asset to Euler Finance
     * @dev Only the designated processor can execute this function.
     * The inputAccount must hold the asset to supply.
     * If amount is 0, the entire balance of the asset in the inputAccount will be supplied.
     * @param asset The asset to supply
     * @param amount The amount of asset to supply, or 0 to use the entire balance.
     */
    function supply(address asset, uint256 amount) external onlyProcessor {
        _supply(asset, amount);
    }

    function _supply(address asset, uint256 amount) internal {
        EulerPositionManagerConfig memory storedConfig = config;

        uint256 amountToSupply = amount == 0 ? IERC20(asset).balanceOf(address(storedConfig.inputAccount)) : amount;

        // Approve the Euler Markets contract to spend the asset from the input account
        bytes memory encodedApproveCall = abi.encodeCall(IERC20.approve, (storedConfig.marketsAddress, amountToSupply));

        storedConfig.inputAccount.execute(asset, 0, encodedApproveCall);

        // Supply the asset to Euler Finance
        bytes memory encodedSupplyCall = abi.encodeCall(
            IEulerMarkets.supplyFrom, 
            (storedConfig.subAccountId, asset, amountToSupply, address(storedConfig.inputAccount))
        );

        storedConfig.inputAccount.execute(storedConfig.marketsAddress, 0, encodedSupplyCall);
    }

    /**
     * @notice Withdraws a specified amount of asset from Euler Finance to the output account.
     * @dev Only the designated processor can execute this function.
     * @param asset The asset to withdraw
     * @param amount The amount of asset to withdraw, or 0 to withdraw the entire balance.
     */
    function withdraw(address asset, uint256 amount) external onlyProcessor {
        _withdraw(asset, amount);
    }

    function _withdraw(address asset, uint256 amount) internal {
        EulerPositionManagerConfig memory storedConfig = config;

        uint256 amountToWithdraw = amount == 0 ? type(uint256).max : amount;

        bytes memory encodedWithdrawCall = abi.encodeCall(
            IEulerMarkets.withdrawTo, 
            (storedConfig.subAccountId, asset, amountToWithdraw, address(storedConfig.outputAccount))
        );

        storedConfig.inputAccount.execute(storedConfig.marketsAddress, 0, encodedWithdrawCall);
    }

    /**
     * @notice Borrows a specified amount of asset from Euler Finance
     * @dev Only the designated processor can execute this function.
     * @param asset The asset to borrow
     * @param amount The amount of asset to borrow
     */
    function borrow(address asset, uint256 amount) external onlyProcessor {
        EulerPositionManagerConfig memory storedConfig = config;

        bytes memory encodedBorrowCall = abi.encodeCall(
            IEulerMarkets.borrow, 
            (storedConfig.subAccountId, asset, amount)
        );

        storedConfig.inputAccount.execute(storedConfig.marketsAddress, 0, encodedBorrowCall);
    }

    /**
     * @notice Repays a specified amount of borrowed asset to Euler Finance
     * @dev Only the designated processor can execute this function.
     * The inputAccount must hold the asset to repay.
     * If amount is 0, the entire balance of the asset in the inputAccount will be used for repayment.
     * @param asset The asset to repay
     * @param amount The amount of asset to repay, or 0 to use the entire balance.
     */
    function repay(address asset, uint256 amount) external onlyProcessor {
        _repay(asset, amount);
    }

    function _repay(address asset, uint256 amount) internal {
        EulerPositionManagerConfig memory storedConfig = config;

        uint256 amountToRepay = amount == 0 ? IERC20(asset).balanceOf(address(storedConfig.inputAccount)) : amount;

        // Approve the Euler Markets contract to spend the asset from the input account
        bytes memory encodedApproveCall = abi.encodeCall(IERC20.approve, (storedConfig.marketsAddress, amountToRepay));

        storedConfig.inputAccount.execute(asset, 0, encodedApproveCall);

        // Repay the borrowed asset to Euler Finance
        bytes memory encodedRepayCall = abi.encodeCall(
            IEulerMarkets.repayFrom, 
            (storedConfig.subAccountId, asset, amountToRepay, address(storedConfig.inputAccount))
        );

        storedConfig.inputAccount.execute(storedConfig.marketsAddress, 0, encodedRepayCall);
    }

    /**
     * @notice Gets the supply balance of an asset for the input account
     * @param asset The asset address
     * @return The supply balance of the asset
     */
    function getSupplyBalance(address asset) external view returns (uint256) {
        EulerPositionManagerConfig memory storedConfig = config;
        return IEulerMarkets(storedConfig.marketsAddress).balanceOf(
            address(storedConfig.inputAccount), 
            storedConfig.subAccountId, 
            asset
        );
    }

    /**
     * @notice Gets the borrow balance of an asset for the input account
     * @param asset The asset address
     * @return The borrow balance of the asset
     */
    function getBorrowBalance(address asset) external view returns (uint256) {
        EulerPositionManagerConfig memory storedConfig = config;
        return IEulerMarkets(storedConfig.marketsAddress).borrowBalance(
            address(storedConfig.inputAccount), 
            storedConfig.subAccountId, 
            asset
        );
    }

    /**
     * @notice Gets the supply rate for an asset
     * @param asset The asset address
     * @return The supply rate (scaled by 1e27)
     */
    function getSupplyRate(address asset) external view returns (uint256) {
        EulerPositionManagerConfig memory storedConfig = config;
        return IEulerMarkets(storedConfig.marketsAddress).supplyRate(asset);
    }

    /**
     * @notice Gets the borrow rate for an asset
     * @param asset The asset address
     * @return The borrow rate (scaled by 1e27)
     */
    function getBorrowRate(address asset) external view returns (uint256) {
        EulerPositionManagerConfig memory storedConfig = config;
        return IEulerMarkets(storedConfig.marketsAddress).borrowRate(asset);
    }

    /**
     * @dev Internal initialization function called during construction
     * @param _config New configuration
     */
    function _initConfig(bytes memory _config) internal override {
        config = validateConfig(_config);
    }

    /**
     * @dev Updates the EulerPositionManager configuration.
     * Only the contract owner is authorized to call this function.
     * @param _config New encoded configuration parameters.
     */
    function updateConfig(bytes memory _config) public override onlyOwner {
        // Validate and update the configuration.
        config = validateConfig(_config);
    }
} 