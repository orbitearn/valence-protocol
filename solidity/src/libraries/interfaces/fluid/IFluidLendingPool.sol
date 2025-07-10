// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title IFluidLendingPool
 * @dev Interface for Fluid Finance Lending Pool contract
 * @notice This interface provides the core functions needed to interact with Fluid Finance lending protocol
 */
interface IFluidLendingPool {
    /**
     * @notice Supply an asset to Fluid Finance
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @param onBehalfOf The address that will receive the fTokens
     * @param referralCode The referral code for tracking
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraw an asset from Fluid Finance
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     * @param to The address that will receive the underlying asset
     * @return The amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /**
     * @notice Borrow an asset from Fluid Finance
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param referralCode The referral code for tracking
     * @param onBehalfOf The address that will incur the debt
     */
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;

    /**
     * @notice Repay a borrowed asset
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param onBehalfOf The address that will have the debt repaid
     * @return The amount repaid
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);

    /**
     * @notice Get the balance of fTokens for a specific asset and user
     * @param asset The asset address
     * @param user The user address
     * @return The fToken balance
     */
    function balanceOf(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the borrow balance for a specific asset and user
     * @param asset The asset address
     * @param user The user address
     * @return The borrow balance
     */
    function borrowBalanceOf(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the fToken address for a specific asset
     * @param asset The asset address
     * @return fTokenAddress The fToken address
     */
    function getReserveData(address asset) external view returns (address fTokenAddress);

    /**
     * @notice Check if a user has any debt
     * @param user The user address
     * @return True if the user has debt
     */
    function hasDebt(address user) external view returns (bool);

    /**
     * @notice Get the total debt for a user
     * @param user The user address
     * @return The total debt amount
     */
    function getTotalDebt(address user) external view returns (uint256);
} 