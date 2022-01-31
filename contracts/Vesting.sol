// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Token Vesting Contract
/// @author defikintaro
/// @notice This contract treats all of the addresses equally
contract Vesting is Ownable {
  using SafeMath for uint256;
  using Address for address;

  /// @dev Emits when `initialize` method has been called
  /// @param caller The address of the caller
  /// @param distributionStart Distribution start date
  /// @param installmentPeriod Per installment period
  event Initialized(address caller, uint256 distributionStart, uint256 installmentPeriod);

  /// @dev Emits when `withdraw` method has been called
  /// @param recipient Recipient address
  /// @param value Transferred value
  event Withdrawn(address recipient, uint256 value);

  /// @dev Emits when `withdraw` method has been called
  /// @param recipient Recipient address
  /// @param value Transferred value
  event WithdrawnTge(address recipient, uint256 value);

  /// @dev Emits when `addParticipants` method has been called
  /// @param participants Participants addresses
  /// @param stakes Participants stakes
  /// @param caller The address of the caller
  event ParticipantsAdded(address[] participants, uint256[] stakes, address caller);

  /// @dev Emits when `addGroup` method has been called
  /// @param cliff Group cliff period
  /// @param tgePerMillion Unlocked tokens per million
  /// @param numberOfInstallments Number of installments of being distributed
  /// @param caller The address of the caller
  event GroupAdded(
    uint256 cliff,
    uint256 tgePerMillion,
    uint256 numberOfInstallments,
    address caller
  );

  /// @dev The instance of ERC20 token
  IERC20 token;

  /// @dev Total amount of tokens
  /// @dev Amount of remaining tokens to distribute for the beneficiary
  /// @dev Beneficiary cliff period
  /// @dev Total number of installments for the beneficiary
  /// @dev Number of installments that were made
  /// @dev The value of single installment
  /// @dev The value to transfer to the beneficiary at TGE
  /// @dev Boolean variable that contains whether the value at TGE was paid or not
  struct Beneficiary {
    uint256 stake;
    uint256 tokensLeft;
    uint256 cliff;
    uint256 numberOfInstallments;
    uint256 numberOfInstallmentsMade;
    uint256 installmentValue;
    uint256 tgeValue;
    bool wasValueAtTgePaid;
  }

  /// @dev Is group active
  /// @dev Cliff period
  /// @dev TGE unlock amount per million
  /// @dev Number of installments will be made
  struct Group {
    bool active;
    uint256 cliff;
    uint256 tgePerMillion;
    uint256 numberOfInstallments;
  }

  /// @dev Beneficiary records
  mapping(address => Beneficiary) public beneficiaries;
  /// @dev Group records
  mapping(uint8 => Group) public groups;

  /// @dev Track the number of beneficiaries
  uint256 public numberOfBeneficiaries;
  /// @dev Track the total sum
  uint256 public sumOfStakes;
  /// @dev Total deposited tokens
  uint256 public totalDepositedTokens;
  /// @dev Installment period
  uint256 public period;

  /// @dev The timestamp of the distribution start
  uint256 public distributionStartTimestamp;
  /// @dev Boolean variable that indicates whether the contract was initialized
  bool public isInitialized = false;

  /// @dev Checks that the contract is initialized
  modifier initialized() {
    require(isInitialized, "Not initialized");
    _;
  }

  constructor() {}

  /// @dev Initializes the distribution
  /// @param _token Distributed token address
  /// @param _distributionStart Distribution start date
  /// @param _installmentPeriod Per installment period
  function initialize(
    address _token,
    uint256 _distributionStart,
    uint256 _installmentPeriod
  ) external onlyOwner {
    require(!isInitialized, "Already initialized");
    require(_distributionStart > block.timestamp, "Cannot start early");
    require(_installmentPeriod > 0, "Installment period must be greater than 0");
    require(_token.isContract(), "The token address must be a deployed contract");

    isInitialized = true;
    token = IERC20(_token);
    distributionStartTimestamp = _distributionStart;
    period = _installmentPeriod;

    emit Initialized(msg.sender, _distributionStart, _installmentPeriod);
  }

  /// @dev Deposit the tokens from the owner wallet then increase `totalDepositedTokens`
  /// @param _amount Amount of the tokens
  function deposit(uint256 _amount) external onlyOwner initialized {
    totalDepositedTokens += _amount;
    token.transferFrom(msg.sender, address(this), _amount);
  }

  /// @dev Withdraw the TGE amount
  /// @notice Reverts if there are not enough tokens
  function withdrawTge() external initialized {
    require(beneficiaries[msg.sender].stake > 0, "Not a participant");
    if (!beneficiaries[msg.sender].wasValueAtTgePaid) {
      beneficiaries[msg.sender].wasValueAtTgePaid = true;
      token.transfer(msg.sender, beneficiaries[msg.sender].tgeValue);
      emit WithdrawnTge(msg.sender, beneficiaries[msg.sender].tgeValue);
    }
  }

  /// @dev Withdraws the available installment amount
  /// @notice Does not allow withdrawal before the cliff date
  function withdraw() external initialized {
    address sender = msg.sender;
    require(beneficiaries[sender].stake > 0, "Not a participant");
    require(
      block.timestamp >= distributionStartTimestamp.add(beneficiaries[sender].cliff),
      "Cliff duration has not passed"
    );
    require(
      beneficiaries[sender].numberOfInstallments > beneficiaries[sender].numberOfInstallmentsMade,
      "Installments have been paid"
    );

    uint256 elapsedPeriods = block
      .timestamp
      .sub(distributionStartTimestamp.add(beneficiaries[sender].cliff))
      .div(period);

    if (elapsedPeriods > beneficiaries[sender].numberOfInstallments) {
      elapsedPeriods = beneficiaries[sender].numberOfInstallments;
    }

    uint256 availableInstallments = elapsedPeriods.sub(
      beneficiaries[sender].numberOfInstallmentsMade
    );
    uint256 amount = availableInstallments.mul(beneficiaries[sender].installmentValue);

    beneficiaries[sender].numberOfInstallmentsMade += availableInstallments;
    token.transfer(sender, amount);
    emit Withdrawn(sender, amount);
  }

  /// @dev Adds new participants
  /// @param _participants The addresses of new participants
  /// @param _stakes The amounts of the tokens that belong to each participant
  /// @param _group Group id of the participants
  /// @notice Ceils the installment value distributed per period by 1x10^-6
  function addParticipants(
    address[] calldata _participants,
    uint256[] calldata _stakes,
    uint8 _group
  ) external onlyOwner {
    require(!isInitialized, "Cannot add participants after initialization");
    require(groups[_group].active, "Group is not active");
    require(_participants.length == _stakes.length, "Different array sizes");
    for (uint256 i = 0; i < _participants.length; i++) {
      require(_participants[i] != address(0), "Invalid address");
      require(_stakes[i] > 0, "Stake must be more than 0");
      require(beneficiaries[_participants[i]].stake == 0, "Participant has already been added");

      uint256 _tgeValue = _stakes[i].mul(groups[_group].tgePerMillion).div(1e6);

      uint256 _installmentValue = _stakes[i].sub(_tgeValue).div(
        groups[_group].numberOfInstallments
      );
      // Ceil the installment amount
      _installmentValue = _installmentValue.div(1e12).add(1);
      _installmentValue *= 1e12;

      // Track the sum
      sumOfStakes += _installmentValue.mul(groups[_group].numberOfInstallments).add(_tgeValue);

      beneficiaries[_participants[i]] = Beneficiary({
        stake: _stakes[i],
        tokensLeft: 0,
        cliff: groups[_group].cliff,
        numberOfInstallments: groups[_group].numberOfInstallments,
        numberOfInstallmentsMade: 0,
        installmentValue: _installmentValue,
        tgeValue: _tgeValue,
        wasValueAtTgePaid: false
      });
      numberOfBeneficiaries++;
    }

    emit ParticipantsAdded(_participants, _stakes, msg.sender);
  }

  /// @dev Add or change a group parameters
  /// @param _groupId Id of the group
  /// @param _cliff Cliff duration period
  /// @param _tgePerMillion Unlocked token amount at TGE per million
  /// @param _numberOfInstallments Number of installments of being distributed
  function setGroup(
    uint8 _groupId,
    uint256 _cliff,
    uint256 _tgePerMillion,
    uint256 _numberOfInstallments
  ) external onlyOwner {
    require(!isInitialized, "Cannot change a group after initialization");
    groups[_groupId] = Group({
      active: true,
      cliff: _cliff,
      tgePerMillion: _tgePerMillion,
      numberOfInstallments: _numberOfInstallments
    });
    emit GroupAdded(_cliff, _tgePerMillion, _numberOfInstallments, msg.sender);
  }

  /// @dev Withdraw the remaining amount to the owner after stakes are initialized
  function withdrawRemaining() external onlyOwner initialized {
    uint256 remaining = totalDepositedTokens.sub(sumOfStakes);
    totalDepositedTokens = sumOfStakes;
    token.transfer(owner(), remaining);
  }
}
