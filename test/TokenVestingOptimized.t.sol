// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TokenVestingOptimized, IERC20 } from '../src/TokenVestingOptimized.sol';
import { Test, console } from 'forge-std/Test.sol';
import { ERC20 } from '../lib/solady/src/tokens/ERC20.sol';

contract TestToken is ERC20 {
  string private _name = 'Test Token';
  string private _symbol = 'TEST';

  constructor() {
    _mint(msg.sender, 1_000_000e18);
  }

  function name() public view override returns (string memory) {
    return _name;
  }

  function symbol() public view override returns (string memory) {
    return _symbol;
  }
}

contract TokenVestingOptimizedTest is Test {
  TokenVestingOptimized tokenVesting;
  TestToken token1;

  uint256 start;
  uint256 cliff;
  uint256 duration;
  address beneficiary = makeAddr('beneficiary');

  function setUp() public {
    start = 1;
    cliff = 7;
    duration = 100;

    tokenVesting = new TokenVestingOptimized(beneficiary, start, cliff, duration, true);
    token1 = new TestToken();
  }

  function testGetRealesed() public {
    uint256 released = tokenVesting.getReleased(address(this));
    assertEq(released, 0);
  }

  function testGetRevoked() public {
    bool revoked = tokenVesting.getRevoked(address(this));
    assertEq(revoked, false);
  }

  function testRelease() public {
    vm.warp(50);
    token1.transfer(address(tokenVesting), 1_000e18);
    tokenVesting.release(IERC20(address(token1)));

    uint256 released = tokenVesting.getReleased(address(token1));
    console.log('released', released);
    assertEq(released, 490000000000000000000, 'released is not correct');
  }

  function testRevoke() public {
    vm.warp(50);
    uint256 balanceBefore = token1.balanceOf(address(this));
    token1.transfer(address(tokenVesting), 1_000e18);
    tokenVesting.release(IERC20(address(token1)));

    tokenVesting.revoke(IERC20(address(token1)));

    uint256 balanceAfter = token1.balanceOf(address(this));
    uint256 balContract = token1.balanceOf(address(tokenVesting));
  }

  function testEmergencyRevoke() public {
    vm.warp(50);
    token1.transfer(address(tokenVesting), 1_000e18);
    tokenVesting.release(IERC20(address(token1)));

    tokenVesting.emergencyRevoke(IERC20(address(token1)));
  }
}
