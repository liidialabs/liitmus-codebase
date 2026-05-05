// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Aave V3 Pool interface - https://github.com/aave/aave-v3-core

interface IPool {
    // Errors
    error InvalidAmount();
    error NotOwner();
    error NotBorrowable();
    error NotCollateral();
    error BorrowNotAllowed();
    error InvalidHealthFactor();
    error AlreadyInitialized();
    error CallNotAllowed();

    // Structs
    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    struct InterestRate {
        uint256 variableRateSlope1;
        uint256 variableRateSlope2;
        uint256 stableRateSlope1;
        uint256 stableRateSlope2;
        uint256 baseVariableBorrowRate;
        uint256 optimalUsageRatio;
    }

    // Events
    event Supply(address indexed reserve, address indexed user, uint256 amount);
    event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);
    event Borrow(
        address indexed reserve,
        address indexed user,
        address indexed onBehalfOf,
        uint256 amount,
        uint8 interestRateMode,
        uint256 borrowRate,
        uint16 referralCode
    );
    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount,
        bool useATokens
    );
    event SwapBorrowRateMode(address indexed reserve, address indexed user, uint256 interestRateMode);
    event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);
    event UserEModeSet(address indexed user, uint8 categoryId);
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 amount,
        address liquidator,
        bool receiveAToken
    );
    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint8 interestRateMode,
        uint256 premium,
        uint16 referralCode
    );
    event ReserveDataUpdated(
        address indexed asset,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    // Core functions
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawn);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256 repaid);

    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (uint256 repaid);

    function swapBorrowRateMode(address asset, uint256 interestRateMode) external;

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    // Flash loans
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    // View functions
    function getUserAccountData(address user) external view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getReserveData(address asset) external view returns (ReserveData memory);

    function getReservesList() external view returns (address[] memory);

    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view returns (uint256);

    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint256);

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint256);

    function ADDRESSES_PROVIDER() external view returns (address);

    // E-Mode functions
    function setUserEMode(uint8 categoryId) external;

    function getUserEMode(address user) external view returns (uint256);
}
