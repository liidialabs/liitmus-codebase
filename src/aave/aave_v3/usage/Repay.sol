// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";
import {IAToken} from "../interface/IAToken.sol";

/**
 * @title Repay
 * @notice Demonstrates how to repay borrowed assets in Aave V3
 * @dev Repaying reduces debt and improves health factor. Can repay partial or full debt.
 */
contract Repay is AaveV3Base {
    constructor(address _provider) AaveV3Base(_provider) {}

    /**
     * @notice Repay the full variable debt for an asset
     * @param asset Address of the borrowed asset
     * @return repaid actual amount repaid
     *
     * @dev Automatically calculates the debt including accrued interest.
     * Transfers any needed tokens from msg.sender to cover the full debt.
     */
    function repayFull(address asset) external returns (uint256 repaid) {
        return _repay(asset, type(uint256).max, VARIABLE_RATE, address(this));
    }

    /**
     * @notice Repay a specific amount of debt
     * @param asset Address of the borrowed asset
     * @param amount Amount to repay (in token decimals)
     * @return repaid actual amount repaid
     *
     * @dev If amount exceeds debt, only the debt amount is repaid.
     */
    function repayPartial(address asset, uint256 amount) external returns (uint256 repaid) {
        return _repay(asset, amount, VARIABLE_RATE, address(this));
    }

    /**
     * @notice Repay debt on behalf of another user
     * @param asset Address of the borrowed asset
     * @param amount Amount to repay
     * @param rateMode Interest rate mode (1 = stable, 2 = variable)
     * @param onBehalfOf Address whose debt is being repaid
     * @return repaid actual amount repaid
     *
     * @dev Anyone can repay anyone else's debt. Useful for liquidations or helping others.
     */
    function repayForUser(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256 repaid) {
        return _repay(asset, amount, rateMode, onBehalfOf);
    }

    function _repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) internal returns (uint256) {
        // Calculate how much this contract already has
        // A user might have sent some tokens directly to this contract before calling repay
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 debt = _getVariableDebtToken(asset).balanceOf(onBehalfOf);

        require(balance != 0 && debt != 0, ZeroBalance());
            
        if (debt > balance)
            amount = balance; // In case user didn't transfer enough, repay what we have
        else
            amount = debt; // We have enough to cover full debt
        
        // Transfer tokens from msg.sender to this contract to cover the repayment
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        // Approve pool to spend tokens
        IERC20(asset).approve(address(pool), amount);

        // Repay to Aave V3
        uint256 repaid = pool.repay({
            asset: asset,
            amount: amount,
            interestRateMode: rateMode,
            onBehalfOf: onBehalfOf
        });

        return repaid;
    }

    /**
     * @notice Get the current variable debt for an asset
     * @param asset Address of the borrowed asset
     * @return Current variable debt balance
     */
    function getVariableDebt(address asset) public view returns (uint256) {
        return _getVariableDebtToken(asset).balanceOf(address(this));
    }

    /**
     * @notice Check if there is any debt to repay
     * @param asset Address of the asset
     * @return True if there is variable debt
     */
    function hasDebt(address asset) external view returns (bool) {
        return getVariableDebt(asset) > 0;
    }
}
