// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {BaseAccount} from "../accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IMorphonLendingPool} from "./interfaces/morphon/IMorphonLendingPool.sol";

/**
 * @title MorphonPositionManager
 * @dev Contract for managing Morphon Finance lending positions through supply, borrow, withdraw, and repay operations.
 * It leverages Account contracts to interact with the Morphon Finance protocol, enabling automated position management.
 */
contract MorphonPositionManager is Library {
    /**
     * @title MorphonPositionManagerConfig
     * @notice Configuration struct for Morphon Finance lending operations
     * @dev Used to define parameters for interacting with Morphon Finance protocol
     * @param inputAccount The Base Account from which transactions will be initiated
     * @param outputAccount The Base Account that will receive withdrawals
     * @param lendingPoolAddress Address of the Morphon Lending Pool contract
     * @param assetAddress Address of the underlying asset to manage
     * @param referralCode The referral code for Morphon Finance operations
     */
    struct MorphonPositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address lendingPoolAddress;
        address assetAddress;
        uint16 referralCode;
    }

    /// @notice Holds the current configuration for the MorphonPositionManager.
    MorphonPositionManagerConfig public config;

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the MorphonPositionManager.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @dev Initializes the contract configuration by decoding the provided config bytes.
     * @param _config Encoded configuration parameters.
     */
    function _initConfig(bytes memory _config) internal override {
        MorphonPositionManagerConfig memory decodedConfig = abi.decode(_config, (MorphonPositionManagerConfig));
        config = decodedConfig;
    }

    /**
     * @notice Supplies assets to Morphon Finance.
     * @param amount The amount to supply (0 for all available balance).
     */
    function supply(uint256 amount) external onlyProcessor {
        IERC20 asset = IERC20(config.assetAddress);
        IMorphonLendingPool lendingPool = IMorphonLendingPool(config.lendingPoolAddress);
        
        uint256 supplyAmount = amount;
        if (amount == 0) {
            supplyAmount = asset.balanceOf(address(config.inputAccount));
        }
        
        require(supplyAmount > 0, "No assets to supply");
        
        // Transfer assets from input account to this contract
        config.inputAccount.execute(
            address(asset),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), supplyAmount)
        );
        
        // Approve lending pool to spend assets
        asset.approve(config.lendingPoolAddress, supplyAmount);
        
        // Supply to Morphon Finance
        lendingPool.supply(config.assetAddress, supplyAmount, address(config.outputAccount), config.referralCode);
    }

    /**
     * @notice Withdraws assets from Morphon Finance.
     * @param amount The amount to withdraw (0 for all mToken balance).
     */
    function withdraw(uint256 amount) external onlyProcessor {
        IMorphonLendingPool lendingPool = IMorphonLendingPool(config.lendingPoolAddress);
        
        uint256 withdrawAmount = amount;
        if (amount == 0) {
            withdrawAmount = lendingPool.balanceOf(config.assetAddress, address(config.outputAccount));
        }
        
        require(withdrawAmount > 0, "No mTokens to withdraw");
        
        // Withdraw from Morphon Finance to input account
        lendingPool.withdraw(config.assetAddress, withdrawAmount, address(config.inputAccount));
    }

    /**
     * @notice Borrows assets from Morphon Finance.
     * @param amount The amount to borrow.
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable).
     */
    function borrow(uint256 amount, uint256 interestRateMode) external onlyProcessor {
        require(amount > 0, "Borrow amount must be greater than 0");
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");
        
        IMorphonLendingPool lendingPool = IMorphonLendingPool(config.lendingPoolAddress);
        
        // Borrow from Morphon Finance to input account
        lendingPool.borrow(config.assetAddress, amount, interestRateMode, config.referralCode, address(config.inputAccount));
    }

    /**
     * @notice Repays borrowed assets to Morphon Finance.
     * @param amount The amount to repay (0 for all borrow balance).
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable).
     */
    function repay(uint256 amount, uint256 interestRateMode) external onlyProcessor {
        require(interestRateMode == 1 || interestRateMode == 2, "Invalid interest rate mode");
        
        IMorphonLendingPool lendingPool = IMorphonLendingPool(config.lendingPoolAddress);
        IERC20 asset = IERC20(config.assetAddress);
        
        uint256 repayAmount = amount;
        if (amount == 0) {
            repayAmount = lendingPool.borrowBalanceOf(config.assetAddress, address(config.inputAccount));
        }
        
        require(repayAmount > 0, "No debt to repay");
        
        // Transfer assets from input account to this contract
        config.inputAccount.execute(
            address(asset),
            0,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), repayAmount)
        );
        
        // Approve lending pool to spend assets
        asset.approve(config.lendingPoolAddress, repayAmount);
        
        // Repay to Morphon Finance
        lendingPool.repay(config.assetAddress, repayAmount, interestRateMode, address(config.inputAccount));
    }

    /**
     * @notice Updates the configuration of the MorphonPositionManager.
     * @param _config New configuration parameters.
     */
    function updateConfig(bytes memory _config) public override {
        _initConfig(_config);
    }
} 