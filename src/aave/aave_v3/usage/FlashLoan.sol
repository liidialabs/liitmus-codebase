// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {AaveV3Base} from "./AaveV3Base.sol";

/**
 * @title FlashLoan
 * @notice Demonstrates how to execute flash loans in Aave V3
 * @dev Flash loans allow borrowing assets with no collateral, as long as they are repaid in the same transaction.
 */
contract FlashLoan is AaveV3Base {
    constructor(address _provider) AaveV3Base(_provider) {}

    /**
     * @notice Execute a simple flash loan for a single asset
     * @param asset Address of the asset to borrow
     * @param amount Amount to borrow (in token decimals)
     * @param params Custom data to pass to executeOperation
     * 
     * @dev Requirements:
     * - The contract must implement executeOperation callback
     * - Loan + fee must be approved for the pool before the callback returns
     * - Fee is typically 0.05% of the borrowed amount
     */
    function flashLoanSimple(address asset, uint256 amount, bytes memory params) external {
        pool.flashLoanSimple({
            receiverAddress: address(this),
            asset: asset,
            amount: amount,
            params: params,
            referralCode: 0
        });
    }

    /**
     * @notice Callback executed during a simple flash loan
     * @param asset Address of the flashed asset
     * @param amount Amount that was borrowed
     * @param fee Fee that must be repaid
     * @param initiator Address that initiated the flash loan
     * @param params Custom parameters passed to the flash loan
     * @return True if the operation succeeded
     *
     * @dev This function is called by the pool with the borrowed funds.
     * The contract must approve the pool for amount + fee before returning.
     * All custom logic (arbitrage, liquidation, etc.) happens here.
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        // Verify callback is from the pool
        require(msg.sender == address(pool), "FlashLoan: unauthorized callback");
        require(initiator == address(this), "FlashLoan: invalid initiator");

        // Decode custom parameters
        (address caller) = abi.decode(params, (address));

        // ============================
        // CUSTOM LOGIC GOES HERE
        // ============================
        // Examples:
        // - Arbitrage: swap tokens on DEX for profit
        // - Liquidation: liquidate underwater positions
        // - Collateral swap: change collateral type
        // - Self-liquidation: repay debt and withdraw collateral

        // Transfer the fee from the caller (or pay from contract balance)
        uint256 amountOwing = amount + fee;
        IERC20(asset).transferFrom(caller, address(this), fee);

        // Approve the pool to take back the loan + fee
        IERC20(asset).approve(address(pool), amountOwing);

        return true;
    }

    /**
     * @notice Execute a multi-asset flash loan
     * @param assets Array of asset addresses to borrow
     * @param amounts Array of amounts to borrow for each asset
     * @param interestRateModes Array of rate modes (1 = stable, 2 = variable) for each asset
     * @param onBehalfOf Address that will be responsible for the debt during the transaction
     * @param params Custom parameters
     *
     * @dev More complex than simple flash loans. Allows borrowing multiple assets simultaneously.
     * Requires implementing the IFlashLoanSimpleReceiver or IFlashLoanReceiver interface.
     */
    function flashLoanMulti(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params
    ) external {
        pool.flashLoan({
            receiverAddress: address(this),
            assets: assets,
            amounts: amounts,
            interestRateModes: interestRateModes,
            onBehalfOf: onBehalfOf,
            params: params,
            referralCode: 0
        });
    }

    /**
     * @notice Get the current flash loan fee percentage
     * @return premiumTotal Total premium charged (1e4 = 100%)
     * @return premiumToProtocol Portion that goes to protocol
     *
     * @dev Typical values: premiumTotal = 5 (0.05%), premiumToProtocol varies by governance
     */
    function getFlashLoanFee() external view returns (uint256 premiumTotal, uint256 premiumToProtocol) {
        return (pool.FLASHLOAN_PREMIUM_TOTAL(), pool.FLASHLOAN_PREMIUM_TO_PROTOCOL());
    }

    /**
     * @notice Calculate the fee for a flash loan
     * @param amount Amount to borrow
     * @return fee Fee amount that must be repaid
     */
    function calculateFlashLoanFee(uint256 amount) external view returns (uint256) {
        uint256 premium = pool.FLASHLOAN_PREMIUM_TOTAL();
        return (amount * premium) / 10000;
    }
}
