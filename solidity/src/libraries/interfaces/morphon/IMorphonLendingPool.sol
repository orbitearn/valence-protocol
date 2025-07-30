// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title IMorphonLendingPool
 * @dev Interface for Morphon Finance Lending Pool contract
 * @notice This interface provides the core functions needed to interact with Morphon Finance lending protocol
 */
interface IMorphonLendingPool {
    /**
     * @notice Supply an asset to Morphon Finance
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @param onBehalfOf The address that will receive the mTokens
     * @param referralCode The referral code for tracking
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraw an asset from Morphon Finance
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     * @param to The address that will receive the underlying asset
     * @return The amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /**
     * @notice Borrow an asset from Morphon Finance
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param referralCode The referral code for tracking
     * @param onBehalfOf The address that will incur the debt
     */
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;

    /**
     * @notice Repay a borrowed asset
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @param interestRateMode The interest rate mode (1 for stable, 2 for variable)
     * @param onBehalfOf The address that will have the debt repaid
     * @return The amount repaid
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    /**
     * @notice Get the balance of mTokens for a specific asset and user
     * @param asset The asset address
     * @param user The user address
     * @return The mToken balance
     */
    function balanceOf(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the borrow balance for a specific asset and user
     * @param asset The asset address
     * @param user The user address
     * @return The borrow balance
     */
    function borrowBalanceOf(address asset, address user) external view returns (uint256);
}
