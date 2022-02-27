// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWorkerToken is IERC20 {
  function mint(address account, uint256 amount) external;
  function burn(address account, uint256 amount) external;
}
