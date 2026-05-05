// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";
import {IAToken} from "../interface/IAToken.sol";

/**
 * @title Liquidate
 * @notice Demonstrates how to liquidate underwater positions in Aave V3
 * @dev Liquidators repay a user's debt in exchange for their collateral at a discount (liquidation bonus).
 */
contract Liquidate is AaveV3Base {
    constructor(address _provider) AaveV3Base(_provider) {}

    /**
     * @notice Liquidate an underwater user position
     * @param collateralAsset Address of the collateral asset to receive
     * @param debtAsset Address of the debt asset to repay
     * @param user Address of the user to liquidate
     * @param debtToCover Amount of debt to cover (in token decimals)
     *
     * @dev Requirements:
     * - User's health factor must be below 1
     * - Liquidator must have enough debtAsset to cover the debt
     * - Max 50% of debt can be liquidated per transaction
     * - Liquidator receives collateralAsset at a bonus (liquidationBonus)
     *
     * @param receiveAToken If true, receive aTokens instead of underlying tokens
     */
    function liquidate(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external {
        // Transfer debt tokens from liquidator to this contract
        IERC20(debtAsset).transferFrom(msg.sender, address(this), debtToCover);
        IERC20(debtAsset).approve(address(pool), debtToCover);

        // Execute liquidation
        pool.liquidationCall({
            collateralAsset: collateralAsset,
            debtAsset: debtAsset,
            user: user,
            debtToCover: debtToCover,
            receiveAToken: receiveAToken
        });
    }

    /**
     * @notice Calculate the liquidation bonus for a collateral asset
     * @param asset Address of the collateral asset
     * @return liquidationBonus The bonus percentage (1e4 = 100%)
     *
     * @dev Liquidation bonus is typically 5-15% depending on the asset.
     * A 10% bonus means you receive 1.10x the value of debt repaid.
     */
    function getLiquidationBonus(address asset) external view returns (uint256) {
        (,, uint256 liquidationBonus,,,) = dataProvider.getReserveConfigurationData(asset);
        return liquidationBonus;
    }

    /**
     * @notice Get the debt balance of a user for a specific asset
     * @param asset Address of the debt asset
     * @param user Address of the user
     * @return Current variable debt balance
     */
    function getUserDebt(address asset, address user) external view returns (uint256) {
        return _getVariableDebtToken(asset).balanceOf(user);
    }

    /**
     * @notice Check if a user is liquidatable
     * @param user Address of the user to check
     * @return True if health factor is below 1 (liquidatable)
     */
    function isLiquidatable(address user) external view returns (bool) {
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        return healthFactor < 1e18;
    }

    /**
     * @notice Get the maximum amount of debt that can be liquidated for a user
     * @param debtAsset Address of the debt asset
     * @param user Address of the user
     * @return Maximum liquidatable debt (50% of total debt)
     *
     * @dev Aave V3 limits liquidation to 50% of debt per transaction.
     * Multiple transactions may be needed to fully liquidate a position.
     */
    function getMaxLiquidatableDebt(address debtAsset, address user) external view returns (uint256) {
        uint256 totalDebt = _getVariableDebtToken(debtAsset).balanceOf(user);
        return totalDebt / 2; // 50% max per liquidation
    }
}
