// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WorkerToken is Ownable, ERC20 {
  constructor() ERC20("WorkerToken", "HWT") {}

  /**
   * @dev Creates `amount` tokens and assigns them to `account`,
   * increasing the total supply.
   * @param account token receiving address
   * @param amount tokens
   */
  function mint(address account, uint256 amount) public onlyOwner {
    _mint(account, amount);
  }

  /**
   * @dev Destroys `amount` tokens and assigns them to `account`,
   * decreasing the total supply.
   * @param account token receiving address
   * @param amount tokens
   */
  function burn(address account, uint256 amount) public onlyOwner {
    _burn(account, amount);
  }
}
