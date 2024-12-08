// SPDX-License-Identifier : MIT

pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import { BlocEstateEth } from "../src/BlocEstateEth.sol";

contract BlocEstateEthScript is Script {
    // 
    
    event BlocEstateEthCreated(address indexed blocEstateEth);

    function run() external returns (BlocEstateEth) {
        vm.startBroadcast();
        BlocEstateEth blocEstateEth = new BlocEstateEth();
        vm.stopBroadcast();
        
        emit BlocEstateEthCreated(address(blocEstateEth));
        return blocEstateEth;
    }

    //
}