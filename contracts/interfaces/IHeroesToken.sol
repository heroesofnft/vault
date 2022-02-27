// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IHeroesToken is IERC721Enumerable {
  /**
   * @dev bundle
   * @param _bundle_type bundle type identifier
   *   0 : single character
   *   1 : five charactersÓ
   */
  function purchaseBundle(uint8 _bundle_type) external payable;

  /**
   * @dev Get all tokens of specified owner address
   * Requires ERC721Enumerable extension
   */
  function tokensOfOwner(address _owner) external view returns (uint256[] memory);

  /**
   * @dev Get character rarity and random number
   */
  function getCharacter(uint256 character_id)
    external
    view
    returns (
      uint8 o_generation,
      uint8 o_rarity,
      uint256 o_randomNumber,
      bytes32 o_randomHash
    );
}
