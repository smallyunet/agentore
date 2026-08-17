// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AgentOre } from "../src/AgentOre.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployAgentOre {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (AgentOre deployed) {
        vm.startBroadcast();
        deployed = new AgentOre({
            epochDuration_: 1 days,
            halvingInterval_: 365,
            initialReward_: 1_000 ether,
            finalizerBps_: 100
        });
        vm.stopBroadcast();
    }
}
