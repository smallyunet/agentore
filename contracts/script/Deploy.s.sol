// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AgentOre } from "../src/AgentOre.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256 value);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployAgentOre {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (AgentOre deployed) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        deployed = new AgentOre({ epochDuration_: 1 days, finalizerBps_: 100 });
        vm.stopBroadcast();
    }
}
