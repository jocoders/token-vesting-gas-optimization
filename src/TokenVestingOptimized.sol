// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Ownable } from '../lib/solady/src/auth/Ownable.sol';
import { SafeTransferLib } from '../lib/solady/src/utils/SafeTransferLib.sol';
import { Test, console } from 'forge-std/Test.sol';

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

  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) {
    require(_beneficiary != address(0), 'TokenVesting: beneficiary is the zero address');
    require(_cliff <= _duration, 'TokenVesting: cliff is longer than duration');
    require(_duration > 0, 'TokenVesting: duration is 0');
    require(_start + _duration > block.timestamp, 'TokenVesting: final time is before current time');

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    cliff = _start + _cliff;
    start = _start;
    _initializeOwner(msg.sender);
  }

  function getReleased(address token) public view returns (uint256 value) {
    value = released[token];
  }

  function getRevoked(address token) public view returns (bool value) {
    value = revoked[token];
  }

  function release(IERC20 token) public {
    uint256 unreleased = _releasableAmount(token);

    require(unreleased > 0, 'TokenVesting: no tokens are due');

    released[address(token)] = released[address(token)] + unreleased;

    address(token).safeTransfer(beneficiary, unreleased);

    emit TokensReleased(address(token), unreleased);
  }

  function revoke(IERC20 token) public onlyOwner {
    require(revocable, 'TokenVesting: cannot revoke');
    require(!revoked[address(token)], 'TokenVesting: token already revoked');

    uint256 balance = token.balanceOf(address(this));
    uint256 unreleased = _releasableAmount(token);
    uint256 refund = balance - unreleased;

    revoked[address(token)] = true;
    address(token).safeTransfer(owner(), refund);

    emit TokenVestingRevoked(address(token));
  }

  function emergencyRevoke(IERC20 token) public onlyOwner {
    require(revocable, 'TokenVesting: cannot revoke');
    require(!revoked[address(token)], 'TokenVesting: token already revoked');

    uint256 balance = token.balanceOf(address(this));

    revoked[address(token)] = true;

    address(token).safeTransfer(owner(), balance);

    emit TokenVestingRevoked(address(token));
  }

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
