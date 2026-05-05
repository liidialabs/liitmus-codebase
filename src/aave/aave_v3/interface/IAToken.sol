// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Aave V3 aToken interface
// Represents a supply position in an Aave V3 reserve
// https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/tokenization/AToken.sol

interface IAToken {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Deposit(address indexed caller, address indexed onBehalfOf, uint256 value, uint256 balanceIncrease);
    event Withdraw(address indexed from, address indexed to, uint256 value, uint256 balanceIncrease);

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

    function mint(address caller, address onBehalfOf, uint256 amount, uint256 balanceIncrease) external returns (bool);
    function burn(address from, address to, uint256 amount, uint256 balanceIncrease) external;

    function RESERVE_TREASURY_ADDRESS() external view returns (address);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function POOL() external view returns (address);

    function transferUnderlyingTo(address target, uint256 amount) external;

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function nonce(address user) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function RESERVE_REVERSE_CALLBACK() external view returns (bytes4);
}
