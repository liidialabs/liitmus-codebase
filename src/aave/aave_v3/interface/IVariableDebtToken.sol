// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Aave V3 Variable Debt Token interface
// Represents a variable rate borrow position
// https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/tokenization/VariableDebtToken.sol

interface IVariableDebtToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Borrow(address indexed from, address indexed to, uint256 value, uint256 balanceIncrease, uint256 index);
    event Mint(address indexed caller, address indexed onBehalfOf, uint256 value, uint256 balanceIncrease, uint256 index);
    event Burn(address indexed from, uint256 value, uint256 balanceIncrease, uint256 index);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function scaledBalanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function mint(address user, address onBehalfOf, uint256 amount, uint256 index) external returns (bool);
    function burn(address from, uint256 amount, uint256 index) external returns (uint256);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function POOL() external view returns (address);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function nonce(address user) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
