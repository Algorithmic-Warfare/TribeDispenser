// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib, ResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";

contract PostDeploy is Script {
  IWorld world;

  using ResourceIdInstance for ResourceId;

  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    world = IWorld(worldAddress);
    ResourceId tribeDispenserSystemId = Utils.tribeDispenserSystemId();

    console.log("[SYSTEM] TribeDispenser ResourceId: ");
    console.logBytes32(tribeDispenserSystemId.unwrap());

    ResourceId tribeStorageSystemId = Utils.tribeStorageSystemId();

    console.log("[SYSTEM] TribeStorage ResourceId: ");
    console.logBytes32(tribeStorageSystemId.unwrap());

    vm.stopBroadcast();
  }
}
