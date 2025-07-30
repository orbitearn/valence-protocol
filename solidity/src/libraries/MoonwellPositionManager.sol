// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Library} from "./Library.sol";
import {BaseAccount} from "../accounts/BaseAccount.sol";
import {IERC20} from "forge-std/src/interfaces/IERC20.sol";
import {IMoonwellComptroller} from "./interfaces/moonwell/IMoonwellComptroller.sol";
import {IMoonwellMToken} from "./interfaces/moonwell/IMoonwellMToken.sol";

/**
 * @title MoonwellPositionManager
 * @dev Contract for managing Moonwell Finance lending positions through supply, borrow, withdraw, and repay operations.
 * It leverages Account contracts to interact with the Moonwell Finance protocol, enabling automated position management.
 */
contract MoonwellPositionManager is Library {
    /**
     * @title MoonwellPositionManagerConfig
     * @notice Configuration struct for Moonwell Finance lending operations
     * @dev Used to define parameters for interacting with Moonwell Finance protocol
     * @param inputAccount The Base Account from which transactions will be initiated
     * @param outputAccount The Base Account that will receive withdrawals
     * @param comptrollerAddress Address of the Moonwell Comptroller contract
     * @param mTokenAddress Address of the specific mToken market to interact with
     */
    struct MoonwellPositionManagerConfig {
        BaseAccount inputAccount;
        BaseAccount outputAccount;
        address comptrollerAddress;
        address mTokenAddress;
    }

    /// @notice Holds the current configuration for the MoonwellPositionManager.
    MoonwellPositionManagerConfig public config;

    /**
     * @dev Constructor initializes the contract with the owner, processor, and initial configuration.
     * @param _owner Address of the contract owner.
     * @param _processor Address of the processor that can execute functions.
     * @param _config Encoded configuration parameters for the MoonwellPositionManager.
     */
    constructor(address _owner, address _processor, bytes memory _config) Library(_owner, _processor, _config) {}

    /**
     * @notice Validates the provided configuration parameters
     * @dev Checks for validity of input account, output account, comptroller, and mToken addresses
     * @param _config The encoded configuration bytes to validate
     * @return MoonwellPositionManagerConfig A validated configuration struct
     */
    function validateConfig(bytes memory _config) internal view returns (MoonwellPositionManagerConfig memory) {
        // Decode the configuration bytes into the MoonwellPositionManagerConfig struct.
        MoonwellPositionManagerConfig memory decodedConfig = abi.decode(_config, (MoonwellPositionManagerConfig));

        // Ensure the comptroller address is valid (non-zero).
        if (decodedConfig.comptrollerAddress == address(0)) {
            revert("Comptroller address can't be zero address");
        }

        // Ensure the mToken address is valid (non-zero).
        if (decodedConfig.mTokenAddress == address(0)) {
            revert("mToken address can't be zero address");
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
     * @notice Supplies an asset to Moonwell Finance by minting mTokens
     * @dev Only the designated processor can execute this function.
     * The inputAccount must hold the underlying asset to supply.
     * If amount is 0, the entire balance of the underlying asset in the inputAccount will be supplied.
     * @param amount The amount of underlying asset to supply, or 0 to use the entire balance.
     */
    function supply(uint256 amount) external onlyProcessor {
        _supply(amount);
    }

    function _supply(uint256 amount) internal {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        address underlyingAsset = mToken.underlying();

        uint256 amountToSupply =
            amount == 0 ? IERC20(underlyingAsset).balanceOf(address(storedConfig.inputAccount)) : amount;

        // Approve the mToken contract to spend the underlying asset from the input account
        bytes memory encodedApproveCall = abi.encodeCall(IERC20.approve, (storedConfig.mTokenAddress, amountToSupply));

        storedConfig.inputAccount.execute(underlyingAsset, 0, encodedApproveCall);

        // Mint mTokens by supplying the underlying asset
        bytes memory encodedMintCall = abi.encodeCall(IMoonwellMToken.mint, (amountToSupply));

        storedConfig.inputAccount.execute(storedConfig.mTokenAddress, 0, encodedMintCall);
    }

    /**
     * @notice Withdraws a specified amount of underlying asset from Moonwell Finance
     * @dev Only the designated processor can execute this function.
     * @param amount The amount of underlying asset to withdraw, or 0 to withdraw the entire balance.
     */
    function withdraw(uint256 amount) external onlyProcessor {
        _withdraw(amount);
    }

    function _withdraw(uint256 amount) internal {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);

        uint256 amountToWithdraw = amount == 0 ? type(uint256).max : amount;

        // Redeem underlying asset by burning mTokens
        bytes memory encodedRedeemCall = abi.encodeCall(IMoonwellMToken.redeemUnderlying, (amountToWithdraw));

        storedConfig.inputAccount.execute(storedConfig.mTokenAddress, 0, encodedRedeemCall);
    }

    /**
     * @notice Borrows a specified amount of underlying asset from Moonwell Finance
     * @dev Only the designated processor can execute this function.
     * @param amount The amount of underlying asset to borrow
     */
    function borrow(uint256 amount) external onlyProcessor {
        MoonwellPositionManagerConfig memory storedConfig = config;

        bytes memory encodedBorrowCall = abi.encodeCall(IMoonwellMToken.borrow, (amount));

        storedConfig.inputAccount.execute(storedConfig.mTokenAddress, 0, encodedBorrowCall);
    }

    /**
     * @notice Repays a specified amount of borrowed underlying asset to Moonwell Finance
     * @dev Only the designated processor can execute this function.
     * The inputAccount must hold the underlying asset to repay.
     * If amount is 0, the entire balance of the underlying asset in the inputAccount will be used for repayment.
     * @param amount The amount of underlying asset to repay, or 0 to use the entire balance.
     */
    function repay(uint256 amount) external onlyProcessor {
        _repay(amount);
    }

    function _repay(uint256 amount) internal {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        address underlyingAsset = mToken.underlying();

        uint256 amountToRepay =
            amount == 0 ? IERC20(underlyingAsset).balanceOf(address(storedConfig.inputAccount)) : amount;

        // Approve the mToken contract to spend the underlying asset from the input account
        bytes memory encodedApproveCall = abi.encodeCall(IERC20.approve, (storedConfig.mTokenAddress, amountToRepay));

        storedConfig.inputAccount.execute(underlyingAsset, 0, encodedApproveCall);

        // Repay the borrowed underlying asset
        bytes memory encodedRepayCall = abi.encodeCall(IMoonwellMToken.repayBorrow, (amountToRepay));

        storedConfig.inputAccount.execute(storedConfig.mTokenAddress, 0, encodedRepayCall);
    }

    /**
     * @notice Enters the mToken market for the input account
     * @dev Only the designated processor can execute this function.
     * This is required before borrowing from the market.
     */
    function enterMarket() external onlyProcessor {
        MoonwellPositionManagerConfig memory storedConfig = config;

        address[] memory mTokens = new address[](1);
        mTokens[0] = storedConfig.mTokenAddress;

        bytes memory encodedEnterMarketCall = abi.encodeCall(IMoonwellComptroller.enterMarkets, (mTokens));

        storedConfig.inputAccount.execute(storedConfig.comptrollerAddress, 0, encodedEnterMarketCall);
    }

    /**
     * @notice Exits the mToken market for the input account
     * @dev Only the designated processor can execute this function.
     */
    function exitMarket() external onlyProcessor {
        MoonwellPositionManagerConfig memory storedConfig = config;

        bytes memory encodedExitMarketCall =
            abi.encodeCall(IMoonwellComptroller.exitMarket, (storedConfig.mTokenAddress));

        storedConfig.inputAccount.execute(storedConfig.comptrollerAddress, 0, encodedExitMarketCall);
    }

    /**
     * @notice Gets the mToken balance for the input account
     * @return The mToken balance
     */
    function getMTokenBalance() external view returns (uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        return mToken.balanceOf(address(storedConfig.inputAccount));
    }

    /**
     * @notice Gets the borrow balance for the input account
     * @return The borrow balance
     */
    function getBorrowBalance() external view returns (uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        return mToken.borrowBalanceStored(address(storedConfig.inputAccount));
    }

    /**
     * @notice Gets the supply rate per block for the mToken
     * @return The supply rate per block (scaled by 1e18)
     */
    function getSupplyRatePerBlock() external view returns (uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        return mToken.supplyRatePerBlock();
    }

    /**
     * @notice Gets the borrow rate per block for the mToken
     * @return The borrow rate per block (scaled by 1e18)
     */
    function getBorrowRatePerBlock() external view returns (uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        return mToken.borrowRatePerBlock();
    }

    /**
     * @notice Gets the exchange rate between mTokens and underlying
     * @return The exchange rate (scaled by 1e18)
     */
    function getExchangeRate() external view returns (uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellMToken mToken = IMoonwellMToken(storedConfig.mTokenAddress);
        return mToken.exchangeRateStored();
    }

    /**
     * @notice Gets the account liquidity for the input account
     * @return Total collateral value in USD
     * @return Total borrow value in USD
     * @return Total number of markets entered
     */
    function getAccountLiquidity() external view returns (uint256, uint256, uint256) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellComptroller comptroller = IMoonwellComptroller(storedConfig.comptrollerAddress);
        return comptroller.getAccountLiquidity(address(storedConfig.inputAccount));
    }

    /**
     * @notice Checks if the input account has entered the mToken market
     * @return True if the account has entered the market
     */
    function isMarketEntered() external view returns (bool) {
        MoonwellPositionManagerConfig memory storedConfig = config;
        IMoonwellComptroller comptroller = IMoonwellComptroller(storedConfig.comptrollerAddress);
        return comptroller.checkMembership(address(storedConfig.inputAccount), storedConfig.mTokenAddress);
    }

    // Public getters for config fields
    function inputAccount() public view returns (BaseAccount) {
        return config.inputAccount;
    }

    function outputAccount() public view returns (BaseAccount) {
        return config.outputAccount;
    }

    function comptrollerAddress() public view returns (address) {
        return config.comptrollerAddress;
    }

    function mTokenAddress() public view returns (address) {
        return config.mTokenAddress;
    }

    /**
     * @dev Internal initialization function called during construction
     * @param _config New configuration
     */
    function _initConfig(bytes memory _config) internal override {
        config = validateConfig(_config);
    }

    /**
     * @dev Updates the MoonwellPositionManager configuration.
     * Only the contract owner is authorized to call this function.
     * @param _config New encoded configuration parameters.
     */
    function updateConfig(bytes memory _config) public override onlyOwner {
        // Validate and update the configuration.
        config = validateConfig(_config);
    }
}
