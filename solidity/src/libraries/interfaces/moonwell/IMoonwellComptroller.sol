// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

/**
 * @title IMoonwellComptroller
 * @dev Interface for Moonwell Finance Comptroller contract
 * @notice This interface provides the core functions needed to interact with Moonwell Finance lending protocol
 */
interface IMoonwellComptroller {
    /**
     * @notice Enter markets for a list of assets
     * @param mTokens The list of addresses of the mToken markets to enter
     * @return An array of integers indicating the success of entering each market
     */
    function enterMarkets(address[] calldata mTokens) external returns (uint256[] memory);

    /**
     * @notice Exit a market
     * @param mTokenAddress The address of the mToken market to exit
     * @return An integer indicating the success of exiting the market
     */
    function exitMarket(address mTokenAddress) external returns (uint256);

    /**
     * @notice Get the list of markets an account has entered
     * @param account The account address
     * @return An array of mToken addresses
     */
    function getAssetsIn(address account) external view returns (address[] memory);

    /**
     * @notice Check if an account has entered a specific market
     * @param account The account address
     * @param mToken The mToken address
     * @return True if the account has entered the market
     */
    function checkMembership(address account, address mToken) external view returns (bool);

    /**
     * @notice Get the account liquidity for a specific account
     * @param account The account address
     * @return Total collateral value in USD
     * @return Total borrow value in USD
     * @return Total number of markets entered
     */
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    /**
     * @notice Get the close factor for liquidations
     * @return The close factor (scaled by 1e18)
     */
    function closeFactorMantissa() external view returns (uint256);

    /**
     * @notice Get the liquidation incentive
     * @return The liquidation incentive (scaled by 1e18)
     */
    function liquidationIncentiveMantissa() external view returns (uint256);

    /**
     * @notice Check if a market is listed
     * @param mToken The mToken address
     * @return True if the market is listed
     */
    function isMarketListed(address mToken) external view returns (bool);

    /**
     * @notice Get the price oracle address
     * @return The price oracle address
     */
    function oracle() external view returns (address);

    /**
     * @notice Get the pause guardian address
     * @return The pause guardian address
     */
    function pauseGuardian() external view returns (address);

    /**
     * @notice Check if minting is paused for a market
     * @param mToken The mToken address
     * @return True if minting is paused
     */
    function mintGuardianPaused(address mToken) external view returns (bool);

    /**
     * @notice Check if borrowing is paused for a market
     * @param mToken The mToken address
     * @return True if borrowing is paused
     */
    function borrowGuardianPaused(address mToken) external view returns (bool);
}
