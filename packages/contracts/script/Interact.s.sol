// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IBaseWorld } from "@latticexyz/world/src/codegen/interfaces/IBaseWorld.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { EphemeralInvItemTableData, EphemeralInvItemTable } from "@eveworld/world/src/codegen/tables/EphemeralInvItemTable.sol";
import { InventoryItemTableData, InventoryItemTable } from "@eveworld/world/src/codegen/tables/InventoryItemTable.sol";
import { Utils as InventoryUtils } from "@eveworld/world/src/modules/inventory/Utils.sol";
import { FRONTIER_WORLD_DEPLOYMENT_NAMESPACE } from "@eveworld/common-constants/src/constants.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";
import { Utils } from "../src/systems/Utils.sol";
import { TribeStorageSystem } from "../src/systems/TribeStorageSystem.sol";
import { CharactersTableData, CharactersTable } from "@eveworld/world/src/codegen/tables/CharactersTable.sol";
import { CharactersByAddressTable } from "@eveworld/world/src/codegen/tables/CharactersByAddressTable.sol";

contract Interact is Script {
  using InventoryUtils for bytes14;

  //Player
  uint256 playerPrivateKey;
  address player;
  uint256 tribesmenPrivateKey;
  uint256 nontribesmenPrivateKey;
  address tribesmen;
  address nontribesmen;

  //SSU ID
  uint256 smartStorageUnitId;

  //Testing
  uint64 testQuantityIn;

  function displayInventory(uint256 inventoryItemId, address user) public {
    InventoryItemTableData memory invItem = InventoryItemTable.get(smartStorageUnitId, inventoryItemId);
    console.log("[INVENTORY] Owner's Inventory [", inventoryItemId, "]: ", invItem.quantity);

    EphemeralInvItemTableData memory ephInvItem = EphemeralInvItemTable.get(smartStorageUnitId, inventoryItemId, user);
    console.log("[EPHEMERAL] Other Player's Inventory [", inventoryItemId, "]: ", ephInvItem.quantity);
  }

  function run(address worldAddress) external {
    tribesmenPrivateKey = vm.envUint("TEST_TRIBESMEN_PRIVATE_KEY");
    nontribesmenPrivateKey = vm.envUint("TEST_NONTRIBESMEN_PRIVATE_KEY");
    tribesmen = vm.addr(tribesmenPrivateKey);
    nontribesmen = vm.addr(nontribesmenPrivateKey);

    StoreSwitch.setStoreAddress(worldAddress);
    IBaseWorld world = IBaseWorld(worldAddress);

    //Read from .env
    smartStorageUnitId = vm.envUint("SSU_ID");
    uint256 inventoryItem1 = vm.envUint("ITEM_1");
    uint256 inventoryItem2 = vm.envUint("ITEM_2");
    uint256 inventoryItem3 = vm.envUint("ITEM_3");

    ResourceId systemId = Utils.smartStorageUnitSystemId();

    //Check Players ephemeral inventory before
    console.log("Inventories Before");
    displayInventory(inventoryItem1, nontribesmen);
    displayInventory(inventoryItem3, nontribesmen);
    uint256[] memory tribesmenEphemeralItems = new uint256[](1);
    uint256[] memory nontribesmenEphemeralItems = new uint256[](1);

    tribesmenEphemeralItems[0] = inventoryItem2;
    nontribesmenEphemeralItems[0] = inventoryItem3;

    vm.startBroadcast(nontribesmenPrivateKey);
    //The method below will change based on the namespace you have configurd. If the namespace is changed, make sure to update the method name

    // world.call(systemId, abi.encodeCall(TribeStorageSystem.deposit, (smartStorageUnitId, tribesmenEphemeralItems)));
    world.call(systemId, abi.encodeCall(TribeStorageSystem.deposit, (smartStorageUnitId, nontribesmenEphemeralItems)));

    world.call(systemId, abi.encodeCall(TribeStorageSystem.withdraw, (smartStorageUnitId, inventoryItem1, 5)));
    vm.stopBroadcast();
    //Check Players ephemeral inventory after

    console.log("\nInventories After");
    displayInventory(inventoryItem1, nontribesmen);
    displayInventory(inventoryItem2, nontribesmen);
  }
}
