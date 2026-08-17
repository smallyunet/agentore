// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AgentOre } from "../src/AgentOre.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address sender) external;
    function expectRevert(bytes calldata revertData) external;
}

contract AgentOreTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    AgentOre private ore;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant FINALIZER = address(0xF1A1);

    function setUp() public {
        ore = new AgentOre(1 days, 365, 1_000 ether, 100);
    }

    function testParametersAndHalving() public view {
        _assertEq(ore.currentEpoch(), 0);
        _assertEq(ore.rewardForEpoch(0), 1_000 ether);
        _assertEq(ore.rewardForEpoch(364), 1_000 ether);
        _assertEq(ore.rewardForEpoch(365), 500 ether);
        _assertEq(ore.rewardForEpoch(730), 250 ether);
    }

    function testFirstSubmissionOnlyEstablishesBaseline() public {
        vm.prank(ALICE);
        ore.submit(1_000_000);

        _assertTrue(ore.registered(ALICE));
        _assertEq(ore.lastCumulativeTokens(ALICE), 1_000_000);
        _assertEq(ore.totalWeight(0), 0);
        _assertEq(ore.entryCount(0), 0);
    }

    function testWalletCanSubmitOnlyOncePerEpoch() public {
        vm.prank(ALICE);
        ore.submit(100);

        vm.expectRevert(abi.encodeWithSelector(AgentOre.AlreadySubmitted.selector, 0, ALICE));
        vm.prank(ALICE);
        ore.submit(200);
    }

    function testCounterMustIncrease() public {
        vm.prank(ALICE);
        ore.submit(100);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(abi.encodeWithSelector(AgentOre.CounterDidNotIncrease.selector, 100, 100));
        vm.prank(ALICE);
        ore.submit(100);
    }

    function testWeightedEntriesAndFinalization() public {
        _establishBaseline(ALICE, 1_000);
        _establishBaseline(BOB, 2_000);

        vm.warp(block.timestamp + 1 days);

        vm.prank(ALICE);
        ore.submit(1_100);
        vm.prank(BOB);
        ore.submit(2_300);

        _assertEq(ore.totalWeight(1), 400);
        _assertEq(ore.entryCount(1), 2);

        AgentOre.Entry memory first = ore.entryAt(1, 0);
        AgentOre.Entry memory second = ore.entryAt(1, 1);
        _assertEq(first.account, ALICE);
        _assertEq(first.cumulativeWeight, 100);
        _assertEq(second.account, BOB);
        _assertEq(second.cumulativeWeight, 400);

        vm.warp(block.timestamp + 1 days);
        vm.prank(FINALIZER);
        address selected = ore.finalize(1);

        _assertTrue(selected == ALICE || selected == BOB);
        _assertEq(ore.winner(1), selected);
        _assertEq(ore.totalSupply(), 1_000 ether);
        _assertEq(ore.balanceOf(FINALIZER), 10 ether);
        _assertEq(ore.balanceOf(selected), 990 ether);
        _assertEq(ore.mintedReward(1), 1_000 ether);
    }

    function testEmptyEpochMintsNothing() public {
        vm.warp(block.timestamp + 1 days);
        vm.prank(FINALIZER);
        address selected = ore.finalize(0);

        _assertEq(selected, address(0));
        _assertTrue(ore.finalized(0));
        _assertEq(ore.totalSupply(), 0);
    }

    function testCannotFinalizeOpenOrFinalizedEpoch() public {
        vm.expectRevert(abi.encodeWithSelector(AgentOre.EpochStillOpen.selector, 0));
        ore.finalize(0);

        vm.warp(block.timestamp + 1 days);
        ore.finalize(0);

        vm.expectRevert(abi.encodeWithSelector(AgentOre.EpochAlreadyFinalized.selector, 0));
        ore.finalize(0);
    }

    function testERC20TransferAndAllowance() public {
        _establishBaseline(ALICE, 0);
        vm.warp(block.timestamp + 1 days);
        vm.prank(ALICE);
        ore.submit(10);
        vm.warp(block.timestamp + 1 days);
        vm.prank(FINALIZER);
        address selected = ore.finalize(1);

        vm.prank(selected);
        ore.transfer(BOB, 100 ether);
        _assertEq(ore.balanceOf(BOB), 100 ether);

        vm.prank(BOB);
        ore.approve(ALICE, 25 ether);
        vm.prank(ALICE);
        ore.transferFrom(BOB, ALICE, 25 ether);
        _assertEq(ore.balanceOf(BOB), 75 ether);
        _assertEq(ore.balanceOf(ALICE), 915 ether);
        _assertEq(ore.allowance(BOB, ALICE), 0);
    }

    function _establishBaseline(address account, uint256 value) private {
        vm.prank(account);
        ore.submit(value);
    }

    function _assertTrue(bool condition) private pure {
        require(condition, "assertion failed");
    }

    function _assertEq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "uint assertion failed");
    }

    function _assertEq(address actual, address expected) private pure {
        require(actual == expected, "address assertion failed");
    }
}
