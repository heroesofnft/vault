// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IHeroesToken.sol";
import "./interfaces/IWorkerToken.sol";

/// @title Heroes Vault Contract
/// @notice Heroes Vault allows users to stake their Hro tokens with Hon tokens
/// to gain Hon tokens without impermanent loss
/// @author defikintaro
contract HeroesVault is Ownable, IERC721Receiver {
  /// @dev Heroes Nft tokens
  address public hroToken;
  /// @dev Hon tokens
  address public honToken;
  /// @dev Worker tokens rewarded after staking
  address public workerToken;

  // Fee address
  address public feeAddress;
  /// @dev Unstaking fee
  uint256 public feePerMillion;

  /// @dev Heroes Nft Id
  /// @dev Hon token amount
  /// @dev Worker token amount
  struct Record {
    uint256 hroId;
    uint256 honAmount;
    uint256 workerAmount;
  }

  /// @dev Heroes Nft rarity
  /// @dev Hon token amount
  /// @dev Worker token amount
  struct Tier {
    uint256 hroRarity;
    uint256 honAmount;
    uint256 workerAmount;
  }

  /// @dev Staked asset record for each player
  mapping(address => mapping(uint256 => Record)) public records;
  /// @dev Track the record count of each player
  mapping(address => uint256) public recordCounts;

  /// @dev Tier list
  Tier[5] public tiers;

  /// @dev Emits when `stake` method has been called
  /// @param staker Staker address
  /// @param tier Staker's tier
  /// @param honAmount Staked Hon token amount
  /// @param hroId Staked Hro token's id
  /// @param workerAmount Issued Worker token amount
  event Stake(address staker, uint256 tier, uint256 honAmount, uint256 hroId, uint256 workerAmount);

  /// @dev Emits when `unstake` method has been called
  /// @param staker Staker address
  /// @param hroId Id of the Hro token
  /// @param fee Hon token fee
  event Unstake(address staker, uint256 hroId, uint256 fee);

  /// @param _hroToken Address of the Hro token contract
  /// @param _workerToken Address of the Worker token contract
  /// @param _honToken Address of the Hon token contract
  /// @param _feeAddress Address of the Fee account
  constructor(
    address _hroToken,
    address _workerToken,
    address _honToken,
    address _feeAddress
  ) {
    hroToken = _hroToken;
    workerToken = _workerToken;
    honToken = _honToken;
    feeAddress = _feeAddress;
  }

  /// @dev Allows staking Hon + Hro pair on tier's requirements
  /// @param honAmount Hon token amount to stake
  /// @param hroId Hro token id to stake
  /// @param tier Staking tier to decide staking requirements
  function stake(
    uint256 honAmount,
    uint256 hroId,
    uint256 tier
  ) external {
    require(tier < tiers.length, "Tier does not exist");
    require(tiers[tier].workerAmount > 0, "Tier is not ready");

    address sender = msg.sender;
    IHeroesToken iHeroesToken = IHeroesToken(hroToken);
    IERC20 iHonToken = IERC20(honToken);

    // Get character data from HRO contract
    (, uint8 rarity, , ) = iHeroesToken.getCharacter(hroId);

    require(iHeroesToken.ownerOf(hroId) == sender, "Sender is not the owner");
    require(iHonToken.balanceOf(sender) >= honAmount, "Not enough Hon tokens");
    require(tiers[tier].honAmount == honAmount, "Hon amount does not match with tier");
    require(tiers[tier].hroRarity == rarity, "Hro rarity does not match with tier");

    // Insert a new record
    records[sender][hroId] = Record({
      hroId: hroId,
      honAmount: honAmount,
      workerAmount: tiers[tier].workerAmount
    });
    recordCounts[sender]++;

    // Collect Hon token
    iHonToken.transferFrom(sender, address(this), honAmount);
    // Collect Hro token
    iHeroesToken.safeTransferFrom(sender, address(this), hroId);
    // Mint Worker token
    IWorkerToken(workerToken).mint(sender, tiers[tier].workerAmount);

    emit Stake(sender, tier, honAmount, hroId, tiers[tier].workerAmount);
  }

  /// @dev Unstakes the staked HON/HRO pair and burns the Worker tokens
  /// @param hroId Id of the Hro token that is being staked
  function unstake(uint256 hroId) external {
    address sender = msg.sender;
    Record memory record = records[sender][hroId];

    require(record.workerAmount > 0, "Record does not exist");
    require(
      IWorkerToken(workerToken).balanceOf(sender) >= record.workerAmount,
      "Not enough worker tokens"
    );

    // Delete the matching record
    delete records[sender][hroId];
    recordCounts[sender]--;

    // Collect the Hon token fee if any
    uint256 fee = (record.honAmount * feePerMillion) / 1e6;

    // Distribute back Hon token
    IERC20(honToken).transfer(sender, record.honAmount - fee);
    // Transfer the fee Hon token
    IERC20(honToken).transfer(feeAddress, fee);
    // Distribute back Hro token
    IHeroesToken(hroToken).safeTransferFrom(address(this), sender, record.hroId);
    // Burn Worker token
    IWorkerToken(workerToken).burn(sender, record.workerAmount);

    emit Unstake(sender, hroId, fee);
  }

  /// @dev Compatability with IERC721 Receiver
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /// @dev Update the tier information
  /// @param _tier Tier id
  /// @param _hroRarity Rarity of Hro token
  /// @param _honAmount Amount of Hon token
  /// @param _workerAmount Amount of Worker token
  /// @notice Updating the amount of Worker token that is given at the each stake
  /// does not change the previous stakes. This can be used to reward previous
  /// stakers by decreasing the future amounts or forces them to unstake them restake
  /// to get increased pool share by increasing the future amounts.
  function updateTier(
    uint256 _tier,
    uint256 _hroRarity,
    uint256 _honAmount,
    uint256 _workerAmount
  ) external onlyOwner {
    tiers[_tier] = Tier({
      hroRarity: _hroRarity,
      honAmount: _honAmount,
      workerAmount: _workerAmount
    });
  }

  /// @dev Update the Hon token contract address
  function updateHonToken(address _honToken) external onlyOwner {
    require(_honToken != address(0), "The new contract address must not be 0");
    honToken = _honToken;
  }

  /// @dev Update the Hro token contract address
  function updateHroToken(address _hroToken) external onlyOwner {
    require(_hroToken != address(0), "The new contract address must not be 0");
    hroToken = _hroToken;
  }

  /// @dev Update the Worker token contract address
  function updateWorkerToken(address _workerToken) external onlyOwner {
    require(_workerToken != address(0), "The new contract address must not be 0");
    workerToken = _workerToken;
  }

  /// @dev Update fee
  function updateFeePerMillion(uint256 _feePerMillion) external onlyOwner {
    feePerMillion = _feePerMillion;
  }

  /// @dev Update fee address
  function updateFeeAddress(address _feeAddress) external onlyOwner {
    feeAddress = _feeAddress;
  }
}
