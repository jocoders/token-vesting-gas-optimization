// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from '../lib/solady/src/auth/Ownable.sol';
import { SafeTransferLib } from '../lib/solady/src/utils/SafeTransferLib.sol';

interface IERC20 {
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * @title TokenVestingOptimized
 * @notice A smart contract for token vesting with an optional revocable feature.
 * @dev Uses SafeTransferLib for secure token transfers.
 */
contract TokenVestingOptimized is Ownable {
  using SafeTransferLib for address;

  event TokensReleased(address token, uint256 amount);
  event TokenVestingRevoked(address token);

  address public beneficiary;
  bool public revocable;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  mapping(address => uint256) private released;
  mapping(address => bool) private revoked;

  error InvalidBeneficiary();
  error InvalidCliff();
  error InvalidDuration();
  error InvalidStartTime();
  error InvalidRevocable();
  error WrongFinalkTime();
  error NoTokensDue();
  error CannotRevoke();
  error TokenAlreadyRevoked();

  /**
   * @notice Initializes the vesting contract.
   * @param _beneficiary The address of the beneficiary.
   * @param _start The start time of the vesting schedule.
   * @param _cliff The cliff duration in seconds.
   * @param _duration The total duration of the vesting.
   * @param _revocable Whether the vesting can be revoked by the owner.
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) {
    if (_beneficiary == address(0)) revert InvalidBeneficiary();
    if (_cliff > _duration) revert InvalidCliff();
    if (_duration == 0) revert InvalidDuration();
    if (_start + _duration <= block.timestamp) revert WrongFinalkTime();

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    cliff = _start + _cliff;
    start = _start;
    _initializeOwner(msg.sender);
  }

  /**
   * @notice Returns the amount of tokens already released for a given token.
   * @param token The token address.
   * @return value The amount of tokens released.
   */
  function getReleased(address token) public view returns (uint256 value) {
    value = released[token];
  }

  /**
   * @notice Checks if a token has been revoked.
   * @param token The token address.
   * @return value True if revoked, false otherwise.
   */
  function getRevoked(address token) public view returns (bool value) {
    value = revoked[token];
  }

  /**
   * @notice Releases vested tokens to the beneficiary.
   * @param token The token to release.
   */
  function release(IERC20 token) public {
    uint256 unreleased = _releasableAmount(token);

    if (unreleased == 0) revert NoTokensDue();

    released[address(token)] = released[address(token)] + unreleased;
    address(token).safeTransfer(beneficiary, unreleased);
    emit TokensReleased(address(token), unreleased);
  }

  /**
   * @notice Revokes the vesting of a token, transferring remaining balance to the owner.
   * @param token The token to revoke.
   */
  function revoke(IERC20 token) public onlyOwner {
    if (!revocable) revert CannotRevoke();
    if (revoked[address(token)]) revert TokenAlreadyRevoked();

    uint256 balance = token.balanceOf(address(this));
    uint256 unreleased = _releasableAmount(token);
    uint256 refund = balance - unreleased;

    revoked[address(token)] = true;
    address(token).safeTransfer(owner(), refund);

    emit TokenVestingRevoked(address(token));
  }

  /**
   * @notice Emergency revocation of vesting, transferring all remaining tokens to the owner.
   * @param token The token to revoke.
   */
  function emergencyRevoke(IERC20 token) public onlyOwner {
    if (!revocable) revert CannotRevoke();
    if (revoked[address(token)]) revert TokenAlreadyRevoked();

    uint256 balance = token.balanceOf(address(this));

    revoked[address(token)] = true;

    address(token).safeTransfer(owner(), balance);

    emit TokenVestingRevoked(address(token));
  }

  /**
   * @notice Calculates the amount of vested tokens that can be released.
   * @param token The token to calculate for.
   * @return amount The amount of releasable tokens.
   */
  function _releasableAmount(IERC20 token) private view returns (uint256 amount) {
    uint256 tokenReleased = released[address(token)];
    uint256 currentBalance = token.balanceOf(address(this));
    uint256 totalBalance = currentBalance + tokenReleased;
    uint256 timeStamp = block.timestamp;

    uint256 vestedAmount;
    uint256 _start = start;
    uint256 _duration = duration;

    if (timeStamp < cliff) {
      vestedAmount = 0;
    } else if (timeStamp >= _start + _duration || revoked[address(token)]) {
      vestedAmount = totalBalance;
    } else {
      vestedAmount = (totalBalance * (timeStamp - _start)) / _duration;
    }

    amount = vestedAmount - tokenReleased;
  }
}
