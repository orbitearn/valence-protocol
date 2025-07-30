// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {BaseAccount} from "../accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IFluidLendingPool} from "./interfaces/fluid/IFluidLendingPool.sol";

/**
 * @title FluidPositionManager
 * @dev Contract for managing Fluid Finance lending positions through supply, borrow, withdraw, and repay operations.
 * It leverages Account contracts to interact with the Fluid Finance protocol, enabling automated position management.
 */
contract FluidPositionManager is Library {
    /**
     * @title FluidPositionManagerConfig
     * @notice Configuration struct for Fluid Finance lending operations
     * @dev Used to define parameters for interacting with Fluid Finance protocol
     * @param inputAccount The Base Account from which transactions will be initiated
     * @param outputAccount The Base Account that will receive withdrawals
     * @param lendingPoolAddress Address of the Fluid Lending Pool contract
     * @param assetAddress Address of the underlying asset to manage
     * @param referralCode The referral code for Fluid Finance operations
     */
    struct FluidPositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address lendingPoolAddress;
        address assetAddress;
        uint16 referralCode;
    }

    /// @notice Holds the current configuration for the FluidPositionManager.
    FluidPositionManagerConfig public config;

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the FluidPositionManager.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @dev Internal function for initialization during construction
     * @param _config Encoded configuration parameters.
     */
    function _initConfig(bytes memory _config) internal override {
        FluidPositionManagerConfig memory decodedConfig = abi.decode(_config, (FluidPositionManagerConfig));

        require(decodedConfig.lendingPoolAddress != address(0), "Lending pool address can't be zero address");
        require(decodedConfig.assetAddress != address(0), "Asset address can't be zero address");
        require(address(decodedConfig.inputAccount) != address(0), "Input account can't be zero address");
        require(address(decodedConfig.outputAccount) != address(0), "Output account can't be zero address");

        config = decodedConfig;
    }

    /**
     * @notice Updates the configuration of the FluidPositionManager.
     * @param _config Encoded configuration parameters.
     */
    function updateConfig(bytes memory _config) public override onlyOwner {
        FluidPositionManagerConfig memory decodedConfig = abi.decode(_config, (FluidPositionManagerConfig));

        require(decodedConfig.lendingPoolAddress != address(0), "Lending pool address can't be zero address");
        require(decodedConfig.assetAddress != address(0), "Asset address can't be zero address");
        require(address(decodedConfig.inputAccount) != address(0), "Input account can't be zero address");
        require(address(decodedConfig.outputAccount) != address(0), "Output account can't be zero address");

        config = decodedConfig;
    }

    /**
     * @notice Supplies assets to Fluid Finance.
     * @param amount The amount to supply (0 for all available balance).
     */
    function supply(uint256 amount) external onlyProcessor {
        IERC20 asset = IERC20(config.assetAddress);
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);

        uint256 supplyAmount = amount;
        if (amount == 0) {
            supplyAmount = asset.balanceOf(address(config.inputAccount));
        }

        require(supplyAmount > 0, "No assets to supply");

        // Transfer assets from input account to this contract
        config.inputAccount.execute(
            address(asset), 0, abi.encodeWithSelector(IERC20.transfer.selector, address(this), supplyAmount)
        );

        // Approve lending pool to spend assets
        asset.approve(config.lendingPoolAddress, supplyAmount);

        // Supply to Fluid Finance
        lendingPool.supply(config.assetAddress, supplyAmount, address(config.outputAccount), config.referralCode);
    }

    /**
     * @notice Withdraws assets from Fluid Finance.
     * @param amount The amount to withdraw (0 for all fToken balance).
     */
    function withdraw(uint256 amount) external onlyProcessor {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);

        uint256 withdrawAmount = amount;
        if (amount == 0) {
            withdrawAmount = lendingPool.balanceOf(config.assetAddress, address(config.outputAccount));
        }

        require(withdrawAmount > 0, "No fTokens to withdraw");

        // Withdraw from Fluid Finance to input account
        lendingPool.withdraw(config.assetAddress, withdrawAmount, address(config.inputAccount));
    }

    /**
     * @notice Borrows assets from Fluid Finance.
     * @param amount The amount to borrow.
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable).
     */
    function borrow(uint256 amount, uint256 interestRateMode) external onlyProcessor {
        require(amount > 0, "Borrow amount must be greater than 0");
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");

        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);

        // Borrow from Fluid Finance to input account
        lendingPool.borrow(
            config.assetAddress, amount, interestRateMode, config.referralCode, address(config.inputAccount)
        );
    }

    /**
     * @notice Repays borrowed assets to Fluid Finance.
     * @param amount The amount to repay (0 for all borrow balance).
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable).
     */
    function repay(uint256 amount, uint256 interestRateMode) external onlyProcessor {
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");

        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        IERC20 asset = IERC20(config.assetAddress);

        uint256 repayAmount = amount;
        if (amount == 0) {
            repayAmount = lendingPool.borrowBalanceOf(config.assetAddress, address(config.inputAccount));
        }

        require(repayAmount > 0, "No debt to repay");

        // Transfer assets from input account to this contract
        config.inputAccount.execute(
            address(asset), 0, abi.encodeWithSelector(IERC20.transfer.selector, address(this), repayAmount)
        );

        // Approve lending pool to spend assets
        asset.approve(config.lendingPoolAddress, repayAmount);

        // Repay to Fluid Finance
        lendingPool.repay(config.assetAddress, repayAmount, interestRateMode, address(config.inputAccount));
    }

    /**
     * @notice Gets the current fToken balance for the output account.
     * @return The fToken balance.
     */
    function getFTokenBalance() external view returns (uint256) {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        return lendingPool.balanceOf(config.assetAddress, address(config.outputAccount));
    }

    /**
     * @notice Gets the current borrow balance for the input account.
     * @return The borrow balance.
     */
    function getBorrowBalance() external view returns (uint256) {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        return lendingPool.borrowBalanceOf(config.assetAddress, address(config.inputAccount));
    }

    /**
     * @notice Gets the underlying asset balance for the input account.
     * @return The underlying asset balance.
     */
    function getUnderlyingBalance() external view returns (uint256) {
        IERC20 asset = IERC20(config.assetAddress);
        return asset.balanceOf(address(config.inputAccount));
    }

    /**
     * @notice Gets the underlying asset balance for the output account.
     * @return The underlying asset balance.
     */
    function getOutputAccountBalance() external view returns (uint256) {
        IERC20 asset = IERC20(config.assetAddress);
        return asset.balanceOf(address(config.outputAccount));
    }

    /**
     * @notice Gets the fToken address for the configured asset.
     * @return The fToken address.
     */
    function getFTokenAddress() external view returns (address) {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        return lendingPool.getReserveData(config.assetAddress);
    }

    /**
     * @notice Checks if the input account has any debt.
     * @return True if the account has debt.
     */
    function hasDebt() external view returns (bool) {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        return lendingPool.hasDebt(address(config.inputAccount));
    }

    /**
     * @notice Gets the total debt for the input account.
     * @return The total debt amount.
     */
    function getTotalDebt() external view returns (uint256) {
        IFluidLendingPool lendingPool = IFluidLendingPool(config.lendingPoolAddress);
        return lendingPool.getTotalDebt(address(config.inputAccount));
    }

    // ============== Config Getters ==============

    /**
     * @notice Gets the input account address.
     * @return The input account address.
     */
    function inputAccount() external view returns (BaseAccount) {
        return config.inputAccount;
    }

    /**
     * @notice Gets the output account address.
     * @return The output account address.
     */
    function outputAccount() external view returns (BaseAccount) {
        return config.outputAccount;
    }

    /**
     * @notice Gets the lending pool address.
     * @return The lending pool address.
     */
    function lendingPoolAddress() external view returns (address) {
        return config.lendingPoolAddress;
    }

    /**
     * @notice Gets the asset address.
     * @return The asset address.
     */
    function assetAddress() external view returns (address) {
        return config.assetAddress;
    }

    /**
     * @notice Gets the referral code.
     * @return The referral code.
     */
    function referralCode() external view returns (uint16) {
        return config.referralCode;
    }
}
